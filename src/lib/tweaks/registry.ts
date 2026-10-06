import data from "../../../data/tweaks.json";

export type Risk = "safe" | "recommended" | "advanced";

export type Tweak = {
  id: string;
  name: string;
  description: string;
  category: "debloat" | "privacy" | "performance" | "appearance" | "fixes";
  platform: "windows" | "linux";
  risk: Risk;
  does: string;
  revert: string;
  script: string;
};

export const tweaks = data as Tweak[];
