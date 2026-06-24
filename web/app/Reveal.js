"use client";

import { useEffect, useRef, useState } from "react";

/// Fades + slides its children in when they scroll into view. Uses a scroll +
/// getBoundingClientRect check (reliable everywhere), with a safety timeout so
/// the content is never left hidden if scroll detection ever fails.
export default function Reveal({ children, delay = 0, className = "" }) {
  const ref = useRef(null);
  const [shown, setShown] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    let done = false;

    const finish = () => {
      if (done) return;
      done = true;
      setShown(true);
      window.removeEventListener("scroll", check);
      window.removeEventListener("resize", check);
      clearTimeout(timer);
    };
    const check = () => {
      const top = el.getBoundingClientRect().top;
      if (top < (window.innerHeight || 800) * 0.92) finish();
    };

    check(); // reveal immediately if already in view
    window.addEventListener("scroll", check, { passive: true });
    window.addEventListener("resize", check);
    const timer = setTimeout(finish, 2600); // safety net: never stay hidden

    return () => {
      window.removeEventListener("scroll", check);
      window.removeEventListener("resize", check);
      clearTimeout(timer);
    };
  }, []);

  return (
    <div
      ref={ref}
      className={`reveal ${shown ? "in" : ""} ${className}`}
      style={{ transitionDelay: `${delay}s` }}
    >
      {children}
    </div>
  );
}
