/**
 * Tiny, XSS-safe markdown renderer for the chat bubble subset that GreenPT
 * actually emits: paragraphs, bullet/numbered lists, bold, italic, inline
 * code. Returns React nodes (no innerHTML, no dangerouslySetInnerHTML), so
 * any HTML in the model output renders as plain text.
 */

import { Fragment, type ReactNode } from "react";

interface Props {
  text: string;
}

export function ChatMarkdown({ text }: Props) {
  const blocks = parseBlocks(text);
  return (
    <>
      {blocks.map((block, i) => (
        <Fragment key={i}>{renderBlock(block)}</Fragment>
      ))}
    </>
  );
}

interface ParagraphBlock {
  kind: "p";
  text: string;
}
interface ListBlock {
  kind: "ul" | "ol";
  items: string[];
}
type Block = ParagraphBlock | ListBlock;

function parseBlocks(input: string): Block[] {
  const blocks: Block[] = [];
  // Normalise line endings + collapse 3+ blank lines.
  const lines = input.replace(/\r\n/g, "\n").split("\n");

  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (line.trim() === "") {
      i++;
      continue;
    }
    const bulletMatch = line.match(/^\s*[-*]\s+(.+)$/);
    const orderedMatch = line.match(/^\s*\d+[.)]\s+(.+)$/);
    if (bulletMatch || orderedMatch) {
      const kind: "ul" | "ol" = bulletMatch ? "ul" : "ol";
      const items: string[] = [];
      while (i < lines.length) {
        const m =
          kind === "ul"
            ? lines[i].match(/^\s*[-*]\s+(.+)$/)
            : lines[i].match(/^\s*\d+[.)]\s+(.+)$/);
        if (!m) break;
        items.push(m[1].trim());
        i++;
      }
      blocks.push({ kind, items });
      continue;
    }
    // Greedy paragraph: gather until next blank line OR list start.
    const paragraphLines: string[] = [line];
    i++;
    while (i < lines.length) {
      const next = lines[i];
      if (next.trim() === "") break;
      if (/^\s*[-*]\s+/.test(next) || /^\s*\d+[.)]\s+/.test(next)) break;
      paragraphLines.push(next);
      i++;
    }
    blocks.push({ kind: "p", text: paragraphLines.join(" ") });
  }
  return blocks;
}

function renderBlock(block: Block): ReactNode {
  if (block.kind === "p") {
    return <p>{renderInline(block.text)}</p>;
  }
  if (block.kind === "ul") {
    return (
      <ul className="chat-md-list">
        {block.items.map((item, i) => (
          <li key={i}>{renderInline(item)}</li>
        ))}
      </ul>
    );
  }
  return (
    <ol className="chat-md-list">
      {block.items.map((item, i) => (
        <li key={i}>{renderInline(item)}</li>
      ))}
    </ol>
  );
}

/**
 * Inline parser — bold, italic, inline code. Walks through a string and
 * emits an array of React nodes. No regex replace + dangerouslySetInnerHTML;
 * nodes are constructed directly so any literal `<` stays literal.
 */
function renderInline(input: string): ReactNode[] {
  const nodes: ReactNode[] = [];
  let buffer = "";
  let i = 0;
  let key = 0;

  const flush = () => {
    if (buffer) {
      nodes.push(buffer);
      buffer = "";
    }
  };

  while (i < input.length) {
    const c = input[i];
    // Inline code: `…`
    if (c === "`") {
      const end = input.indexOf("`", i + 1);
      if (end !== -1) {
        flush();
        nodes.push(<code key={key++}>{input.slice(i + 1, end)}</code>);
        i = end + 1;
        continue;
      }
    }
    // Bold: **…**
    if (c === "*" && input[i + 1] === "*") {
      const end = input.indexOf("**", i + 2);
      if (end !== -1) {
        flush();
        nodes.push(
          <strong key={key++}>{renderInline(input.slice(i + 2, end))}</strong>,
        );
        i = end + 2;
        continue;
      }
    }
    // Italic: *…* or _…_ — must not be inside the bold case above.
    // Only opens at a word boundary so "5*2" / "en *zonder sluiting" stay literal.
    if ((c === "*" || c === "_") && input[i + 1] !== c) {
      const prevChar = i === 0 ? "" : input[i - 1];
      const opensAtBoundary = !prevChar || /[^A-Za-z0-9]/.test(prevChar);
      if (opensAtBoundary && input[i + 1] && /\S/.test(input[i + 1])) {
        const end = input.indexOf(c, i + 1);
        const closesAtBoundary =
          end !== -1 &&
          /\S/.test(input[end - 1]) &&
          (end === input.length - 1 || /[^A-Za-z0-9]/.test(input[end + 1]));
        if (closesAtBoundary) {
          flush();
          nodes.push(
            <em key={key++}>{renderInline(input.slice(i + 1, end))}</em>,
          );
          i = end + 1;
          continue;
        }
      }
    }
    buffer += c;
    i++;
  }
  flush();
  return nodes;
}
