"use client";

import { useState } from "react";
import { useSession } from "next-auth/react";
import Link from "next/link";
import { useMyApprovalHistory } from "@/lib/hooks/useLeave";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { ArrowLeft, CalendarDays, CheckCircle2, XCircle, Clock, Building2, User } from "lucide-react";
import { formatDate } from "@/lib/utils";

const ROLE_LABELS: Record<string, string> = {
  FIRST_REPORTING:  "1st Reporting Manager",
  SECOND_REPORTING: "2nd Reporting Manager",
  THIRD_REPORTING:  "3rd Reporting Manager",
  // kept for historical data
  HOD: "Head of Department", HOI: "Head of Institution",
  REGISTRAR: "Registrar", VC: "Vice Chancellor",
};

const STEP_ROLE_LABELS: Record<string, string> = {
  FIRST_REPORTING:  "1st Reporting",
  SECOND_REPORTING: "2nd Reporting",
  THIRD_REPORTING:  "3rd Reporting",
  // kept for historical data
  HOD: "Dept. Head", HOI: "Principal", VC: "Vice Chancellor", REGISTRAR: "Registrar",
};

const STATUS_STYLES: Record<string, string> = {
  APPROVED:         "bg-emerald-100 text-emerald-700 border-emerald-200",
  REJECTED:         "bg-rose-100 text-rose-600 border-rose-200",
  HOD_RECOMMENDED:  "bg-blue-100 text-blue-700 border-blue-200",
  HOI_RECOMMENDED:  "bg-indigo-100 text-indigo-700 border-indigo-200",
  PENDING:          "bg-amber-100 text-amber-700 border-amber-200",
  CANCELLED:        "bg-slate-100 text-slate-500 border-slate-200",
  AUTO_LWP:         "bg-orange-100 text-orange-700 border-orange-200",
};

const STATUS_LABELS: Record<string, string> = {
  APPROVED:         "Approved",
  REJECTED:         "Rejected",
  HOD_RECOMMENDED:  "1st Reporting Recommended",
  HOI_RECOMMENDED:  "2nd Reporting Recommended",
  PENDING:          "Pending",
  CANCELLED:        "Cancelled",
  AUTO_LWP:         "Auto LWP",
};

const currentYear = new Date().getFullYear();
const YEARS = [currentYear, currentYear - 1, currentYear - 2];

