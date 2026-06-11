"use client";

import { useEffect, useMemo, useState } from "react";
import {
  useAdminAddPunch,
  useAdminAttendanceDay,
  useAdminAttendancePolicy,
  useAdminUpdateAttendancePolicy,
  useAdminUpdatePunch,
} from "@/lib/hooks/useAttendance";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

function ymdToday() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const da = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${da}`;
}

function fmtTime(iso: string) {
  const d = new Date(iso);
  return d.toLocaleTimeString("en-IN", { timeZone: "Asia/Kolkata", hour: "2-digit", minute: "2-digit" });
}

export default function AdminAttendancePage() {
  const [date, setDate] = useState<string>(ymdToday());
  const [newEmployeeId, setNewEmployeeId] = useState<string>("");
  const [newTime, setNewTime] = useState<string>("09:00");
  const [newPunchType, setNewPunchType] = useState<string>("IN");
  const [newTerminal, setNewTerminal] = useState<string>("MANUAL");
  const [editingPunchId, setEditingPunchId] = useState<string | null>(null);
  const [editingTime, setEditingTime] = useState<string>("");
  const [editingType, setEditingType] = useState<string>("");
  const [editingTerminal, setEditingTerminal] = useState<string>("");

  const q = useAdminAttendanceDay(date);
  const policyQ = useAdminAttendancePolicy();
  const updatePolicy = useAdminUpdateAttendancePolicy();
  const [policyIn, setPolicyIn] = useState<string>("09:00");
  const [policyOut, setPolicyOut] = useState<string>("15:30");
  const [policyInBuf, setPolicyInBuf] = useState<string>("10");
  const [policyOutBuf, setPolicyOutBuf] = useState<string>("10");
  const addPunch = useAdminAddPunch();
  const updatePunch = useAdminUpdatePunch();

  const rows = useMemo(() => (q.data ?? []).slice().sort((a, b) => a.employeeId - b.employeeId), [q.data]);

  useEffect(() => {
    if (!policyQ.data) return;
    setPolicyIn(policyQ.data.defaultPunchInTime);
    setPolicyOut(policyQ.data.defaultPunchOutTime);
    setPolicyInBuf(String(policyQ.data.punchInBufferMinutes));
    setPolicyOutBuf(String(policyQ.data.punchOutBufferMinutes));
  }, [policyQ.data]);

  const handleAddPunch = async () => {
    const employeeId = Number(newEmployeeId);
    if (!Number.isFinite(employeeId) || employeeId <= 0) return;
    await addPunch.mutateAsync({
      employeeId,
      punchAt: `${date}T${newTime}:00+05:30`,
      punchType: newPunchType || "MANUAL",
      terminalId: newTerminal || "MANUAL",
    });
    setNewEmployeeId("");
  };

  const startEdit = (p: { id: string; punchAt: string; punchType: string | null; terminalId: string | null }) => {
    setEditingPunchId(p.id);
    const d = new Date(p.punchAt);
    const hh = new Intl.DateTimeFormat("en-IN", { timeZone: "Asia/Kolkata", hour: "2-digit", hour12: false }).format(d);
    const mm = new Intl.DateTimeFormat("en-IN", { timeZone: "Asia/Kolkata", minute: "2-digit" }).format(d);
    setEditingTime(`${hh}:${mm}`);
    setEditingType(p.punchType ?? "");
    setEditingTerminal(p.terminalId ?? "");
  };

  const submitEdit = async () => {
    if (!editingPunchId) return;
    await updatePunch.mutateAsync({
      punchId: editingPunchId,
      punchAt: `${date}T${editingTime}:00+05:30`,
      punchType: editingType || null,
      terminalId: editingTerminal || null,
    });
    setEditingPunchId(null);
  };

  const savePolicy = async () => {
    const punchInBufferMinutes = Number(policyInBuf);
    const punchOutBufferMinutes = Number(policyOutBuf);
    await updatePolicy.mutateAsync({
      defaultPunchInTime: policyIn,
      defaultPunchOutTime: policyOut,
      punchInBufferMinutes,
      punchOutBufferMinutes,
    });
  };

  return (
    <div className="space-y-4">
      <div className="flex flex-col md:flex-row md:items-end gap-3">
        <div className="flex-1">
          <h1 className="text-xl font-bold text-[#1d3459]">Attendance</h1>
          <p className="text-xs text-slate-500">Pick a date to see all employees and their punch logs.</p>
        </div>
        <div className="w-full md:w-[220px]">
          <label className="text-xs font-semibold text-slate-600">Date</label>
          <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
        </div>
      </div>

      <Card className="p-4">
        <div className="mb-4 p-3 border border-slate-200 rounded-lg bg-white">
          <div className="flex items-center justify-between gap-3 flex-wrap">
            <div>
              <p className="text-xs font-semibold text-slate-800">Punch timing policy</p>
              <p className="text-[11px] text-slate-500">
                Late if punch-in is after <span className="font-semibold">Punch In + buffer</span>. Eligible if punch-out is after{" "}
                <span className="font-semibold">Punch Out - buffer</span>.
              </p>
            </div>
            <Button onClick={savePolicy} disabled={updatePolicy.isPending || policyQ.isLoading}>
              {updatePolicy.isPending ? "Saving..." : "Save Policy"}
            </Button>
          </div>

          <div className="mt-3 grid grid-cols-1 md:grid-cols-4 gap-2">
            <div>
              <label className="text-xs font-semibold text-slate-600">Default Punch In</label>
              <Input type="time" value={policyIn} onChange={(e) => setPolicyIn(e.target.value)} />
            </div>
            <div>
              <label className="text-xs font-semibold text-slate-600">In Buffer (mins)</label>
              <Input inputMode="numeric" value={policyInBuf} onChange={(e) => setPolicyInBuf(e.target.value)} />
            </div>
            <div>
              <label className="text-xs font-semibold text-slate-600">Default Punch Out</label>
              <Input type="time" value={policyOut} onChange={(e) => setPolicyOut(e.target.value)} />
            </div>
            <div>
              <label className="text-xs font-semibold text-slate-600">Out Buffer (mins)</label>
              <Input inputMode="numeric" value={policyOutBuf} onChange={(e) => setPolicyOutBuf(e.target.value)} />
            </div>
          </div>

          {policyQ.isError ? <div className="mt-2 text-xs text-red-600">Failed to load policy.</div> : null}
          {updatePolicy.isError ? <div className="mt-2 text-xs text-red-600">Failed to save policy.</div> : null}
        </div>

        <div className="mb-4 p-3 border border-slate-200 rounded-lg bg-slate-50">
          <p className="text-xs font-semibold text-slate-700 mb-2">Admin controls: add manual punch</p>
          <div className="grid grid-cols-1 md:grid-cols-5 gap-2">
            <Input placeholder="Employee ID" value={newEmployeeId} onChange={(e) => setNewEmployeeId(e.target.value)} />
            <Input type="time" value={newTime} onChange={(e) => setNewTime(e.target.value)} />
            <Input placeholder="Type (IN/OUT)" value={newPunchType} onChange={(e) => setNewPunchType(e.target.value)} />
            <Input placeholder="Terminal" value={newTerminal} onChange={(e) => setNewTerminal(e.target.value)} />
            <Button onClick={handleAddPunch} disabled={addPunch.isPending}>
              {addPunch.isPending ? "Adding..." : "Add Punch"}
            </Button>
          </div>
        </div>

        {q.isLoading ? (
          <div className="text-sm text-slate-500">Loading...</div>
        ) : q.isError ? (
          <div className="text-sm text-red-600">Failed to load attendance.</div>
        ) : rows.length === 0 ? (
          <div className="text-sm text-slate-500">No punches found for this date.</div>
        ) : (
          <div className="space-y-3">
            {rows.map((r) => (
              <div key={r.employeeId} className="rounded-lg border border-slate-200 p-3">
                <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-2">
                  <div className="min-w-0">
                    <div className="font-semibold text-slate-800 truncate">{r.fullName}</div>
                    <div className="text-xs text-slate-500">
                      {r.employeeCode ? `Code ${r.employeeCode}` : `ID ${r.employeeId}`}
                      {r.department ? ` • ${r.department}` : ""}
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge variant="outline">{r.punches.length} punches</Badge>
                    {r.punches.length ? (
                      <Badge variant="secondary">
                        {fmtTime(r.punches[0].punchAt)} - {fmtTime(r.punches[r.punches.length - 1].punchAt)}
                      </Badge>
                    ) : null}
                  </div>
                </div>

                {r.punches.length ? (
                  <div className="mt-3 overflow-x-auto">
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
                        {r.punches.map((p, idx) => (
                          <tr key={`${r.employeeId}-${idx}`} className="border-t border-slate-100">
                            <td className="py-2 pr-3 font-medium text-slate-700">
                              {editingPunchId === p.id ? (
                                <Input type="time" value={editingTime} onChange={(e) => setEditingTime(e.target.value)} />
                              ) : (
                                fmtTime(p.punchAt)
                              )}
                            </td>
                            <td className="py-2 pr-3 text-slate-600">
                              {editingPunchId === p.id ? (
                                <Input value={editingType} onChange={(e) => setEditingType(e.target.value)} />
                              ) : (
                                p.punchType ?? "-"
                              )}
                            </td>
                            <td className="py-2 pr-3 text-slate-600">
                              {editingPunchId === p.id ? (
                                <Input value={editingTerminal} onChange={(e) => setEditingTerminal(e.target.value)} />
                              ) : (
                                p.terminalId ?? "-"
                              )}
                            </td>
                            <td className="py-2 pr-3 text-slate-600">{p.source}</td>
                            <td className="py-2 pr-3">
                              {editingPunchId === p.id ? (
                                <div className="flex gap-2">
                                  <Button size="sm" onClick={submitEdit} disabled={updatePunch.isPending}>
                                    Save
                                  </Button>
                                  <Button size="sm" variant="outline" onClick={() => setEditingPunchId(null)}>
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
                ) : (
                  <div className="mt-2 text-xs text-slate-500">No punches.</div>
                )}
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}

