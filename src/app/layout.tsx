import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Workout Tracker",
  description: "Personal workout logging with pain-aware progression.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  // Mobile-first: primary use is on a phone at the gym.
  maximumScale: 1,
  themeColor: "#f3f3f5",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="h-full">
      <body className="min-h-full">{children}</body>
    </html>
  );
}
