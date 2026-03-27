"use client";

import { ApolloClient, InMemoryCache, HttpLink, from } from "@apollo/client/core";
import { setContext } from "@apollo/client/link/context";

const HASURA_URL =
  process.env.NEXT_PUBLIC_HASURA_URL ?? "http://localhost:8080/v1/graphql";

const HASURA_ADMIN_SECRET =
  process.env.NEXT_PUBLIC_HASURA_ADMIN_SECRET ?? "myadminsecret";

import { getSession } from "next-auth/react";

async function getToken(): Promise<string | null> {
  if (typeof window === "undefined") return null;
  const session = await getSession();
  return (session as any)?.token || localStorage.getItem("hrms_token");
}

const httpLink = new HttpLink({ uri: HASURA_URL });

const authLink = setContext(async (_, { headers }) => {
  const token = await getToken();
  return {
    headers: {
      ...headers,
      ...(token
        ? { Authorization: `Bearer ${token}` }
        : { "x-hasura-admin-secret": HASURA_ADMIN_SECRET }),
    },
  };
});

export const apolloClient = new ApolloClient({
  link: from([authLink, httpLink]),
  cache: new InMemoryCache(),
  defaultOptions: {
    watchQuery: { fetchPolicy: "cache-and-network" },
  },
});
