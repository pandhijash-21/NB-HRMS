"use client";

import { useState } from "react";
import { useQuery, skipToken } from "@apollo/client/react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { GET_AUDIT_LOGS } from "@/lib/graphql";

interface AuditLogDrawerProps {
  employeeId: string;
  trigger: React.ReactNode;
}

const OPERATION_COLORS: Record<string, string> = {
  INSERT: "bg-emerald-100 text-emerald-700",
  UPDATE: "bg-blue-100 text-blue-700",
  DELETE: "bg-rose-100 text-rose-700",
};

export function AuditLogDrawer({ employeeId, trigger }: AuditLogDrawerProps) {
  const [open, setOpen] = useState(false);
  const safeEmployeeId = employeeId ? String(employeeId) : null;
  const { data, loading } = useQuery<any>(
    GET_AUDIT_LOGS,
    open && safeEmployeeId
      ? { variables: { employeeId: safeEmployeeId, limit: 50, offset: 0 } }
      : skipToken
  );

  const logs = data?.audit_log ?? [];

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>{trigger}</SheetTrigger>
      <SheetContent className="w-full overflow-y-auto sm:max-w-[min(98vw,88rem)]">
        <SheetHeader className="mb-4">
          <SheetTitle>Audit Log</SheetTitle>
        </SheetHeader>

        {loading && (
          <div className="space-y-3">
            {Array.from({ length: 5 }).map((_, i) => (
              <Skeleton key={i} className="h-14 w-full" />
            ))}
          </div>
        )}

        {!loading && logs.length === 0 && (
          <p className="text-sm text-slate-500 text-center py-8">
            No audit entries found.
          </p>
        )}

        <div className="space-y-3">
          {logs.map(
            (log: {
              id: string;
              operation: string;
              tableName: string;
              fieldName: string;
              oldValueMasked?: string;
              newValueMasked?: string;
              changedByName?: string;
              createdAt: string;
            }) => (
              <div
                key={log.id}
                className="border border-slate-100 rounded-lg p-3 space-y-1"
              >
                <div className="flex items-center justify-between">
                  <Badge
                    className={`text-xs ${OPERATION_COLORS[log.operation] ?? "bg-slate-100 text-slate-600"}`}
                  >
                    {log.operation}
                  </Badge>
                  <span className="text-xs text-slate-400">
                    {new Date(log.createdAt).toLocaleString()}
                  </span>
                </div>
                <p className="text-xs font-medium text-slate-700">
                  {log.tableName} › {log.fieldName}
                </p>
                {(log.oldValueMasked || log.newValueMasked) && (
                  <p className="text-xs text-slate-500">
                    {log.oldValueMasked && (
                      <span className="line-through text-rose-500 mr-1">
                        {log.oldValueMasked}
                      </span>
                    )}
                    {log.newValueMasked && (
                      <span className="text-emerald-600">{log.newValueMasked}</span>
                    )}
                  </p>
                )}
                {log.changedByName && (
                  <p className="text-xs text-slate-400">
                    by {log.changedByName}
                  </p>
                )}
              </div>
            )
          )}
        </div>
      </SheetContent>
    </Sheet>
  );
}
