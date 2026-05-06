import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { Frame, RainSample } from "~/lib/api";
import { Timeline } from "./Timeline";

const f = (id: string, kind: Frame["kind"], iso: string): Frame => ({
  id,
  ts: iso,
  kind,
  cadence_minutes: 5,
  max_zoom: 10,
});

const FRAMES: Frame[] = [
  f("a", "observed", "2026-05-03T06:25Z"),
  f("b", "observed", "2026-05-03T06:30Z"),
  f("c", "nowcast", "2026-05-03T06:35Z"),
];

const SAMPLES: RainSample[] = [
  { minutes_ahead: 0, mm_per_h: 0.4, valid_at: "2026-05-03T06:30Z" },
  { minutes_ahead: 5, mm_per_h: 1.2, valid_at: "2026-05-03T06:35Z" },
];

describe("Timeline", () => {
  it("renders a play button at rest", () => {
    render(
      <Timeline
        frames={FRAMES}
        currentIndex={1}
        isPlaying={false}
        onSeek={() => {}}
        onTogglePlay={() => {}}
      />,
    );
    expect(
      screen.getByRole("button", { name: /Speel af/ }),
    ).toBeInTheDocument();
  });

  it("opens with the cursor at nowIndex via aria-valuenow", () => {
    render(
      <Timeline
        frames={FRAMES}
        currentIndex={2}
        nowIndex={2}
        isPlaying={false}
        onSeek={() => {}}
        onTogglePlay={() => {}}
      />,
    );
    expect(screen.getByRole("slider")).toHaveAttribute("aria-valuenow", "2");
  });

  it("calls onSeek when the slider is dragged", () => {
    const onSeek = vi.fn();
    render(
      <Timeline
        frames={FRAMES}
        currentIndex={0}
        isPlaying={false}
        onSeek={onSeek}
        onTogglePlay={() => {}}
      />,
    );
    const slider = screen.getByRole("slider");
    fireEvent.change(slider, { target: { value: "2" } });
    expect(onSeek).toHaveBeenCalledWith(2);
  });

  it("calls onTogglePlay when the play button is clicked", async () => {
    const onTogglePlay = vi.fn();
    const user = userEvent.setup();
    render(
      <Timeline
        frames={FRAMES}
        currentIndex={1}
        isPlaying={false}
        onSeek={() => {}}
        onTogglePlay={onTogglePlay}
      />,
    );
    await user.click(screen.getByRole("button", { name: /Speel af/ }));
    expect(onTogglePlay).toHaveBeenCalledOnce();
  });

  it("toggles play with the space-bar shortcut while focused", () => {
    const onTogglePlay = vi.fn();
    render(
      <Timeline
        frames={FRAMES}
        currentIndex={1}
        isPlaying={false}
        onSeek={() => {}}
        onTogglePlay={onTogglePlay}
      />,
    );
    fireEvent.keyDown(screen.getByRole("slider"), { key: " " });
    expect(onTogglePlay).toHaveBeenCalledOnce();
  });

  it("shows pause label when playing", () => {
    render(
      <Timeline
        frames={FRAMES}
        currentIndex={0}
        isPlaying={true}
        onSeek={() => {}}
        onTogglePlay={() => {}}
      />,
    );
    expect(screen.getByRole("button", { name: /Pauzeer/ })).toBeInTheDocument();
  });

  it("renders nothing when there are no frames", () => {
    const { container } = render(
      <Timeline
        frames={[]}
        currentIndex={0}
        isPlaying={false}
        onSeek={() => {}}
        onTogglePlay={() => {}}
      />,
    );
    expect(container).toBeEmptyDOMElement();
  });

  it("exposes the current frame's time as the slider's aria-valuetext", () => {
    render(
      <Timeline
        frames={FRAMES}
        currentIndex={1}
        nowIndex={1}
        isPlaying={false}
        onSeek={() => {}}
        onTogglePlay={() => {}}
      />,
    );
    // 06:30 UTC == 08:30 Europe/Amsterdam (CEST in May)
    const valueText = screen.getByRole("slider").getAttribute("aria-valuetext");
    expect(valueText).toContain("08:30");
  });

  it("renders intensity bars when rain samples are provided", () => {
    const { container } = render(
      <Timeline
        frames={FRAMES}
        currentIndex={1}
        nowIndex={1}
        isPlaying={false}
        rainSamples={SAMPLES}
        onSeek={() => {}}
        onTogglePlay={() => {}}
      />,
    );
    // One bar per frame.
    const bars = container.querySelectorAll(
      "[data-testid='intensity-bars'] > span",
    );
    expect(bars.length).toBe(FRAMES.length);
  });

  it("handles empty rain-sample arrays without crashing", () => {
    render(
      <Timeline
        frames={FRAMES}
        currentIndex={1}
        nowIndex={1}
        isPlaying={false}
        rainSamples={[]}
        onSeek={() => {}}
        onTogglePlay={() => {}}
      />,
    );
    expect(screen.getByRole("slider")).toBeInTheDocument();
  });
});
