import Link from "next/link";
import { requireUser } from "@/lib/auth/session";
import { HistoryTabs } from "./history-tabs";

export default async function HistoryLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  await requireUser();

  return (
    <div className="mx-auto flex min-h-dvh max-w-[420px] flex-col">
      <header className="sticky top-0 z-10 border-b border-line bg-card px-[18px] pb-0 pt-4">
        <Link href="/" className="text-[12px] text-ink-2">
          ← Days
        </Link>
        <h1 className="mt-1.5 text-[21px] font-semibold tracking-[-0.01em]">
          History
        </h1>
        <HistoryTabs />
      </header>
      <main className="px-3 pb-10 pt-3">{children}</main>
    </div>
  );
}
