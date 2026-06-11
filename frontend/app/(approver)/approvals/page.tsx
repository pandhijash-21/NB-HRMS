"use client";

import { useState } from "react";
import { useSession } from "next-auth/react";
import Link from "next/link";
import {
  usePendingApprovals,
  useApproveLeave,
  useRejectLeave,
} from "@/lib/hooks/useLeave";
import type { LeaveApplication } from "@/lib/hooks/useLeave";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { CheckCircle2, XCircle, CalendarDays, User, Building2, Clock } from "lucide-react";
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

type ActionDialog = { type: "approve" | "reject"; app: LeaveApplication } | null;

function StepBadge({ step }: { step: { approverRole: string; action?: string | null; isSuperseded: boolean } }) {
  const label = STEP_ROLE_LABELS[step.approverRole] ?? step.approverRole;
  const action = step.action;

  if (step.isSuperseded && !action) {
    return (
      <span className="text-[10px] px-2 py-0.5 rounded-full border bg-slate-50 border-slate-200 text-slate-400 font-medium">
        {label}: —
      </span>
    );
  }

  const style =
    action === "RECOMMENDED" || action === "APPROVED"
      ? "bg-emerald-50 border-emerald-200 text-emerald-700"
      : action === "REJECTED"
      ? "bg-rose-50 border-rose-200 text-rose-600"
      : "bg-amber-50 border-amber-200 text-amber-700";

  return (
    <span className={`text-[10px] px-2 py-0.5 rounded-full border font-medium ${style}`}>
      {label}: {action ?? "Awaiting"}
    </span>
  );
}

