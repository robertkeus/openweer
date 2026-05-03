import { describe, expect, it, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import type { Frame } from "~/lib/api";
import { TimeSlider } from "./TimeSlider";

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

describe("TimeSlider", () => {
  it("renders a play button at rest", () => {
    render(
      <TimeSlider
        frames={FRAMES}
        currentIndex={1}
        isPlaying={false}
        onSeek={() => {}}
        onTogglePlay={() => {}}
      />,
    );
    expect(screen.getByRole("button", { name: /Speel af/ })).toBeInTheDocument();
  });

  it("calls onSeek when slider changes", () => {
    const onSeek = vi.fn();
    render(
      <TimeSlider
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
      <TimeSlider
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

  it("shows pause label when playing", () => {
    render(
      <TimeSlider
        frames={FRAMES}
        currentIndex={0}
        isPlaying={true}
        onSeek={() => {}}
        onTogglePlay={() => {}}
      />,
    );
    expect(
      screen.getByRole("button", { name: /Pauzeer/ }),
    ).toBeInTheDocument();
  });

  it("renders nothing when there are no frames", () => {
    const { container } = render(
      <TimeSlider
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
      <TimeSlider
        frames={FRAMES}
        currentIndex={1}
        nowIndex={1}
        isPlaying={false}
        onSeek={() => {}}
        onTogglePlay={() => {}}
      />,
    );
    // 06:30 UTC == 08:30 Europe/Amsterdam (CEST in May)
    const valueText = screen
      .getByRole("slider")
      .getAttribute("aria-valuetext");
    expect(valueText).toContain("08:30");
  });
});
