import Link from "next/link";

export default function NotFound() {
  return (
    <div className="mx-auto flex max-w-xl flex-col items-center gap-4 px-4 py-24 text-center">
      <h1 className="text-4xl font-bold tracking-tight">404</h1>
      <p className="text-muted-foreground">That page doesn&rsquo;t exist. Head back home and pick a tool.</p>
      <Link href="/" className="inline-flex h-10 items-center rounded-full bg-neutral-900 px-6 text-sm font-medium text-white hover:bg-neutral-700 dark:bg-neutral-100 dark:text-neutral-900">
        Go home
      </Link>
    </div>
  );
}
