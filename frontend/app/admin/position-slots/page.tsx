"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

/** Legacy route — alias accounts live on Designations now. */
export default function PositionSlotsRedirectPage() {
  const router = useRouter();
  useEffect(() => {
    router.replace("/admin/designations#alias-accounts");
  }, [router]);
  return null;
}
