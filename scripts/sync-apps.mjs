import { readFile, writeFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY;
const SOURCE = process.env.WINGET_SOURCE_URL || "https://api.winget.run/v2/packages";
const TAKE = Number(process.env.WINGET_SYNC_TAKE || 500);

const queries = ["browser", "messaging", "media", "developer", "editor", "database", "terminal", "design", "game", "office", "security", "utility", "runtime", "java", "python", "node", "docker", "git", "pdf", "cloud", "audio", "video", "backup"];

function categoryFor(pkg, query) {
  const text = `${pkg.Latest?.Name ?? ""} ${pkg.Latest?.Description ?? ""} ${(pkg.Latest?.Tags ?? []).join(" ")} ${query}`.toLowerCase();
  if (/browser|firefox|chrome|chromium|vivaldi|opera|brave|edge/.test(text)) return "browser";
  if (/chat|messag|discord|slack|zoom|telegram|signal|team/.test(text)) return "communication";
  if (/audio|video|media|music|vlc|spotify|obs|handbrake/.test(text)) return "media";
  if (/java|python|node|docker|git|ide|editor|compiler|sdk|terminal|api|code/.test(text)) return "developer";
  if (/image|photo|paint|design|3d|blender|gimp|krita|inkscape/.test(text)) return "creator";
  if (/game|steam|launcher|gaming/.test(text)) return "gaming";
  if (/pdf|office|document|note|libreoffice|reader/.test(text)) return "productivity";
  if (/security|password|vpn|antivirus|malware/.test(text)) return "security";
  if (/cloud|backup|drive|dropbox|sync/.test(text)) return "storage";
  return "utilities";
}

function slug(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 70);
}

async function fetchSource(query) {
  const url = new URL(SOURCE);
  url.searchParams.set("query", query);
  url.searchParams.set("take", String(TAKE));
  url.searchParams.set("skip", "0");
  const response = await fetch(url);
  if (!response.ok) throw new Error(`WinGet source failed for ${query}: ${response.status}`);
  const body = await response.json();
  return body.Packages ?? [];
}

const fetched = (await Promise.all(queries.map(fetchSource))).flat();
let curated = [];
try { curated = JSON.parse(execFileSync("git", ["show", "HEAD:data/apps.json"], { encoding: "utf8" })); } catch { /* Source-only checkout. */ }
const deduped = new Map();
for (const pkg of fetched) {
  if (!pkg?.Id || !pkg.Latest?.Name || !pkg.Latest?.Homepage) continue;
  const id = slug(pkg.Id);
  if (!deduped.has(id)) deduped.set(id, pkg);
}

const sourceApps = [...deduped.values()].map((pkg) => ({
  id: slug(pkg.Id),
  name: pkg.Latest.Name,
  description: pkg.Latest.Description?.slice(0, 180) || `${pkg.Latest.Publisher ?? "Verified publisher"} package`,
  category: categoryFor(pkg, pkg.Latest.Tags?.join(" ") ?? ""),
  icon: pkg.IconUrl || slug(pkg.Latest.Name),
  verified: true,
  win_winget: pkg.Id,
  win_choco: null,
  linux_apt: null,
  linux_dnf: null,
  linux_pacman: null,
  linux_flatpak: null,
  linux_snap: null,
  homepage: pkg.Latest.Homepage,
  source_url: `https://winget.run/pkg/${pkg.Id}`,
  source_updated_at: pkg.UpdatedAt,
}));
const apps = [...curated, ...sourceApps.filter((candidate) => !curated.some((base) => base.id === candidate.id || base.win_winget === candidate.win_winget))].slice(0, Math.max(250, Math.min(curated.length + sourceApps.length, 500)));

if (apps.length < 200) throw new Error(`Source returned only ${apps.length} usable apps; refusing to replace the catalog.`);

await writeFile("data/apps.json", `${JSON.stringify(apps, null, 2)}\n`);
console.log(`Fetched ${apps.length} apps from ${SOURCE}`);

if (!SUPABASE_URL || !SERVICE_ROLE) {
  console.log("Catalog snapshot written. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY to upsert it.");
  process.exit(0);
}

async function upsert(table, rows, onConflict = "id") {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${table}?on_conflict=${onConflict}`, { method: "POST", headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, "Content-Type": "application/json", Prefer: "resolution=merge-duplicates,return=minimal" }, body: JSON.stringify(rows) });
  if (!response.ok) throw new Error(`${table} upsert failed: ${response.status} ${await response.text()}`);
  console.log(`${table}: upserted ${rows.length}`);
}

const categories = [...new Set(apps.map((app) => app.category))].map((id) => ({ id, name: id[0].toUpperCase() + id.slice(1) }));
const templates = JSON.parse(await readFile("data/templates.json", "utf8"));
await upsert("categories", categories);
await upsert("apps", apps);
await upsert("templates", templates);
console.log("Catalog sync complete.");
