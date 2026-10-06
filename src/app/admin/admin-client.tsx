"use client";

import { useEffect, useRef, useState } from "react";
import Image from "next/image";
import { supabase, supabaseConfigured, isAuthorizedAdmin } from "@/lib/supabase";
import type { Pack, Wallpaper } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";

const SQL_SCHEMA = `create table if not exists packs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  description text,
  tags text[] default '{}',
  cover_url text,
  count int default 0,
  resolution text default '4K',
  license text default 'CC0',
  zip_url text,
  created_at timestamptz default now()
);

create table if not exists wallpapers (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid references packs(id) on delete cascade,
  image_url text not null,
  width int, height int,
  size_kb int,
  created_at timestamptz default now()
);

alter table packs enable row level security;
alter table wallpapers enable row level security;

create policy "public read packs" on packs for select using (true);
create policy "public read wallpapers" on wallpapers for select using (true);
create policy "admin write packs" on packs for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
create policy "admin write wallpapers" on wallpapers for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

insert into storage.buckets (id, name, public) values ('wallpapers', 'wallpapers', true) on conflict do nothing;
create policy "public read wallpapers bucket" on storage.objects for select using (bucket_id = 'wallpapers');
create policy "admin write wallpapers bucket" on storage.objects for all using (bucket_id = 'wallpapers' and auth.role() = 'authenticated') with check (bucket_id = 'wallpapers' and auth.role() = 'authenticated');
`;

