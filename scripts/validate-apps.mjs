import { readFileSync } from "node:fs";

const apps = JSON.parse(readFileSync("data/apps.json", "utf8"));
const templates = JSON.parse(readFileSync("data/templates.json", "utf8"));
const ids = new Set(apps.map((a) => a.id));
const errors = [];

for (const a of apps) {
  if (!a.id || !a.name) errors.push(`app missing id/name: ${JSON.stringify(a)}`);
  if (!a.win_winget && !a.win_choco && !a.linux_apt && !a.linux_flatpak && !a.linux_snap)
    errors.push(`${a.id}: no install mapping`);
  if (ids.has(a.id) && apps.filter((x) => x.id === a.id).length > 1)
    errors.push(`${a.id}: duplicate id`);
}
for (const t of templates) {
  for (const id of t.app_ids ?? []) if (!ids.has(id)) errors.push(`template ${t.id}: unknown app ${id}`);
}

if (errors.length) {
  console.error(errors.join("\n"));
  process.exit(1);
}
console.log(`OK: ${apps.length} apps, ${templates.length} templates`);