export default function ApprovalHistoryPage() {
  const { data: session } = useSession();
  const role = (session?.user as any)?.role ?? "";
  const roleLabel = ROLE_LABELS[role] ?? role;

  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [yearFilter, setYearFilter] = useState<number>(currentYear);

  const { data, isLoading, isError } = useMyApprovalHistory({
    status: statusFilter === "all" ? undefined : statusFilter,
    limit: 100,
  });

  const items = (data?.items ?? []).filter((a) => {
    if (!yearFilter) return true;
    return new Date(a.fromDate).getFullYear() === yearFilter;
  });

  return (
    <div className="space-y-6 animate-in fade-in duration-500">
      {/* Header */}
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/approvals">
            <ArrowLeft className="w-4 h-4" />
          </Link>
        </Button>
        <div className="flex-1 min-w-0">
          <h1 className="text-xl font-bold text-slate-900">Approval History</h1>
          <p className="text-xs text-slate-500 mt-0.5">
            All leave applications processed through your queue as <strong>{roleLabel}</strong>
          </p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex items-center gap-3 flex-wrap">
        <Select value={statusFilter} onValueChange={setStatusFilter}>
          <SelectTrigger className="w-44 h-8 text-xs">
            <SelectValue placeholder="All statuses" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All statuses</SelectItem>
            <SelectItem value="APPROVED">Approved</SelectItem>
            <SelectItem value="REJECTED">Rejected</SelectItem>
            <SelectItem value="HOD_RECOMMENDED">HOD Recommended</SelectItem>
            <SelectItem value="HOI_RECOMMENDED">HOI Recommended</SelectItem>
            <SelectItem value="PENDING">Still Pending</SelectItem>
            <SelectItem value="CANCELLED">Cancelled</SelectItem>
          </SelectContent>
        </Select>

        <Select
          value={String(yearFilter)}
          onValueChange={(v) => setYearFilter(Number(v))}
        >
          <SelectTrigger className="w-28 h-8 text-xs">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {YEARS.map((y) => (
              <SelectItem key={y} value={String(y)}>
                {y}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <span className="text-xs text-slate-400 ml-auto">
          {isLoading ? "…" : items.length} application{items.length !== 1 ? "s" : ""}
        </span>
      </div>

      {/* List */}
      {isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-24 rounded-xl" />
          ))}
        </div>
      ) : isError ? (
        <div className="flex flex-col items-center justify-center py-16 text-center">
          <div className="w-12 h-12 rounded-xl bg-slate-100 flex items-center justify-center mb-3">
            <XCircle className="w-6 h-6 text-slate-400" />
          </div>
          <p className="text-sm font-medium text-slate-600">Could not load history</p>
          <p className="text-xs text-slate-400 mt-1">
            You may not have permission to view all applications.
          </p>
        </div>
      ) : items.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 text-center">
          <div
            className="w-14 h-14 rounded-2xl flex items-center justify-center mb-3"
            style={{ backgroundColor: "#1d3459" }}
          >
            <CalendarDays className="w-7 h-7 text-[#d9b557]" />
          </div>
          <p className="text-sm font-medium text-slate-700">No records found</p>
          <p className="text-xs text-slate-400 mt-1">
            No leave applications match the selected filters.
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {items.map((app) => (
            <Card
              key={app.id}
              className="border-none shadow-sm hover:shadow-md transition-shadow"
            >
              <CardContent className="py-4 px-5">
                <div className="flex flex-col sm:flex-row sm:items-start gap-3">
                  <div className="flex-1 min-w-0 space-y-1.5">
                    {/* Name + code */}
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-semibold text-slate-800">
                        {app.employee?.generalInfo?.fullName ?? `Employee #${app.employee?.id}`}
                      </span>
                      {app.employee?.generalInfo?.employeeCode && (
                        <span className="text-xs text-slate-400 font-mono">
                          {app.employee.generalInfo.employeeCode}
                        </span>
                      )}
                    </div>

                    {/* Designation + dept */}
                    <div className="flex items-center gap-3 text-xs text-slate-500 flex-wrap">
                      {app.employee?.generalInfo?.designation && (
                        <span className="flex items-center gap-1">
                          <User className="w-3 h-3" />
                          {app.employee.generalInfo.designation}
                        </span>
                      )}
                      {app.employee?.generalInfo?.department && (
                        <span className="flex items-center gap-1">
                          <Building2 className="w-3 h-3" />
                          {app.employee.generalInfo.department}
                        </span>
                      )}
                    </div>

                    {/* Leave details */}
                    <p className="text-sm text-slate-700">
                      <span
                        className="inline-block font-semibold rounded px-1.5 py-0.5 text-xs mr-2"
                        style={{ background: "#1d3459", color: "#d9b557" }}
                      >
                        {app.leaveType.code}
                      </span>
                      {app.leaveType.name} &middot;{" "}
                      <span className="font-medium">
                        {formatDate(app.fromDate)}
                        {app.fromDate !== app.toDate && ` – ${formatDate(app.toDate)}`}
                      </span>
                      &middot; {app.totalDays} day{app.totalDays !== 1 ? "s" : ""}
                    </p>

                    {/* Reason */}
                    {app.reason && (
                      <p className="text-xs text-slate-500 italic line-clamp-1">
                        &ldquo;{app.reason}&rdquo;
                      </p>
                    )}

                    {/* Applied at */}
                    <p className="text-[11px] text-slate-400 flex items-center gap-1">
                      <Clock className="w-3 h-3" />
                      Applied {formatDate(app.appliedAt)}
                    </p>

                    {/* Approval steps pipeline */}
                    {app.approvalSteps.length > 0 && (
                      <div className="flex items-center gap-1.5 flex-wrap pt-0.5">
                        {app.approvalSteps
                          .filter((s) => !s.isSuperseded || s.action)
                          .map((s) => {
                            const stepLabel = STEP_ROLE_LABELS[s.approverRole] ?? s.approverRole;
                            const stepStyle =
                              s.action === "RECOMMENDED" || s.action === "APPROVED"
                                ? "bg-emerald-50 border-emerald-200 text-emerald-700"
                                : s.action === "REJECTED"
                                ? "bg-rose-50 border-rose-200 text-rose-600"
                                : s.isSuperseded
                                ? "bg-slate-50 border-slate-200 text-slate-400"
                                : "bg-amber-50 border-amber-200 text-amber-700";
                            return (
                              <span
                                key={s.id}
                                className={`text-[10px] px-2 py-0.5 rounded-full border font-medium ${stepStyle}`}
                              >
                                {stepLabel}: {s.action ?? "Awaiting"}
                              </span>
                            );
                          })}
                      </div>
                    )}
                  </div>

                  {/* Status badge */}
                  <div className="shrink-0 flex sm:flex-col items-start gap-1.5">
                    <Badge
                      className={`text-xs border ${STATUS_STYLES[app.status] ?? "bg-slate-100 text-slate-500 border-slate-200"}`}
                    >
                      {STATUS_LABELS[app.status] ?? app.status}
                    </Badge>
                    <span className="text-[10px] text-slate-400 font-mono">
                      #{app.applicationNo}
                    </span>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
