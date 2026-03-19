"use client";

import { ApolloClient, InMemoryCache, HttpLink, from } from "@apollo/client/core";
import { setContext } from "@apollo/client/link/context";

const HASURA_URL =
  process.env.NEXT_PUBLIC_HASURA_URL ?? "http://localhost:8080/v1/graphql";

function getToken(): string | null {
  if (typeof window === "undefined") return null;
  try {
    return localStorage.getItem("hrms_token");
  } catch {
    return null;
  }
}

const httpLink = new HttpLink({ uri: HASURA_URL });

const authLink = setContext((_, { headers }) => {
  const token = getToken();
  return {
    headers: {
      ...headers,
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
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
