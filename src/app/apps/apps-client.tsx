"use client";

import { useEffect, useMemo, useState } from "react";
import { ArrowDown, ArrowUpRight, Check, Copy, DownloadSimple, Briefcase, Camera, ChatCircle, Chats, Code, Cube, Desktop, FileArchive, FilmStrip, GameController, GitBranch, Globe, Image as ImageIcon, NotePencil, PenNib, PlayCircle, VideoCamera, Waveform, Wrench } from "@phosphor-icons/react";
import { supabase, supabaseConfigured } from "@/lib/supabase";
import { bundledApps, bundledTemplates } from "@/lib/catalog";
import type { App, Template } from "@/lib/types";
import { buildWindowsScript } from "@/lib/scripts/windows";
import { buildLinuxScript } from "@/lib/scripts/linux";

function detectedPlatform(): "windows" | "linux" {
  return typeof navigator !== "undefined" && /linux/i.test(navigator.userAgent) && !/android/i.test(navigator.userAgent) ? "linux" : "windows";
}
const fromQuery = () => typeof window === "undefined" ? new Set<string>() : new Set((new URLSearchParams(window.location.search).get("apps") ?? "").split(",").filter(Boolean));

const extraApps: App[] = [
  ["chrome", "Google Chrome", "Web browser", "browser"], ["brave", "Brave", "Privacy browser", "browser"], ["vivaldi", "Vivaldi", "Power-user browser", "browser"], ["opera", "Opera", "Web browser", "browser"], ["edge", "Microsoft Edge", "Web browser", "browser"],
  ["firefox-developer", "Firefox Developer Edition", "Developer browser", "browser"], ["thunderbird", "Thunderbird", "Email client", "communication"], ["signal", "Signal", "Private messaging", "communication"], ["telegram", "Telegram", "Messaging", "communication"], ["zoom", "Zoom", "Video meetings", "communication"], ["slack", "Slack", "Team chat", "communication"], ["notion", "Notion", "Notes and workspace", "productivity"], ["obsidian", "Obsidian", "Linked notes", "productivity"], ["todoist", "Todoist", "Task manager", "productivity"], ["libreoffice", "LibreOffice", "Office suite", "productivity"], ["7zip", "7-Zip", "File archiver", "utilities"], ["powertoys", "PowerToys", "Windows utilities", "utilities"], ["everything", "Everything", "File search", "utilities"], ["keepassxc", "KeePassXC", "Password manager", "utilities"],
  ["figma", "Figma", "Interface design", "creator"], ["blender", "Blender", "3D creation", "creator"], ["krita", "Krita", "Digital painting", "creator"], ["inkscape", "Inkscape", "Vector design", "creator"], ["davinci-resolve", "DaVinci Resolve", "Video editing", "creator"], ["handbrake", "HandBrake", "Video conversion", "creator"],
  ["postman", "Postman", "API development", "developer"], ["jetbrains-toolbox", "JetBrains Toolbox", "Developer IDEs", "developer"], ["github-desktop", "GitHub Desktop", "Git client", "developer"], ["go", "Go", "Programming language", "developer"], ["rust", "Rust", "Programming language", "developer"], ["powershell", "PowerShell 7", "Terminal shell", "developer"], ["warp", "Warp", "Modern terminal", "developer"], ["insomnia", "Insomnia", "API client", "developer"],
  ["steam", "Steam", "Game library", "gaming"], ["epic-games", "Epic Games Launcher", "Game library", "gaming"], ["gog-galaxy", "GOG Galaxy", "Game library", "gaming"], ["heroic", "Heroic Games Launcher", "Game library", "gaming"], ["lutris", "Lutris", "Linux game manager", "gaming"], ["moonlight", "Moonlight", "Game streaming", "gaming"], ["discord", "Discord", "Gaming community", "gaming"],
  ["anki", "Anki", "Flashcards", "student"], ["zotero", "Zotero", "Research manager", "student"], ["calibre", "Calibre", "Ebook manager", "student"], ["geogebra", "GeoGebra", "Math tools", "student"], ["inkscape-student", "Inkscape", "Diagramming", "student"],
  ["itunes", "iTunes", "Music and media manager", "media"], ["spotify", "Spotify", "Online music service", "media"], ["foobar2000", "foobar2000", "Music player", "media"], ["winamp", "Winamp", "Music player", "media"], ["k-lite", "K-Lite Codecs", "Video decoders and Media Player Classic", "media"], ["gom", "GOM Player", "Video player", "media"], ["mediamonkey", "MediaMonkey", "Music organizer", "media"],
  ["dotnet48", ".NET 4.8.1", "Microsoft .NET Framework", ".NET"], ["dotnet8", ".NET Desktop Runtime 8 x64", ".NET Desktop Runtime", ".NET"], ["dotnet9", ".NET Desktop Runtime 9 x64", ".NET Desktop Runtime", ".NET"], ["dotnet10", ".NET Desktop Runtime 10 x64", ".NET Desktop Runtime", ".NET"], ["aspnet8", "ASP.NET Core Runtime 8", "ASP.NET runtime", ".NET"],
  ["java8", "Java x64 8", "Java Runtime Environment", "Java"], ["java11", "Java x64 11", "Java Runtime Environment", "Java"], ["java17", "Java x64 17", "Java Runtime Environment", "Java"], ["java21", "Java x64 21", "Java Runtime Environment", "Java"], ["jdk17", "JDK x64 17", "Java Development Kit", "Java"],
  ["cura", "UltiMaker Cura", "3D printing slicer", "3D Printing"], ["bambu", "Bambu Studio", "3D printing slicer", "3D Printing"], ["foxit", "Foxit Reader", "PDF reader", "Documents"], ["sumatrapdf", "SumatraPDF", "Lightweight PDF reader", "Documents"], ["qbittorrent", "qBittorrent", "BitTorrent client", "File Sharing"], ["dropbox", "Dropbox", "Online file sync", "Online Storage"], ["googledrive", "Google Drive", "Online file sync", "Online Storage"], ["malwarebytes", "Malwarebytes", "Malware remover", "Security"], ["avast", "Avast", "Free antivirus", "Security"], ["7zip", "7-Zip", "Compression utility", "Compression"], ["winrar", "WinRAR", "File compression tool", "Compression"], ["wireshark", "Wireshark", "Network protocol analyzer", "Utilities"], ["anydesk", "AnyDesk", "Remote desktop", "Utilities"], ["rustdesk", "RustDesk", "Open-source remote desktop", "Utilities"]
].map(([id, name, description, category]) => ({ id, name, description, category, icon: id, verified: true, win_winget: null, win_choco: null, linux_apt: null, linux_dnf: null, linux_pacman: null, linux_flatpak: null, linux_snap: null }));

