import Link from "next/link";
import { ArrowUpRight, DesktopTower, SlidersHorizontal, SquaresFour } from "@phosphor-icons/react/dist/ssr";

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "WebSite",
  name: "taured.space",
  url: "https://taured.space",
  description: "Free, safe, open system utilities: app installer, system tweaker, CC0 wallpapers.",
};

export default function Home() {
  return (
    <div className="home-stack">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <section className="home-section home-tools-focus">
        <div className="section-head">
          <div><span className="eyebrow">Choose your starting point</span><h2>What do you want to do?</h2></div>
          <a className="text-link" href="https://www.patreon.com/nibirbiswas" target="_blank" rel="noreferrer">Support a solo dev ↗</a>
        </div>
        <div className="tool-grid">
          <ToolTile number="01 / SETUP" icon={<DesktopTower size={116} weight="thin" />} href="/apps" title="The app setup" body="Build your own app bundle. Pick what you need and get a ready-to-run installer script for your system." cta="Choose your apps" />
          <ToolTile number="02 / TUNE" icon={<SlidersHorizontal size={100} weight="thin" />} href="/tweaks" title="The system tune-up" body="Browse practical, reversible tweaks, then jump into the Windows or Linux toolbox." cta="Tune your system" />
          <ToolTile number="03 / MAKE IT YOURS" icon={<SquaresFour size={105} weight="thin" />} href="/wallpapers" title="A new point of view" body="Find a little more atmosphere for your desktop. Browse curated wallpaper collections." cta="Find a wallpaper" />
        </div>
      </section>
      <div className="home-ribbon"><span>Open source by design</span><span>Readable scripts</span><span>No login required</span><span>Built for Windows + Linux</span></div>
    </div>
  );
}

function ToolTile({ number, icon, href, title, body, cta }: { number: string; icon: React.ReactNode; href: string; title: string; body: string; cta: string }) {
  return <Link className="tool-tile" href={href}><div className="tile-top"><span>{number}</span><ArrowUpRight size={17} /></div><span className="tile-symbol" aria-hidden="true">{icon}</span><div className="tile-copy"><h3>{title}</h3><p>{body}</p><span className="tile-link">{cta}<span>→</span></span></div></Link>;
}
