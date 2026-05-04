"""POST /api/chat — context-aware AI chat proxy to GreenPT.

The browser never sees the upstream API key. We accept the user's chat
history + the live weather context, build the system prompt server-side,
and stream the OpenAI-compatible SSE response straight back. SSRF is
guarded by the allowlist in `knmi/_security.py`.
"""

from __future__ import annotations

import json
from collections.abc import AsyncIterator
from typing import Annotated, Literal

import httpx
import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from openweer.api.dependencies import AppState, get_state
from openweer.api.routes._chat_prompt import ChatContext, build_system_prompt
from openweer.knmi._security import UrlNotAllowedError, assert_greenpt_url

router = APIRouter(prefix="/api", tags=["chat"])
log = structlog.get_logger("openweer.chat")

_GREENPT_URL = "https://api.greenpt.ai/v1/chat/completions"
_REQUEST_TIMEOUT = httpx.Timeout(60.0, connect=10.0)
_MAX_TURNS = 20
_MAX_CONTENT_LEN = 4000


class ChatTurn(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=_MAX_CONTENT_LEN)


class ChatRequest(BaseModel):
    """Body posted by the browser. `messages` excludes any client-supplied
    system message — the server adds it from `context`."""

    messages: list[ChatTurn] = Field(min_length=1, max_length=_MAX_TURNS)
    context: ChatContext


@router.post("/chat")
async def chat(
    payload: ChatRequest,
    state: Annotated[AppState, Depends(get_state)],
) -> StreamingResponse:
    settings = state.settings
    try:
        api_key = settings.require_greenpt_key()
    except RuntimeError as exc:
        # Missing secret — surface a clean 503 in Dutch, no leak.
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="De AI-assistent is nog niet geconfigureerd.",
        ) from exc

    try:
        upstream_url = assert_greenpt_url(_GREENPT_URL)
    except UrlNotAllowedError:
        # Defence in depth: should never trigger because _GREENPT_URL is a constant.
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="De AI-host is niet toegestaan.",
        )

    body = {
        "model": settings.greenpt_model,
        "stream": True,
        "messages": [
            {"role": "system", "content": build_system_prompt(payload.context)},
            *(turn.model_dump() for turn in payload.messages),
        ],
    }

    async def proxy() -> AsyncIterator[bytes]:
        try:
            async with httpx.AsyncClient(timeout=_REQUEST_TIMEOUT) as client:
                async with client.stream(
                    "POST",
                    upstream_url,
                    headers={
                        "Authorization": f"Bearer {api_key}",
                        "Accept": "text/event-stream",
                        "Content-Type": "application/json",
                    },
                    content=json.dumps(body),
                ) as resp:
                    if resp.status_code == 429:
                        yield _sse_error(
                            "De AI-assistent is even druk. Probeer het zo opnieuw."
                        )
                        return
                    if resp.status_code >= 400:
                        # Drop upstream body — never leak provider error details
                        # (could include account / billing info).
                        log.warning(
                            "chat.upstream_error",
                            status=resp.status_code,
                        )
                        yield _sse_error(
                            "De AI-assistent kon je vraag niet beantwoorden."
                        )
                        return
                    async for chunk in resp.aiter_lines():
                        if not chunk:
                            # SSE event boundary — preserve it.
                            yield b"\n"
                            continue
                        # Forward only `data:` lines. GreenPT's spec mirrors OpenAI;
                        # any other server lines (`event:`, comments) are dropped.
                        if chunk.startswith("data:"):
                            yield (chunk + "\n\n").encode("utf-8")
        except httpx.HTTPError as exc:
            log.warning("chat.transport_error", error=type(exc).__name__)
            yield _sse_error("De verbinding met de AI viel weg.")

    return StreamingResponse(
        proxy(),
        media_type="text/event-stream",
        headers={
            # Disable proxy buffering so chunks reach the browser as they land.
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )


def _sse_error(message: str) -> bytes:
    """Encode a Dutch error as a single SSE `data:` event the frontend renders."""
    payload = json.dumps({"error": message})
    return f"data: {payload}\n\n".encode("utf-8")
