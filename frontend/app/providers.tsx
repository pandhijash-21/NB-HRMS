"use client";

import { SessionProvider } from "next-auth/react";
import { ApolloProvider } from "@apollo/client/react";
import { apolloClient } from "@/lib/apollo-client";
import type { ReactNode } from "react";

export function AppProviders({ children }: { children: ReactNode }) {
  return (
    <SessionProvider>
      <ApolloProvider client={apolloClient}>{children}</ApolloProvider>
    </SessionProvider>
  );
}

