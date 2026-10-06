# taured.space

Free, open, no-login utilities for your machine.

- **Software Setup** — pick apps, get one script that installs everything. Windows & Linux.
- **Tweak your OS** — safe, reversible debloat, privacy, and performance tweaks from one CLI command.
- **Wallpapers** — curated 4K CC0 packs, single or full ZIP download.

No accounts. No paywalls. Readable scripts only.

## Develop

```bash
npm install
npm run dev        # http://localhost:3000
npm run build      # static export to out/
npm run lint
npm run validate:apps
```

## Sync

```bash
npm run sync:apps        # data/apps.json + data/templates.json → Supabase (needs SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY)
npm run sync:tweak-cli   # data/tweaks.json → cli/taured-lin tweak tab
```

## CLI

```bash
# Linux TUI
cd cli/taured-lin
cargo build --release    # binary: target/release/taured

# Windows toolbox
cd cli/taured-win
pwsh -File Compile.ps1   # produces taured.ps1
```

Windows build note: use a space-free MinGW path (e.g. `C:\mingw`) with it first on `PATH`.

## Environment

Create `.env.local` with your Supabase project values:

```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
NEXT_PUBLIC_CF_ANALYTICS_TOKEN=
```

Database schema lives in `supabase/migrations/0001_init.sql`.