export default function PendingApprovalsPage() {
  const { data: session } = useSession();
  const role = (session?.user as any)?.role ?? "";
  const roleLabel = ROLE_LABELS[role] ?? "Reporting Manager";
  const myUserId = String((session?.user as any)?.id ?? "");

  const { data: apps = [], isLoading, refetch } = usePendingApprovals();
  const { mutateAsync: approve, isPending: approving } = useApproveLeave();
  const { mutateAsync: reject, isPending: rejecting } = useRejectLeave();

  const [action, setAction] = useState<ActionDialog>(null);
  const [remarks, setRemarks] = useState("");

  // Determine if the current user is a recommender or final approver for a given application
  // based on which step number they occupy (final tier is the max step number)
  function getActionLabel(app: { approvalSteps: { stepNumber: number; approverId?: number | null; action?: string | null; isSuperseded: boolean }[] }) {
    const myStep = app.approvalSteps.find(
      (s: any) => s.approverUserId === myUserId && !s.isSuperseded && !s.action
    );
    const finalTier = app.approvalSteps.length
      ? Math.max(...app.approvalSteps.map((s) => s.stepNumber))
      : 0;
    return myStep && myStep.stepNumber < finalTier ? "Recommend" : "Approve";
  }

  const actionLabel = action?.type === "approve" && action ? getActionLabel(action.app) : "Approve";

  const handleAction = async () => {
    if (!action) return;
    if (action.type === "approve") {
      await approve({ id: action.app.id, remarks });
    } else {
      await reject({ id: action.app.id, remarks });
    }
    setAction(null);
    setRemarks("");
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-500">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-900">Pending Approvals</h1>
          <p className="text-xs text-slate-500 mt-0.5">
            Leave applications awaiting your action as <strong>{roleLabel}</strong>
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Badge
            className={
              apps.length > 0
                ? "bg-amber-100 text-amber-700 border-amber-200 text-sm px-3 py-1"
                : "bg-slate-100 text-slate-500 border-slate-200 text-sm px-3 py-1"
            }
          >
            {isLoading ? "…" : apps.length} pending
          </Badge>
          <Link
            href="/approvals/history"
            className="text-xs text-[#1d3459] hover:underline font-medium"
          >
            View history →
          </Link>
        </div>
      </div>

      {/* Leave cards */}
      {isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton key={i} className="h-28 rounded-xl" />
          ))}
        </div>
      ) : apps.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 text-center">
          <div
            className="w-16 h-16 rounded-2xl flex items-center justify-center mb-4"
            style={{ backgroundColor: "#1d3459" }}
          >
            <CheckCircle2 className="w-8 h-8 text-[#d9b557]" />
          </div>
          <p className="text-base font-semibold text-slate-700">All caught up!</p>
          <p className="text-xs text-slate-400 mt-1">
            No leave applications are pending your approval.
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {apps.map((app) => (
            <Card
              key={app.id}
              className="border-none shadow-sm border-l-4 border-l-amber-400 hover:shadow-md transition-shadow"
            >
              <CardContent className="py-4 px-5">
                <div className="flex flex-col sm:flex-row sm:items-start gap-4">
                  {/* Info */}
                  <div className="flex-1 min-w-0 space-y-1.5">
                    {/* Employee name + meta */}
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
                      {app.isHalfDay && (
                        <span className="ml-1 text-xs text-slate-400">
                          ({app.halfDaySession === "FIRST" ? "First" : "Second"} half)
                        </span>
                      )}
                    </p>

                    {/* Reason */}
                    {app.reason && (
                      <p className="text-xs text-slate-500 italic line-clamp-2">
                        &ldquo;{app.reason}&rdquo;
                      </p>
                    )}

                    {/* Applied at */}
                    <p className="text-[11px] text-slate-400 flex items-center gap-1">
                      <Clock className="w-3 h-3" />
                      Applied {formatDate(app.appliedAt)}
                    </p>

                    {/* Approval step pipeline */}
                    {app.approvalSteps.length > 0 && (
                      <div className="flex items-center gap-1.5 flex-wrap pt-0.5">
                        {app.approvalSteps
                          .filter((s) => !s.isSuperseded || s.action)
                          .map((s) => (
                            <StepBadge key={s.id} step={s} />
                          ))}
                      </div>
                    )}
                  </div>

                  {/* Action buttons */}
                  <div className="flex gap-2 shrink-0 sm:flex-col sm:items-end">
                    <Button
                      size="sm"
                      className="bg-emerald-600 hover:bg-emerald-700 text-white h-8 px-4 text-xs"
                      onClick={() => {
                        setRemarks("");
                        setAction({ type: "approve", app });
                      }}
                    >
                      <CheckCircle2 className="w-3.5 h-3.5 mr-1" />
                      {getActionLabel(app)}
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      className="border-rose-200 text-rose-600 hover:bg-rose-50 h-8 px-4 text-xs"
                      onClick={() => {
                        setRemarks("");
                        setAction({ type: "reject", app });
                      }}
                    >
                      <XCircle className="w-3.5 h-3.5 mr-1" />
                      Reject
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Confirm dialog */}
      <Dialog
        open={!!action}
        onOpenChange={(open) => {
          if (!open) setAction(null);
        }}
      >
        <DialogContent className="sm:max-w-[min(98vw,32rem)]">
          <DialogHeader>
            <DialogTitle>
              {action?.type === "approve"
                ? `${action.app ? getActionLabel(action.app) : "Approve"} Leave Application`
                : "Reject Leave Application"}
            </DialogTitle>
          </DialogHeader>

          <div className="space-y-4 py-2">
            {action && (
              <div className="rounded-lg border border-slate-100 bg-slate-50 p-4 space-y-1.5 text-sm">
                <p className="font-semibold text-slate-800">
                  {action.app.employee?.generalInfo?.fullName ?? `Employee #${action.app.employee?.id}`}
                </p>
                <p className="text-slate-600">
                  {action.app.leaveType.name} &middot;{" "}
                  {formatDate(action.app.fromDate)}
                  {action.app.fromDate !== action.app.toDate && ` – ${formatDate(action.app.toDate)}`}
                  &nbsp;({action.app.totalDays} day{action.app.totalDays !== 1 ? "s" : ""})
                </p>
                {action.app.reason && (
                  <p className="text-xs text-slate-500 italic">&ldquo;{action.app.reason}&rdquo;</p>
                )}
              </div>
            )}

            <div className="space-y-1.5">
              <Label>Remarks <span className="text-slate-400 font-normal">(optional)</span></Label>
              <Textarea
                value={remarks}
                onChange={(e) => setRemarks(e.target.value)}
                placeholder="Add remarks for the employee…"
                rows={3}
              />
            </div>
          </div>

          <DialogFooter className="gap-2">
            <Button variant="outline" onClick={() => setAction(null)}>
              Cancel
            </Button>
            <Button
              disabled={approving || rejecting}
              onClick={handleAction}
              className={
                action?.type === "approve"
                  ? "bg-emerald-600 hover:bg-emerald-700 text-white"
                  : "bg-rose-600 hover:bg-rose-700 text-white"
              }
            >
              {approving || rejecting
                ? "Processing…"
                : action?.type === "approve"
                  ? `Confirm ${actionLabel}`
                  : "Confirm Rejection"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
