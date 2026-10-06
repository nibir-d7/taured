import type { Metadata } from "next";
import TweaksClient from "./tweaks-client";

export const metadata: Metadata = {
  title: "System Tweaker — taured.space",
  description: "Safe, reversible Windows and Linux tweaks via one CLI command.",
};

export default function Page() {
  return <TweaksClient />;
}
