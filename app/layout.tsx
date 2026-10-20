import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "KYAW ZIN Gaming Shop",
  description: "MLBB Diamond top-up wallet in Thai Baht",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="my"><body>{children}</body></html>;
}