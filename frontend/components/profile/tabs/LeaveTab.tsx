"use client";

import { useState } from "react";
import {
  useAdminEmployeeBalances,
  useAdminLeaveApplications,
  useAdminLeaveTypes,
  useAdminApplyLeave,
} from "@/lib/hooks/useLeave";
import type { LeaveApplication } from "@/lib/hooks/useLeave";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from "@/components/ui/dialog";
import {
  CalendarDays, Plus, ChevronLeft, ChevronRight,
  Clock, CheckCircle2, XCircle, MinusCircle,
} from "lucide-react";

// ─── helpers ──────────────────────────────────────────────────────────────────

const STATUS_STYLES: Record<string, string> = {
  PENDING:   "bg-amber-100 text-amber-700 border-amber-200",
  APPROVED:  "bg-emerald-100 text-emerald-700 border-emerald-200",
  REJECTED:  "bg-rose-100 text-rose-600 border-rose-200",
  CANCELLED: "bg-slate-100 text-slate-500 border-slate-200",
};

const STATUS_ICONS: Record<string, React.ReactNode> = {
  PENDING:   <Clock className="w-3.5 h-3.5" />,
  APPROVED:  <CheckCircle2 className="w-3.5 h-3.5" />,
  REJECTED:  <XCircle className="w-3.5 h-3.5" />,
  CANCELLED: <MinusCircle className="w-3.5 h-3.5" />,
};

