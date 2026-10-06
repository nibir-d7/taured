import type { Metadata } from "next";
import AppsClient from "./apps-client";

export const metadata: Metadata = {
  title: "App Installer — taured.space",
  description: "Pick your apps and get one audited install script for Windows or Linux. Free, no login.",
};

export default function Page() {
  return <AppsClient />;
}
