export type App = {
  id: string;
  name: string;
  description: string | null;
  category: string | null;
  icon: string | null;
  verified: boolean;
  win_winget: string | null;
  win_choco: string | null;
  linux_apt: string | null;
  linux_dnf: string | null;
  linux_pacman: string | null;
  linux_flatpak: string | null;
  linux_snap: string | null;
  homepage?: string | null;
};

export type Template = {
  id: string;
  name: string;
  description: string | null;
  app_ids: string[];
  tweak_ids: string[];
};

export type Pack = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  tags: string[];
  cover_url: string | null;
  count: number;
  resolution: string | null;
  license: string;
  zip_url: string | null;
};
