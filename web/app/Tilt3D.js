"use client";

import { useEffect, useRef } from "react";

/// Premium 3D tilt: the wrapped element leans toward the cursor (perspective set
/// on the parent). Pure transform writes via ref — no per-frame React renders.
export default function Tilt3D({ children, max = 7, className = "" }) {
  const ref = useRef(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const parent = el.parentElement;
    if (!parent) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const onMove = (e) => {
      const r = parent.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5;
      const y = (e.clientY - r.top) / r.height - 0.5;
      el.style.transform = `rotateY(${x * max}deg) rotateX(${-y * max}deg)`;
    };
    const onLeave = () => {
      el.style.transform = "rotateY(0deg) rotateX(0deg)";
    };

    parent.addEventListener("mousemove", onMove);
    parent.addEventListener("mouseleave", onLeave);
    return () => {
      parent.removeEventListener("mousemove", onMove);
      parent.removeEventListener("mouseleave", onLeave);
    };
  }, [max]);

  return (
    <div ref={ref} className={`tilt3d ${className}`}>
      {children}
    </div>
  );
}
