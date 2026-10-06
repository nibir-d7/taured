import { readFileSync, writeFileSync, mkdirSync, readdirSync, rmSync } from "node:fs";
import { join } from "node:path";

const tweaks = JSON.parse(readFileSync("data/tweaks.json", "utf8"));
const linux = tweaks.filter((t) => t.platform === "linux");
const dir = "cli/taured-lin/core/tabs/taured-tweaks";
mkdirSync(dir, { recursive: true });
// remove old generated scripts
for (const f of readdirSync(dir)) if (f.endsWith(".sh")) rmSync(join(dir, f));

const lines = ['name = "Taured Tweaks"', ""];
for (const t of linux) {
  const file = `${t.id.replace(/^lin-/, "")}.sh`;
  writeFileSync(join(dir, file), `#!/usr/bin/env bash\nset -euo pipefail\n\n${t.script}\n`);
  lines.push("[[data]]");
  lines.push(`name = "${t.name}"`);
  lines.push(`description = "${t.description.replace(/"/g, '\\"')}"`);
  lines.push(`script = "${file}"`);
  lines.push('task_list = "I"');
  lines.push("");
}
writeFileSync(join(dir, "tab_data.toml"), lines.join("\n"));

const tabsPath = "cli/taured-lin/core/tabs/tabs.toml";
const tabs = readFileSync(tabsPath, "utf8");
if (!tabs.includes('"taured-tweaks"')) {
  writeFileSync(tabsPath, tabs.replace(/directories = \[\r?\n/, 'directories = [\n    "taured-tweaks",\n'));
}
console.log(`generated ${linux.length} tweak entries into ${dir}`);
