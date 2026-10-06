import type { Metadata } from "next";

export const metadata: Metadata = { title: "Privacy" };

export default function Page() {
  return (
    <article className="mx-auto max-w-3xl space-y-4 px-4 py-14 text-sm leading-relaxed text-muted-foreground">
      <h1 className="text-3xl font-bold tracking-tight text-foreground">Privacy Policy</h1>
      <p>Last updated: October 2026</p>
      <p>taured.space is built to be used without an account. We do not sell your data.</p>
      <h2 className="text-lg font-semibold text-foreground">What we collect</h2>
      <p>With your consent, we collect privacy-friendly analytics (page views, approximate country, device type) via Cloudflare Web Analytics. We serve advertising via Google AdSense, which may use cookies to personalize or measure ads. We do not receive the contents of those cookies.</p>
      <h2 className="text-lg font-semibold text-foreground">What we never collect</h2>
      <p>We do not ask for names, emails, or passwords on any public page. The admin area is protected by Supabase Auth and restricted to the site owner.</p>
      <h2 className="text-lg font-semibold text-foreground">Script generation</h2>
      <p>Installer and tweak scripts are generated in your browser. We do not upload your selections to any server.</p>
      <h2 className="text-lg font-semibold text-foreground">Your choices</h2>
      <p>You can block cookies at any time through your browser settings. Contact us via the Contact page for any privacy questions.</p>
    </article>
  );
}
