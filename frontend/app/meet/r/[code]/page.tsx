"use client";

import { use } from "react";
import dynamic from "next/dynamic";

const MeetRoom = dynamic(
  () => import("@/components/meet/MeetRoom").then((m) => m.MeetRoom),
  { ssr: false, loading: () => <div className="min-h-dvh grid place-items-center">Connecting…</div> },
);

export default function MeetRoomPage({ params }: { params: Promise<{ code: string }> }) {
  const { code } = use(params);
  return (
    <div className="h-dvh">
      <MeetRoom code={code} />
    </div>
  );
}
