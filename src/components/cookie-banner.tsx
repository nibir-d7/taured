"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";

export function CookieBanner() {
  const [show, setShow] = useState(false);
  useEffect(() => {
    const id = requestAnimationFrame(() => {
      if (!localStorage.getItem("taured-consent")) setShow(true);
    });
    return () => cancelAnimationFrame(id);
  }, []);
  if (!show) return null;
  return (
    <div className="fixed bottom-4 inset-x-4 z-50 mx-auto flex max-w-xl flex-wrap items-center justify-center gap-3 rounded-full border bg-background px-5 py-3 text-sm shadow-lg">
      <p className="text-muted-foreground">We use minimal, privacy-friendly analytics and AdSense. By continuing you consent.</p>
      <Button size="sm" onClick={() => { localStorage.setItem("taured-consent", "1"); setShow(false); }}>Accept</Button>
    </div>
  );
}
