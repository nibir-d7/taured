import Link from "next/link";
import { Laptop, Wrench, Images } from "@phosphor-icons/react/dist/ssr";
import { DetectedOs } from "@/components/detected-os";

export default function Home() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "WebSite",
    name: "taured.space",
    url: "https://taured.space",
    description: "Free, safe, open system utilities: app installer, system tweaker, CC0 wallpapers.",
  };
  return (
    <div className="mx-auto flex max-w-5xl flex-col items-center gap-12 px-4 py-16 text-center">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />

      <section className="flex flex-col items-center gap-4">
        <h1 className="text-4xl font-bold tracking-tight md:text-5xl">What do you want to do?</h1>
        <p className="text-sm text-muted-foreground">
          Free · No login · Open source · <DetectedOs />
        </p>
      </section>

      <section className="grid w-full gap-5 md:grid-cols-3">
        <ToolCard
          href="/apps"
          tint="bg-[#fdf3c9] dark:bg-[#3d3a26]"
          icon={<Laptop size={34} weight="duotone" />}
          title="1. Software Setup"
          body="Pick apps, download one .exe/.sh that auto-installs everything like Ninite. Cross-platform."
          cta="Start Setup →"
        />
        <ToolCard
          href="/tweaks"
          tint="bg-[#dbe9fd] dark:bg-[#26334a]"
          icon={<Wrench size={34} weight="duotone" />}
          title="2. Tweak your OS"
          body="One CLI command. Safe, reversible. Debloat, privacy, performance."
          cta="Show Command →"
        />
        <ToolCard
          href="/wallpapers"
          tint="bg-[#fbdcf0] dark:bg-[#3f2737]"
          icon={<Images size={34} weight="duotone" />}
          title="3. Download Wallpapers"
          body="Curated 4K CC0 packs. Single or full ZIP download."
          cta="Browse Packs →"
        />
      </section>
    </div>
  );
}

function ToolCard({ href, tint, icon, title, body, cta }: { href: string; tint: string; icon: React.ReactNode; title: string; body: string; cta: string }) {
  return (
    <div className={`flex flex-col items-center gap-4 rounded-3xl p-8 text-center shadow-sm ${tint}`}>
      <span className="text-foreground/80">{icon}</span>
      <h2 className="text-lg font-semibold tracking-tight">{title}</h2>
      <p className="text-sm leading-relaxed text-foreground/70">{body}</p>
      <Link href={href} className="mt-2 inline-flex h-10 items-center rounded-full bg-neutral-900 px-6 text-sm font-medium text-white transition hover:bg-neutral-700 active:scale-[0.97] dark:bg-neutral-100 dark:text-neutral-900 dark:hover:bg-neutral-300">
        {cta}
      </Link>
    </div>
  );
}
