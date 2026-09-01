import type { Metadata } from "next";
import { Roboto } from "next/font/google";
import "./globals.css";
import { AppProviders } from "./providers";
import { Toaster } from "sonner";

const roboto = Roboto({
  variable: "--font-roboto",
  subsets: ["latin"],
  weight: ["300", "400", "500", "700"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "NB CRM",
  description: "NB CRM — CRM, HRMS and ERP",
  icons: {
    icon: "/favicon.png",
    apple: "/nb-logo.png",
  },
};

import { LocationGuard } from "@/components/auth/LocationGuard";

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className={`${roboto.variable} antialiased`}
      >
        <AppProviders>
          <LocationGuard>
            {children}
          </LocationGuard>
          <Toaster
            position="top-right"
            richColors
            closeButton
            toastOptions={{
              duration: 5000,
              classNames: {
                toast: "rounded-xl shadow-lg border border-slate-100 text-sm",
              },
            }}
          />
        </AppProviders>
      </body>
    </html>
  );
}
