/**
 * Typed fetcher for the OpenWeer JSON API.
 *
 * On the server the loader uses INTERNAL_API_URL (the docker-compose service
 * name); in the browser everything goes through Caddy at the same origin.
 */

import { z } from "zod";

const isServer = typeof window === "undefined";

const SERVER_BASE =
  process.env.OPENWEER_INTERNAL_API_URL ??
  process.env.OPENWEER_API_URL ??
  "http://127.0.0.1:8000";

function url(path: string): string {
  if (!path.startsWith("/")) {
    throw new Error(`API path must start with "/": ${path}`);
  }
  return isServer ? `${SERVER_BASE}${path}` : path;
}

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly path: string,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

async function fetchJson<T>(path: string, schema: z.ZodSchema<T>): Promise<T> {
  const res = await fetch(url(path), {
    headers: { accept: "application/json" },
  });
  if (!res.ok) {
    throw new ApiError(res.status, path, `${path} returned ${res.status}`);
  }
  return schema.parse(await res.json());
}

// ---- schemas mirror the FastAPI response models ----

export const FrameSchema = z.object({
  id: z.string(),
  ts: z.string(),
  kind: z.enum(["observed", "nowcast", "hourly"]),
  cadence_minutes: z.number(),
  max_zoom: z.number(),
});

export const FramesResponseSchema = z.object({
  frames: z.array(FrameSchema),
  generated_at: z.string(),
});

export type Frame = z.infer<typeof FrameSchema>;
export type FramesResponse = z.infer<typeof FramesResponseSchema>;

export const RainSampleSchema = z.object({
  minutes_ahead: z.number(),
  mm_per_h: z.number(),
  valid_at: z.string(),
});

export const RainResponseSchema = z.object({
  lat: z.number(),
  lon: z.number(),
  analysis_at: z.string(),
  samples: z.array(RainSampleSchema),
});

export type RainSample = z.infer<typeof RainSampleSchema>;
export type RainResponse = z.infer<typeof RainResponseSchema>;

const DatasetFreshnessSchema = z.object({
  dataset: z.string(),
  filename: z.string().nullable(),
  ingested_at: z.string().nullable(),
});

export const HealthResponseSchema = z.object({
  ok: z.boolean(),
  version: z.string(),
  datasets: z.array(DatasetFreshnessSchema),
});

export type HealthResponse = z.infer<typeof HealthResponseSchema>;

// ---- public API ----

export const api = {
  health: () => fetchJson("/api/health", HealthResponseSchema),
  frames: () => fetchJson("/api/frames", FramesResponseSchema),
  rain: (lat: number, lon: number) =>
    fetchJson(
      `/api/rain/${lat.toFixed(4)}/${lon.toFixed(4)}`,
      RainResponseSchema,
    ),
};