function slugify(text: string): string {
  return text.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

export default function AdminClient() {
  const [session, setSession] = useState<{ user?: { email?: string } } | null>(null);
  const [checkingAuth, setCheckingAuth] = useState(true);

  // Simple Email & Password Login
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loginError, setLoginError] = useState("");
  const [loginLoading, setLoginLoading] = useState(false);

  // Packs & Wallpapers state
  const [packs, setPacks] = useState<Pack[]>([]);
  const [selectedPackId, setSelectedPackId] = useState<string>("");
  const [wallpapers, setWallpapers] = useState<Wallpaper[]>([]);
  const [loadingWallpapers, setLoadingWallpapers] = useState(false);
  const [missingTables, setMissingTables] = useState(false);
  const [copiedSql, setCopiedSql] = useState(false);

  // New Pack Form
  const [packName, setPackName] = useState("");
  const [packCategory, setPackCategory] = useState("Landscape");
  const [packResolution, setPackResolution] = useState("4K");

  // New Wallpaper inputs
  const [imageUrlInput, setImageUrlInput] = useState("");
  const [uploadStatus, setUploadStatus] = useState("");
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Auth session check
  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session as unknown as { user?: { email?: string } } | null);
      setCheckingAuth(false);
    });
    const { data: listener } = supabase.auth.onAuthStateChange((_e, s) => {
      setSession(s as unknown as { user?: { email?: string } } | null);
      setCheckingAuth(false);
    });
    return () => listener?.subscription?.unsubscribe();
  }, []);

  // Fetch packs
  const loadPacks = async () => {
    const { data, error } = await supabase.from("packs").select("*").order("created_at", { ascending: false });
    if (error) {
      if (error.code === "PGRST205" || error.message.includes("schema cache")) {
        setMissingTables(true);
      }
    } else {
      setMissingTables(false);
      setPacks(data ?? []);
      if (!selectedPackId && data && data.length > 0) {
        setSelectedPackId(data[0].id);
      }
    }
  };

  useEffect(() => {
    if (!session?.user?.email) return;
    loadPacks();
  }, [session]);

  // Load wallpapers for selected pack
  const loadWallpapers = async (packId: string) => {
    if (!packId) return;
    setLoadingWallpapers(true);
    const { data } = await supabase
      .from("wallpapers")
      .select("*")
      .eq("pack_id", packId)
      .order("created_at", { ascending: false });
    setWallpapers(data ?? []);
    setLoadingWallpapers(false);
  };

  useEffect(() => {
    if (selectedPackId) {
      loadWallpapers(selectedPackId);
    } else {
      setWallpapers([]);
    }
  }, [selectedPackId]);

  // Handle Login
  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoginError("");
    setLoginLoading(true);

    const { data, error } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password,
    });

    if (error) {
      setLoginError(error.message);
      setLoginLoading(false);
      return;
    }

    setSession(data.session as unknown as { user?: { email?: string } } | null);
    setLoginLoading(false);
  };

  // Create Pack
  const handleCreatePack = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!packName.trim()) return;

    const slug = slugify(packName);
    const { data, error } = await supabase
      .from("packs")
      .insert({
        name: packName.trim(),
        slug,
        tags: [packCategory],
        resolution: packResolution,
        count: 0,
      })
      .select()
      .single();

    if (error) {
      alert("Error creating pack: " + error.message);
      return;
    }

    setPacks([data, ...packs]);
    setSelectedPackId(data.id);
    setPackName("");
  };

  // Delete Pack
  const handleDeletePack = async (pack: Pack) => {
    if (!confirm(`Delete pack "${pack.name}" and all its wallpapers?`)) return;
    const { error } = await supabase.from("packs").delete().eq("id", pack.id);
    if (error) {
      alert("Error deleting pack: " + error.message);
      return;
    }
    const updated = packs.filter((p) => p.id !== pack.id);
    setPacks(updated);
    setSelectedPackId(updated[0]?.id || "");
  };

  // Add Wallpaper via File Upload
  const handleUploadFiles = async (files: FileList | null) => {
    if (!files || files.length === 0 || !selectedPackId) return;
    const currentPack = packs.find((p) => p.id === selectedPackId);
    if (!currentPack) return;

    setUploadStatus(`Uploading ${files.length} wallpaper(s)…`);

    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const ext = file.name.split(".").pop() || "png";
      const filePath = `packs/${currentPack.slug}/${Date.now()}-${slugify(file.name.replace(/\.[^/.]+$/, ""))}.${ext}`;

      // 1. Upload to storage
      const { error: uploadError } = await supabase.storage.from("wallpapers").upload(filePath, file, {
        contentType: file.type || "image/png",
        upsert: false,
      });

      if (uploadError) {
        alert(`Failed to upload ${file.name}: ${uploadError.message}`);
        continue;
      }

      // 2. Get Public URL
      const { data: urlData } = supabase.storage.from("wallpapers").getPublicUrl(filePath);
      const publicUrl = urlData.publicUrl;

      // 3. Insert into wallpapers table
      await supabase.from("wallpapers").insert({
        pack_id: currentPack.id,
        image_url: publicUrl,
        size_kb: Math.round(file.size / 1024),
      });

      // Update cover if empty
      if (!currentPack.cover_url) {
        currentPack.cover_url = publicUrl;
        await supabase.from("packs").update({ cover_url: publicUrl }).eq("id", currentPack.id);
      }
    }

    // Refresh wallpapers and update count
    const { data: latestWallpapers } = await supabase
      .from("wallpapers")
      .select("*")
      .eq("pack_id", currentPack.id)
      .order("created_at", { ascending: false });

    const newCount = latestWallpapers?.length || 0;
    await supabase.from("packs").update({ count: newCount }).eq("id", currentPack.id);

    setWallpapers(latestWallpapers ?? []);
    setPacks((prev) => prev.map((p) => (p.id === currentPack.id ? { ...p, count: newCount, cover_url: currentPack.cover_url } : p)));
    setUploadStatus("");
  };

  // Add Wallpaper via URL
  const handleAddUrl = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!imageUrlInput.trim() || !selectedPackId) return;
    const currentPack = packs.find((p) => p.id === selectedPackId);
    if (!currentPack) return;

    const url = imageUrlInput.trim();
    const { data: inserted, error } = await supabase
      .from("wallpapers")
      .insert({
        pack_id: currentPack.id,
        image_url: url,
      })
      .select()
      .single();

    if (error) {
      alert("Error adding wallpaper: " + error.message);
      return;
    }

    const updated = [inserted, ...wallpapers];
    const newCount = updated.length;
    const newCover = currentPack.cover_url || url;

    await supabase.from("packs").update({ count: newCount, cover_url: newCover }).eq("id", currentPack.id);

    setWallpapers(updated);
    setPacks((prev) => prev.map((p) => (p.id === currentPack.id ? { ...p, count: newCount, cover_url: newCover } : p)));
    setImageUrlInput("");
  };

  // Delete Wallpaper
  const handleDeleteWallpaper = async (wp: Wallpaper) => {
    if (!confirm("Delete this wallpaper?")) return;
    const { error } = await supabase.from("wallpapers").delete().eq("id", wp.id);
    if (error) {
      alert("Error deleting: " + error.message);
      return;
    }

    const updated = wallpapers.filter((w) => w.id !== wp.id);
    const currentPack = packs.find((p) => p.id === selectedPackId);
    if (currentPack) {
      let newCover = currentPack.cover_url;
      if (currentPack.cover_url === wp.image_url) {
        newCover = updated[0]?.image_url || null;
      }
      await supabase.from("packs").update({ count: updated.length, cover_url: newCover }).eq("id", currentPack.id);
      setPacks((prev) => prev.map((p) => (p.id === currentPack.id ? { ...p, count: updated.length, cover_url: newCover } : p)));
    }

    setWallpapers(updated);
  };

  // Set Wallpaper as Pack Cover
  const handleSetCover = async (imageUrl: string) => {
    if (!selectedPackId) return;
    await supabase.from("packs").update({ cover_url: imageUrl }).eq("id", selectedPackId);
    setPacks((prev) => prev.map((p) => (p.id === selectedPackId ? { ...p, cover_url: imageUrl } : p)));
  };

  if (!supabaseConfigured) {
    return <p className="mx-auto max-w-xl p-10 text-sm text-muted-foreground">Configure Supabase in .env.local first.</p>;
  }

  if (checkingAuth) {
    return <p className="mx-auto max-w-xl p-10 text-sm text-muted-foreground">Checking login…</p>;
  }

  // Not signed in -> Simple login form
  if (!session) {
    return (
      <div className="mx-auto flex max-w-sm flex-col gap-4 px-4 py-20">
        <h1 className="text-xl font-bold tracking-tight text-white">Admin Login</h1>
        <p className="text-xs text-muted-foreground">Sign in to add and delete wallpapers on admin.taured.space</p>

        <form onSubmit={handleLogin} className="flex flex-col gap-3">
          <div>
            <Label className="text-xs text-muted-foreground">Email</Label>
            <Input
              type="email"
              placeholder="nibirbiswas410@gmail.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="mt-1"
            />
          </div>

          <div>
            <Label className="text-xs text-muted-foreground">Password</Label>
            <Input
              type="password"
              placeholder="••••••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="mt-1"
            />
          </div>

          {loginError && <p className="text-xs text-red-400">{loginError}</p>}

          <Button type="submit" disabled={loginLoading} className="mt-2 bg-[#8ccf7e] text-black font-semibold hover:bg-[#a3db97]">
            {loginLoading ? "Signing in…" : "Sign In"}
          </Button>
        </form>
      </div>
    );
  }

  // Signed in user authorization check
  const userEmail = session?.user?.email;
  if (!isAuthorizedAdmin(userEmail)) {
    return (
      <div className="mx-auto flex max-w-md flex-col gap-3 px-4 py-16 text-center">
        <h1 className="text-lg font-bold text-red-400">Access Denied</h1>
        <p className="text-sm text-muted-foreground">Logged in as {userEmail}, but not authorized as admin.</p>
        <Button variant="outline" size="sm" onClick={() => supabase.auth.signOut()} className="mx-auto w-fit">
          Sign out
        </Button>
      </div>
    );
  }

  const selectedPack = packs.find((p) => p.id === selectedPackId);

  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-6 px-4 py-10">
      {/* Top Header */}
      <div className="flex items-center justify-between border-b border-line pb-4">
        <div>
          <h1 className="text-xl font-bold text-white">Wallpaper Admin</h1>
          <p className="text-xs text-muted-foreground">Signed in as {userEmail}</p>
        </div>
        <div className="flex items-center gap-2">
          <a href="/wallpapers" target="_blank" className="text-xs text-acid underline">
            Public Wallpapers ↗
          </a>
          <Button variant="outline" size="sm" onClick={() => supabase.auth.signOut()}>
            Sign out
          </Button>
        </div>
      </div>

      {/* Database Schema Alert if tables are missing in Supabase */}
      {missingTables && (
        <div className="rounded border border-amber-500/40 bg-amber-950/20 p-4 text-xs text-amber-200">
          <div className="flex items-center justify-between">
            <span>
              <strong>Setup needed:</strong> Tables <code>packs</code> and <code>wallpapers</code> not found in Supabase.
            </span>
            <Button
              size="sm"
              variant="outline"
              onClick={() => {
                navigator.clipboard.writeText(SQL_SCHEMA);
                setCopiedSql(true);
                setTimeout(() => setCopiedSql(false), 2500);
              }}
            >
              {copiedSql ? "Copied SQL!" : "Copy SQL Migration"}
            </Button>
          </div>
          <p className="mt-1 text-muted-foreground">
            Paste and run this in your Supabase SQL Editor (https://supabase.com/dashboard/project/vlczimklurqcjwfmzzwk/sql).
          </p>
        </div>
      )}

      {/* PACKS MANAGEMENT */}
      <div className="grid gap-6 md:grid-cols-3">
        {/* Left: Packs list & Create Form */}
        <div className="flex flex-col gap-4 rounded border border-line p-4 md:col-span-1">
          <h2 className="text-sm font-semibold uppercase tracking-wider text-muted-foreground">Wallpaper Packs ({packs.length})</h2>

          {/* New Pack Form */}
          <form onSubmit={handleCreatePack} className="flex flex-col gap-2 rounded bg-[#161f22] p-3 text-xs">
            <span className="font-semibold text-white">Create New Pack</span>
            <Input
              placeholder="Pack Name (e.g. Nordic Winter)"
              value={packName}
              onChange={(e) => setPackName(e.target.value)}
              required
              className="h-8 text-xs"
            />
            <div className="flex gap-2">
              <select
                value={packCategory}
                onChange={(e) => setPackCategory(e.target.value)}
                className="h-8 flex-1 rounded border border-line bg-black/40 px-2 text-xs text-white"
              >
                <option value="Landscape">Landscape</option>
                <option value="Minimal">Minimal</option>
                <option value="Sci-fi">Sci-fi</option>
                <option value="Anime">Anime</option>
              </select>
              <select
                value={packResolution}
                onChange={(e) => setPackResolution(e.target.value)}
                className="h-8 flex-1 rounded border border-line bg-black/40 px-2 text-xs text-white"
              >
                <option value="4K">4K</option>
                <option value="5K">5K</option>
                <option value="8K">8K</option>
                <option value="Ultrawide">Ultrawide</option>
              </select>
            </div>
            <Button type="submit" size="sm" className="bg-[#8ccf7e] text-black font-semibold hover:bg-[#a3db97]">
              + Add Pack
            </Button>
          </form>

          {/* Pack selection list */}
          <div className="flex flex-col gap-1.5 overflow-y-auto max-h-[450px]">
            {packs.map((p) => {
              const active = p.id === selectedPackId;
              return (
                <div
                  key={p.id}
                  onClick={() => setSelectedPackId(p.id)}
                  className={`flex cursor-pointer items-center justify-between rounded p-2.5 text-xs transition ${
                    active ? "bg-[#232f33] text-white border border-[#8ccf7e]" : "border border-line/50 hover:bg-white/5"
                  }`}
                >
                  <div className="truncate">
                    <strong className="block truncate">{p.name}</strong>
                    <span className="text-[10px] text-muted-foreground">
                      {p.resolution || "4K"} · {p.count || 0} images
                    </span>
                  </div>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-6 px-1.5 text-red-400 hover:text-red-300"
                    onClick={(e) => {
                      e.stopPropagation();
                      handleDeletePack(p);
                    }}
                  >
                    ×
                  </Button>
                </div>
              );
            })}
          </div>
        </div>

        {/* Right: Wallpapers inside selected pack */}
        <div className="flex flex-col gap-4 rounded border border-line p-4 md:col-span-2">
          {selectedPack ? (
            <>
              <div className="flex items-center justify-between border-b border-line/60 pb-3">
                <div>
                  <h2 className="text-base font-bold text-white">{selectedPack.name}</h2>
                  <span className="text-xs text-muted-foreground">
                    slug: {selectedPack.slug} · {wallpapers.length} wallpapers · {selectedPack.tags?.join(", ")}
                  </span>
                </div>
                {selectedPack.cover_url && (
                  <Badge variant="outline" className="text-[10px]">
                    Cover Set ✓
                  </Badge>
                )}
              </div>

              {/* Add Wallpaper Controls */}
              <div className="flex flex-col gap-3 rounded bg-[#161f22] p-4 text-xs">
                <span className="font-semibold text-white">Add Wallpapers</span>

                {/* File Upload Button */}
                <div className="flex items-center gap-3">
                  <input
                    ref={fileInputRef}
                    type="file"
                    multiple
                    accept="image/*"
                    className="hidden"
                    onChange={(e) => {
                      handleUploadFiles(e.target.files);
                      e.target.value = "";
                    }}
                  />
                  <Button
                    type="button"
                    onClick={() => fileInputRef.current?.click()}
                    className="bg-[#8ccf7e] text-black font-semibold hover:bg-[#a3db97]"
                  >
                    📁 Upload Wallpaper Images (File)
                  </Button>
                  {uploadStatus && <span className="text-xs text-acid">{uploadStatus}</span>}
                </div>

                {/* URL Input */}
                <form onSubmit={handleAddUrl} className="flex gap-2 pt-2 border-t border-line/40">
                  <Input
                    type="url"
                    placeholder="Or paste direct image URL (https://...)"
                    value={imageUrlInput}
                    onChange={(e) => setImageUrlInput(e.target.value)}
                    className="h-8 text-xs"
                  />
                  <Button type="submit" size="sm" variant="outline">
                    Add URL
                  </Button>
                </form>
              </div>

              {/* Wallpapers List / Grid */}
              <div className="flex flex-col gap-2">
                <span className="text-xs font-semibold text-muted-foreground uppercase">
                  Wallpapers ({wallpapers.length})
                </span>

                {loadingWallpapers ? (
                  <p className="p-6 text-center text-xs text-muted-foreground">Loading images…</p>
                ) : wallpapers.length === 0 ? (
                  <p className="rounded border border-dashed border-line p-8 text-center text-xs text-muted-foreground">
                    No wallpapers in this pack yet. Click &quot;Upload Wallpaper Images&quot; above to add.
                  </p>
                ) : (
                  <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
                    {wallpapers.map((wp) => {
                      const isCover = selectedPack.cover_url === wp.image_url;
                      return (
                        <div key={wp.id} className="relative group overflow-hidden rounded border border-line bg-black/40">
                          <div className="relative aspect-[16/10] w-full">
                            <Image
                              src={wp.image_url}
                              alt="Wallpaper"
                              fill
                              unoptimized
                              className="object-cover"
                            />
                            {isCover && (
                              <span className="absolute left-1.5 top-1.5 rounded bg-[#8ccf7e] px-1.5 py-0.5 text-[9px] font-bold text-black uppercase">
                                Cover
                              </span>
                            )}
                          </div>

                          <div className="flex items-center justify-between p-2 text-[11px]">
                            {!isCover ? (
                              <button
                                type="button"
                                onClick={() => handleSetCover(wp.image_url)}
                                className="text-xs text-muted-foreground hover:text-[#8ccf7e]"
                              >
                                Set Cover
                              </button>
                            ) : (
                              <span className="text-[10px] text-[#8ccf7e]">Pack Cover</span>
                            )}

                            <div className="flex items-center gap-1.5">
                              <a
                                href={wp.image_url}
                                target="_blank"
                                rel="noreferrer"
                                className="text-muted-foreground hover:text-white"
                                title="Open full size"
                              >
                                ↗
                              </a>
                              <Button
                                variant="destructive"
                                size="sm"
                                className="h-6 px-1.5 text-xs"
                                onClick={() => handleDeleteWallpaper(wp)}
                              >
                                Delete
                              </Button>
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </>
          ) : (
            <div className="p-10 text-center text-xs text-muted-foreground">
              Select or create a wallpaper pack to add wallpapers.
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
