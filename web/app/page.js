import CopyButton from "./CopyButton";
import Reveal from "./Reveal";
import Tilt3D from "./Tilt3D";
import Showcase3D from "./Showcase3D";

const DOWNLOAD_URL = "https://github.com/f0rkr/DiskLens/releases/latest/download/DiskLens.dmg";
const DONATE_URL = "https://www.buymeacoffee.com/f0rkr";
const QUARANTINE_CMD = "xattr -dr com.apple.quarantine /Applications/DiskLens.app";

/* ---------- inline icons ---------- */
const IconCheck = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12" /></svg>
);
const IconDownload = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 3v12" /><path d="m7 12 5 5 5-5" /><path d="M5 21h14" /></svg>
);
const IconApple = () => (
  <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M16.365 1.43c0 1.14-.493 2.27-1.177 3.08-.744.9-1.99 1.57-2.987 1.57-.12 0-.23-.02-.3-.03-.01-.06-.04-.22-.04-.39 0-1.15.572-2.27 1.206-2.98.804-.94 2.142-1.64 3.248-1.68.03.13.05.28.05.43zm4.565 15.71c-.03.07-.463 1.58-1.518 3.12-.91 1.33-1.86 2.66-3.36 2.68-1.47.03-1.95-.87-3.63-.87-1.68 0-2.22.84-3.61.9-1.45.05-2.55-1.43-3.47-2.75-1.88-2.72-3.32-7.69-1.39-11.05.96-1.67 2.67-2.73 4.53-2.76 1.42-.03 2.76.96 3.63.96.86 0 2.49-1.19 4.2-1.01.71.03 2.71.29 3.99 2.18-.1.07-2.38 1.39-2.36 4.15.03 3.3 2.9 4.4 2.93 4.41z" /></svg>
);
const IconWindows = () => (
  <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><rect x="3" y="3" width="8" height="8" /><rect x="13" y="3" width="8" height="8" /><rect x="3" y="13" width="8" height="8" /><rect x="13" y="13" width="8" height="8" /></svg>
);
const IconLinux = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="4" width="18" height="16" rx="2" /><path d="m7 9 3 2.5L7 14" /><line x1="12.5" y1="15" x2="16" y2="15" /></svg>
);
const IconCoffee = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="M8 2.4c-.7.8-.7 1.6 0 2.4" opacity="0.6" />
    <path d="M11.6 2c-.7.8-.7 1.6 0 2.4" opacity="0.6" />
    <path d="M4 7.6h12v4.9a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5V7.6Z" fill="currentColor" stroke="none" />
    <path d="M16 9h1.6a2.4 2.4 0 0 1 0 4.8H16" />
    <path d="M5 20.4h10" />
  </svg>
);

