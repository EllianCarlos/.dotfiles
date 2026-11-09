import React, { useState } from "react";
import { createRoot } from "react-dom/client";
import "@cloudscape-design/global-styles/index.css";
import { PrototypeSwitcher, VariantKey } from "./Switcher";
import { VariantA } from "./VariantA";
import { VariantB } from "./VariantB";
import { VariantC } from "./VariantC";

function App() {
  const initial = (new URLSearchParams(location.search).get("variant") ?? "A").toUpperCase() as VariantKey;
  const [variant, setVariant] = useState<VariantKey>(["A", "B", "C"].includes(initial) ? initial : "A");
  const change = (k: VariantKey) => {
    const u = new URL(location.href);
    u.searchParams.set("variant", k);
    history.replaceState(null, "", u);
    setVariant(k);
  };
  return (
    <>
      {variant === "A" && <VariantA />}
      {variant === "B" && <VariantB />}
      {variant === "C" && <VariantC />}
      <PrototypeSwitcher current={variant} onChange={change} />
    </>
  );
}

createRoot(document.getElementById("root")!).render(<App />);
