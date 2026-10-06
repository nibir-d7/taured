import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const { ids = [], os = "windows" } = await req.json();
    if (!Array.isArray(ids) || ids.length === 0 || !["windows", "linux"].includes(os)) {
      return Response.json({ error: "provide ids[] and os" }, { status: 400, headers: corsHeaders });
    }
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!);
    const { data: apps, error } = await supabase.from("apps").select("*").in("id", ids);
    if (error) throw error;

    const lines: string[] = [];
    if (os === "windows") {
      lines.push("# taured.space — Windows setup script (signed)");
      lines.push("# Review every line before running. Create a restore point first.");
      lines.push("$ErrorActionPreference = 'Stop'", "");
      for (const a of apps ?? []) {
        if (a.win_winget) lines.push(`# ${a.name}`, `winget install --id ${a.win_winget} -e --source winget`, "");
        else if (a.win_choco) lines.push(`# ${a.name}`, `choco install ${a.win_choco} -y`, "");
      }
    } else {
      lines.push("#!/usr/bin/env bash", "# taured.space — Linux setup script (signed)", "set -euo pipefail", "");
      for (const a of apps ?? []) {
        const pkg = a.linux_apt ?? a.linux_dnf ?? a.linux_pacman;
        if (pkg) lines.push(`# ${a.name}`, `sudo apt-get install -y ${pkg}`, "");
      }
    }
    const script = lines.join("\n");
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(script));
    const sha256 = [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");

    const secret = Deno.env.get("SCRIPT_SIGNING_SECRET") ?? "";
    const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
    const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(script));
    const signature = [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");

    return Response.json({ script, sha256, signature }, { headers: corsHeaders });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500, headers: corsHeaders });
  }
});
