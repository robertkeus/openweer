import { describe, expect, it } from "vitest";
import { render } from "@testing-library/react";
import { ChatMarkdown } from "./ChatMarkdown";

describe("ChatMarkdown", () => {
  it("splits double newlines into separate paragraphs", () => {
    const { container } = render(
      <ChatMarkdown text={"Hallo wereld.\n\nTweede alinea hier."} />,
    );
    const paragraphs = container.querySelectorAll("p");
    expect(paragraphs.length).toBe(2);
    expect(paragraphs[0].textContent).toBe("Hallo wereld.");
    expect(paragraphs[1].textContent).toBe("Tweede alinea hier.");
  });

  it("renders **bold** as <strong>", () => {
    const { container } = render(
      <ChatMarkdown text={"**Tips voor straks:** blijf binnen."} />,
    );
    const strong = container.querySelector("strong");
    expect(strong?.textContent).toBe("Tips voor straks:");
  });

  it("renders *italic* as <em>", () => {
    const { container } = render(
      <ChatMarkdown text={"Het wordt *waarschijnlijk* droog."} />,
    );
    const em = container.querySelector("em");
    expect(em?.textContent).toBe("waarschijnlijk");
  });

  it("renders bullet lists", () => {
    const text = "Tips:\n\n- pak een jas\n- check de slider\n- ga met de fiets";
    const { container } = render(<ChatMarkdown text={text} />);
    const list = container.querySelector("ul.chat-md-list");
    expect(list).toBeTruthy();
    expect(list?.querySelectorAll("li").length).toBe(3);
    expect(list?.querySelectorAll("li")[2].textContent).toBe(
      "ga met de fiets",
    );
  });

  it("renders ordered lists", () => {
    const { container } = render(
      <ChatMarkdown text={"1. eerste\n2. tweede\n3. derde"} />,
    );
    const ol = container.querySelector("ol.chat-md-list");
    expect(ol?.querySelectorAll("li").length).toBe(3);
  });

  it("renders inline `code`", () => {
    const { container } = render(
      <ChatMarkdown text={"De waarde was `3,2 mm/u`."} />,
    );
    expect(container.querySelector("code")?.textContent).toBe("3,2 mm/u");
  });

  it("does not execute embedded HTML (XSS guard)", () => {
    const { container } = render(
      <ChatMarkdown text={"Voorzichtig: <script>alert(1)</script>"} />,
    );
    // No <script> child; the literal stays as text content.
    expect(container.querySelector("script")).toBeNull();
    expect(container.textContent).toContain("<script>alert(1)</script>");
  });

  it("ignores stray asterisks without a closing pair", () => {
    const { container } = render(
      <ChatMarkdown text={"5*2 is tien, en *dit blijft tekst."} />,
    );
    expect(container.querySelector("em")).toBeNull();
    expect(container.textContent).toContain("5*2 is tien");
  });
});
