"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const TABS = [
  { href: "/history", label: "Sessions" },
  { href: "/history/trends", label: "Weight" },
  { href: "/history/pain", label: "Pain" },
];

export function HistoryTabs() {
  const pathname = usePathname();

  return (
    <nav className="-mb-px flex gap-1 pt-3">
      {TABS.map((tab) => {
        const active = pathname === tab.href;
        return (
          <Link
            key={tab.href}
            href={tab.href}
            className={`border-b-2 px-3 pb-2 text-[13px] font-medium ${
              active
                ? "border-ink text-ink"
                : "border-transparent text-ink-3"
            }`}
          >
            {tab.label}
          </Link>
        );
      })}
    </nav>
  );
}
