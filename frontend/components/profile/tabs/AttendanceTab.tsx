"use client";

import { useMemo, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useMyAttendanceCalendar, useMyAttendanceDay } from "@/lib/hooks/useAttendance";
import { CalendarDays, ChevronLeft, ChevronRight, Clock } from "lucide-react";

function ymd(d: Date) {
  // Date key in IST (Asia/Kolkata) for API + UI
  const shifted = new Date(d.getTime() + 330 * 60 * 1000);
  return `${shifted.getUTCFullYear()}-${String(shifted.getUTCMonth() + 1).padStart(2, "0")}-${String(shifted.getUTCDate()).padStart(2, "0")}`;
}

function monthRangeUtc(base: Date) {
  // Month range in IST; returned Dates are still JS Dates (UTC instants)
  const shifted = new Date(base.getTime() + 330 * 60 * 1000);
  const y = shifted.getUTCFullYear();
  const m = shifted.getUTCMonth();
  const from = new Date(Date.UTC(y, m, 1));
  const to = new Date(Date.UTC(y, m + 1, 0)); // last day
  return { from, to };
}

function minutesToHM(mins: number) {
  const h = Math.floor(mins / 60);
  const m = mins % 60;
  return `${h}h ${m}m`;
}

export function AttendanceTab() {
  const [month, setMonth] = useState(() => {
    const now = new Date();
    return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  });
  const [selected, setSelected] = useState<string>(() => ymd(new Date()));

  const { from, to } = useMemo(() => monthRangeUtc(month), [month]);
  const calendar = useMyAttendanceCalendar({ from: ymd(from), to: ymd(to) });
  const day = useMyAttendanceDay(selected);

  const days = useMemo(() => {
    const firstDow = new Date(Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), 1)).getUTCDay(); // 0 Sun
    const totalDays = to.getUTCDate();
    const slots: Array<{ key: string; date: string | null }> = [];
    for (let i = 0; i < firstDow; i++) slots.push({ key: `pad-${i}`, date: null });
    for (let d = 1; d <= totalDays; d++) {
      const dt = new Date(Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), d));
      slots.push({ key: ymd(dt), date: ymd(dt) });
    }
    return slots;
  }, [from, to]);

  return (
    <Card className="border-slate-200/60 shadow-sm">
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between gap-3 flex-wrap">
          <div className="flex items-center gap-2">
            <CalendarDays className="w-4 h-4 text-[#1d3459]" />
            <CardTitle className="text-sm font-bold text-slate-800 uppercase tracking-tight">
              Attendance
            </CardTitle>
          </div>
          <div className="flex items-center gap-2">
            <Button
              size="sm"
              variant="outline"
              className="h-9 rounded-xl"
              onClick={() => setMonth((m) => new Date(Date.UTC(m.getUTCFullYear(), m.getUTCMonth() - 1, 1)))}
            >
              <ChevronLeft className="w-4 h-4" />
            </Button>
            <div className="text-xs font-bold text-slate-700 min-w-[150px] text-center">
              {month.toLocaleString("en-IN", { month: "long", year: "numeric", timeZone: "Asia/Kolkata" })}
            </div>
            <Button
              size="sm"
              variant="outline"
              className="h-9 rounded-xl"
              onClick={() => setMonth((m) => new Date(Date.UTC(m.getUTCFullYear(), m.getUTCMonth() + 1, 1)))}
            >
              <ChevronRight className="w-4 h-4" />
            </Button>
          </div>
        </div>
        <p className="text-[11px] text-slate-500 font-medium">
          Raw biometric punches synced from device. Work-hours are derived from first-in and last-out.
        </p>
      </CardHeader>

      <CardContent className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2">
          {calendar.isLoading ? (
            <Skeleton className="h-64 w-full rounded-xl" />
          ) : (
            <div className="grid grid-cols-7 gap-2">
              {["Sun","Mon","Tue","Wed","Thu","Fri","Sat"].map((d) => (
                <div key={d} className="text-[10px] font-bold text-slate-400 uppercase tracking-widest px-1 py-1">
                  {d}
                </div>
              ))}
              {days.map((slot) => {
                if (!slot.date) return <div key={slot.key} className="h-16 rounded-xl bg-transparent" />;
                const info = calendar.data?.[slot.date];
                const isSelected = slot.date === selected;
                return (
                  <button
                    key={slot.key}
                    onClick={() => setSelected(slot.date!)}
                    className={`h-16 rounded-xl border text-left p-2 transition-all ${
                      isSelected
                        ? "border-[#1d3459] bg-[#1d3459]/5"
                        : info
                          ? "border-emerald-200 bg-emerald-50/40 hover:bg-emerald-50"
                          : "border-slate-200 bg-white hover:bg-slate-50"
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <div className="text-xs font-bold text-slate-700">
                        {Number(slot.date.slice(-2))}
                      </div>
                      {info?.count ? (
                        <Badge variant="outline" className="text-[9px] h-4 px-2 border-emerald-200 text-emerald-700 bg-white">
                          {info.count}
                        </Badge>
                      ) : null}
                    </div>
                    <div className="mt-1 text-[10px] text-slate-500 font-medium">
                      {info?.firstIn ? new Date(info.firstIn).toLocaleTimeString("en-IN", { timeZone: "Asia/Kolkata", hour: "2-digit", minute: "2-digit" }) : "—"}
                      {" → "}
                      {info?.lastOut ? new Date(info.lastOut).toLocaleTimeString("en-IN", { timeZone: "Asia/Kolkata", hour: "2-digit", minute: "2-digit" }) : "—"}
                    </div>
                  </button>
                );
              })}
            </div>
          )}
        </div>

        <div className="lg:col-span-1">
          <div className="rounded-2xl border border-slate-200 bg-white p-4">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-xs font-bold text-slate-800">{selected}</div>
                <div className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">
                  Day punches
                </div>
              </div>
              <Clock className="w-4 h-4 text-slate-400" />
            </div>

            {day.isLoading ? (
              <div className="mt-3 space-y-2">
                <Skeleton className="h-5 w-full" />
                <Skeleton className="h-5 w-full" />
                <Skeleton className="h-5 w-full" />
              </div>
            ) : (
              <>
                <div className="mt-3 grid grid-cols-3 gap-2">
                  <div className="rounded-xl bg-slate-50 p-2 border border-slate-100">
                    <div className="text-[9px] text-slate-400 font-bold uppercase tracking-widest">First In</div>
                    <div className="text-xs font-bold text-slate-700">
                      {day.data?.summary.firstIn ? new Date(day.data.summary.firstIn).toLocaleTimeString("en-IN", { timeZone: "Asia/Kolkata", hour: "2-digit", minute: "2-digit" }) : "—"}
                    </div>
                  </div>
                  <div className="rounded-xl bg-slate-50 p-2 border border-slate-100">
                    <div className="text-[9px] text-slate-400 font-bold uppercase tracking-widest">Last Out</div>
                    <div className="text-xs font-bold text-slate-700">
                      {day.data?.summary.lastOut ? new Date(day.data.summary.lastOut).toLocaleTimeString("en-IN", { timeZone: "Asia/Kolkata", hour: "2-digit", minute: "2-digit" }) : "—"}
                    </div>
                  </div>
                  <div className="rounded-xl bg-slate-50 p-2 border border-slate-100">
                    <div className="text-[9px] text-slate-400 font-bold uppercase tracking-widest">Worked</div>
                    <div className="text-xs font-bold text-slate-700">
                      {minutesToHM(day.data?.summary.totalMinutes ?? 0)}
                    </div>
                  </div>
                </div>

                <div className="mt-3 flex flex-wrap gap-2">
                  {day.data?.summary.evaluation.isHalfDay ? (
                    <Badge variant="destructive" className="text-[10px]">
                      Half day (late after buffer)
                    </Badge>
                  ) : day.data?.summary.evaluation.isLate === false ? (
                    <Badge variant="secondary" className="text-[10px]">
                      On time
                    </Badge>
                  ) : null}
                  {day.data?.summary.evaluation.meetsPunchOut ? (
                    <Badge variant="outline" className="text-[10px] border-emerald-200 text-emerald-700">
                      Punch-out eligible
                    </Badge>
                  ) : day.data?.summary.evaluation.meetsPunchOut === false ? (
                    <Badge variant="outline" className="text-[10px] border-amber-200 text-amber-700">
                      Early punch-out
                    </Badge>
                  ) : null}
                </div>

                <div className="mt-3 space-y-2 max-h-[340px] overflow-auto pr-1">
                  {(day.data?.punches ?? []).length === 0 ? (
                    <div className="text-xs text-slate-400 italic">No punches stored for this day.</div>
                  ) : (
                    (day.data?.punches ?? []).map((p) => (
                      <div key={p.id} className="flex items-center justify-between rounded-xl border border-slate-100 bg-white px-3 py-2">
                        <div className="text-xs font-bold text-slate-700">
                          {new Date(p.punchAt).toLocaleTimeString("en-IN", { timeZone: "Asia/Kolkata", hour: "2-digit", minute: "2-digit", second: "2-digit" })}
                        </div>
                        <div className="text-[10px] text-slate-400 font-bold uppercase tracking-widest">
                          {p.punchType ?? p.source}
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

