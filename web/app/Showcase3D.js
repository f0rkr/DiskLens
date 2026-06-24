"use client";

import { useEffect, useRef } from "react";
import { ChartsMock, BreakdownMock, TreemapMock, FilesMock, DuplicatesMock, CleanupMock } from "./mockups";

const SCREENS = [
  { mock: <ChartsMock />, title: "Visual overview", desc: "Usage by file type at a glance — a donut plus your largest items." },
  { mock: <BreakdownMock />, title: "Folder breakdown", desc: "Every folder as a tree, sorted largest-first, with size bars." },
  { mock: <TreemapMock />, title: "Visual treemap", desc: "Each rectangle is its disk usage — the big hogs pop out. Click to zoom." },
  { mock: <FilesMock />, title: "Largest files", desc: "The single biggest files anywhere — plus an 'old & large' filter for the safest deletes." },
  { mock: <DuplicatesMock />, title: "Duplicate finder", desc: "Byte-identical files found by SHA-256, with the space you'd reclaim." },
  { mock: <CleanupMock />, title: "Smart cleanup", desc: "Caches, node_modules, junk & old archives — moved to the Trash safely." },
];

/// Apple-style 3D coverflow. As you scroll the pinned section, the deck of glass
/// app-screens rotates through every feature; the centered one faces you.
export default function Showcase3D() {
  const secRef = useRef(null);
  const cardRefs = useRef([]);
  const capRefs = useRef([]);
  const dotRefs = useRef([]);

  useEffect(() => {
    const sec = secRef.current;
    if (!sec) return;
    const N = SCREENS.length;

    const apply = () => {
      const rect = sec.getBoundingClientRect();
      const vh = window.innerHeight || 800;
      const total = sec.offsetHeight - vh;
      const p = total > 0 ? Math.min(Math.max(-rect.top / total, 0), 1) : 0;
      const center = p * (N - 1);

      cardRefs.current.forEach((card, i) => {
        if (!card) return;
        const d = i - center;
        const ad = Math.abs(d);
        const tx = d * 50;                                   // %
        const tz = -ad * 160;                                // px (depth)
        const ry = Math.max(-55, Math.min(55, -d * 40));     // deg
        const sc = Math.max(0.62, 1 - ad * 0.13);
        card.style.transform =
          `translate(-50%, -50%) translateX(${tx}%) translateZ(${tz}px) rotateY(${ry}deg) scale(${sc})`;
        card.style.opacity = String(Math.max(0.12, 1 - ad * 0.4));
        card.style.zIndex = String(100 - Math.round(ad * 10));
        card.style.filter = ad > 0.55 ? "brightness(0.65)" : "none";
        card.style.pointerEvents = ad < 0.5 ? "auto" : "none";
      });

      const active = Math.round(center);
      capRefs.current.forEach((c, i) => { if (c) c.style.opacity = i === active ? "1" : "0"; });
      dotRefs.current.forEach((dot, i) => { if (dot) dot.className = `cf-dot ${i === active ? "on" : ""}`; });
    };

    apply();
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    window.addEventListener("scroll", apply, { passive: true });
    window.addEventListener("resize", apply);
    return () => {
      window.removeEventListener("scroll", apply);
      window.removeEventListener("resize", apply);
    };
  }, []);

  return (
    <section className="showcase" ref={secRef} id="features">
      <div className="showcase-sticky">
        <div className="cf-stage">
          {SCREENS.map((s, i) => (
            <div className="cf-card" key={s.title} ref={(el) => (cardRefs.current[i] = el)}>
              {s.mock}
            </div>
          ))}
        </div>
        <div className="cf-captions">
          {SCREENS.map((s, i) => (
            <div className="cf-caption" key={s.title} ref={(el) => (capRefs.current[i] = el)}
                 style={{ opacity: i === 0 ? 1 : 0 }}>
              <h3>{s.title}</h3>
              <p>{s.desc}</p>
            </div>
          ))}
        </div>
        <div className="cf-progress">
          {SCREENS.map((s, i) => (
            <span key={s.title} className={`cf-dot ${i === 0 ? "on" : ""}`} ref={(el) => (dotRefs.current[i] = el)} />
          ))}
        </div>
      </div>
    </section>
  );
}
