"use client";

import { useSession } from "next-auth/react";

/** True once NextAuth has a logged-in session (avoids API calls before the JWT is available). */
export function useAuthReady() {
  const { status } = useSession();
  return status === "authenticated";
}