function fmt(d: string) {
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

// ─── Apply on Behalf dialog ───────────────────────────────────────────────────

interface ApplyDialogProps {
  open: boolean;
  onClose: () => void;
  employeeId: number;
}

const emptyForm = {
  leaveTypeId: "",
  fromDate: "",
  toDate: "",
  isHalfDay: false,
  halfDaySession: "" as string | null,
  reason: "",
};

function ApplyLeaveDialog({ open, onClose, employeeId }: ApplyDialogProps) {
  const { data: types = [] } = useAdminLeaveTypes();
  const { mutateAsync: applyLeave, isPending } = useAdminApplyLeave();
  const [form, setForm] = useState({ ...emptyForm });

  const activeTypes = types.filter((t) => t.isActive);

  async function handleSubmit() {
    if (!form.leaveTypeId || !form.fromDate || !form.toDate || !form.reason) return;
    await applyLeave({
      employeeId,
      leaveTypeId:    form.leaveTypeId,
      fromDate:       form.fromDate,
      toDate:         form.toDate,
      isHalfDay:      form.isHalfDay,
      halfDaySession: form.isHalfDay ? form.halfDaySession : null,
      reason:         form.reason,
    });
    setForm({ ...emptyForm });
    onClose();
  }

  return (
    <Dialog open={open} onOpenChange={(v) => { if (!v) onClose(); }}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle className="text-base font-semibold" style={{ color: "#1d3459" }}>
            Apply Leave on Behalf of Employee
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4 py-2">
          {/* Leave type */}
          <div className="space-y-1.5">
            <label className="text-xs font-medium text-slate-600">Leave Type</label>
            <Select value={form.leaveTypeId} onValueChange={(v) => setForm((f) => ({ ...f, leaveTypeId: v }))}>
              <SelectTrigger className="h-9 text-sm"><SelectValue placeholder="Select leave type" /></SelectTrigger>
              <SelectContent>
                {activeTypes.map((t) => (
                  <SelectItem key={t.id} value={t.id}>
                    <span className="font-medium">{t.code}</span>
                    <span className="ml-2 text-slate-500">{t.name}</span>
                    {!t.employeeCanApply && (
                      <span className="ml-2 text-[10px] text-orange-500 font-medium">admin-only</span>
                    )}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {/* Dates */}
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-slate-600">From Date</label>
              <Input type="date" className="h-9 text-sm"
                value={form.fromDate} onChange={(e) => setForm((f) => ({ ...f, fromDate: e.target.value }))} />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-slate-600">To Date</label>
              <Input type="date" className="h-9 text-sm"
                value={form.toDate} onChange={(e) => setForm((f) => ({ ...f, toDate: e.target.value }))} />
            </div>
          </div>

          {/* Half day */}
          <div className="flex items-center gap-3">
            <label className="flex items-center gap-2 cursor-pointer select-none">
              <input type="checkbox" className="w-4 h-4 accent-[#1d3459]"
                checked={form.isHalfDay}
                onChange={(e) => setForm((f) => ({ ...f, isHalfDay: e.target.checked }))} />
              <span className="text-sm text-slate-700">Half Day</span>
            </label>
            {form.isHalfDay && (
              <Select value={form.halfDaySession ?? ""} onValueChange={(v) => setForm((f) => ({ ...f, halfDaySession: v }))}>
                <SelectTrigger className="h-8 w-36 text-xs"><SelectValue placeholder="Session" /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="MORNING">Morning</SelectItem>
                  <SelectItem value="AFTERNOON">Afternoon</SelectItem>
                </SelectContent>
              </Select>
            )}
          </div>

          {/* Reason */}
          <div className="space-y-1.5">
            <label className="text-xs font-medium text-slate-600">Reason</label>
            <textarea
              rows={3}
              className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring resize-none"
              placeholder="Enter reason for leave…"
              value={form.reason}
              onChange={(e) => setForm((f) => ({ ...f, reason: e.target.value }))}
            />
          </div>
        </div>

        <DialogFooter>
          <Button variant="ghost" size="sm" onClick={onClose}>Cancel</Button>
          <Button size="sm" className="text-white" style={{ background: "#1d3459" }}
            disabled={isPending || !form.leaveTypeId || !form.fromDate || !form.toDate || !form.reason}
            onClick={handleSubmit}>
            {isPending ? "Applying…" : "Apply Leave"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// ─── main tab ─────────────────────────────────────────────────────────────────

interface Props {
  employeeId: number;
}

export function LeaveTab({ employeeId }: Props) {
  const currentYear = new Date().getFullYear();
  const [year, setYear]           = useState(currentYear);
  const [applyOpen, setApplyOpen] = useState(false);
  // Backend paging is 0-based
  const [page, setPage]           = useState(0);
  const LIMIT = 8;

  const { data: types  = [],  isLoading: tLoading }  = useAdminLeaveTypes();
  const { data: balances = [], isLoading: bLoading } = useAdminEmployeeBalances(employeeId, year);
  const { data: appsData, isLoading: aLoading }      = useAdminLeaveApplications({
    employeeId, year, page, limit: LIMIT,
  });

  const apps  = appsData?.items ?? [];
  const total = appsData?.total ?? 0;

  // Merge every active type with its balance so zero-balance types show too
  const merged = types
    .filter((t) => t.isActive)
    .map((t) => {
      const bal = balances.find((b) => b.leaveTypeId === t.id);
      const totalCredited = bal?.totalCredited ?? 0;
      const carryForward  = bal?.carryForward  ?? 0;
      const used          = bal?.used          ?? 0;
      // Important: compute dynamically (server-side `available` can drift)
      const available     = totalCredited + carryForward - used;
      return {
        code:          t.code,
        name:          t.name,
        id:            t.id,
        totalCredited,
        carryForward,
        used,
        pending:       bal?.pending ?? 0,
        available,
        isAdminOnly:   !t.employeeCanApply,
        isCarryForward: t.isCarryForward,
      };
    });

  return (
    <div className="space-y-8">
      {/* ── Header ────────────────────────────────────────────────────────── */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-base font-semibold text-slate-800">Leave Summary</h2>
          <p className="text-xs text-slate-400 mt-0.5">Balances and application history</p>
        </div>
        <div className="flex items-center gap-2">
          {/* Year selector */}
          <div className="flex items-center gap-1 border border-slate-200 rounded-lg px-2 py-1 bg-white">
            <button title="Previous year" onClick={() => setYear((y) => y - 1)} className="p-0.5 rounded hover:bg-slate-100">
              <ChevronLeft className="w-3.5 h-3.5 text-slate-500" />
            </button>
            <span className="text-sm font-medium text-slate-700 w-10 text-center">{year}</span>
            <button title="Next year" onClick={() => setYear((y) => y + 1)} disabled={year >= currentYear}
              className="p-0.5 rounded hover:bg-slate-100 disabled:opacity-30">
              <ChevronRight className="w-3.5 h-3.5 text-slate-500" />
            </button>
          </div>
          <Button size="sm" className="h-8 text-xs text-white" style={{ background: "#1d3459" }}
            onClick={() => setApplyOpen(true)}>
            <Plus className="w-3.5 h-3.5 mr-1" /> Apply Leave
          </Button>
        </div>
      </div>

      {/* ── Balance grid ──────────────────────────────────────────────────── */}
      {(bLoading || tLoading) ? (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
          {Array.from({ length: 6 }).map((_, i) => <Skeleton key={i} className="h-28 rounded-2xl" />)}
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
          {merged.map((b) => (
            <Card key={b.id} className={`border-none shadow-sm ${b.isAdminOnly ? "opacity-70" : ""}`}>
              <CardContent className="pt-4 pb-3 px-4">
                <div className="flex items-start justify-between mb-2">
                  <span className="text-xs font-bold px-1.5 py-0.5 rounded"
                    style={{ background: "#1d3459", color: "#d9b557", fontSize: "10px" }}>
                    {b.code}
                  </span>
                  <CalendarDays className="w-3.5 h-3.5 text-slate-300" />
                </div>

                {/* Available — big number */}
                <p className="text-2xl font-extrabold text-slate-800 leading-none">
                  {b.available}
                  <span className="text-xs font-medium text-slate-400 ml-1">left</span>
                </p>
                <p className="text-xs text-slate-500 mt-0.5 truncate">{b.name}</p>

                {/* Stats row */}
                <div className="mt-2.5 flex flex-wrap gap-x-3 gap-y-0.5 text-[11px] text-slate-400">
                  <span>Credited <strong className="text-slate-600">{b.totalCredited}</strong></span>
                  {b.isCarryForward && b.carryForward > 0 && (
                    <span>C/F <strong className="text-slate-600">{b.carryForward}</strong></span>
                  )}
                  <span>Used <strong className="text-slate-600">{b.used}</strong></span>
                  {b.pending > 0 && (
                    <span>Pending <strong className="text-amber-600">{b.pending}</strong></span>
                  )}
                </div>

                {b.isAdminOnly && (
                  <p className="text-[10px] text-orange-400 mt-1 italic">HR applied only</p>
                )}
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* ── Application history ───────────────────────────────────────────── */}
      <div>
        <h3 className="text-sm font-semibold text-slate-500 uppercase tracking-wider mb-3">
          Applications — {year}
        </h3>

        {aLoading ? (
          <div className="space-y-2">
            {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-16 rounded-xl" />)}
          </div>
        ) : !apps.length ? (
          <p className="text-sm text-slate-400 italic">No leave applications for {year}.</p>
        ) : (
          <div className="space-y-2">
            {apps.map((a: LeaveApplication) => (
              <Card key={a.id} className="border-none shadow-sm">
                <CardContent className="py-3 px-4 flex items-center justify-between gap-4">
                  <div className="flex items-center gap-3 min-w-0">
                    <div className="p-2 rounded-xl bg-slate-100 shrink-0">
                      <CalendarDays className="w-4 h-4 text-slate-500" />
                    </div>
                    <div className="min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="text-xs font-bold px-1.5 py-0.5 rounded"
                          style={{ background: "#1d3459", color: "#d9b557", fontSize: "10px" }}>
                          {a.leaveType.code}
                        </span>
                        <p className="text-sm font-medium text-slate-800">
                          {fmt(a.fromDate)}
                          {a.fromDate !== a.toDate && <> → {fmt(a.toDate)}</>}
                          {a.isHalfDay && <span className="ml-1 text-xs text-slate-400">(Half day)</span>}
                        </p>
                        <span className="text-xs text-slate-400">{a.totalDays}d</span>
                      </div>
                      <p className="text-xs text-slate-400 truncate mt-0.5">{a.reason}</p>
                    </div>
                  </div>
                  <div className="flex flex-col items-end gap-1 shrink-0">
                    <Badge className={`text-[11px] border flex items-center gap-1 ${STATUS_STYLES[a.status] ?? ""}`}>
                      {STATUS_ICONS[a.status]}
                      {a.status}
                    </Badge>
                    {a.isAppliedByAdmin && (
                      <span className="text-[10px] text-slate-400 italic">by HR/Admin</span>
                    )}
                  </div>
                </CardContent>
              </Card>
            ))}

            {/* Pagination */}
            {total > LIMIT && (
              <div className="flex items-center justify-center gap-3 pt-2">
                <Button variant="ghost" size="sm" disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
                  <ChevronLeft className="w-4 h-4" />
                </Button>
                <span className="text-xs text-slate-500">Page {page + 1} of {Math.ceil(total / LIMIT)}</span>
                <Button variant="ghost" size="sm" disabled={page * LIMIT >= total} onClick={() => setPage((p) => p + 1)}>
                  <ChevronRight className="w-4 h-4" />
                </Button>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Apply dialog */}
      <ApplyLeaveDialog open={applyOpen} onClose={() => setApplyOpen(false)} employeeId={employeeId} />
    </div>
  );
}
