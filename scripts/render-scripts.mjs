import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { buildWindowsScript } from "../src/lib/scripts/windows.ts";
import { buildLinuxScript } from "../src/lib/scripts/linux.ts";
import { readFileSync } from "node:fs";

const apps = JSON.parse(readFileSync("data/apps.json", "utf8"));
const outDir = join("scripts", "preview");
mkdirSync(outDir, { recursive: true });

const windows = buildWindowsScript(apps);
const linux = buildLinuxScript(apps);
writeFileSync(join(outDir, "preview-windows.ps1"), windows);
writeFileSync(join(outDir, "preview-linux.sh"), linux);
console.log(`rendered ${apps.length} apps into ${outDir}`);