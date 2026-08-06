"use client";

import { useState } from "react";
import Link from "next/link";
import { useSalaryRecords } from "@/lib/hooks/useSalary";
import { formatINR } from "@/lib/utils/currency";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

export default function SalaryRecordsPage() {
  const [employeeId, setEmployeeId] = useState("");
  const [month, setMonth] = useState("");
  const [year, setYear] = useState("");
  const [status, setStatus] = useState("");

  const filters: Record<string, string | number | undefined> = {};
  if (employeeId) filters.employeeId = Number(employeeId);
  if (month) filters.salaryMonth = Number(month);
  if (year) filters.salaryYear = Number(year);
  if (status) filters.status = status;

  const { data, isLoading } = useSalaryRecords(filters);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-bold text-slate-800">Salary Records</h1>
        <p className="text-sm text-slate-500">View and manage monthly salary records.</p>
      </div>

      <Card className="p-4 grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="space-y-1">
          <Label>Employee ID</Label>
          <Input value={employeeId} onChange={(e) => setEmployeeId(e.target.value)} />
        </div>
        <div className="space-y-1">
          <Label>Month</Label>
          <Input value={month} onChange={(e) => setMonth(e.target.value)} />
        </div>
        <div className="space-y-1">
          <Label>Year</Label>
          <Input value={year} onChange={(e) => setYear(e.target.value)} />
        </div>
        <div className="space-y-1">
          <Label>Status</Label>
          <Select value={status || "all"} onValueChange={(v) => setStatus(v === "all" ? "" : v)}>
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All</SelectItem>
              <SelectItem value="DRAFT">Draft</SelectItem>
              <SelectItem value="FINALIZED">Finalized</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </Card>

      <Card className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b bg-slate-50 text-left">
              <th className="p-3">Employee</th>
              <th className="p-3">Designation</th>
              <th className="p-3">Commission</th>
              <th className="p-3">Month</th>
              <th className="p-3">Gross</th>
              <th className="p-3">Net</th>
              <th className="p-3">Status</th>
              <th className="p-3">Actions</th>
            </tr>
          </thead>
          <tbody>
            {isLoading && (
              <tr><td colSpan={8} className="p-4 text-slate-500">Loading…</td></tr>
            )}
            {(data ?? []).map((r) => (
              <tr key={r.id} className="border-b">
                <td className="p-3">{r.employee?.generalInfo?.fullName ?? `#${r.employeeId}`}</td>
                <td className="p-3">{r.template?.designation?.name ?? "—"}</td>
                <td className="p-3">{r.payCommissionCode}</td>
                <td className="p-3">{r.salaryMonth}/{r.salaryYear}</td>
                <td className="p-3">{formatINR(r.grossPay)}</td>
                <td className="p-3">{formatINR(r.netPay)}</td>
                <td className="p-3">
                  <Badge variant={r.status === "FINALIZED" ? "default" : "secondary"}>{r.status}</Badge>
                </td>
                <td className="p-3 flex gap-2">
                  <Link href={`/admin/salary/records/${r.id}/slip`}>
                    <Button size="sm" variant="outline">Slip</Button>
                  </Link>
                  {r.status === "DRAFT" && (
                    <Link href={`/admin/salary/entry?recordId=${r.id}`}>
                      <Button size="sm" variant="ghost">Edit</Button>
                    </Link>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  );
}
