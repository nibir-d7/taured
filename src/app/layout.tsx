import type { Metadata } from "next";
import Link from "next/link";
import { SiteNav } from "@/components/site-nav";
import { Geist, Geist_Mono, Syne } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});
const syne = Syne({
  variable: "--font-display",
  subsets: ["latin"],
});

import { CookieBanner } from "@/components/cookie-banner";
import { Analytics } from "@/components/analytics";

export const metadata: Metadata = {
  metadataBase: new URL("https://taured.space"),
  title: { default: "taured.space — Free, safe, open system utilities", template: "%s | taured.space" },
  description: "Cross-platform app installer, safe system tweaker, and CC0 wallpaper packs. Free forever.",
  openGraph: {
    title: "taured.space",
    description: "Free, safe, open system utilities.",
    url: "https://taured.space",
    siteName: "taured.space",
    type: "website",
    images: [{ url: "/taured-logo.png", width: 1024, height: 1024 }],
  },
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`dark ${geistSans.variable} ${geistMono.variable} ${syne.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        <header className="site-header">
          <SiteNav />
        </header>
        <main className="site-main">{children}</main>
        <CookieBanner />
        <Analytics />
        <footer className="site-footer">
          <div className="footer-inner">
            <span>Independent tools for a computer that feels like yours.</span>
            <div className="footer-links">
              <Link href="/about">About</Link>
              <Link href="/contact">Contact</Link>
              <Link href="/privacy">Privacy</Link>
              <Link href="/terms">Terms</Link>
              <a href="https://www.patreon.com/nibirbiswas" target="_blank" rel="noreferrer">Donate ↗</a>
            </div>
          </div>
        </footer>
      </body>
    </html>
  );
}
