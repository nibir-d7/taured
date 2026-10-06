import type { Metadata } from "next";

export const metadata: Metadata = { title: "Terms" };

export default function Page() {
  return (
    <article className="mx-auto max-w-3xl space-y-4 px-4 py-14 text-sm leading-relaxed text-muted-foreground">
      <h1 className="text-3xl font-bold tracking-tight text-foreground">Terms of Service</h1>
      <p>Last updated: October 2026</p>
      <p>taured.space is provided free of charge, as is. All scripts are generated for your convenience and are meant to be reviewed before execution. You are solely responsible for running them on your machines. We make no warranties regarding the suitability or safety of any third-party package referenced in generated scripts.</p>
      <p>Wallpaper packs are CC0 unless stated otherwise. Do not submit copyrighted material.</p>
      <p>We may change the content, features, or branding of this site at any time without notice.</p>
    </article>
  );
}
