"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { ArrowUpRight, DesktopTower, SlidersHorizontal, SquaresFour } from "@phosphor-icons/react";
import AdminClient from "./admin/admin-client";

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "WebSite",
  name: "taured.space",
  url: "https://taured.space",
  description: "Free, safe, open system utilities: app installer, system tweaker, CC0 wallpapers.",
};

export default function Home() {
  const [isAdminSubdomain, setIsAdminSubdomain] = useState(false);

  useEffect(() => {
    if (typeof window !== "undefined" && window.location.hostname.startsWith("admin.")) {
      setIsAdminSubdomain(true);
    }
  }, []);

  if (isAdminSubdomain) {
    return <AdminClient />;
  }

  return (
    <div>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <section className="home-section home-tools-focus">
        <div className="section-head">
          <div><span className="eyebrow">Choose your starting point</span><h2>What do you want to do?</h2></div>
        </div>
        <div className="tool-grid">
          <ToolTile number="01 / SETUP" icon={<DesktopTower size={34} weight="regular" />} href="/apps" title="The app setup" body="Choose the apps you need and create a ready-to-run installer for your system." cta="Choose your apps" />
          <ToolTile number="02 / TUNE" icon={<SlidersHorizontal size={34} weight="regular" />} href="/tweaks" title="The system tune-up" body="Run the taured toolbox for practical, reversible system tweaks." cta="Tune your system" />
          <ToolTile number="03 / WALLPAPERS" icon={<SquaresFour size={34} weight="regular" />} href="/wallpapers" title="A new point of view" body="Browse curated wallpaper collections for your desktop." cta="Find a wallpaper" />
        </div>
      </section>
    </div>
  );
}

function ToolTile({ number, icon, href, title, body, cta }: { number: string; icon: React.ReactNode; href: string; title: string; body: string; cta: string }) {
  return <Link className="tool-tile" href={href}><div className="tile-top"><span>{number}</span><span className="tile-symbol" aria-hidden="true">{icon}</span></div><div className="tile-copy"><h3>{title}</h3><p>{body}</p><span className="tile-link">{cta}<ArrowUpRight size={15} /></span></div></Link>;
}
