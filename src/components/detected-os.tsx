"use client";

import { useEffect, useState } from "react";

export function DetectedOs() {
  const [os, setOs] = useState("your OS");
  useEffect(() => {
    const id = requestAnimationFrame(() => {
      const ua = navigator.userAgent;
      if (ua.includes("Windows NT 10")) setOs("Windows 11/10");
      else if (ua.includes("Windows")) setOs("Windows");
      else if (ua.includes("Linux")) setOs("Linux");
      else if (ua.includes("Mac")) setOs("macOS");
    });
    return () => cancelAnimationFrame(id);
  }, []);
  return <span>Detected {os}</span>;
}