const brandSlugs: Record<string, string> = { "vscode": "visualstudiocode", "git": "git", "nodejs": "nodedotjs", "docker": "docker", "python": "python", "google-chrome": "googlechrome", chrome: "googlechrome", brave: "brave", vivaldi: "vivaldi", opera: "opera", edge: "microsoftedge", firefox: "firefox", "firefox-developer": "firefoxbrowser", thunderbird: "thunderbird", signal: "signal", telegram: "telegram", zoom: "zoom", slack: "slack", notion: "notion", obsidian: "obsidian", todoist: "todoist", libreoffice: "libreoffice", figma: "figma", blender: "blender", krita: "krita", inkscape: "inkscape", "davinci-resolve": "davinciresolve", handbrake: "handbrake", postman: "postman", "github-desktop": "github", go: "go", rust: "rust", powershell: "powershell", steam: "steam", discord: "discord", anki: "anki", zotero: "zotero", calibre: "calibre", gimp: "gimp", obs: "obsstudio", audacity: "audacity", vlc: "vlc" };
const niniteCategory: Record<string, string> = { browser: "Web Browsers", communication: "Messaging", creator: "Imaging", developer: "Developer Tools", productivity: "Documents", utilities: "Utilities", gaming: "Other", minimal: "Other", student: "Documents" };
const roleQuestions: Record<string, { label: string; hint: string; ids: string[] }[]> = {
  developer: [{ label: "Choose your browser", hint: "One or more browsers for testing and daily work.", ids: ["chrome", "firefox", "brave", "vivaldi", "opera", "edge", "firefox-developer"] }, { label: "Choose your IDE", hint: "Pick the editors and environments you actually use.", ids: ["vscode", "jetbrains-toolbox", "github-desktop", "notepadplusplus", "sublime-text", "cursor"] }, { label: "Choose runtimes", hint: "Languages and runtimes for your projects.", ids: ["nodejs", "python", "go", "rust", "java17", "jdk17"] }, { label: "Choose CLI and API tools", hint: "The tools that keep your terminal moving.", ids: ["docker", "powershell", "warp", "postman", "insomnia", "git"] }],
  creator: [{ label: "Choose your creative suite", hint: "Image, video, audio, and 3D tools.", ids: ["gimp", "krita", "blender", "inkscape", "figma", "davinci-resolve"] }, { label: "Choose capture and media tools", hint: "Record, convert, and manage your media.", ids: ["obs", "audacity", "handbrake", "vlc", "spotify", "mediamonkey"] }, { label: "Choose your browser", hint: "For research, references, and publishing.", ids: ["chrome", "firefox", "brave", "vivaldi", "opera"] }],
  student: [{ label: "Choose your browser", hint: "Research, classes, and everyday browsing.", ids: ["chrome", "firefox", "brave", "edge"] }, { label: "Choose study tools", hint: "Notes, references, flashcards, and documents.", ids: ["libreoffice", "notion", "obsidian", "anki", "zotero", "calibre"] }, { label: "Choose communication", hint: "Stay in touch with your classes and groups.", ids: ["zoom", "discord", "slack", "telegram"] }],
  gamer: [{ label: "Choose your launcher", hint: "Your libraries, in one setup.", ids: ["steam", "epic-games", "gog-galaxy", "heroic", "lutris"] }, { label: "Choose voice and chat", hint: "Squad comms and communities.", ids: ["discord", "telegram", "signal"] }, { label: "Choose your browser", hint: "Guides, streams, and everything else.", ids: ["chrome", "firefox", "brave", "opera"] }],
  minimal: [{ label: "Choose your browser", hint: "Keep it light, keep it yours.", ids: ["firefox", "brave", "chrome", "vivaldi"] }, { label: "Choose essentials", hint: "A few useful tools without the clutter.", ids: ["vlc", "7zip", "keepassxc", "libreoffice", "thunderbird"] }]
};

