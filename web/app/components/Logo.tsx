export function Logo(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" {...props}>
      <g
        className="opacity-0 scale-50 origin-[17px_7px] translate-x-[-3px] translate-y-[2px]
                   transition-all duration-300 ease-out
                   group-hover:opacity-100 group-hover:scale-100 group-hover:translate-x-0 group-hover:translate-y-0"
      >
        <circle cx="17" cy="7" r="3" fill="var(--color-sun-400)" />
        <g
          stroke="var(--color-sun-400)"
          strokeWidth="1.25"
          strokeLinecap="round"
        >
          <line x1="17" y1="2" x2="17" y2="3.5" />
          <line x1="12" y1="7" x2="13.5" y2="7" />
          <line x1="13.5" y1="3.5" x2="14.5" y2="4.5" />
          <line x1="20.5" y1="3.5" x2="19.5" y2="4.5" />
        </g>
      </g>

      <path
        d="M5 14a4 4 0 014-4 5 5 0 019.5 1.5A3.5 3.5 0 1118 18H8a3 3 0 01-3-4z"
        fill="var(--color-accent-600)"
      />

      <g
        className="opacity-0 translate-y-[-3px]
                   transition-all duration-300 ease-out
                   group-hover:opacity-100 group-hover:translate-y-0"
        fill="var(--color-accent-500)"
      >
        <circle cx="9" cy="21" r="0.9" />
        <circle cx="13" cy="22" r="0.9" />
        <circle cx="17" cy="21" r="0.9" />
      </g>
    </svg>
  );
}
