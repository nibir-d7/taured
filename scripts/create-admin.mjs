import { createClient } from "@supabase/supabase-js";
import * as dotenv from "dotenv";

dotenv.config({ path: ".env.local" });

const url = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !key) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env.local");
  process.exit(1);
}

const email = process.argv[2] || "nibir.cns@gmail.com";
const password = process.argv[3];

if (!password) {
  console.log("Usage: node scripts/create-admin.mjs <email> <password>");
  console.log("Example: node scripts/create-admin.mjs nibir.cns@gmail.com MyStrongPassword123!");
  process.exit(1);
}

const supabase = createClient(url, key, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function main() {
  console.log(`Creating / confirming admin user: ${email}...`);
  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });

  if (error) {
    console.error("Failed to create admin:", error.message);
    process.exit(1);
  }

  console.log("Admin user created successfully!");
  console.log(`User ID: ${data.user.id}`);
  console.log(`Email: ${data.user.email}`);
  console.log("You can now sign in immediately at /admin or admin.taured.space");
}

main();