function AppIcon({ icon, name, id }: { icon: string | null; name: string; id: string }) {
  const props = { size: 22, weight: "duotone" as const };
  const icons: Record<string, React.ReactNode> = { code: <Code {...props} />, "git-branch": <GitBranch {...props} />, docker: <Cube {...props} />, image: <ImageIcon {...props} />, video: <VideoCamera {...props} />, waveform: <Waveform {...props} />, "film-strip": <FilmStrip {...props} />, globe: <Globe {...props} />, "game-controller": <GameController {...props} />, chat: <ChatCircle {...props} />, chats: <Chats {...props} />, "play-circle": <PlayCircle {...props} />, "file-zip": <FileArchive {...props} />, "note-pencil": <NotePencil {...props} />, wrench: <Wrench {...props} />, "video-camera": <VideoCamera {...props} />, briefcase: <Briefcase {...props} />, "pen-nib": <PenNib {...props} /> };
  const slug = brandSlugs[id] ?? brandSlugs[icon ?? ""];
  return <span className="app-icon">{slug ? <img src={`https://cdn.simpleicons.org/${slug}`} alt="" /> : icons[icon ?? ""] ?? <Desktop {...props} />}<span className="app-icon-fallback">{name.slice(0, 1)}</span></span>;
}

function PresetArt({ id }: { id: string }) {
  const props = { size: 78, weight: "duotone" as const };
  const icon = id === "developer" ? <Code {...props} /> : id === "creator" ? <Camera {...props} /> : id === "minimal" ? <CircleNotchedIcon /> : id === "student" ? <NotePencil {...props} /> : id === "gamer" ? <GameController {...props} /> : <span className="manual-crosshair">+</span>;
  return <span className={`preset-art preset-art-${id}`}>{icon}</span>;
}

function CircleNotchedIcon() { return <span className="minimal-mark" aria-hidden="true" />; }

