import type { Metadata } from "next";
import AdminClient from "./admin-client";

export const metadata: Metadata = {
  title: "Admin — taured.space",
  robots: { index: false, follow: false },
};

export default function Page() {
  return <AdminClient />;
}
