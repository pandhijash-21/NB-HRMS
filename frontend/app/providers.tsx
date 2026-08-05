"use client";

import { SessionProvider } from "next-auth/react";
import { ApolloProvider } from "@apollo/client/react";
import { apolloClient } from "@/lib/apollo-client";
import type { ReactNode } from "react";
import { QueryProvider } from "@/components/providers/QueryProvider";
import { ThemeProvider } from "next-themes";

export function AppProviders({ children }: { children: ReactNode }) {
  return (
    <ThemeProvider attribute="class" defaultTheme="system" enableSystem disableTransitionOnChange>
      <QueryProvider>
        <SessionProvider refetchOnWindowFocus={false}>
          <ApolloProvider client={apolloClient}>{children}</ApolloProvider>
        </SessionProvider>
      </QueryProvider>
    </ThemeProvider>
  );
}

