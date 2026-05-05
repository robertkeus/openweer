/**
 * Typed fetcher for the OpenWeer JSON API.
 *
 * On the server the loader uses INTERNAL_API_URL (the docker-compose service
 * name); in the browser everything goes through Caddy at the same origin.
 */

import { z } from "zod";

const isServer = typeof window === "undefined";

/**
 * Resolves the SSR-side base URL only when actually needed; `process.env`
 * doesn't exist in the browser bundle, so we never touch it client-side.
 */
function serverBase(): string {
  if (typeof process === "undefined" || !process.env) return "";
  return (
    process.env.OPENWEER_INTERNAL_API_URL ??
    process.env.OPENWEER_API_URL ??
    "http://127.0.0.1:8000"
  );
}

function url(path: string): string {
  if (!path.startsWith("/")) {
    throw new Error(`API path must start with "/": ${path}`);
  }
  return isServer ? `${serverBase()}${path}` : path;
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

const ConditionKindSchema = z.enum([
  "clear",
  "partly-cloudy",
  "cloudy",
  "fog",
  "drizzle",
  "rain",
  "thunder",
  "snow",
  "unknown",
]);

const WeatherStationSchema = z.object({
  name: z.string(),
  id: z.string(),
  lat: z.number(),
  lon: z.number(),
  distance_km: z.number(),
});

const CurrentWeatherSchema = z.object({
  observed_at: z.string(),
  temperature_c: z.number().nullable(),
  feels_like_c: z.number().nullable(),
  condition: ConditionKindSchema,
  condition_label: z.string(),
  wind_speed_mps: z.number().nullable(),
  wind_speed_bft: z.number().int().nullable(),
  wind_direction_deg: z.number().nullable(),
  wind_direction_compass: z.string().nullable(),
  humidity_pct: z.number().nullable(),
  pressure_hpa: z.number().nullable(),
  rainfall_1h_mm: z.number().nullable(),
  rainfall_24h_mm: z.number().nullable(),
  cloud_cover_octas: z.number().nullable(),
  visibility_m: z.number().nullable(),
});

export const WeatherResponseSchema = z.object({
  station: WeatherStationSchema,
  current: CurrentWeatherSchema,
});

export type ConditionKind = z.infer<typeof ConditionKindSchema>;
export type WeatherStation = z.infer<typeof WeatherStationSchema>;
export type CurrentWeather = z.infer<typeof CurrentWeatherSchema>;
export type WeatherResponse = z.infer<typeof WeatherResponseSchema>;

const DailyForecastSchema = z.object({
  date: z.string(),
  weather_code: z.number().int().nullable(),
  temperature_max_c: z.number().nullable(),
  temperature_min_c: z.number().nullable(),
  precipitation_sum_mm: z.number().nullable(),
  precipitation_probability_pct: z.number().int().nullable(),
  wind_max_kph: z.number().nullable(),
  wind_direction_deg: z.number().int().nullable(),
  sunrise: z.string().nullable(),
  sunset: z.string().nullable(),
  source: z.string().nullable().optional(),
});

export const ForecastResponseSchema = z.object({
  lat: z.number(),
  lon: z.number(),
  source: z.string(),
  days: z.array(DailyForecastSchema),
});

export type DailyForecast = z.infer<typeof DailyForecastSchema>;
export type ForecastResponse = z.infer<typeof ForecastResponseSchema>;

// ---- public API ----

export const api = {
  health: () => fetchJson("/api/health", HealthResponseSchema),
  frames: () => fetchJson("/api/frames", FramesResponseSchema),
  rain: (lat: number, lon: number) =>
    fetchJson(
      `/api/rain/${lat.toFixed(4)}/${lon.toFixed(4)}`,
      RainResponseSchema,
    ),
  weather: (lat: number, lon: number) =>
    fetchJson(
      `/api/weather/${lat.toFixed(4)}/${lon.toFixed(4)}`,
      WeatherResponseSchema,
    ),
  forecast: (lat: number, lon: number) =>
    fetchJson(
      `/api/forecast/${lat.toFixed(4)}/${lon.toFixed(4)}`,
      ForecastResponseSchema,
    ),
};