export default function AppsClient() {
  const [apps, setApps] = useState<App[]>(supabaseConfigured ? [] : [...bundledApps, ...extraApps]);
  const [templates, setTemplates] = useState<Template[]>(supabaseConfigured ? [] : bundledTemplates);
  const [loading, setLoading] = useState(supabaseConfigured);
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("All apps");
  const [selected, setSelected] = useState<Set<string>>(fromQuery);
  const [os, setOs] = useState<"windows" | "linux">("windows");
  const [notice, setNotice] = useState("");
  const [showDonation, setShowDonation] = useState(false);
  const [catalogVisible, setCatalogVisible] = useState(false);
  const [wizardMode, setWizardMode] = useState(false);
  const [wizardIndex, setWizardIndex] = useState(0);
  const [activePreset, setActivePreset] = useState<string | null>(null);

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => setOs(detectedPlatform()));
    if (!supabaseConfigured) return () => window.cancelAnimationFrame(frame);
    let cancelled = false;
    Promise.all([supabase.from("apps").select("*").order("name"), supabase.from("templates").select("*")]).then(([a, t]) => {
      if (cancelled) return;
      setApps(a.data?.length ? a.data : [...bundledApps, ...extraApps]); setTemplates(t.data?.length ? t.data : bundledTemplates); setLoading(false);
    }).catch(() => setLoading(false));
    return () => { cancelled = true; window.cancelAnimationFrame(frame); };
  }, []);

  const categories = useMemo(() => ["All apps", ...new Set(apps.map((app) => niniteCategory[app.category ?? ""] ?? app.category).filter((value): value is string => Boolean(value)))], [apps]);
  const filtered = useMemo(() => apps.filter((a) => (category === "All apps" || (niniteCategory[a.category ?? ""] ?? a.category) === category) && `${a.name} ${a.category ?? ""} ${a.description ?? ""}`.toLowerCase().includes(query.toLowerCase())), [apps, category, query]);
  const grouped = useMemo(() => Object.entries(filtered.reduce<Record<string, App[]>>((groups, app) => { const key = (niniteCategory[app.category ?? ""] ?? app.category) || "Other"; (groups[key] ??= []).push(app); return groups; }, {})), [filtered]);
  const selectedApps = apps.filter((a) => selected.has(a.id));
  const selectedTemplate = templates.find((template) => template.id === activePreset);
  const wizardQuestions = selectedTemplate ? roleQuestions[selectedTemplate.id] ?? [] : [];
  const wizardQuestion = wizardQuestions[wizardIndex];
  const wizardApps = wizardQuestion ? apps.filter((app) => wizardQuestion.ids.includes(app.id)) : [];
  const script = selectedApps.length ? os === "windows" ? buildWindowsScript(selectedApps) : buildLinuxScript(selectedApps) : "";

  useEffect(() => {
    if (loading || typeof window === "undefined") return;
    const params = new URLSearchParams(); if (selected.size) params.set("apps", [...selected].join(",")); params.set("os", os);
    window.history.replaceState(null, "", `?${params.toString()}`);
  }, [selected, os, loading]);

  const toggle = (id: string) => setSelected((current) => { const next = new Set(current); if (next.has(id)) next.delete(id); else next.add(id); return next; });
  const copy = async (value: string, label: string) => { await navigator.clipboard.writeText(value); setNotice(`${label} copied`); window.setTimeout(() => setNotice(""), 2400); };
  const download = () => {
    if (!script) return;
    const blob = new Blob([script], { type: "text/plain;charset=utf-8" }); const url = URL.createObjectURL(blob); const anchor = document.createElement("a");
    anchor.href = url; anchor.download = os === "windows" ? "taured-setup-windows.ps1" : "taured-setup-linux.sh"; anchor.click(); URL.revokeObjectURL(url); setShowDonation(true);
  };
  const cancelPicker = () => { setWizardMode(false); setCatalogVisible(false); setActivePreset(null); setSelected(new Set()); setWizardIndex(0); };

  return <div className={`page-shell ${catalogVisible ? "catalog-open" : ""}`}>
    <div className="app-page-kicker"><span className="eyebrow">01 / Choose your setup</span><span>Draft a bundle, then edit every pick</span></div>
    <div className="preset-grid">{templates.map((t) => <button key={t.id} className={`preset-card ${activePreset === t.id ? "active" : ""}`} onClick={() => { setActivePreset(t.id); setSelected(new Set(t.app_ids)); setWizardIndex(0); setWizardMode(true); setCatalogVisible(false); }}><span className="preset-number">{String(templates.indexOf(t) + 1).padStart(2, "0")}</span><PresetArt id={t.id} /><strong>{t.name}</strong></button>)}<button className="preset-card manual" onClick={() => { setActivePreset("manual"); setSelected(new Set()); setWizardMode(false); setCatalogVisible(true); }}><span className="preset-number">+</span><PresetArt id="manual" /><strong>Manual selection</strong><span>Open full catalog →</span></button></div>
    {activePreset && activePreset !== "manual" && <p className="selection-note">{selected.size} apps drafted · edit your picks below</p>}
    {(wizardMode || catalogVisible) && <div className="app-picker-backdrop"><div className="app-picker-modal"><div className="picker-modal-bar"><span className="eyebrow">{activePreset === "manual" ? "Manual selection" : `${activePreset ?? "Setup"} builder`}</span><button className="picker-cancel" onClick={cancelPicker}>Cancel and choose another</button></div><button className="picker-close" aria-label="Close app picker" onClick={cancelPicker}>×</button>
    {wizardMode && wizardQuestion && <section className="setup-wizard"><div className="wizard-top"><div><span className="eyebrow">{activePreset} setup · {wizardIndex + 1} / {wizardQuestions.length}</span><h2>{wizardQuestion.label}</h2><p>{wizardQuestion.hint}</p></div><button className="chip" onClick={() => { setWizardMode(false); setCatalogVisible(true); }}>Skip to full catalog</button></div><div className="wizard-progress"><span style={{ width: `${((wizardIndex + 1) / wizardQuestions.length) * 100}%` }} /></div><div className="wizard-options">{wizardApps.map((app) => <label key={app.id} className={`wizard-option ${selected.has(app.id) ? "selected" : ""}`}><input className="app-check" type="checkbox" checked={selected.has(app.id)} onChange={() => toggle(app.id)} /><AppIcon icon={app.icon} name={app.name} id={app.id} /><span><strong>{app.name}</strong><small>{app.description || "Desktop app"}</small></span></label>)}</div><div className="wizard-actions"><button className="chip" disabled={wizardIndex === 0} onClick={() => setWizardIndex((index) => Math.max(0, index - 1))}>← Back</button>{wizardIndex < wizardQuestions.length - 1 ? <button className="pill-action" onClick={() => setWizardIndex((index) => index + 1)}>Next question →</button> : <button className="pill-action acid" onClick={() => { setWizardMode(false); setCatalogVisible(true); }}>Review full selection →</button>}</div></section>}
    <div className="apps-toolbar"><div className="control-row">{categories.map((item) => <button key={item} className={`chip ${category === item ? "active" : ""}`} onClick={() => setCategory(item)}>{item}</button>)}</div><input className="search-field" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search the catalog…" aria-label="Search apps" /></div>
    <div className="control-row" style={{ marginBottom: 15 }}><span className="eyebrow">Detected OS</span><button className={`chip ${os === "windows" ? "active" : ""}`} onClick={() => setOs("windows")}>Windows</button><button className={`chip ${os === "linux" ? "active" : ""}`} onClick={() => setOs("linux")}>Linux</button></div>
    {loading ? <div className="wallpaper-empty">Loading the app catalog…</div> : apps.length === 0 ? <div className="wallpaper-empty"><strong>The catalog is ready for its first apps.</strong>Add apps from the admin page or sync the bundled catalog.</div> : filtered.length === 0 ? <div className="wallpaper-empty"><strong>No apps match that search.</strong>Try another name or choose a different category.</div> : <div className="catalog-sections">{grouped.map(([group, items]) => <section className="catalog-section" key={group}><div className="catalog-section-head"><div><span className="eyebrow">{items.length} picks</span><h2>{group}</h2></div><span>Choose as many as you like</span></div><div className="app-grid">{items.map((app) => <label key={app.id} className={`app-option ${selected.has(app.id) ? "selected" : ""}`}><input className="app-check" type="checkbox" checked={selected.has(app.id)} onChange={() => toggle(app.id)} /><AppIcon icon={app.icon} name={app.name} id={app.id} /><span><strong>{app.name}</strong><small>{app.description || "Desktop app"}</small>{app.verified && <span className="verified-mark">✓ Verified source</span>}</span></label>)}</div></section>)}</div>}
    {script && <div className="code-panel" id="installer-script"><p className="eyebrow" style={{ color: "#cad8a0" }}>Your {os === "windows" ? "PowerShell" : "shell"} installer · {selectedApps.length} apps</p><pre>{script}</pre><div className="code-actions"><button className="pill-action acid" onClick={download}><DownloadSimple size={17} /> Download {os === "windows" ? ".ps1" : ".sh"}</button><button className="pill-action outline" onClick={() => copy(script, "Installer script")}><Copy size={16} /> Copy script</button><button className="pill-action outline" onClick={() => copy(`${window.location.origin}/apps?apps=${[...selected].join(",")}&os=${os}`, "Share link")}><ArrowUpRight size={16} /> Copy share link</button></div><p className="notice-line" style={{ color: "#b7c4b2" }}>Review the script before running it. Apps install through your system’s package manager.</p></div>}
    {selected.size > 0 && <div className="sticky-download"><span>{selected.size} app{selected.size === 1 ? "" : "s"} selected</span><a className="pill-action acid" href="#installer-script">Review installer <ArrowDown size={16} /></a></div>}
    {notice && <p className="notice-line" role="status"><Check size={14} /> {notice}</p>}
    {showDonation && <div className="donate-nudge" role="status"><span>Your installer is ready. Want to support a solo dev?</span><a className="text-link" href="https://www.patreon.com/nibirbiswas" target="_blank" rel="noreferrer">Donate ↗</a><button aria-label="Dismiss" onClick={() => setShowDonation(false)}>×</button></div>}
    </div></div>}
  </div>;
}
