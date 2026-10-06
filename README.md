<p align="center">
  <img src="./public/taured-logo.png" alt="taured" width="96" />
</p>

<h1 align="center">taured</h1>

<p align="center">Free, open, no-login utilities for Windows and Linux.<br/>Every script readable. Every tweak reversible. No paywalls, ever.</p>

---

## One command

**Windows (PowerShell as Administrator)**

```powershell
irm https://raw.githubusercontent.com/nibir-d7/taured/master/cli/taured-win/scripts/start.ps1 | iex
```

**Linux**

```sh
curl -sL https://raw.githubusercontent.com/nibir-d7/taured/master/cli/taured-lin/start.sh | sh
```

That's it. The launcher elevates on Windows, picks the right binary for your CPU on Linux, and cleans up after itself.

## What's inside

| Tool | What it does |
| --- | --- |
| **Install** | Browse and install apps and MSIX packages from the system package managers (winget, Chocolatey, Store) with one click |
| **Tweaks** | Essential fixes, privacy hardening, debloat, performance and appearance tweaks — each with a working undo |
| **Config** | Update profiles, DNS presets, and one-click environment exports |
| **Updates** | Profiles for Windows Update behaviour, plus restore-point and DISM health tools |
| **Web** | taured.space — pick apps in the browser, get one install script. No login, no tracking beyond aggregate pageviews |

## Why taured

- **Free forever.** Funded by a single, non-intrusive ad slot. Nothing is gated.
- **No account.** Open it, use it, close it. Nothing to sign up for.
- **No lock-in.** Settings can be exported to JSON and applied to other machines.
- **Transparent.** Every action shows the commands it runs before it runs them.
- **Cross-platform.** Windows and Linux, from the same project.

## Credits

taured builds on excellent open-source work:

- **[WinUtil](https://github.com/ChrisTitusTech/winutil)** by Chris Titus Tech — the Windows toolbox this project is based on
- **[LinUtil](https://github.com/ChrisTitusTech/linutil)** by Chris Titus Tech — the Linux toolbox this project is based on
- Contributions from the upstream communities, including [@MyDrift-user](https://github.com/MyDrift-user), [@Marterich](https://github.com/Marterich) and [@DeveloperDurp](https://github.com/DeveloperDurp)

## Build from source

```powershell
git clone https://github.com/nibir-d7/taured.git
cd taured
```

**Windows**

```powershell
cd cli\taured-win
.\Compile.ps1
```

**Linux**

```sh
cd cli/taured-lin
cargo build --release
./target/release/taured
```

## Contribute

Patches are welcome. Tweaks live as individual scripts in `cli/taured-lin/core/tabs/`, and the web catalog lives in `data/apps.json`. Keep every change readable and reversible, and describe the undo path in the entry you touch.

## License

MIT. See [LICENSE](./cli/taured-lin/LICENSE).