"use client";

import { useMemo, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  useEmployeeAttendanceSettings,
  useEmployeeMonthlyAttendanceSummary,
  useUpdateEmployeeAttendanceSettings,
} from "@/lib/hooks/useAttendance";
import { LeaveTab } from "./LeaveTab";
import {
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  Clock,
  Pencil,
  ChevronDown,
  ChevronUp,
} from "lucide-react";

const MONTH_LABELS = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

function formatIstTime(iso: string | null | undefined) {
  if (!iso) return "—";
  return new Date(iso).toLocaleTimeString("en-IN", {
    timeZone: "Asia/Kolkata",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function minutesToHM(mins: number) {
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  if (h === 0) return `${m}m`;
  if (m === 0) return `${h}h`;
  return `${h}h ${m}m`;
}

interface AttendanceTabProps {
  employeeId: number;
  canManageSettings?: boolean;
}

export function AttendanceTab({
  employeeId,
  canManageSettings = false,
}: AttendanceTabProps) {
  const now = new Date();
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [showLeave, setShowLeave] = useState(false);
  const [editOpen, setEditOpen] = useState(false);

  const settingsQ = useEmployeeAttendanceSettings(employeeId);
  const summaryQ = useEmployeeMonthlyAttendanceSummary({ employeeId, year, month });
  const updateSettings = useUpdateEmployeeAttendanceSettings(employeeId);

  const [useGlobal, setUseGlobal] = useState(true);
  const [punchIn, setPunchIn] = useState("09:00");
  const [punchOut, setPunchOut] = useState("15:30");
  const [inBuffer, setInBuffer] = useState("10");
  const [outBuffer, setOutBuffer] = useState("10");

  const openEdit = () => {
    const s = settingsQ.data;
    setUseGlobal(s?.useGlobalPolicy ?? true);
    setPunchIn(s?.punchInTime ?? s?.effective.punchInTime ?? "09:00");
    setPunchOut(s?.punchOutTime ?? s?.effective.punchOutTime ?? "15:30");
    setInBuffer(String(s?.punchInBufferMinutes ?? s?.effective.punchInBufferMinutes ?? 10));
    setOutBuffer(String(s?.punchOutBufferMinutes ?? s?.effective.punchOutBufferMinutes ?? 10));
    setEditOpen(true);
  };

  const handleSaveSettings = async () => {
    await updateSettings.mutateAsync({
      useGlobalPolicy: useGlobal,
      ...(useGlobal
        ? {}
        : {
            punchInTime: punchIn.trim(),
            punchOutTime: punchOut.trim(),
            punchInBufferMinutes: Number(inBuffer) || 10,
            punchOutBufferMinutes: Number(outBuffer) || 10,
          }),
    });
    setEditOpen(false);
  };

  const futureMonth = useMemo(() => {
    const ist = new Date(Date.now() + 330 * 60 * 1000);
    const cy = ist.getUTCFullYear();
    const cm = ist.getUTCMonth() + 1;
    return (y: number, m: number) => y > cy || (y === cy && m > cm);
  }, []);

  const stats = summaryQ.data?.stats;
  const days = summaryQ.data?.days ?? [];
  const effective = settingsQ.data?.effective;

  return (
    <div className="space-y-4">
      <Card className="border-slate-200/60 shadow-sm">
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between gap-3 flex-wrap">
            <div className="flex items-center gap-2">
              <Clock className="w-4 h-4 text-[#c5a059]" />
              <CardTitle className="text-sm font-bold text-slate-800 uppercase tracking-tight">
                Punch window
              </CardTitle>
            </div>
            {canManageSettings && (
              <Button size="sm" variant="outline" onClick={openEdit} className="h-8 text-xs gap-1">
                <Pencil className="w-3.5 h-3.5" /> Edit timings
              </Button>
            )}
          </div>
        </CardHeader>
        <CardContent>
          {settingsQ.isLoading ? (
            <Skeleton className="h-16 w-full" />
          ) : (
            <div className="space-y-2">
              <p className="text-xs text-slate-500">
                {effective?.source === "EMPLOYEE"
                  ? "Custom timings for this employee"
                  : "Using global policy"}
              </p>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
                <div className="rounded-xl border border-slate-100 bg-slate-50/60 px-3 py-2">
                  <p className="text-[10px] font-bold uppercase tracking-widest text-slate-400">Punch in</p>
                  <p className="font-bold text-slate-800">
                    {effective?.punchInTime ?? "—"}{" "}
                    <span className="text-xs font-medium text-slate-500">
                      (+{effective?.punchInBufferMinutes ?? 0}m buffer)
                    </span>
                  </p>
                </div>
                <div className="rounded-xl border border-slate-100 bg-slate-50/60 px-3 py-2">
                  <p className="text-[10px] font-bold uppercase tracking-widest text-slate-400">Punch out</p>
                  <p className="font-bold text-slate-800">
                    {effective?.punchOutTime ?? "—"}{" "}
                    <span className="text-xs font-medium text-slate-500">
                      (+{effective?.punchOutBufferMinutes ?? 0}m buffer)
                    </span>
                  </p>
                </div>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      <Card className="border-slate-200/60 shadow-sm">
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-bold text-slate-800">This month</CardTitle>
        </CardHeader>
        <CardContent>
          {summaryQ.isLoading ? (
            <Skeleton className="h-12 w-full" />
          ) : stats ? (
            <div className="flex flex-wrap gap-2">
              <Badge variant="secondary">Present: {stats.presentDays} days</Badge>
              <Badge variant="secondary">Working hours: {stats.totalWorkingHours}h</Badge>
              <Badge variant="secondary">Late: {stats.lateDays}</Badge>
              <Badge variant="secondary">Leave days: {stats.leaveDaysInMonth}</Badge>
              <Badge variant="outline">Absent*: {stats.absentDays}</Badge>
            </div>
          ) : null}
          <p className="text-[11px] text-slate-400 mt-2">* Days in month with no punch recorded</p>
        </CardContent>
      </Card>

      <div className="flex flex-wrap gap-2">
        <Button
          size="sm"
          variant="outline"
          onClick={() => setShowLeave((v) => !v)}
          className="gap-1"
        >
          {showLeave ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
          {showLeave ? "Hide leave" : "Manage leave"}
        </Button>
      </div>

      {showLeave && <LeaveTab employeeId={employeeId} />}

      <Card className="border-slate-200/60 shadow-sm">
        <CardHeader className="pb-2">
          <div className="flex items-center gap-2">
            <CalendarDays className="w-4 h-4 text-[#1d3459]" />
            <CardTitle className="text-sm font-bold text-slate-800">Monthly log</CardTitle>
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-center gap-2">
            <Button size="sm" variant="outline" className="h-8 w-8 p-0" onClick={() => setYear((y) => y - 1)}>
              <ChevronLeft className="w-4 h-4" />
            </Button>
            <span className="text-sm font-bold text-slate-800 min-w-[60px] text-center">{year}</span>
            <Button
              size="sm"
              variant="outline"
              className="h-8 w-8 p-0"
              onClick={() => setYear((y) => y + 1)}
              disabled={year >= now.getFullYear()}
            >
              <ChevronRight className="w-4 h-4" />
            </Button>
          </div>

          <div className="flex flex-wrap gap-1.5 justify-center">
            {MONTH_LABELS.map((label, i) => {
              const m = i + 1;
              const selected = m === month;
              const disabled = futureMonth(year, m);
              return (
                <button
                  key={label}
                  type="button"
                  disabled={disabled}
                  onClick={() => setMonth(m)}
                  className={`px-2.5 py-1 rounded-lg text-xs font-bold border transition-colors ${
                    selected
                      ? "bg-[#1d3459] text-white border-[#1d3459]"
                      : disabled
                        ? "bg-slate-50 text-slate-300 border-slate-100 cursor-not-allowed"
                        : "bg-white text-slate-600 border-slate-200 hover:border-[#1d3459]/40"
                  }`}
                >
                  {label}
                </button>
              );
            })}
          </div>

          {summaryQ.isLoading ? (
            <Skeleton className="h-40 w-full" />
          ) : days.length === 0 ? (
            <p className="text-sm text-slate-400 text-center py-6">No days in range.</p>
          ) : (
            <div className="rounded-xl border border-slate-200 overflow-hidden">
              <div className="grid grid-cols-[100px_1fr_1fr_90px_32px] gap-2 px-3 py-2 bg-slate-50 text-[10px] font-bold uppercase tracking-widest text-slate-400">
                <span>Date</span>
                <span>Punch in</span>
                <span>Punch out</span>
                <span>Hours</span>
                <span />
              </div>
              {days.map((day) => {
                const hasPunch = !!day.firstIn;
                return (
                  <div
                    key={day.date}
                    className="grid grid-cols-[100px_1fr_1fr_90px_32px] gap-2 px-3 py-2 border-t border-slate-100 text-xs items-center"
                  >
                    <span className="font-bold text-slate-700">{day.date}</span>
                    <span className="text-slate-600">{hasPunch ? formatIstTime(day.firstIn) : "—"}</span>
                    <span className="text-slate-600">{hasPunch ? formatIstTime(day.lastOut) : "—"}</span>
                    <span className="font-semibold text-slate-700">
                      {hasPunch ? minutesToHM(day.totalMinutes) : "—"}
                    </span>
                    <span className="flex justify-end">
                      {!hasPunch ? (
                        <span className="w-2 h-2 rounded-full bg-slate-300" />
                      ) : day.isLate ? (
                        <span className="w-2 h-2 rounded-full bg-amber-400" title="Late" />
                      ) : (
                        <span className="w-2 h-2 rounded-full bg-emerald-500" title="On time" />
                      )}
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </CardContent>
      </Card>

      <Dialog open={editOpen} onOpenChange={setEditOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Punch timings</DialogTitle>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="flex items-center justify-between gap-3">
              <Label htmlFor="use-global">Use global policy</Label>
              <Switch id="use-global" checked={useGlobal} onCheckedChange={setUseGlobal} />
            </div>
            {!useGlobal && (
              <div className="space-y-3">
                <div className="space-y-1">
                  <Label>Punch in (HH:MM)</Label>
                  <Input value={punchIn} onChange={(e) => setPunchIn(e.target.value)} />
                </div>
                <div className="space-y-1">
                  <Label>Punch out (HH:MM)</Label>
                  <Input value={punchOut} onChange={(e) => setPunchOut(e.target.value)} />
                </div>
                <div className="space-y-1">
                  <Label>In buffer (minutes)</Label>
                  <Input type="number" value={inBuffer} onChange={(e) => setInBuffer(e.target.value)} />
                </div>
                <div className="space-y-1">
                  <Label>Out buffer (minutes)</Label>
                  <Input type="number" value={outBuffer} onChange={(e) => setOutBuffer(e.target.value)} />
                </div>
              </div>
            )}
          </div>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setEditOpen(false)}>Cancel</Button>
            <Button onClick={handleSaveSettings} disabled={updateSettings.isPending}>
              {updateSettings.isPending ? "Saving…" : "Save"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
