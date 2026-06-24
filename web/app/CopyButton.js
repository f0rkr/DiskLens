"use client";

import { useState } from "react";

export default function CopyButton({ text }) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    } catch {
      /* clipboard unavailable — ignore */
    }
  }

  return (
    <button type="button" className="copy-btn" onClick={copy} aria-label="Copy command">
      {copied ? "Copied ✓" : "Copy"}
    </button>
  );
}
