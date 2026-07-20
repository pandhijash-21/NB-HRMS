"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { useEmployeeSalaryMonthlyOverview } from "@/lib/hooks/useSalary";
import { formatINR } from "@/lib/utils/currency";
import { ChevronLeft, ChevronRight, Download } from "lucide-react";

const MONTH_LABELS = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

interface SalaryMonthlySectionProps {
  employeeId: number;
  isAdmin?: boolean;
}

export function SalaryMonthlySection({ employeeId, isAdmin = false }: SalaryMonthlySectionProps) {
  const now = new Date();
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);

  const overviewQ = useEmployeeSalaryMonthlyOverview({ employeeId, year, month });

  const futureMonth = useMemo(() => {
    const ist = new Date(Date.now() + 330 * 60 * 1000);
    const cy = ist.getUTCFullYear();
    const cm = ist.getUTCMonth() + 1;
    return (y: number, m: number) => y > cy || (y === cy && m > cm);
  }, []);

  const attendance = overviewQ.data?.attendance;
  const salaryRecord = overviewQ.data?.salaryRecord;
  const leaveBalances = overviewQ.data?.leaveBalances ?? [];

  const slipHref = salaryRecord?.canDownloadSlip
    ? isAdmin
      ? `/admin/salary/records/${salaryRecord.id}/slip`
      : `/profile/salary-slip/${salaryRecord.id}?employeeId=${employeeId}`
    : null;

  return (
    <Card className="border-slate-200/60 shadow-sm">
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-bold text-slate-800">Monthly records</CardTitle>
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

        {overviewQ.isLoading ? (
          <Skeleton className="h-32 w-full" />
        ) : overviewQ.isError ? (
          <p className="text-sm text-rose-600">Could not load monthly summary.</p>
        ) : (
          <div className="space-y-4 rounded-xl border border-slate-200 p-4">
            <div>
              <p className="text-xs font-bold uppercase tracking-widest text-slate-400 mb-2">Attendance</p>
              {attendance ? (
                <div className="flex flex-wrap gap-2">
                  <Badge variant="secondary">Present: {attendance.presentDays} days</Badge>
                  <Badge variant="secondary">Working hours: {attendance.totalWorkingHours}h</Badge>
                  <Badge variant="secondary">Late: {attendance.lateDays}</Badge>
                  <Badge variant="secondary">Leave: {attendance.leaveDaysInMonth}</Badge>
                </div>
              ) : (
                <p className="text-sm text-slate-500">No attendance data.</p>
              )}
            </div>

            {leaveBalances.length > 0 && (
              <div>
                <p className="text-xs font-bold uppercase tracking-widest text-slate-400 mb-2">Leave balances</p>
                <div className="space-y-1">
                  {leaveBalances.map((b) => (
                    <p key={b.leaveType.code} className="text-sm font-medium text-slate-700">
                      {b.leaveType.name}: {b.available} remaining
                    </p>
                  ))}
                </div>
              </div>
            )}

            <div>
              <p className="text-xs font-bold uppercase tracking-widest text-slate-400 mb-2">Salary</p>
              {!salaryRecord ? (
                <p className="text-sm text-slate-500">No salary record for this month yet.</p>
              ) : (
                <div className="space-y-1 text-sm">
                  <div className="flex justify-between gap-4">
                    <span className="text-slate-500">Status</span>
                    <span className="font-semibold text-slate-800">{salaryRecord.status}</span>
                  </div>
                  <div className="flex justify-between gap-4">
                    <span className="text-slate-500">Gross pay</span>
                    <span className="font-semibold text-slate-800">{formatINR(salaryRecord.grossPay)}</span>
                  </div>
                  <div className="flex justify-between gap-4">
                    <span className="text-slate-500">Deductions</span>
                    <span className="font-semibold text-slate-800">{formatINR(salaryRecord.totalDeductions)}</span>
                  </div>
                  <div className="flex justify-between gap-4">
                    <span className="text-slate-500">Net pay</span>
                    <span className="font-bold text-slate-900">{formatINR(salaryRecord.netPay)}</span>
                  </div>
                  {slipHref && (
                    <Button size="sm" className="mt-3 gap-1.5" asChild>
                      <Link href={slipHref}>
                        <Download className="w-4 h-4" /> Download salary slip
                      </Link>
                    </Button>
                  )}
                </div>
              )}
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
