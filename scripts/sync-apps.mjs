import { readFileSync } from "node:fs";

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!SUPABASE_URL || !SERVICE_ROLE) {
  console.error("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const apps = JSON.parse(readFileSync("data/apps.json", "utf8"));
const templates = JSON.parse(readFileSync("data/templates.json", "utf8"));

async function upsert(table, rows, onConflict = "id") {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?on_conflict=${onConflict}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_ROLE,
      Authorization: `Bearer ${SERVICE_ROLE}`,
      "Content-Type": "application/json",
      Prefer: "resolution=merge-duplicates,return=minimal",
    },
    body: JSON.stringify(rows),
  });
  if (!res.ok) {
    console.error(`${table} upsert failed: ${res.status} ${await res.text()}`);
    process.exit(1);
  }
  console.log(`${table}: upserted ${rows.length}`);
}

const categories = [...new Set(apps.map((a) => a.category).filter(Boolean))].map((id) => ({
  id,
  name: id[0].toUpperCase() + id.slice(1),
}));

await upsert("categories", categories);
await upsert("apps", apps);
await upsert("templates", templates);
console.log("Sync complete.");
