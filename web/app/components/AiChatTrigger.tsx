interface Props {
  onClick: () => void;
}

/** Small chat-bubble button rendered inside the "Verwachting" row. */
export function AiChatTrigger({ onClick }: Props) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-label="Vraag de AI-assistent over het weer"
      className="inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold text-[--color-accent-600] hover:bg-[--color-accent-500]/10 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[--color-accent-500] transition-colors"
    >
      <ChatIcon className="h-3.5 w-3.5" />
      Vraag de AI
    </button>
  );
}

function ChatIcon(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <path
        d="M5 5h14a2 2 0 012 2v8a2 2 0 01-2 2h-8l-4 4v-4H5a2 2 0 01-2-2V7a2 2 0 012-2z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinejoin="round"
        fill="currentColor"
        fillOpacity="0.12"
      />
      <circle cx="9" cy="11" r="1" fill="currentColor" />
      <circle cx="13" cy="11" r="1" fill="currentColor" />
      <circle cx="17" cy="11" r="1" fill="currentColor" />
    </svg>
  );
}
