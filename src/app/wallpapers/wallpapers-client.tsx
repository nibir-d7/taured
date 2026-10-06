"use client";

import { useEffect, useMemo, useState } from "react";
import Image from "next/image";
import { ArrowDown, ArrowLeft, ArrowUpRight, DownloadSimple, X } from "@phosphor-icons/react";
import { supabase, supabaseConfigured } from "@/lib/supabase";
import type { Pack } from "@/lib/types";

const CATEGORIES = [
  { name: "Minimal", number: "01", art: "radial-gradient(ellipse at 72% 26%, #e5c76b 0 9%, transparent 9.5%), radial-gradient(ellipse at 50% 100%, #6cbfbf 0 35%, transparent 35.5%), linear-gradient(145deg,#232a2d,#141b1e)" },
  { name: "Landscape", number: "02", art: "linear-gradient(160deg,transparent 0 52%,#232a2d 52.5%),linear-gradient(145deg,transparent 0 38%,#8ccf7e 38.5%),linear-gradient(#67b0e8,#6cbfbf)" },
  { name: "Sci-fi", number: "03", art: "radial-gradient(circle at 71% 27%,#e57474 0 4%,transparent 4.5%),linear-gradient(135deg,transparent 0 47%,#232a2d 47.5%),linear-gradient(25deg,#141b1e,#67b0e8 70%,#c47fd5)" },
  { name: "Anime", number: "04", art: "radial-gradient(circle at 66% 25%,#e5c76b 0 12%,transparent 12.5%),linear-gradient(155deg,transparent 0 47%,#232a2d 47.5%),linear-gradient(#e57474,#c47fd5 70%,#6cbfbf)" },
];
const CATEGORY_TAGS: Record<string, string[]> = { Minimal: ["minimal"], Landscape: ["landscape", "nature"], "Sci-fi": ["sci-fi", "sci fi", "scifi", "space"], Anime: ["anime"] };
type Wallpaper = { id: string; image_url: string };
const patreon = "https://www.patreon.com/nibirbiswas";

