import type { Metadata } from "next";
import WallpapersClient from "./wallpapers-client";

export const metadata: Metadata = {
  title: "Wallpaper Packs — taured.space",
  description: "Curated 4K CC0 wallpaper packs, single or full ZIP download.",
};

export default function Page() {
  return <WallpapersClient />;
}
