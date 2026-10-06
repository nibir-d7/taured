import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

export const supabaseConfigured = Boolean(url && key);
export const supabase = createClient(
  url || "https://placeholder.supabase.co",
  key || "placeholder-anon-key"
);

export const adminEmails = (process.env.NEXT_PUBLIC_ADMIN_EMAILS || "nibir.cns@gmail.com,hello@taured.space,admin@example.com")
  .split(",")
  .map((e) => e.trim().toLowerCase())
  .filter(Boolean);

export function isAuthorizedAdmin(email?: string | null): boolean {
  if (!email) return false;
  if (adminEmails.length === 0 || adminEmails.includes("*")) return true;
  return adminEmails.includes(email.toLowerCase());
}
