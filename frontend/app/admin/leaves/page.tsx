"use client";

import { useState } from "react";
import {
  useAdminLeaveApplications,
  useAdminApplyLeave,
  useAdminLeaveTypes,
  useApproveLeave,
  useRejectLeave,
} from "@/lib/hooks/useLeave";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Input } from "@/components/ui/input";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { CalendarDays, CheckCircle2, XCircle, ChevronLeft, ChevronRight, Plus } from "lucide-react";
import { Switch } from "@/components/ui/switch";
import Link from "next/link";
import { formatDate } from "@/lib/utils";
import type { LeaveApplication } from "@/lib/hooks/useLeave";

const STATUS_STYLES: Record<string, string> = {
  PENDING:          "bg-amber-100 text-amber-700 border-amber-200",
  HOD_RECOMMENDED:  "bg-blue-100 text-blue-700 border-blue-200",
  HOI_RECOMMENDED:  "bg-indigo-100 text-indigo-700 border-indigo-200",
  APPROVED:         "bg-emerald-100 text-emerald-700 border-emerald-200",
  REJECTED:         "bg-rose-100 text-rose-600 border-rose-200",
  CANCELLED:        "bg-slate-100 text-slate-500 border-slate-200",
  AUTO_LWP:         "bg-orange-100 text-orange-700 border-orange-200",
};

const STATUS_LABELS: Record<string, string> = {
  PENDING:          "Pending",
  HOD_RECOMMENDED:  "HOD Recommended",
  HOI_RECOMMENDED:  "HOI Recommended",
  APPROVED:         "Approved",
  REJECTED:         "Rejected",
  CANCELLED:        "Cancelled",
  AUTO_LWP:         "Auto LWP",
};

const STEP_ROLE_LABELS: Record<string, string> = {
  HOD:       "Dept. Head",
  HOI:       "Principal",
  REGISTRAR: "Registrar",
  VC:        "Vice Chancellor",
};

function ApprovalPipeline({ steps }: { steps: LeaveApplication["approvalSteps"] }) {
  if (!steps?.length) return null;
  const visible = steps.filter((s) => !s.isSuperseded || s.action);
  if (!visible.length) return null;
  return (
    <div className="flex items-center gap-1.5 flex-wrap mt-2">
      {visible.map((s) => {
        const label = STEP_ROLE_LABELS[s.approverRole] ?? s.approverRole;
        const style =
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
            className={`text-[10px] px-2 py-0.5 rounded-full border font-medium ${style}`}
          >
            {label}: {s.action ?? "Awaiting"}
          </span>
        );
      })}
    </div>
  );
}

const PAGE_SIZE = 20;
const CY = new Date().getFullYear();

type ActionDialog = { type: "approve" | "reject"; app: LeaveApplication } | null;

const emptyApplyForm = {
  employeeId: "",
  leaveTypeId: "",
  fromDate: "",
  toDate: "",
  isHalfDay: false,
  halfDaySession: "",
  reason: "",
};

