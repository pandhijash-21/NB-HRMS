"use client";

import Link from "next/link";
import { useMyLeaveBalances, useLeaveTypes } from "@/lib/hooks/useLeave";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { CalendarDays, Plus, Clock, CheckCircle2, XCircle } from "lucide-react";
import { useMyLeaveApplications } from "@/lib/hooks/useLeave";
import { formatDate } from "@/lib/utils";

const STATUS_STYLES: Record<string, string> = {
  PENDING:   "bg-amber-100 text-amber-700 border-amber-200",
  APPROVED:  "bg-emerald-100 text-emerald-700 border-emerald-200",
  REJECTED:  "bg-rose-100 text-rose-600 border-rose-200",
  CANCELLED: "bg-slate-100 text-slate-500 border-slate-200",
};

export default function LeaveDashboard() {
  const year = new Date().getFullYear();
  const { data: allTypes = [], isLoading: typesLoading } = useLeaveTypes();
  const { data: balances = [], isLoading: bLoading } = useMyLeaveBalances(year);
  const { data: apps, isLoading: aLoading } = useMyLeaveApplications({ limit: 5, year });

  // Merge every active leave type with its balance (default 0 if no record yet)
  // All types are shown here regardless of employeeCanApply — balances page shows everything
  const mergedBalances = allTypes
    .filter((t) => t.isActive)
    .map((t) => {
      const bal = balances.find((b) => b.leaveTypeId === t.id);
      return {
        id:               bal?.id ?? t.id,
        leaveTypeId:      t.id,
        leaveType:        { code: t.code, name: t.name, allowHalfDay: t.allowHalfDay },
        totalCredited:    bal?.totalCredited ?? 0,
        carryForward:     bal?.carryForward  ?? 0,
        used:             bal?.used    ?? 0,
        pending:          bal?.pending ?? 0,
        employeeCanApply: t.employeeCanApply,
        // Show total - used (pending shown separately, NOT deducted until approved)
        available: (bal?.totalCredited ?? 0) + (bal?.carryForward ?? 0) - (bal?.used ?? 0),
      };
    });

  const recent = apps?.items ?? [];

  return (
    <div className="space-y-8 animate-in fade-in duration-500">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Leave Management</h1>
          <p className="text-sm text-slate-500 mt-1">Track your leave balances and applications</p>
        </div>
        <Button asChild style={{ background: "#1d3459" }}>
          <Link href="/leave/apply">
            <Plus className="w-4 h-4 mr-2" />
            Apply Leave
          </Link>
        </Button>
      </div>

      {/* Balance cards */}
      <div>
        <h2 className="text-sm font-semibold text-slate-500 uppercase tracking-wider mb-4">
          Leave Balances — {year}
        </h2>
        {(bLoading || typesLoading) ? (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {Array.from({ length: 6 }).map((_, i) => (
              <Skeleton key={i} className="h-28 rounded-2xl" />
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {mergedBalances.map((b) => {
              const isAdminOnly = !b.employeeCanApply;
              return (
                <Card
                  key={b.leaveTypeId}
                  className={`border-none shadow-sm transition-all duration-200 ${isAdminOnly ? "opacity-60" : "hover:shadow-md"}`}
                >
                  <CardContent className="pt-5 pb-4 px-5">
                    <div className="flex items-start justify-between mb-3">
                      <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">
                        {b.leaveType.code}
                      </span>
                      <CalendarDays className="w-4 h-4 text-slate-300" />
                    </div>
                    <p className="text-2xl font-extrabold text-slate-800">
                      {b.available}
                      <span className="text-sm font-medium text-slate-400 ml-1">days</span>
                    </p>
                    <p className="text-xs text-slate-500 mt-0.5">{b.leaveType.name}</p>
                    <div className="mt-3 flex items-center gap-3 text-[11px] text-slate-400">
                      <span>Used: <strong className="text-slate-600">{b.used}</strong></span>
                      {b.pending > 0 && (
                        <span>Pending: <strong className="text-amber-600">{b.pending}</strong></span>
                      )}
                    </div>
                    {isAdminOnly && (
                      <p className="text-[10px] text-slate-400 mt-1 italic">Applied by HR only</p>
                    )}
                  </CardContent>
                </Card>
              );
            })}
          </div>
        )}
      </div>

      {/* Recent applications */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-sm font-semibold text-slate-500 uppercase tracking-wider">
            Recent Applications
          </h2>
          <Button variant="ghost" size="sm" asChild className="text-xs text-slate-500">
            <Link href="/leave/history">View all →</Link>
          </Button>
        </div>
        {aLoading ? (
          <div className="space-y-3">
            {Array.from({ length: 3 }).map((_, i) => (
              <Skeleton key={i} className="h-16 rounded-xl" />
            ))}
          </div>
        ) : !recent.length ? (
          <p className="text-sm text-slate-400 italic">No applications yet this year.</p>
        ) : (
          <div className="space-y-3">
            {recent.map((a) => (
              <Card key={a.id} className="border-none shadow-sm">
                <CardContent className="py-3 px-5 flex items-center justify-between">
                  <div className="flex items-center gap-4">
                    <div className="p-2 rounded-xl bg-slate-100">
                      <CalendarDays className="w-4 h-4 text-slate-500" />
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-slate-800">{a.leaveType.name}</p>
                      <p className="text-xs text-slate-500">
                        {formatDate(a.fromDate)} – {formatDate(a.toDate)} &middot; {a.totalDays} day{a.totalDays !== 1 ? "s" : ""}
                      </p>
                    </div>
                  </div>
                  <Badge className={`text-[11px] border ${STATUS_STYLES[a.status] ?? ""}`}>
                    {a.status}
                  </Badge>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