const extras = [
  { t: "Menu-bar overview", d: "Free space at a glance, right from your menu bar.",
    i: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="4" width="18" height="16" rx="2" /><line x1="3" y1="8.5" x2="21" y2="8.5" /></svg> },
  { t: "Old & large finder", d: "Surfaces big files you haven't touched in a year or more.",
    i: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></svg> },
  { t: "Quick Look + Undo", d: "Preview any file inline, and undo a cleanup instantly.",
    i: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z" /><circle cx="12" cy="12" r="3" /></svg> },
  { t: "Drag & drop", d: "Drop any folder onto the app to scan it right away.",
    i: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 3v10" /><path d="m8 10 4 4 4-4" /><path d="M5 20h14" /></svg> },
  { t: "Recent folders", d: "Jump straight back to folders you've scanned before.",
    i: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12a9 9 0 1 0 2.6-6.3" /><path d="M3 4v4h4" /><path d="M12 8v4l3 2" /></svg> },
  { t: "Preferences", d: "Units, cleanup thresholds, and keyboard shortcuts.",
    i: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><line x1="4" y1="8" x2="20" y2="8" /><circle cx="9" cy="8" r="2.2" fill="currentColor" stroke="none" /><line x1="4" y1="16" x2="20" y2="16" /><circle cx="15" cy="16" r="2.2" fill="currentColor" stroke="none" /></svg> },
];

const soonPlatforms = [
  { name: "Windows", meta: "x64 & ARM", icon: <IconWindows /> },
  { name: "macOS (Intel)", meta: "x86-64", icon: <IconApple /> },
  { name: "Linux", meta: ".deb & AppImage", icon: <IconLinux /> },
];

function HeroTreemap() {
  const tiles = [
    { x: 6, y: 6, w: 286, h: 214, c: "#4d8cea", n: "Library", s: "12.4 GB" },
    { x: 6, y: 226, w: 176, h: 128, c: "#ed8c4d", n: "Movies", s: "4.0 GB" },
    { x: 186, y: 226, w: 106, h: 128, c: "#4d8cea", n: "Downloads", s: "1.1 GB" },
    { x: 298, y: 6, w: 256, h: 150, c: "#5cc78d", n: "node_modules", s: "2.6 GB" },
    { x: 298, y: 160, w: 150, h: 95, c: "#ccb85c", n: "Photos", s: "1.8 GB" },
    { x: 452, y: 160, w: 102, h: 95, c: "#8c80ea", n: "Docs", s: "640 MB" },
    { x: 298, y: 259, w: 120, h: 95, c: "#66bcdb", n: "Caches", s: "520 MB" },
    { x: 422, y: 259, w: 132, h: 95, c: "#8c95a0", n: "Other", s: "380 MB" },
  ];
  return (
    <svg viewBox="0 0 560 360" role="img" aria-label="DiskLens treemap of a home folder">
      <rect width="560" height="360" fill="#0b0f19" />
      {tiles.map((t, i) => (
        <g key={t.n} className="tm-tile" style={{ animationDelay: `${0.6 + i * 0.07}s` }}>
          <rect x={t.x} y={t.y} width={t.w} height={t.h} rx="5" fill={t.c} />
          <text x={t.x + 11} y={t.y + 24} fill="#fff" fontSize="14" fontWeight="700" fontFamily="-apple-system, sans-serif">{t.n}</text>
          <text x={t.x + 11} y={t.y + 41} fill="#fff" fontSize="12" opacity="0.82" fontFamily="-apple-system, sans-serif">{t.s}</text>
        </g>
      ))}
    </svg>
  );
}

export default function Home() {
  return (
    <>
      <header className="site-header">
        <div className="container nav-row">
          <a className="brand" href="#top"><img src="/icon.svg" alt="" /> DiskLens</a>
          <nav className="nav-links">
            <a href="#features">Features</a>
            <a href="#download">Download</a>
            <a className="btn btn-coffee btn-sm" href={DONATE_URL} target="_blank" rel="noopener noreferrer">
              <IconCoffee /><span className="coffee-label">Donate</span>
            </a>
            <a className="btn btn-primary btn-sm" href="#download">Get DiskLens</a>
          </nav>
        </div>
      </header>

      <main id="top">
        {/* hero — centered, glass */}
        <section className="hero">
          <div className="container">
            <span className="kicker hero-anim a1"><span className="dot" /> Free for macOS · v1.0</span>
            <h1 className="hero-title hero-anim a2">See what&apos;s eating your disk.</h1>
            <p className="hero-sub hero-anim a3">
              A fast, native Mac app that scans any folder and shows exactly where your space
              went — overview, treemap, duplicates, and one-click cleanup.
            </p>
            <div className="hero-cta hero-anim a4">
              <a className="btn btn-primary" href={DOWNLOAD_URL} download><IconApple /> Download for Mac</a>
              <a className="link-arrow" href="#features">See it in 3D ›</a>
            </div>
            <div className="trust hero-anim a5">
              <span className="trust-item"><IconCheck /> Native &amp; tiny</span>
              <span className="trust-item"><IconCheck /> 100% on-device</span>
              <span className="trust-item"><IconCheck /> Deletes go to the Trash</span>
              <span className="trust-item"><IconCheck /> Free, forever</span>
            </div>

            <div className="hero-art hero-anim art">
              <Tilt3D>
                <div className="window">
                  <div className="window-bar">
                    <span className="tl r" /><span className="tl y" /><span className="tl g" />
                    <span className="window-title">DiskLens — Macintosh HD › Users › you</span>
                  </div>
                  <div className="window-body"><HeroTreemap /></div>
                </div>
              </Tilt3D>
            </div>
          </div>
        </section>

        {/* 3D coverflow through every screen */}
        <Showcase3D />

        {/* and more */}
        <section className="section" id="more">
          <div className="container">
            <Reveal className="section-head">
              <div className="kicker">And more</div>
              <h2>Built for real cleanup</h2>
              <p>The little things that make freeing up space feel effortless.</p>
            </Reveal>
            <div className="more-grid">
              {extras.map((e, i) => (
                <Reveal key={e.t} delay={i * 0.05}>
                  <div className="more-card">
                    <div className="more-ico">{e.i}</div>
                    <h3>{e.t}</h3>
                    <p>{e.d}</p>
                  </div>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        {/* download */}
        <section className="section" id="download">
          <div className="container">
            <Reveal className="section-head">
              <div className="kicker">Download</div>
              <h2>Get DiskLens</h2>
              <p>Apple Silicon is ready today. The rest are on the way.</p>
            </Reveal>
            <Reveal>
              <div className="dl-card">
                <div className="dl-main">
                  <div className="dl-main-text">
                    <img src="/icon.svg" alt="DiskLens icon" />
                    <div>
                      <h3>macOS · Apple Silicon</h3>
                      <p>For M1/M2/M3/M4 Macs · macOS 14+ · 0.9 MB</p>
                    </div>
                  </div>
                  <a className="btn btn-primary" href={DOWNLOAD_URL} download><IconDownload /> Download for Mac</a>
                </div>
                <div className="dl-soon-row">
                  {soonPlatforms.map((p) => (
                    <div className="dl-soon" key={p.name}>
                      {p.icon}
                      <div>
                        <div className="name">{p.name}</div>
                        <div className="meta">{p.meta}</div>
                      </div>
                      <span className="soon-pill">Soon</span>
                    </div>
                  ))}
                </div>
                <div className="note">
                  <b>First launch.</b> DiskLens isn&apos;t notarized yet, so macOS will block it the first time. To open it:
                  <ol className="steps">
                    <li>Open the <b>.dmg</b> and drag DiskLens into <b>Applications</b>.</li>
                    <li>Double-click it — when macOS says it can&apos;t verify the developer, click <b>Done</b>.</li>
                    <li>Go to <b>System Settings → Privacy &amp; Security</b>, scroll down, and click <b>Open Anyway</b>.</li>
                  </ol>
                  Prefer the terminal? Run this once after dragging it to Applications:
                  <div className="code-row">
                    <code>{QUARANTINE_CMD}</code>
                    <CopyButton text={QUARANTINE_CMD} />
                  </div>
                </div>
              </div>
            </Reveal>
          </div>
        </section>

        {/* closing */}
        <section className="section" id="get">
          <div className="container">
            <Reveal className="closing">
              <div className="kicker">Free for macOS</div>
              <h2>Free. Forever.</h2>
              <p>No ads, no accounts, no tracking. DiskLens runs entirely on your Mac.</p>
              <div className="closing-cta">
                <a className="btn btn-primary btn-lg" href={DOWNLOAD_URL} download><IconApple /> Download for Mac</a>
                <a className="btn btn-coffee btn-lg" href={DONATE_URL} target="_blank" rel="noopener noreferrer"><IconCoffee /> Buy me a coffee</a>
              </div>
              <p className="closing-note">Free forever — but if it cleared up some gigabytes, a coffee keeps it going. ☕</p>
            </Reveal>
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <div className="container footer-row">
          <span>
            © {new Date().getFullYear()} DiskLens · Made for cluttered Macs
            {process.env.NEXT_PUBLIC_APP_ENV && process.env.NEXT_PUBLIC_APP_ENV !== "production" && (
              <span className="env-badge">{process.env.NEXT_PUBLIC_APP_ENV}</span>
            )}
          </span>
          <span className="footer-links">
            <a href="#features">Features</a>
            <a href="#download">Download</a>
            <a href={DONATE_URL} target="_blank" rel="noopener noreferrer">Donate</a>
            <a href="#get">Free</a>
          </span>
        </div>
      </footer>
    </>
  );
}
