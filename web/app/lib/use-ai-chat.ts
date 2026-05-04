import { useCallback, useRef, useState } from "react";
import type { ChatContext, ChatRequestBody, ChatTurn } from "./ai-chat";

interface UseAiChatResult {
  messages: ChatTurn[];
  pending: string | null;
  error: string | null;
  isStreaming: boolean;
  send: (prompt: string, ctx: ChatContext) => Promise<void>;
  cancel: () => void;
  reset: () => void;
}

/**
 * Reads the SSE stream returned by `POST /api/chat`. Each `data: {...}` line
 * either carries an OpenAI-style delta (`choices[0].delta.content`) or our
 * own `{error: "..."}` envelope from the proxy.
 */
export function useAiChat(): UseAiChatResult {
  const [messages, setMessages] = useState<ChatTurn[]>([]);
  const [pending, setPending] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isStreaming, setIsStreaming] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  const cancel = useCallback(() => {
    abortRef.current?.abort();
    abortRef.current = null;
    setIsStreaming(false);
    setPending(null);
  }, []);

  const reset = useCallback(() => {
    abortRef.current?.abort();
    abortRef.current = null;
    setMessages([]);
    setPending(null);
    setError(null);
    setIsStreaming(false);
  }, []);

  const send = useCallback(
    async (prompt: string, ctx: ChatContext) => {
      const trimmed = prompt.trim();
      if (!trimmed || isStreaming) return;

      const userTurn: ChatTurn = { role: "user", content: trimmed };
      const history = [...messages, userTurn];
      setMessages(history);
      setError(null);
      setPending("");
      setIsStreaming(true);

      const ctrl = new AbortController();
      abortRef.current = ctrl;

      const body: ChatRequestBody = { messages: history, context: ctx };

      try {
        const res = await fetch("/api/chat", {
          method: "POST",
          headers: { "content-type": "application/json", accept: "text/event-stream" },
          body: JSON.stringify(body),
          signal: ctrl.signal,
        });
        if (!res.ok || !res.body) {
          setError(
            res.status === 503
              ? "De AI-assistent is nog niet geconfigureerd."
              : "De AI-assistent kon je vraag niet beantwoorden.",
          );
          setPending(null);
          setIsStreaming(false);
          return;
        }

        const reader = res.body.getReader();
        const decoder = new TextDecoder();
        let buffer = "";
        let assembled = "";

        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          // SSE messages are separated by blank lines.
          const events = buffer.split(/\r?\n\r?\n/);
          buffer = events.pop() ?? "";
          for (const ev of events) {
            const dataLines = ev
              .split(/\r?\n/)
              .filter((l) => l.startsWith("data:"))
              .map((l) => l.slice(5).trim());
            for (const data of dataLines) {
              if (!data || data === "[DONE]") continue;
              try {
                const json = JSON.parse(data);
                if (typeof json.error === "string") {
                  setError(json.error);
                  continue;
                }
                const delta = json?.choices?.[0]?.delta?.content;
                if (typeof delta === "string" && delta.length > 0) {
                  assembled += delta;
                  setPending(assembled);
                }
              } catch {
                // Ignore unparsable chunks — provider sometimes emits keep-alives.
              }
            }
          }
        }

        if (assembled) {
          setMessages((prev) => [
            ...prev,
            { role: "assistant", content: assembled },
          ]);
        }
        setPending(null);
        setIsStreaming(false);
      } catch (err) {
        if ((err as Error).name === "AbortError") {
          setPending(null);
          setIsStreaming(false);
          return;
        }
        setError("De verbinding met de AI viel weg.");
        setPending(null);
        setIsStreaming(false);
      } finally {
        abortRef.current = null;
      }
    },
    [messages, isStreaming],
  );

  return { messages, pending, error, isStreaming, send, cancel, reset };
}
