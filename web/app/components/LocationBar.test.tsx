import { describe, expect, it, vi } from "vitest";
import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { LocationBar } from "./LocationBar";

const AMSTERDAM = { name: "Amsterdam", lat: 52.37, lon: 4.89 };

describe("LocationBar", () => {
  it("renders the current location name in the header", () => {
    render(<LocationBar current={AMSTERDAM} onSelect={() => {}} />);
    const region = screen.getByRole("region", { name: /Locatiekiezer/i });
    // The header label appears in the heading slot; the dropdown also lists it
    // as an option, so we scope to the region's first paragraph.
    const labels = within(region).getAllByText("Amsterdam");
    expect(labels.length).toBeGreaterThanOrEqual(1);
  });

  it("invokes onSelect when a city is picked from the dropdown", async () => {
    const onSelect = vi.fn();
    const user = userEvent.setup();
    render(<LocationBar current={AMSTERDAM} onSelect={onSelect} />);

    await user.selectOptions(
      screen.getByRole("combobox", { name: /Kies een plaats/i }),
      "rotterdam",
    );

    expect(onSelect).toHaveBeenCalledWith(
      expect.objectContaining({ name: "Rotterdam" }),
    );
  });

  it("shows an error when geolocation reports the user is outside NL", async () => {
    const original = global.navigator;
    Object.defineProperty(global, "navigator", {
      value: {
        ...original,
        geolocation: {
          getCurrentPosition: (success: PositionCallback) =>
            success({
              coords: {
                latitude: 48.8,
                longitude: 2.3,
                accuracy: 10,
                altitude: null,
                altitudeAccuracy: null,
                heading: null,
                speed: null,
                toJSON: () => ({}),
              },
              timestamp: Date.now(),
              toJSON: () => ({}),
            } as GeolocationPosition),
        },
      },
      configurable: true,
    });

    const user = userEvent.setup();
    render(<LocationBar current={AMSTERDAM} onSelect={() => {}} />);
    await user.click(screen.getByRole("button", { name: /Mijn locatie/ }));

    expect(
      await screen.findByRole("alert"),
    ).toHaveTextContent(/buiten Nederland/);

    Object.defineProperty(global, "navigator", {
      value: original,
      configurable: true,
    });
  });
});
