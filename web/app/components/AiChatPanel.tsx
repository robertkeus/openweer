/**
 * AI chat surface that lives inside the rain card (desktop) or replaces
 * the rain sheet (mobile). Streams responses from POST /api/chat via the
 * useAiChat hook.
 */

import { useEffect, useRef, useState } from "react";
import { SHORTCUT_CHIPS, type ChatContext } from "~/lib/ai-chat";
import { useAiChat } from "~/lib/use-ai-chat";
import { ChatMarkdown } from "./ChatMarkdown";

interface Props {
  context: ChatContext;
}

export function AiChatPanel({ context }: Props) {
  const composerRef = useRef<HTMLTextAreaElement>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const [draft, setDraft] = useState("");
  const { messages, pending, error, isStreaming, send, cancel, reset } =
    useAiChat();
  const hasConversation = messages.length > 0 || pending !== null;

  function clearConversation() {
    reset();
    setDraft("");
    composerRef.current?.focus();
  }

  // Auto-scroll to the bottom whenever new content lands.
  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollTo({ top: el.scrollHeight, behavior: "smooth" });
  }, [messages, pending]);

  function submit(prompt: string) {
    void send(prompt, context);
  }

  return (
    <div className="flex flex-col h-full">
      {/* Messages */}
      <div
        ref={scrollRef}
        className="relative flex-1 overflow-y-auto px-4 py-3 space-y-3"
        aria-live="polite"
      >
        {messages.length === 0 && !pending ? (
          <div className="text-sm text-[--color-ink-700]">
            <p className="mb-3">
              Vraag iets over het weer op{" "}
              <span className="font-semibold text-[--color-ink-900]">
                {context.location_name}
              </span>
              , of kies hieronder een snelkoppeling.
            </p>
            <ul className="grid gap-2">
              {SHORTCUT_CHIPS.map((chip) => (
                <li key={chip.label}>
                  <button
                    type="button"
                    onClick={() => submit(chip.prompt)}
                    className="chat-shortcut-chip w-full text-left"
                  >
                    <span aria-hidden="true" className="mr-2">
                      {chip.emoji}
                    </span>
                    {chip.label}
                  </button>
                </li>
              ))}
            </ul>
          </div>
        ) : null}

        {messages.map((m, i) => (
          <Bubble key={i} from={m.role} content={m.content} />
        ))}
        {pending !== null ? (
          <Bubble from="assistant" content={pending || "…"} streaming />
        ) : null}
        {error ? (
          <p
            role="alert"
            className="rounded-xl px-3 py-2 text-sm"
            style={{
              background: "var(--color-danger-bg)",
              color: "var(--color-danger-fg)",
            }}
          >
            {error}
          </p>
        ) : null}
      </div>

      {/* Composer */}
      <form
        className="border-t border-[--color-border] px-3 py-2 flex items-end gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          const value = draft.trim();
          if (!value) return;
          setDraft("");
          submit(value);
          composerRef.current?.focus();
        }}
      >
        {hasConversation ? (
          <button
            type="button"
            onClick={clearConversation}
            aria-label="Wis het gesprek"
            title="Wis het gesprek"
            className="btn-secondary inline-grid place-items-center h-10 w-10 rounded-full flex-none"
          >
            <ResetIcon className="h-4 w-4" />
          </button>
        ) : null}
        <textarea
          ref={composerRef}
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !e.shiftKey) {
              e.preventDefault();
              const value = draft.trim();
              if (!value) return;
              setDraft("");
              submit(value);
            }
          }}
          rows={1}
          aria-label="Stel een vraag aan de AI"
          placeholder="Stel een vraag…"
          className="flex-1 max-h-32 resize-none rounded-2xl bg-[--color-ink-50] px-3 py-2 text-sm leading-snug placeholder:text-[--color-ink-700] focus:outline focus:outline-2 focus:outline-[--color-accent-500]"
        />
        {isStreaming ? (
          <button
            type="button"
            onClick={cancel}
            aria-label="Stop het antwoord"
            className="btn-secondary inline-grid place-items-center h-10 w-10 rounded-full"
          >
            <StopIcon className="h-4 w-4" />
          </button>
        ) : (
          <button
            type="submit"
            disabled={!draft.trim()}
            aria-label="Verzend bericht"
            className="btn-primary inline-grid place-items-center h-10 w-10 rounded-full"
          >
            <SendIcon className="h-4 w-4" />
          </button>
        )}
      </form>
    </div>
  );
}

function Bubble({
  from,
  content,
  streaming,
}: {
  from: "user" | "assistant";
  content: string;
  streaming?: boolean;
}) {
  const isUser = from === "user";
  return (
    <div className={`flex ${isUser ? "justify-end" : "justify-start"}`}>
      <div
        className={
          isUser
            ? "chat-bubble chat-bubble-user"
            : `chat-bubble chat-bubble-assistant ${streaming ? "chat-bubble--streaming" : ""}`
        }
      >
        {isUser ? content : <ChatMarkdown text={content} />}
      </div>
    </div>
  );
}

function SendIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <path
        d="M3 12l18-9-7 18-3-7-8-2z"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinejoin="round"
        fill="currentColor"
        fillOpacity="0.2"
      />
    </svg>
  );
}

function StopIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <rect x="6" y="6" width="12" height="12" rx="2" fill="currentColor" />
    </svg>
  );
}

function ResetIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <path
        d="M4 12a8 8 0 1 1 2.5 5.8"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        fill="none"
      />
      <path
        d="M3 5v5h5"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
        fill="none"
      />
    </svg>
  );
}