export default function WallpapersClient() {
  const [packs, setPacks] = useState<Pack[]>([]);
  const [packsLoading, setPacksLoading] = useState(supabaseConfigured);
  const [category, setCategory] = useState("All");
  const [selected, setSelected] = useState<Pack | null>(null);
  const [images, setImages] = useState<Wallpaper[]>([]);
  const [imagesLoading, setImagesLoading] = useState(false);

  useEffect(() => {
    if (!supabaseConfigured) return;
    let cancelled = false;
    void Promise.resolve(supabase.from("packs").select("*").order("created_at", { ascending: false }).then(({ data }) => { if (!cancelled) { setPacks(data ?? []); setPacksLoading(false); } })).catch(() => { if (!cancelled) setPacksLoading(false); });
    return () => { cancelled = true; };
  }, []);
  useEffect(() => {
    if (!selected) return;
    let cancelled = false;
    void Promise.resolve(supabase.from("wallpapers").select("id, image_url").eq("pack_id", selected.id).then(({ data }) => { if (!cancelled) { setImages(data ?? []); setImagesLoading(false); } })).catch(() => { if (!cancelled) setImagesLoading(false); });
    return () => { cancelled = true; };
  }, [selected]);
  const shown = useMemo(() => category === "All" ? packs : packs.filter((pack) => {
    const terms = CATEGORY_TAGS[category] ?? [category.toLowerCase()];
    return pack.tags?.some((tag) => terms.includes(tag.toLowerCase())) || terms.some((term) => pack.name.toLowerCase().includes(term));
  }), [packs, category]);

  return <div className="page-shell">
    <header className="page-intro"><div><span className="eyebrow">03 / Desktop atmosphere</span><h1 className="display-title">A view worth<br /><em>coming back to.</em></h1></div><p className="lede">Small curated collections for your big screen. Pick a mood, browse the pack, and save the ones that feel like yours.</p></header>
    <div className="section-head"><div><span className="eyebrow">Browse by mood</span><h2>Where to today?</h2></div></div>
    <div className="wallpaper-categories">{CATEGORIES.map((item) => <button key={item.name} className="category-card" style={{ "--category-art": item.art } as React.CSSProperties} onClick={() => setCategory(category === item.name ? "All" : item.name)} aria-pressed={category === item.name}><small>{item.number} / COLLECTION</small><strong>{item.name}</strong></button>)}</div>
    <div className="control-row" style={{ marginBottom: 18 }}><button className={`chip ${category === "All" ? "active" : ""}`} onClick={() => setCategory("All")}>All collections</button>{category !== "All" && <span className="eyebrow">{category} selected</span>}</div>
    {packsLoading && <div className="wallpaper-empty" aria-live="polite">Preparing the collections…</div>}
    {!packsLoading && packs.length === 0 && <div className="wallpaper-empty"><strong>The first collections are on their way.</strong>The visual browsing experience is ready for the catalog. No wallpaper files are fetched or downloaded from this frontend.</div>}
    {!packsLoading && packs.length > 0 && shown.length === 0 && <div className="wallpaper-empty"><strong>No {category} collections yet.</strong>Try another mood or browse all collections.</div>}
    {shown.length > 0 && <div className="wallpaper-grid">{shown.map((pack, index) => <button key={pack.id} className="wallpaper-pack" onClick={() => { setImages([]); setImagesLoading(true); setSelected(pack); }} aria-label={`Open ${pack.name} collection`}>
      {pack.cover_url ? <Image src={pack.cover_url} alt={`${pack.name} wallpaper collection cover`} width={1200} height={900} unoptimized loading={index < 2 ? "eager" : "lazy"} /> : <div style={{ aspectRatio: "4 / 3", background: CATEGORIES.find((c) => pack.tags?.some((t) => t.toLowerCase() === c.name.toLowerCase()))?.art ?? CATEGORIES[1].art }} />}
      <span className="wallpaper-pack-info"><strong>{pack.name}</strong><small>{pack.resolution || "Desktop wallpapers"} · {pack.count} images</small></span>
    </button>)}</div>}
    {!supabaseConfigured && <p className="notice-line">Collection cards are wired for the future catalog; this frontend does not download artwork.</p>}
    {selected && <div className="modal-backdrop" role="presentation" onClick={() => setSelected(null)}><section className="wallpaper-modal" role="dialog" aria-modal="true" aria-labelledby="wallpaper-title" onClick={(event) => event.stopPropagation()}>
      <div className="modal-head"><div><button className="text-link" onClick={() => setSelected(null)} style={{ display: "inline-flex", gap: 6, marginBottom: 12 }}><ArrowLeft size={14} /> Back to collections</button><h2 id="wallpaper-title">{selected.name}</h2><span className="modal-license">{selected.resolution || "Desktop wallpapers"} · {selected.count} images · {selected.license} license</span></div><button className="chip" aria-label="Close collection" onClick={() => setSelected(null)}><X size={17} /></button></div>
      {imagesLoading ? <div className="wallpaper-empty">Loading the collection…</div> : images.length > 0 ? <div className="preview-grid">{images.map((wallpaper, index) => <a key={wallpaper.id} className="preview-image" href={wallpaper.image_url} download={`taured-${selected.slug}-${index + 1}`}><Image src={wallpaper.image_url} alt={`${selected.name} wallpaper ${index + 1}`} width={900} height={900} unoptimized loading="lazy" /><span className="text-link" style={{ display: "inline-flex", gap: 5, marginTop: 8 }}><ArrowDown size={13} /> Download image</span></a>)}</div> : <div className="wallpaper-empty"><strong>Preview images are being prepared.</strong>This pack doesn’t have individual previews available yet.</div>}
      <div className="modal-actions">{selected.zip_url ? <a className="pill-action" href={selected.zip_url} download><DownloadSimple size={17} /> Download full pack <ArrowUpRight size={15} /></a> : <button className="pill-action" type="button" disabled title="Full pack not available yet"><DownloadSimple size={17} /> Full pack coming soon</button>}<span className="modal-license">Free to download · {selected.license}</span><a className="text-link" href={patreon} target="_blank" rel="noreferrer">Support the solo dev ↗</a></div>
    </section></div>}
  </div>;
}
