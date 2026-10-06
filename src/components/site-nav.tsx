"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { motion } from "motion/react";

export function SiteNav() {
  const pathname = usePathname();
  const links = [["/apps", "Apps"], ["/tweaks", "Tweaks"], ["/wallpapers", "Wallpapers"]] as const;
  return <nav className="nav-wrap" aria-label="Main navigation">
    <Link href="/" className="brand"><span className="brand-mark" aria-hidden="true"><i /><i /><i /></span><span className="brand-wordmark"><b>tau</b><b>red</b><em>.space</em></span></Link>
    <div className="nav-links">{links.map(([href, label]) => { const active = pathname.startsWith(href); return <Link key={href} href={href} aria-current={active ? "page" : undefined}>{active && <motion.span layoutId="nav-active-pill" className="nav-active-pill" transition={{ type: "spring", stiffness: 420, damping: 32 }} />}{label}</Link>; })}</div>
    <a className="nav-donate" href="https://www.patreon.com/nibirbiswas" target="_blank" rel="noreferrer">Donate <span aria-hidden="true">↗</span></a>
  </nav>;
}
