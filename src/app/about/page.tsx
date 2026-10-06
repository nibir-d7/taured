import type { Metadata } from "next";

export const metadata: Metadata = { title: "About" };

export default function Page() {
  return (
    <article className="mx-auto max-w-3xl space-y-4 px-4 py-14 text-sm leading-relaxed text-muted-foreground">
      <h1 className="text-3xl font-bold tracking-tight text-foreground">About taured.space</h1>
      <p>taured.space is a global, free-forever utility platform for developers, creators, and power users. It started from a simple frustration: setting up a new machine is tedious, and the tools that automate it are either closed, Windows-only, or risky.</p>
      <p>We believe every script should be readable, every tweak should be reversible, and nobody should have to pay to get their own computer working. The site is open source and funded by minimal, non-intrusive ads only.</p>
    </article>
  );
}
