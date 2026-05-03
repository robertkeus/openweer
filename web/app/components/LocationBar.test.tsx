import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { LocationBar } from "./LocationBar";

const AMSTERDAM = { name: "Amsterdam", lat: 52.37, lon: 4.89 };

describe("LocationBar", () => {
  it("shows the current location name as the search placeholder", () => {
    render(<LocationBar current={AMSTERDAM} onSelect={() => {}} />);
    const input = screen.getByRole("combobox", { name: /Zoek een plaats/i });
    expect(input).toHaveAttribute("placeholder", "Amsterdam");
  });

  it("invokes onSelect when a known city is picked from the suggestions", async () => {
    const onSelect = vi.fn();
    const user = userEvent.setup();
    render(<LocationBar current={AMSTERDAM} onSelect={onSelect} />);

    const input = screen.getByRole("combobox", { name: /Zoek een plaats/i });
    await user.click(input);
    await user.type(input, "Rott");

    const option = await screen.findByRole("option", { name: /Rotterdam/ });
    await user.click(option);

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
    await user.click(
      screen.getByRole("button", { name: /Gebruik mijn huidige locatie/ }),
    );

    expect(await screen.findByRole("alert")).toHaveTextContent(
      /buiten Nederland/,
    );

    Object.defineProperty(global, "navigator", {
      value: original,
      configurable: true,
    });
  });
});
