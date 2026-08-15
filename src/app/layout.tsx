import type { Metadata, Viewport } from "next";
import "./globals.css";
import { getThemePreference } from "@/lib/queries";

export const metadata: Metadata = {
  title: "Workout Tracker",
  description: "Personal workout logging with pain-aware progression.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  // Mobile-first: primary use is on a phone at the gym.
  maximumScale: 1,
  // Matched to --color-bg in each palette so the browser chrome doesn't stay
  // light around a dark page. The media-query pair covers 'system'; an explicit
  // override just lands on whichever of the two the device already matches,
  // which is close enough for a status bar.
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f3f3f5" },
    { media: "(prefers-color-scheme: dark)", color: "#0f0f11" },
  ],
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  // Resolved on the server and written into the markup, so the correct palette
  // is in place before the first paint. Reading this in a client effect would
  // render the light theme first and then flip — a white flash on every load,
  // which is worst in exactly the place this app is used: a dark gym.
  const theme = await getThemePreference();

  return (
    <html lang="en" className="h-full" data-theme={theme}>
      <body className="min-h-full">{children}</body>
    </html>
  );
}
