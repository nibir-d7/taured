"use client";

import { useEffect, useMemo, useState } from "react";
import { supabase, supabaseConfigured } from "@/lib/supabase";
import type { App, Template } from "@/lib/types";
import { buildWindowsScript } from "@/lib/scripts/windows";
import { buildLinuxScript } from "@/lib/scripts/linux";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Textarea } from "@/components/ui/textarea";

export default function AppsClient() {
  const [apps, setApps] = useState<App[]>([]);
  const [templates, setTemplates] = useState<Template[]>([]);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [os, setOs] = useState<"windows" | "linux">("windows");

  useEffect(() => {
    if (!supabaseConfigured) return;
    supabase.from("apps").select("*").order("name").then(({ data }) => { setApps(data ?? []); setLoading(false); });
    supabase.from("templates").select("*").then(({ data }) => setTemplates(data ?? []));
  }, []);

  const filtered = useMemo(() => {
    const q = query.toLowerCase();
    return apps.filter((a) => a.name.toLowerCase().includes(q) || (a.category ?? "").includes(q));
  }, [apps, query]);

  const selectedApps = apps.filter((a) => selected.has(a.id));
  const script = selectedApps.length
    ? os === "windows"
      ? buildWindowsScript(selectedApps)
      : buildLinuxScript(selectedApps)
    : "";

  const toggle = (id: string) =>
    setSelected((s) => {
      const n = new Set(s);
      if (n.has(id)) n.delete(id); else n.add(id);
      return n;
    });

  return (
    <div className="mx-auto flex max-w-5xl flex-col items-center gap-8 px-4 py-14 text-center">
      <section>
        <h1 className="text-4xl font-bold tracking-tight">Software Setup</h1>
        <p className="mt-2 text-sm text-muted-foreground">Pick apps · one script · auto-installs. Ninite-style, no login.</p>
      </section>

      {!supabaseConfigured && (
        <p className="rounded border border-dashed p-3 text-sm text-muted-foreground">
          Supabase not configured yet — set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY in .env.local.
        </p>
      )}

      <div className="flex w-full flex-wrap justify-center gap-2">
        {templates.map((t) => (
          <button key={t.id} onClick={() => setSelected(new Set(t.app_ids))}
            className="rounded-full border bg-white px-4 py-1.5 text-sm transition hover:bg-accent dark:bg-neutral-900">
            {t.name}
          </button>
        ))}
        <button onClick={() => setSelected(new Set())} className="rounded-full px-4 py-1.5 text-sm text-muted-foreground transition hover:text-foreground">Clear</button>
      </div>

      <Input placeholder="Search apps…" value={query} onChange={(e) => setQuery(e.target.value)} className="w-full max-w-md rounded-full text-center" />

      {loading && <p className="text-sm text-muted-foreground">Loading apps…</p>}
      {!loading && apps.length === 0 && supabaseConfigured && (
        <p className="text-sm text-muted-foreground">No apps yet — run <code>npm run sync:apps</code> or add them in /admin.</p>
      )}
      <div className="grid w-full gap-3 text-left sm:grid-cols-2 lg:grid-cols-3">
        {filtered.map((app) => (
          <label key={app.id} className="flex items-start gap-3 rounded-2xl border bg-white p-4 text-sm shadow-sm transition hover:shadow-md dark:bg-neutral-900">
            <Checkbox checked={selected.has(app.id)} onCheckedChange={() => toggle(app.id)} />
            <span>
              <span className="font-semibold">{app.name}</span>{" "}
              {app.verified && <Badge variant="secondary">verified</Badge>}
              <span className="block text-xs text-muted-foreground">{app.description}</span>
            </span>
          </label>
        ))}
      </div>

      <div className="flex items-center gap-2">
        <Button variant={os === "windows" ? "default" : "outline"} className="rounded-full" onClick={() => setOs("windows")}>Windows</Button>
        <Button variant={os === "linux" ? "default" : "outline"} className="rounded-full" onClick={() => setOs("linux")}>Linux</Button>
        <span className="text-sm text-muted-foreground">{selected.size} selected</span>
      </div>

      {script && (
        <div className="flex w-full flex-col gap-3 rounded-3xl border bg-white p-6 text-left shadow-sm dark:bg-neutral-900">
          <Textarea readOnly rows={14} className="bg-neutral-50 font-mono text-xs dark:bg-neutral-950" value={script} />
          <div className="flex gap-2">
            <Button onClick={() => navigator.clipboard.writeText(script)}>Copy</Button>
            <Button
              variant="outline"
              onClick={() => {
                const blob = new Blob([script], { type: "text/plain" });
                const a = document.createElement("a");
                a.href = URL.createObjectURL(blob);
                a.download = os === "windows" ? "taured-setup-windows.ps1" : "taured-setup-linux.sh";
                a.click();
              }}
            >
              Download
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
