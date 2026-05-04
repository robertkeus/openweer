import type { Frame, RainResponse } from "./api";

export interface ChatTurn {
  role: "user" | "assistant";
  content: string;
}

export interface ChatContext {
  location_name: string;
  lat: number;
  lon: number;
  cursor_at: string | null;
  samples: Array<{
    minutes_ahead: number;
    mm_per_h: number;
    valid_at: string;
  }>;
  language: "nl" | "en";
  theme: "light" | "dark";
}

export interface ChatRequestBody {
  messages: ChatTurn[];
  context: ChatContext;
}

/** Quick-shortcut chips: visible label vs the prompt the model actually receives. */
export interface ShortcutChip {
  emoji: string;
  label: string;
  prompt: string;
}

export const SHORTCUT_CHIPS: readonly ShortcutChip[] = [
  {
    emoji: "☂️",
    label: "Wanneer kan ik droog naar buiten?",
    prompt:
      "Op basis van de huidige neerslagverwachting voor mijn locatie, wanneer is het komende 2 uur het meest droog?",
  },
  {
    emoji: "🚲",
    label: "Kan ik nu fietsen?",
    prompt:
      "Is het verstandig om de komende 30 minuten te fietsen op mijn locatie? Houd rekening met regen en intensiteit.",
  },
  {
    emoji: "🌧️",
    label: "Leg het weer uit",
    prompt:
      "Leg het huidige weerbeeld op mijn locatie in begrijpelijke taal uit. Geef ook tips voor de komende 2 uur.",
  },
  {
    emoji: "📍",
    label: "Vergelijk met steden in de buurt",
    prompt:
      "Vergelijk de regen op mijn locatie met andere grote steden in Nederland. Waar is het droger?",
  },
];

export function buildContext(opts: {
  location: { name: string; lat: number; lon: number };
  rain: RainResponse | null;
  cursorFrame: Frame | undefined;
  language?: "nl" | "en";
  theme?: "light" | "dark";
}): ChatContext {
  return {
    location_name: opts.location.name,
    // Round to 2 decimals on the wire for privacy (CLAUDE.md A09 nudge).
    lat: Math.round(opts.location.lat * 100) / 100,
    lon: Math.round(opts.location.lon * 100) / 100,
    cursor_at: opts.cursorFrame?.ts ?? null,
    samples: (opts.rain?.samples ?? []).map((s) => ({
      minutes_ahead: s.minutes_ahead,
      mm_per_h: s.mm_per_h,
      valid_at: s.valid_at,
    })),
    language: opts.language ?? "nl",
    theme: opts.theme ?? "light",
  };
}
