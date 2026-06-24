// Static UI mockups of DiskLens's screens (server components — no client JS).

function Dots({ title }) {
  return (
    <div className="window-bar">
      <span className="tl r" /><span className="tl y" /><span className="tl g" />
      <span className="window-title">{title}</span>
    </div>
  );
}

export function TreemapMock() {
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
    <div className="window">
      <Dots title="DiskLens — Treemap" />
      <div className="window-body">
        <svg viewBox="0 0 560 360" role="img" aria-label="Treemap view">
          <rect width="560" height="360" fill="#0b0f19" />
          {tiles.map((t) => (
            <g key={t.n}>
              <rect x={t.x} y={t.y} width={t.w} height={t.h} rx="5" fill={t.c} />
              <text x={t.x + 11} y={t.y + 24} fill="#fff" fontSize="14" fontWeight="700" fontFamily="-apple-system, sans-serif">{t.n}</text>
              <text x={t.x + 11} y={t.y + 41} fill="#fff" fontSize="12" opacity="0.82" fontFamily="-apple-system, sans-serif">{t.s}</text>
            </g>
          ))}
        </svg>
      </div>
    </div>
  );
}

export function ChartsMock() {
  const cats = [
    { l: "Photos & Video", s: "8.2 GB", c: "#ed8c4d" },
    { l: "Code", s: "3.1 GB", c: "#5cc78d" },
    { l: "Documents", s: "2.4 GB", c: "#8c80ea" },
    { l: "Archives", s: "1.6 GB", c: "#e0666f" },
    { l: "Other", s: "1.1 GB", c: "#8c95a0" },
  ];
  const donut =
    "conic-gradient(#ed8c4d 0 50%, #5cc78d 50% 69%, #8c80ea 69% 84%, #e0666f 84% 94%, #8c95a0 94% 100%)";
  return (
    <div className="window">
      <Dots title="DiskLens — Overview" />
      <div className="window-body mock-pad mock-charts">
        <div className="donut" style={{ background: donut }}>
          <span className="donut-hole"><b>16.4 GB</b><small>total</small></span>
        </div>
        <div className="mock-legend">
          {cats.map((c) => (
            <div className="leg-row" key={c.l}>
              <span className="leg-dot" style={{ background: c.c }} />
              <span className="leg-l">{c.l}</span>
              <span className="leg-s">{c.s}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export function BreakdownMock() {
  const rows = [
    { n: "Library", s: "12.4 GB", pct: 100, c: "#4d8cea" },
    { n: "Movies", s: "4.0 GB", pct: 33, c: "#ed8c4d" },
    { n: "node_modules", s: "2.6 GB", pct: 22, c: "#5cc78d" },
    { n: "Photos", s: "1.8 GB", pct: 15, c: "#ccb85c" },
    { n: "Downloads", s: "1.1 GB", pct: 10, c: "#4d8cea" },
    { n: "Documents", s: "640 MB", pct: 6, c: "#8c80ea" },
  ];
  return (
    <div className="window">
      <Dots title="DiskLens — Breakdown" />
      <div className="window-body mock-pad">
        {rows.map((r) => (
          <div className="brk-row" key={r.n}>
            <span className="brk-ico" style={{ background: r.c }} />
            <span className="brk-name">{r.n}</span>
            <span className="brk-bar"><i style={{ width: `${r.pct}%`, background: r.c }} /></span>
            <span className="brk-size">{r.s}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

export function FilesMock() {
  const rows = [
    { n: "Final_Render_4K.mov", s: "6.2 GB", pct: 100, c: "#ed8c4d" },
    { n: "Xcode.app", s: "3.4 GB", pct: 55, c: "#66bcdb" },
    { n: "node_modules.tar", s: "2.6 GB", pct: 42, c: "#5cc78d" },
    { n: "backup-2023.zip", s: "1.9 GB", pct: 31, c: "#e0666f" },
    { n: "dataset.csv", s: "1.2 GB", pct: 19, c: "#ccb85c" },
    { n: "old-project.zip", s: "880 MB", pct: 14, c: "#e0666f" },
  ];
  return (
    <div className="window">
      <Dots title="DiskLens — Largest files" />
      <div className="window-body mock-pad">
        {rows.map((r, i) => (
          <div className="brk-row" key={r.n}>
            <span className="brk-rank">{i + 1}</span>
            <span className="brk-name" style={{ width: 150 }}>{r.n}</span>
            <span className="brk-bar"><i style={{ width: `${r.pct}%`, background: r.c }} /></span>
            <span className="brk-size">{r.s}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

export function DuplicatesMock() {
  const groups = [
    { n: "archive.zip", x: 4, save: "180 MB" },
    { n: "design-v2.sketch", x: 2, save: "48 MB" },
    { n: "IMG_4821.heic", x: 3, save: "36 MB" },
    { n: "report-final.pdf", x: 2, save: "12 MB" },
  ];
  return (
    <div className="window">
      <Dots title="DiskLens — Duplicates" />
      <div className="window-body mock-pad">
        {groups.map((g) => (
          <div className="dup-row" key={g.n}>
            <span className="dup-ico" />
            <span className="dup-name">{g.n}</span>
            <span className="dup-x">×{g.x}</span>
            <span className="dup-save">save {g.save}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

export function CleanupMock() {
  const items = [
    { n: "Xcode DerivedData", t: "Build", s: "3.1 GB", on: true },
    { n: "node_modules", t: "Build", s: "2.6 GB", on: true },
    { n: "Caches", t: "Cache", s: "1.4 GB", on: true },
    { n: ".DS_Store files", t: "Junk", s: "4 MB", on: false },
  ];
  return (
    <div className="window">
      <Dots title="DiskLens — Cleanup" />
      <div className="window-body mock-pad">
        {items.map((i) => (
          <div className="cln-row" key={i.n}>
            <span className={`cln-check ${i.on ? "on" : ""}`} />
            <span className="cln-name">{i.n}</span>
            <span className="cln-tag">{i.t}</span>
            <span className="cln-size">{i.s}</span>
          </div>
        ))}
        <div className="cln-foot"><span className="cln-btn">Move to Trash · 7.1 GB</span></div>
      </div>
    </div>
  );
}
