import "./globals.css";

export const metadata = {
  metadataBase: new URL("https://disklens.vercel.app"),
  title: "DiskLens — See what's eating your Mac's disk",
  description:
    "A fast, native macOS app that scans any folder and shows exactly where your space went — visual treemap, duplicate finder, and one-click cleanup. Free.",
  keywords: ["disk space", "macOS", "storage analyzer", "treemap", "duplicate finder", "cleanup", "free"],
  openGraph: {
    title: "DiskLens — Reclaim your Mac's disk space",
    description:
      "Native macOS disk analyzer: visual treemap, duplicate finder, smart cleanup. Tiny, private, and free.",
    type: "website",
    url: "https://disklens.vercel.app",
    siteName: "DiskLens",
  },
  twitter: {
    card: "summary_large_image",
    title: "DiskLens — Reclaim your Mac's disk space",
    description: "Native macOS disk analyzer: treemap, duplicate finder, smart cleanup. Free.",
  },
};

export const viewport = {
  themeColor: "#06080e",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <noscript>
          <style>{`.reveal{opacity:1 !important;transform:none !important}`}</style>
        </noscript>
        {children}
      </body>
    </html>
  );
}
