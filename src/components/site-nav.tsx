"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { motion } from "motion/react";

import { useEffect, useState } from "react";

export function SiteNav() {
  const pathname = usePathname();
  const [isAdminSubdomain, setIsAdminSubdomain] = useState(false);

  useEffect(() => {
    if (typeof window !== "undefined" && window.location.hostname.startsWith("admin.")) {
      setIsAdminSubdomain(true);
    }
  }, []);

  const isAdmin = pathname.startsWith("/admin") || isAdminSubdomain;

  if (isAdmin) {
    return (
      <nav className="nav-wrap" aria-label="Admin navigation">
        <Link href={isAdminSubdomain ? "/" : "/admin"} className="brand">
          <span className="brand-mark" aria-hidden="true"><i /><i /><i /></span>
          <span className="brand-wordmark"><b>tau</b><b>red</b><em>.admin</em></span>
        </Link>
        <div className="nav-links">
          <Link href={isAdminSubdomain ? "/" : "/admin"} aria-current="page">
            <motion.span layoutId="nav-active-pill" className="nav-active-pill" transition={{ type: "spring", stiffness: 420, damping: 32 }} />
            Studio
          </Link>
          <Link href="/wallpapers" target="_blank">
            Wallpapers ↗
          </Link>
          <Link href="/apps" target="_blank">
            Apps ↗
          </Link>
        </div>
        <a className="nav-donate" href="https://taured.space" target="_blank" rel="noreferrer">
          taured.space <span aria-hidden="true">↗</span>
        </a>
      </nav>
    );
  }

  const links = [["/apps", "Apps"], ["/tweaks", "Tweaks"], ["/wallpapers", "Wallpapers"]] as const;
  return <nav className="nav-wrap" aria-label="Main navigation">
    <Link href="/" className="brand"><span className="brand-mark" aria-hidden="true"><i /><i /><i /></span><span className="brand-wordmark"><b>tau</b><b>red</b><em>.space</em></span></Link>
    <div className="nav-links">{links.map(([href, label]) => { const active = pathname.startsWith(href); return <Link key={href} href={href} aria-current={active ? "page" : undefined}>{active && <motion.span layoutId="nav-active-pill" className="nav-active-pill" transition={{ type: "spring", stiffness: 420, damping: 32 }} />}{label}</Link>; })}</div>
    <a className="nav-donate" href="https://www.patreon.com/nibirbiswas" target="_blank" rel="noreferrer">Donate <span aria-hidden="true">↗</span></a>
  </nav>;
}
