import React, { useEffect } from "react";

const keys = ["A", "B", "C"] as const;
export type VariantKey = (typeof keys)[number];
const names: Record<VariantKey, string> = { A: "Job board + detail panel", B: "Feedback inbox first", C: "Ledger and swimlanes" };

export function PrototypeSwitcher({ current, onChange }: { current: VariantKey; onChange: (k: VariantKey) => void }) {
  const step = (d: number) => onChange(keys[(keys.indexOf(current) + d + keys.length) % keys.length]);

  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      const el = document.activeElement as HTMLElement | null;
      if (el && (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.isContentEditable)) return;
      if (e.key === "ArrowLeft") step(-1);
      if (e.key === "ArrowRight") step(1);
    };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  });

  const btn: React.CSSProperties = { background: "transparent", border: 0, color: "#fff", fontSize: 18, cursor: "pointer", padding: "0 10px" };
  return (
    <div
      style={{
        position: "fixed", bottom: 16, left: "50%", transform: "translateX(-50%)", zIndex: 10000,
        background: "#111", color: "#fff", borderRadius: 999, padding: "8px 14px", display: "flex",
        alignItems: "center", gap: 6, boxShadow: "0 4px 16px rgba(0,0,0,.4)", fontFamily: "system-ui, sans-serif", fontSize: 14,
      }}
    >
      <button style={btn} onClick={() => step(-1)} aria-label="previous variant">←</button>
      <span>{current} ({names[current]})</span>
      <button style={btn} onClick={() => step(1)} aria-label="next variant">→</button>
    </div>
  );
}
