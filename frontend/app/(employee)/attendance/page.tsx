"use client";

import { useSession } from "next-auth/react";
import { AttendanceTab } from "@/components/profile/tabs/AttendanceTab";
import { Skeleton } from "@/components/ui/skeleton";

export default function AttendancePage() {
  const { data: session } = useSession();
  const employeeId = Number((session?.user as { employeeId?: number })?.employeeId);

  if (!employeeId) {
    return (
      <div className="max-w-5xl mx-auto space-y-4">
        <Skeleton className="h-64 w-full rounded-xl" />
      </div>
    );
  }

  return (
    <div className="max-w-5xl mx-auto space-y-4">
      <AttendanceTab employeeId={employeeId} />
    </div>
  );
}
