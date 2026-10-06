"use client";

import { useEffect, useMemo, useState } from "react";
import { supabase, supabaseConfigured } from "@/lib/supabase";
import type { Pack } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Heart, X } from "@phosphor-icons/react";

const FILTERS = ["All", "Nature", "Abstract", "Minimal", "Geometric", "Dark", "Pastel"];
type Wallpaper = { id: string; image_url: string };

export default function WallpapersClient() {
  const [packs, setPacks] = useState<Pack[]>([]);
  const [packsLoading, setPacksLoading] = useState(true);
  const [filter, setFilter] = useState("All");
  const [favs, setFavs] = useState<Set<string>>(new Set());
  const [selected, setSelected] = useState<Pack | null>(null);
  const [images, setImages] = useState<Wallpaper[]>([]);

  useEffect(() => {
    if (!supabaseConfigured) return;
    supabase.from("packs").select("*").order("created_at", { ascending: false }).then(({ data }) => { setPacks(data ?? []); setPacksLoading(false); });
  }, []);

  useEffect(() => {
    if (!selected) return;
    supabase.from("wallpapers").select("id, image_url").eq("pack_id", selected.id).then(({ data }) => setImages(data ?? []));
  }, [selected]);

  const shown = useMemo(
    () => (filter === "All" ? packs : packs.filter((p) => p.tags?.some((t) => t.toLowerCase() === filter.toLowerCase()) || p.name.toLowerCase().includes(filter.toLowerCase()))),
    [packs, filter]
  );

  return (
    <div className="mx-auto flex max-w-5xl flex-col items-center gap-8 px-4 py-14">
      <section className="flex flex-col items-center gap-2 text-center">
        <h1 className="text-4xl font-bold tracking-tight">Wallpaper Packs</h1>
        <p className="text-sm text-muted-foreground">4K · CC0 · One-click</p>
      </section>

      <div className="flex flex-wrap justify-center gap-2">
        {FILTERS.map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`rounded-full border px-4 py-1.5 text-sm transition ${filter === f ? "bg-neutral-900 text-white dark:bg-neutral-100 dark:text-neutral-900" : "bg-white hover:bg-accent dark:bg-neutral-900"}`}
          >
            {f}
          </button>
        ))}
      </div>

      {!supabaseConfigured && (
        <p className="rounded-xl border border-dashed p-4 text-sm text-muted-foreground">Supabase not configured — add env vars and seed packs.</p>
      )}

      {packsLoading && <p className="text-sm text-muted-foreground">Loading packs…</p>}
      {!packsLoading && packs.length === 0 && supabaseConfigured && (
        <p className="text-sm text-muted-foreground">No packs yet — add some from /admin.</p>
      )}

      <div className="grid w-full grid-cols-2 gap-4 md:grid-cols-4">
        {shown.map((pack) => (
          <div key={pack.id} className="group relative overflow-hidden rounded-2xl border bg-white text-left shadow-sm transition hover:shadow-md dark:bg-neutral-900">
            <button onClick={() => setSelected(pack)} className="block w-full text-left">
              {pack.cover_url ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={pack.cover_url} alt={pack.name} loading="lazy" className="aspect-[4/3] w-full object-cover" />
              ) : (
                <div className="aspect-[4/3] w-full bg-gradient-to-br from-amber-100 to-rose-100" />
              )}
              <div className="p-3">
                <h2 className="text-sm font-semibold">{pack.name}</h2>
                <p className="text-xs text-muted-foreground">{pack.resolution} · {pack.count} wallpapers</p>
              </div>
            </button>
            <button
              aria-label="favorite"
              onClick={() => setFavs((s) => { const n = new Set(s); if (n.has(pack.id)) n.delete(pack.id); else n.add(pack.id); return n; })}
              className="absolute right-2 top-2 rounded-full bg-white/80 p-1.5 backdrop-blur transition hover:bg-white"
            >
              <Heart size={16} weight={favs.has(pack.id) ? "fill" : "regular"} className={favs.has(pack.id) ? "text-rose-500" : "text-neutral-500"} />
            </button>
          </div>
        ))}
      </div>

      {selected && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4 backdrop-blur-sm" onClick={() => setSelected(null)}>
          <div className="w-full max-w-2xl rounded-3xl bg-white p-6 shadow-xl dark:bg-neutral-900" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-start justify-between">
              <h2 className="text-xl font-semibold tracking-tight">{selected.name} Pack · Preview</h2>
              <button onClick={() => setSelected(null)} className="rounded-full p-1 hover:bg-accent"><X size={18} /></button>
            </div>
            <div className="mt-4 grid grid-cols-3 gap-2">
              {images.slice(0, 6).map((w) => (
                // eslint-disable-next-line @next/next/no-img-element
                <img key={w.id} src={w.image_url} alt="" loading="lazy" className="aspect-square w-full rounded-xl object-cover" />
              ))}
              {images.length === 0 && <p className="col-span-3 text-sm text-muted-foreground">No previews uploaded yet.</p>}
            </div>
            <a href={selected.zip_url ?? "#"} download className="mt-5 block">
              <Button className="h-12 w-full rounded-full bg-neutral-900 text-base text-white hover:bg-neutral-700 dark:bg-neutral-100 dark:text-neutral-900">
                Download Full Pack ZIP{selected.count ? ` — ${selected.count * 12} MB` : ""}
              </Button>
            </a>
            <p className="mt-2 text-center text-xs text-muted-foreground">Includes {selected.count} images · {selected.license} license · ZIP</p>
          </div>
        </div>
      )}
    </div>
  );
}