export default function AdminLeavesPage() {
  const [status, setStatus] = useState("PENDING");
  const [year, setYear] = useState(CY);
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState("");
  const [action, setAction] = useState<ActionDialog>(null);
  const [remarks, setRemarks] = useState("");

  // Apply on behalf state
  const [applyOpen, setApplyOpen] = useState(false);
  const [applyForm, setApplyForm] = useState(emptyApplyForm);

  const { data: leaveTypes = [] } = useAdminLeaveTypes();
  const { mutateAsync: adminApply, isPending: applying } = useAdminApplyLeave();

  const handleAdminApply = async () => {
    if (!applyForm.employeeId || !applyForm.leaveTypeId || !applyForm.fromDate || !applyForm.toDate || !applyForm.reason) return;
    await adminApply({
      employeeId:    Number(applyForm.employeeId),
      leaveTypeId:   applyForm.leaveTypeId,
      fromDate:      applyForm.fromDate,
      toDate:        applyForm.isHalfDay ? applyForm.fromDate : applyForm.toDate,
      isHalfDay:     applyForm.isHalfDay,
      halfDaySession: applyForm.isHalfDay && applyForm.halfDaySession ? applyForm.halfDaySession : null,
      reason:        applyForm.reason,
    });
    setApplyOpen(false);
    setApplyForm(emptyApplyForm);
  };

  const { data, isLoading } = useAdminLeaveApplications({
    status: status === "ALL" ? undefined : status,
    year,
    page,
    limit: PAGE_SIZE,
  });

  const { mutateAsync: approve, isPending: approving } = useApproveLeave();
  const { mutateAsync: reject, isPending: rejecting } = useRejectLeave();

  const items = (data?.items ?? []).filter((a) => {
    if (!search) return true;
    const name = a.employee?.generalInfo?.fullName?.toLowerCase() ?? "";
    const code = a.employee?.generalInfo?.employeeCode?.toLowerCase() ?? "";
    const s = search.toLowerCase();
    return name.includes(s) || code.includes(s) || a.applicationNo.toLowerCase().includes(s);
  });

  const totalPages = data ? Math.ceil(data.total / PAGE_SIZE) : 0;

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
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Leave Applications</h1>
          <p className="text-sm text-slate-500 mt-1">Review and manage all employee leave applications</p>
        </div>
        <div className="flex gap-2 flex-wrap">
          <Button
            size="sm"
            style={{ background: "#1d3459" }}
            className="text-white hover:opacity-90"
            onClick={() => { setApplyForm(emptyApplyForm); setApplyOpen(true); }}
          >
            <Plus className="w-4 h-4 mr-1" /> Apply on Behalf
          </Button>
          <Button variant="outline" size="sm" asChild>
            <Link href="/admin/leaves/holidays">Holidays</Link>
          </Button>
          <Button variant="outline" size="sm" asChild>
            <Link href="/admin/leaves/settings">Settings</Link>
          </Button>
          <Button variant="outline" size="sm" asChild>
            <Link href="/admin/leaves/pending">Pending Approvals</Link>
          </Button>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3 items-center">
        <Input
          placeholder="Search by name, code, or app no…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-64"
        />
        <Select value={String(year)} onValueChange={(v) => { setYear(Number(v)); setPage(0); }}>
          <SelectTrigger className="w-28">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {[CY, CY - 1, CY - 2].map((y) => (
              <SelectItem key={y} value={String(y)}>{y}</SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Select value={status} onValueChange={(v) => { setStatus(v); setPage(0); }}>
          <SelectTrigger className="w-36">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="ALL">All</SelectItem>
            <SelectItem value="PENDING">Pending</SelectItem>
            <SelectItem value="APPROVED">Approved</SelectItem>
            <SelectItem value="REJECTED">Rejected</SelectItem>
            <SelectItem value="CANCELLED">Cancelled</SelectItem>
          </SelectContent>
        </Select>
        {data && (
          <span className="text-xs text-slate-400 ml-auto">
            {data.total} total
          </span>
        )}
      </div>

      {/* List */}
      {isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 6 }).map((_, i) => <Skeleton key={i} className="h-20 rounded-xl" />)}
        </div>
      ) : !items.length ? (
        <div className="text-center py-16 text-slate-400">
          <CalendarDays className="w-10 h-10 mx-auto mb-3 opacity-30" />
          <p>No applications found</p>
        </div>
      ) : (
        <div className="space-y-3">
          {items.map((a) => (
            <Card key={a.id} className="border-none shadow-sm hover:shadow-md transition-all">
              <CardContent className="py-4 px-5">
                <div className="flex items-start gap-4">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-semibold text-slate-800">
                        {a.employee?.generalInfo?.fullName ?? `Employee #${a.employee?.id}`}
                      </span>
                      <span className="text-xs text-slate-400">
                        {a.employee?.generalInfo?.employeeCode} &middot; {a.employee?.generalInfo?.department}
                      </span>
                      <Badge className={`text-[11px] border ${STATUS_STYLES[a.status] ?? ""}`}>
                        {STATUS_LABELS[a.status] ?? a.status}
                      </Badge>
                    </div>
                    <p className="text-sm text-slate-600 mt-1">
                      <strong>{a.leaveType.name}</strong> &middot; {formatDate(a.fromDate)} – {formatDate(a.toDate)} &middot; {a.totalDays} day{a.totalDays !== 1 ? "s" : ""}
                    </p>
                    <p className="text-xs text-slate-400 mt-0.5">{a.applicationNo} &middot; {formatDate(a.appliedAt)}</p>
                    <p className="text-xs text-slate-500 mt-0.5 italic line-clamp-1">"{a.reason}"</p>
                    <ApprovalPipeline steps={a.approvalSteps} />
                  </div>
                  <div className="flex items-center gap-2 shrink-0">
                    {a.status === "PENDING" && (
                      <>
                        <Button
                          size="sm"
                          className="bg-emerald-600 hover:bg-emerald-700 text-white h-8 px-3 text-xs"
                          onClick={() => { setAction({ type: "approve", app: a }); setRemarks(""); }}
                        >
                          <CheckCircle2 className="w-3.5 h-3.5 mr-1" /> Approve
                        </Button>
                        <Button
                          size="sm"
                          variant="outline"
                          className="border-rose-200 text-rose-600 hover:bg-rose-50 h-8 px-3 text-xs"
                          onClick={() => { setAction({ type: "reject", app: a }); setRemarks(""); }}
                        >
                          <XCircle className="w-3.5 h-3.5 mr-1" /> Reject
                        </Button>
                      </>
                    )}
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between">
          <Button variant="ghost" size="sm" disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
            <ChevronLeft className="w-4 h-4 mr-1" /> Previous
          </Button>
          <span className="text-xs text-slate-500">Page {page + 1} of {totalPages}</span>
          <Button variant="ghost" size="sm" disabled={page >= totalPages - 1} onClick={() => setPage((p) => p + 1)}>
            Next <ChevronRight className="w-4 h-4 ml-1" />
          </Button>
        </div>
      )}

      {/* Apply on Behalf dialog */}
      <Dialog open={applyOpen} onOpenChange={(o) => { if (!o) setApplyOpen(false); }}>
        <DialogContent className="sm:max-w-[min(98vw,34rem)]">
          <DialogHeader>
            <DialogTitle>Apply Leave on Behalf of Employee</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-1">
            <p className="text-xs text-slate-500">
              Use this to apply <strong>Sick Leave (SL)</strong>, <strong>Earned Leave (EL)</strong>, or any leave type for an employee. The application will go through the normal approval workflow.
            </p>

            {/* Employee ID */}
            <div className="space-y-1.5">
              <Label>Employee ID</Label>
              <Input
                type="number"
                placeholder="e.g. 3"
                value={applyForm.employeeId}
                onChange={(e) => setApplyForm((f) => ({ ...f, employeeId: e.target.value }))}
              />
            </div>

            {/* Leave Type */}
            <div className="space-y-1.5">
              <Label>Leave Type</Label>
              <Select
                value={applyForm.leaveTypeId}
                onValueChange={(v) => setApplyForm((f) => ({ ...f, leaveTypeId: v }))}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select leave type…" />
                </SelectTrigger>
                <SelectContent>
                  {leaveTypes.filter((t) => t.isActive).map((t) => (
                    <SelectItem key={t.id} value={t.id}>
                      {t.name} ({t.code})
                      {["SL", "EL"].includes(t.code) && (
                        <span className="ml-2 text-[10px] text-amber-600 font-semibold">Admin only</span>
                      )}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Dates */}
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label>From Date</Label>
                <Input
                  type="date"
                  value={applyForm.fromDate}
                  onChange={(e) => setApplyForm((f) => ({ ...f, fromDate: e.target.value }))}
                />
              </div>
              <div className="space-y-1.5">
                <Label>To Date</Label>
                <Input
                  type="date"
                  value={applyForm.isHalfDay ? applyForm.fromDate : applyForm.toDate}
                  disabled={applyForm.isHalfDay}
                  min={applyForm.fromDate}
                  onChange={(e) => setApplyForm((f) => ({ ...f, toDate: e.target.value }))}
                />
              </div>
            </div>

            {/* Half Day */}
            <div className="flex items-center gap-3">
              <Switch
                id="admin-half-day"
                checked={applyForm.isHalfDay}
                onCheckedChange={(v) =>
                  setApplyForm((f) => ({ ...f, isHalfDay: v, halfDaySession: "" }))
                }
              />
              <Label htmlFor="admin-half-day" className="cursor-pointer">Half Day</Label>
              {applyForm.isHalfDay && (
                <Select
                  value={applyForm.halfDaySession}
                  onValueChange={(v) => setApplyForm((f) => ({ ...f, halfDaySession: v }))}
                >
                  <SelectTrigger className="w-36">
                    <SelectValue placeholder="Session…" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="MORNING">Morning</SelectItem>
                    <SelectItem value="AFTERNOON">Afternoon</SelectItem>
                  </SelectContent>
                </Select>
              )}
            </div>

            {/* Reason */}
            <div className="space-y-1.5">
              <Label>Reason</Label>
              <Textarea
                value={applyForm.reason}
                onChange={(e) => setApplyForm((f) => ({ ...f, reason: e.target.value }))}
                placeholder="Enter reason for leave…"
                rows={3}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setApplyOpen(false)}>Cancel</Button>
            <Button
              disabled={applying || !applyForm.employeeId || !applyForm.leaveTypeId || !applyForm.fromDate || !applyForm.toDate || !applyForm.reason}
              onClick={handleAdminApply}
              style={{ background: "#1d3459" }}
              className="text-white"
            >
              {applying ? "Submitting…" : "Submit Application"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Action dialog */}
      <Dialog open={!!action} onOpenChange={(o) => { if (!o) setAction(null); }}>
        <DialogContent className="sm:max-w-[min(98vw,32rem)]">
          <DialogHeader>
            <DialogTitle>
              {action?.type === "approve" ? "Approve Application" : "Reject Application"}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            {action && (
              <div className="bg-slate-50 rounded-lg p-3 text-sm space-y-1">
                <p><strong>{action.app.employee?.generalInfo?.fullName}</strong></p>
                <p>{action.app.leaveType.name} &middot; {formatDate(action.app.fromDate)} – {formatDate(action.app.toDate)}</p>
                <p className="text-slate-500 text-xs italic">"{action.app.reason}"</p>
              </div>
            )}
            <div className="space-y-1.5">
              <Label>Remarks (optional)</Label>
              <Textarea
                value={remarks}
                onChange={(e) => setRemarks(e.target.value)}
                placeholder="Add your remarks…"
                rows={3}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAction(null)}>Cancel</Button>
            <Button
              onClick={handleAction}
              disabled={approving || rejecting}
              className={action?.type === "approve" ? "bg-emerald-600 hover:bg-emerald-700" : "bg-rose-600 hover:bg-rose-700"}
            >
              {action?.type === "approve" ? "Approve" : "Reject"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
