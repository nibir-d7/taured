import type { Metadata } from "next";

export const metadata: Metadata = { title: "Contact" };

export default function Page() {
  return (
    <article className="mx-auto max-w-3xl space-y-4 px-4 py-14 text-sm leading-relaxed text-muted-foreground">
      <h1 className="text-3xl font-bold tracking-tight text-foreground">Contact</h1>
      <p>Email: <a className="underline" href="mailto:hello@taured.space">hello@taured.space</a></p>
      <p>For bugs or script reports, please include the generated script and your OS version.</p>
    </article>
  );
}
