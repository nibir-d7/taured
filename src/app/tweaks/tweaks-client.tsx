"use client";

import { useEffect, useState } from "react";
import { Check, Copy, TerminalWindow } from "@phosphor-icons/react";

type Platform = "windows" | "linux";
const commands: Record<Platform, string> = {
  windows: "irm https://raw.githubusercontent.com/nibir-d7/taured/master/cli/taured-win/scripts/start.ps1 | iex",
  linux: "curl -sL https://raw.githubusercontent.com/nibir-d7/taured/master/cli/taured-lin/start.sh | sh",
};

function detectPlatform(): Platform {
  return typeof navigator !== "undefined" && /linux/i.test(navigator.userAgent) && !/android/i.test(navigator.userAgent) ? "linux" : "windows";
}

export default function TweaksClient() {
  const [platform, setPlatform] = useState<Platform>("windows");
  const [copied, setCopied] = useState(false);
  useEffect(() => { const frame = window.requestAnimationFrame(() => setPlatform(detectPlatform())); return () => window.cancelAnimationFrame(frame); }, []);
  const command = commands[platform];
  const copy = async () => { await navigator.clipboard.writeText(command); setCopied(true); window.setTimeout(() => setCopied(false), 2200); };

  return <div className="tweaks-focus-page">
    <section className="tweaks-command-card">
      <div className="tweaks-card-top"><span className="eyebrow">02 / System tool</span><span className="tweaks-live"><i /> ready</span></div>
      <div className="tweaks-heading"><TerminalWindow size={28} weight="duotone" /><h1>One command.<br /><em>A better system.</em></h1></div>
      <p className="tweaks-lede">The taured toolbox detects your platform and launches the right collection of safe, reversible system tools.</p>
      <div className="platform-switch"><button className={platform === "windows" ? "active" : ""} onClick={() => setPlatform("windows")}>Windows</button><button className={platform === "linux" ? "active" : ""} onClick={() => setPlatform("linux")}>Linux</button></div>
      <div className="terminal-block"><div className="terminal-bar"><span><i /><i /><i /></span><small>{platform === "windows" ? "PowerShell" : "Terminal"}</small><span>taured / launch</span></div><div className="terminal-command"><span className="terminal-prompt">$</span><code>{command}</code></div><button className="copy-command" onClick={copy}>{copied ? <><Check size={18} /> Copied</> : <><Copy size={18} /> Copy command</>}</button></div>
      <p className="tweaks-footnote">Review what it runs before you execute it. Windows should be opened as Administrator.</p>
    </section>
  </div>;
}
