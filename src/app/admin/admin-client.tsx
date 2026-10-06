"use client";

import { useEffect, useState } from "react";
import { supabase, supabaseConfigured } from "@/lib/supabase";
import type { App, Pack } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";

export default function AdminClient() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [session, setSession] = useState<unknown>(null);
  const [apps, setApps] = useState<App[]>([]);
  const [packs, setPacks] = useState<Pack[]>([]);
  const [packForm, setPackForm] = useState({ name: "", slug: "", description: "", resolution: "4K", zip_url: "" });
  const [form, setForm] = useState({ id: "", name: "", win_winget: "", win_choco: "", linux_apt: "", linux_flatpak: "", category: "developer" });

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    supabase.auth.onAuthStateChange((_e, s) => setSession(s));
  }, []);

  useEffect(() => {
    if (!session) return;
    supabase.from("apps").select("*").order("name").then(({ data }) => setApps(data ?? []));
    supabase.from("packs").select("*").order("created_at", { ascending: false }).then(({ data }) => setPacks(data ?? []));
  }, [session]);

  if (!supabaseConfigured) {
    return <p className="mx-auto max-w-xl p-10 text-sm text-muted-foreground">Configure Supabase env vars first.</p>;
  }

  if (!session) {
    return (
      <div className="mx-auto flex max-w-sm flex-col gap-4 px-4 py-16">
        <h1 className="text-xl font-semibold">Admin sign in</h1>
        <Input placeholder="you@example.com" value={email} onChange={(e) => setEmail(e.target.value)} />
        <Button
          onClick={async () => {
            await supabase.auth.signInWithOtp({ email, options: { emailRedirectTo: window.location.origin + "/admin" } });
            setSent(true);
          }}
        >
          Send magic link
        </Button>
        {sent && <p className="text-sm text-muted-foreground">Check your email for the login link.</p>}
      </div>
    );
  }

  return (
    <div className="mx-auto flex max-w-4xl flex-col gap-6 px-4 py-10">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold">Admin</h1>
        <Button variant="outline" size="sm" onClick={() => supabase.auth.signOut()}>Sign out</Button>
      </div>

      <form
        className="grid gap-2 rounded border p-4 sm:grid-cols-2"
        onSubmit={async (e) => {
          e.preventDefault();
          const row: Record<string, unknown> = Object.fromEntries(Object.entries(form).map(([k, v]) => [k, v || null]));
          row.verified = true;
          const { error } = await supabase.from("apps").upsert(row);
          if (!error) {
            const { data } = await supabase.from("apps").select("*").order("name");
            setApps(data ?? []);
            setForm({ id: "", name: "", win_winget: "", win_choco: "", linux_apt: "", linux_flatpak: "", category: "developer" });
          } else alert(error.message);
        }}
      >
        <Label>Add / update app</Label>
        <div />
        <Input placeholder="id (e.g. vscode)" value={form.id} onChange={(e) => setForm({ ...form, id: e.target.value })} required />
        <Input placeholder="name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
        <Input placeholder="winget id" value={form.win_winget} onChange={(e) => setForm({ ...form, win_winget: e.target.value })} />
        <Input placeholder="choco id" value={form.win_choco} onChange={(e) => setForm({ ...form, win_choco: e.target.value })} />
        <Input placeholder="apt package" value={form.linux_apt} onChange={(e) => setForm({ ...form, linux_apt: e.target.value })} />
        <Input placeholder="flatpak id" value={form.linux_flatpak} onChange={(e) => setForm({ ...form, linux_flatpak: e.target.value })} />
        <Button type="submit">Save</Button>
      </form>

      <div className="flex flex-col gap-2">
        <h2 className="text-lg font-medium">Wallpaper packs</h2>
        <form
          className="grid gap-2 rounded border p-4 sm:grid-cols-2"
          onSubmit={async (e) => {
            e.preventDefault();
            const row = Object.fromEntries(Object.entries(packForm).map(([k, v]) => [k, v || null]));
            const { error } = await supabase.from("packs").insert(row);
            if (error) alert(error.message);
            else {
              const { data } = await supabase.from("packs").select("*").order("created_at", { ascending: false });
              setPacks(data ?? []);
              setPackForm({ name: "", slug: "", description: "", resolution: "4K", zip_url: "" });
            }
          }}
        >
          <Input placeholder="name" value={packForm.name} onChange={(e) => setPackForm({ ...packForm, name: e.target.value })} required />
          <Input placeholder="slug" value={packForm.slug} onChange={(e) => setPackForm({ ...packForm, slug: e.target.value })} required />
          <Input placeholder="description" value={packForm.description} onChange={(e) => setPackForm({ ...packForm, description: e.target.value })} />
          <Input placeholder="resolution" value={packForm.resolution} onChange={(e) => setPackForm({ ...packForm, resolution: e.target.value })} />
          <Input placeholder="zip URL (optional)" value={packForm.zip_url} onChange={(e) => setPackForm({ ...packForm, zip_url: e.target.value })} />
          <Button type="submit">Add pack</Button>
        </form>
        {packs.map((p) => (
          <div key={p.id} className="flex items-center justify-between rounded border p-3 text-sm">
            <span><b>{p.name}</b> <Badge variant="secondary">{p.resolution}</Badge></span>
            <Button variant="destructive" size="sm" onClick={async () => { await supabase.from("packs").delete().eq("id", p.id); setPacks(packs.filter((x) => x.id !== p.id)); }}>Delete</Button>
          </div>
        ))}
      </div>

      <div className="flex flex-col gap-2">
        {apps.map((a) => (
          <div key={a.id} className="flex items-center justify-between rounded border p-3 text-sm">
            <span>
              <b>{a.name}</b> <Badge variant="secondary">{a.category}</Badge>
              <span className="ml-2 font-mono text-xs text-muted-foreground">{a.id}</span>
            </span>
            <Button
              variant="destructive"
              size="sm"
              onClick={async () => {
                await supabase.from("apps").delete().eq("id", a.id);
                setApps(apps.filter((x) => x.id !== a.id));
              }}
            >
              Delete
            </Button>
          </div>
        ))}
      </div>
    </div>
  );
}
