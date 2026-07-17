"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import {
  useAdminAddPunch,
  useAdminEmployeeHistory,
  useAdminUpdatePunch,
} from "@/lib/hooks/useAttendance";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

function monthRange(year: number, month: number) {
  const from = `${year}-${String(month).padStart(2, "0")}-01`;
  const last = new Date(year, month, 0).getDate();
  const to = `${year}-${String(month).padStart(2, "0")}-${String(last).padStart(2, "0")}`;
  return { from, to };
}

function fmtTime(iso: string) {
  return new Date(iso).toLocaleTimeString("en-IN", {
    timeZone: "Asia/Kolkata",
    hour: "2-digit",
    minute: "2-digit",
  });
}

const MONTHS = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December",
];

export default function AdminEmployeeAttendanceHistoryPage() {
  const params = useParams<{ employeeId: string }>();
  const employeeId = Number(params.employeeId);
  const now = new Date();
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);
  const range = useMemo(() => monthRange(year, month), [year, month]);

  const historyQ = useAdminEmployeeHistory({
    employeeId,
    from: range.from,
    to: range.to,
  });
  const addPunch = useAdminAddPunch();
  const updatePunch = useAdminUpdatePunch();

  const [newDate, setNewDate] = useState(range.from);
  const [newTime, setNewTime] = useState("09:00");
  const [newType, setNewType] = useState("IN");
  const [editingPunchId, setEditingPunchId] = useState<string | null>(null);
  const [editingDate, setEditingDate] = useState("");
  const [editingTime, setEditingTime] = useState("");
  const [editingType, setEditingType] = useState("");

  const daysWithPunches = useMemo(
    () => (historyQ.data?.days ?? []).filter((d) => d.punches.length > 0).slice().reverse(),
    [historyQ.data],
  );

  const prevMonth = () => {
    if (month === 1) {
      setYear((y) => y - 1);
      setMonth(12);
    } else setMonth((m) => m - 1);
  };
  const nextMonth = () => {
    if (month === 12) {
      setYear((y) => y + 1);
      setMonth(1);
    } else setMonth((m) => m + 1);
  };

  const handleAdd = async () => {
    if (!Number.isFinite(employeeId) || employeeId <= 0) return;
    await addPunch.mutateAsync({
      employeeId,
      punchAt: `${newDate}T${newTime}:00+05:30`,
      punchType: newType,
      terminalId: "MANUAL",
    });
  };

  const startEdit = (p: {
    id: string;
    punchAt: string;
    punchType: string | null;
  }) => {
    setEditingPunchId(p.id);
    const d = new Date(p.punchAt);
    const ymd = new Intl.DateTimeFormat("en-CA", {
      timeZone: "Asia/Kolkata",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(d);
    const hh = new Intl.DateTimeFormat("en-IN", {
      timeZone: "Asia/Kolkata",
      hour: "2-digit",
      hour12: false,
    }).format(d);
    const mm = new Intl.DateTimeFormat("en-IN", {
      timeZone: "Asia/Kolkata",
      minute: "2-digit",
    }).format(d);
    setEditingDate(ymd);
    setEditingTime(`${hh}:${mm}`);
    setEditingType(p.punchType ?? "IN");
  };

  const submitEdit = async () => {
    if (!editingPunchId) return;
    await updatePunch.mutateAsync({
      punchId: editingPunchId,
      punchAt: `${editingDate}T${editingTime}:00+05:30`,
      punchType: editingType || null,
      terminalId: "MANUAL",
    });
    setEditingPunchId(null);
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <Button asChild variant="ghost" size="sm">
          <Link href="/admin/attendance">← Back</Link>
        </Button>
        <div className="flex-1">
          <h1 className="text-xl font-bold text-[#1d3459]">
            {historyQ.data?.employee.fullName ?? `Employee #${employeeId}`}
          </h1>
          <p className="text-xs text-slate-500">
            {historyQ.data?.employee.employeeCode
              ? `Code ${historyQ.data.employee.employeeCode}`
              : `ID ${employeeId}`}
            {historyQ.data?.employee.department
              ? ` • ${historyQ.data.employee.department}`
              : ""}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={prevMonth}>
            Prev
          </Button>
          <span className="text-sm font-semibold min-w-[140px] text-center">
            {MONTHS[month - 1]} {year}
          </span>
          <Button variant="outline" size="sm" onClick={nextMonth}>
            Next
          </Button>
        </div>
      </div>

      <Card className="p-4 space-y-3">
        <p className="text-xs font-semibold text-slate-700">Add manual punch</p>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-2">
          <Input type="date" value={newDate} onChange={(e) => setNewDate(e.target.value)} />
          <Input type="time" value={newTime} onChange={(e) => setNewTime(e.target.value)} />
          <Input value={newType} onChange={(e) => setNewType(e.target.value)} placeholder="IN/OUT" />
          <Button onClick={handleAdd} disabled={addPunch.isPending}>
            {addPunch.isPending ? "Adding..." : "Add Punch"}
          </Button>
        </div>
      </Card>

      <Card className="p-4">
        {historyQ.isLoading ? (
          <div className="text-sm text-slate-500">Loading history...</div>
        ) : historyQ.isError ? (
          <div className="text-sm text-red-600">Failed to load history.</div>
        ) : daysWithPunches.length === 0 ? (
          <div className="text-sm text-slate-500">No punches this month.</div>
        ) : (
          <div className="space-y-3">
            {daysWithPunches.map((day) => (
              <div key={day.date} className="rounded-lg border border-slate-200 p-3">
                <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
                  <div>
                    <div className="font-semibold text-slate-800">{day.date}</div>
                    <div className="text-xs text-slate-500">
                      In {day.firstIn ? fmtTime(day.firstIn) : "—"} · Out{" "}
                      {day.lastOut ? fmtTime(day.lastOut) : "—"}
                    </div>
                  </div>
                  <div className="flex gap-2">
                    {day.isLate ? <Badge variant="destructive">Late</Badge> : null}
                    {day.meetsPunchOut === false ? (
                      <Badge variant="outline">Early out</Badge>
                    ) : null}
                    <Badge variant="secondary">{day.punches.length} punches</Badge>
                  </div>
                </div>
                <table className="w-full text-xs">
                  <thead>
                    <tr className="text-left text-slate-500">
                      <th className="py-2 pr-3">Time</th>
                      <th className="py-2 pr-3">Type</th>
                      <th className="py-2 pr-3">Terminal</th>
                      <th className="py-2 pr-3">Source</th>
                      <th className="py-2 pr-3">Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {day.punches.map((p) => (
                      <tr key={p.id} className="border-t border-slate-100">
                        <td className="py-2 pr-3 font-medium text-slate-700">
                          {editingPunchId === p.id ? (
                            <div className="flex gap-2">
                              <Input
                                type="date"
                                value={editingDate}
                                onChange={(e) => setEditingDate(e.target.value)}
                              />
                              <Input
                                type="time"
                                value={editingTime}
                                onChange={(e) => setEditingTime(e.target.value)}
                              />
                            </div>
                          ) : (
                            fmtTime(p.punchAt)
                          )}
                        </td>
                        <td className="py-2 pr-3">
                          {editingPunchId === p.id ? (
                            <Input
                              value={editingType}
                              onChange={(e) => setEditingType(e.target.value)}
                            />
                          ) : (
                            p.punchType ?? "-"
                          )}
                        </td>
                        <td className="py-2 pr-3">{p.terminalId ?? "-"}</td>
                        <td className="py-2 pr-3">{p.source}</td>
                        <td className="py-2 pr-3">
                          {editingPunchId === p.id ? (
                            <div className="flex gap-2">
                              <Button size="sm" onClick={submitEdit} disabled={updatePunch.isPending}>
                                Save
                              </Button>
                              <Button
                                size="sm"
                                variant="outline"
                                onClick={() => setEditingPunchId(null)}
                              >
                                Cancel
                              </Button>
                            </div>
                          ) : (
                            <Button size="sm" variant="outline" onClick={() => startEdit(p)}>
                              Edit
                            </Button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}
