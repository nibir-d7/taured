import type { Metadata } from "next";
import Link from "next/link";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
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
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col bg-background text-foreground">
        <header className="border-b">
          <nav className="mx-auto flex h-14 max-w-5xl items-center justify-between px-4">
            <Link href="/" className="flex items-center gap-2 font-mono text-sm font-semibold tracking-tight">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src="/taured-logo.png" alt="" width={22} height={22} className="h-[22px] w-[22px]" />
              taured<span className="text-rose-600 dark:text-rose-400">.space</span>
            </Link>
            <div className="flex gap-5 text-sm text-muted-foreground">
              <Link href="/apps" className="transition hover:text-foreground">Apps</Link>
              <Link href="/tweaks" className="transition hover:text-foreground">Tweaks</Link>
              <Link href="/wallpapers" className="transition hover:text-foreground">Wallpapers</Link>
            </div>
          </nav>
        </header>
        <main className="flex-1">{children}</main>
        <CookieBanner />
        <Analytics />
        <footer className="border-t text-xs text-muted-foreground">
          <div className="mx-auto flex max-w-5xl flex-wrap gap-4 px-4 py-6">
            <Link href="/privacy">Privacy</Link>
            <Link href="/terms">Terms</Link>
            <Link href="/about">About</Link>
            <Link href="/contact">Contact</Link>
            <Link href="/admin">Admin</Link>
          </div>
        </footer>
      </body>
    </html>
  );
}
