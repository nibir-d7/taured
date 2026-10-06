"use client";

import { useMemo, useState } from "react";
import { tweaks, type Tweak } from "@/lib/tweaks/registry";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { Badge } from "@/components/ui/badge";
import { Textarea } from "@/components/ui/textarea";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

const riskColor: Record<Tweak["risk"], string> = {
  safe: "bg-green-100 text-green-800",
  recommended: "bg-yellow-100 text-yellow-800",
  advanced: "bg-red-100 text-red-800",
};

function buildTweakScript(platform: "windows" | "linux", selected: Tweak[]): string {
  const header =
    platform === "windows"
      ? "# taured.space — WinTweak\n# Create a restore point first: Checkpoint-Computer -Description 'Before taured tweaks' -RestorePointType MODIFY_SETTINGS\n"
      : "#!/usr/bin/env bash\n# taured.space — LinTweak\n# Back up important data first.\nset -euo pipefail\n";
  const body = selected
    .map((t) => `# --- ${t.name} [${t.risk}] ---\n# Does: ${t.does}\n# Revert: ${t.revert}\n${t.script}`)
    .join("\n\n");
  return `${header}\n${body}\n`;
}

export default function TweaksClient() {
  const [platform, setPlatform] = useState<"windows" | "linux">("windows");
  const [selected, setSelected] = useState<Set<string>>(new Set());

  const filtered = useMemo(() => tweaks.filter((t) => t.platform === platform), [platform]);
  const selectedTweaks = tweaks.filter((t) => selected.has(t.id) && t.platform === platform);
  const oneLiner =
    platform === "windows"
      ? "irm https://raw.githubusercontent.com/nibir-d7/taured/master/cli/taured-win/scripts/start.ps1 | iex"
      : "curl -sL https://raw.githubusercontent.com/nibir-d7/taured/master/cli/taured-lin/start.sh | sh";

  const toggle = (id: string) =>
    setSelected((s) => {
      const n = new Set(s);
      if (n.has(id)) n.delete(id); else n.add(id);
      return n;
    });

  return (
    <div className="mx-auto flex max-w-5xl flex-col items-center gap-6 px-4 py-14 text-center">
      <section>
        <h1 className="text-4xl font-bold tracking-tight">Tweak your OS</h1>
        <p className="mt-2 text-sm text-muted-foreground">One CLI command. Safe, reversible. Debloat, privacy, performance.</p>
      </section>

      <div className="flex w-full max-w-2xl flex-col gap-3 rounded-3xl border bg-white p-6 shadow-sm dark:bg-neutral-900">
        <p className="text-sm font-medium">
          Run it now
          {selectedTweaks.length > 0 ? ` — ${selectedTweaks.length} tweak${selectedTweaks.length > 1 ? "s" : ""} preselected below` : ""}
        </p>
        <pre className="overflow-x-auto rounded-xl bg-neutral-900 p-4 text-xs text-rose-300">{oneLiner}</pre>
        <div className="flex justify-center">
          <Button className="rounded-full" onClick={() => navigator.clipboard.writeText(oneLiner)}>Copy command</Button>
        </div>
      </div>

      <p className="text-xs text-muted-foreground">
        Create a restore point (Windows) or back up your data (Linux) before running any tweaks.
      </p>

      <div className="flex gap-2">
        <Button variant="outline" size="sm" onClick={() => {
          const json = JSON.stringify([...selected]);
          navigator.clipboard.writeText(json);
          alert("Tweak selection copied as JSON.");
        }}>Export selection</Button>
        <Button variant="outline" size="sm" onClick={() => {
          const raw = prompt("Paste exported JSON:");
          if (!raw) return;
          try { setSelected(new Set(JSON.parse(raw))); } catch { alert("Invalid JSON"); }
        }}>Import selection</Button>
      </div>

      <p className="text-xs text-muted-foreground">A preview of what the CLI ships — the full catalog lives inside the toolbox.</p>

      <Tabs value={platform} onValueChange={(v) => setPlatform(v as "windows" | "linux")}>
        <TabsList>
          <TabsTrigger value="windows">WinTweak</TabsTrigger>
          <TabsTrigger value="linux">LinTweak</TabsTrigger>
        </TabsList>
        <TabsContent value="windows" className="mt-4"><TweakList items={filtered} selected={selected} toggle={toggle} /></TabsContent>
        <TabsContent value="linux" className="mt-4"><TweakList items={filtered} selected={selected} toggle={toggle} /></TabsContent>
      </Tabs>

      {selectedTweaks.length > 0 && (
        <div className="flex w-full flex-col gap-3 rounded-3xl border bg-white p-6 text-left shadow-sm dark:bg-neutral-900">
          <p className="text-sm font-medium">Run the taured toolbox — your selection is highlighted inside:</p>
          <pre className="overflow-x-auto rounded-xl bg-neutral-900 p-4 text-xs text-rose-300">{oneLiner}</pre>
          <Button className="rounded-full" onClick={() => navigator.clipboard.writeText(oneLiner)}>Copy command</Button>
          <details className="text-xs text-muted-foreground">
            <summary>See what this runs (for transparency)</summary>
            <Textarea readOnly rows={8} className="mt-2 font-mono text-xs" value={buildTweakScript(platform, selectedTweaks)} />
          </details>
        </div>
      )}
    </div>
  );
}

function TweakList({ items, selected, toggle }: { items: Tweak[]; selected: Set<string>; toggle: (id: string) => void }) {
  return (
    <div className="flex w-full flex-col gap-3">
      {items.map((t) => (
        <label key={t.id} className="flex items-start gap-3 rounded-2xl border bg-white p-4 text-left text-sm shadow-sm dark:bg-neutral-900">
          <Checkbox checked={selected.has(t.id)} onCheckedChange={() => toggle(t.id)} />
          <span className="flex-1">
            <span className="font-medium">{t.name}</span>{" "}
            <span className={`rounded px-1.5 py-0.5 text-xs ${riskColor[t.risk]}`}>{t.risk}</span>{" "}
            <Badge variant="secondary">{t.category}</Badge>
            <span className="block text-xs text-muted-foreground">{t.description}</span>
            <span className="mt-1 block text-xs text-muted-foreground">Does: {t.does}</span>
            <span className="block text-xs text-muted-foreground">Revert: {t.revert}</span>
          </span>
        </label>
      ))}
    </div>
  );
}
