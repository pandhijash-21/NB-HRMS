"use client";

import { useEffect, useMemo, useState } from "react";
import {
  useComputeSalary,
  useCreateSalaryRecord,
  useUpdateSalaryRecord,
  useFinalizeSalaryRecord,
  useSalaryTemplate,
  useSalaryRecords,
} from "@/lib/hooks/useSalary";
import { formatINR } from "@/lib/utils/currency";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { RotateCcw } from "lucide-react";
import api from "@/lib/axios";
import { useQuery } from "@tanstack/react-query";

type EmployeeOption = { id: number; fullName: string; designationId?: string };

export default function SalaryEntryPage() {
  const [employeeId, setEmployeeId] = useState("");
  const [month, setMonth] = useState(String(new Date().getMonth() + 1));
  const [year, setYear] = useState(String(new Date().getFullYear()));
  const [recordId, setRecordId] = useState<string | null>(null);
  const [overrides, setOverrides] = useState<Record<string, number>>({});

  const employeesQ = useQuery({
    queryKey: ["employees-search"],
    queryFn: async () => {
      const { data } = await api.get("employees", { params: { limit: 500 } });
      const list = data.data?.items ?? data.data?.employees ?? data.data ?? [];
      return list as Array<{ id: number; generalInfo?: { fullName: string; designationId?: string } }>;
    },
  });

  const profileQ = useQuery({
    queryKey: ["salary-profile", employeeId],
    queryFn: async () => {
      const { data } = await api.get(`salary/employees/${employeeId}/profile`);
      return data.data as {
        profile: { payCommissionType: "FIFTH" | "SIXTH"; designationId: string } | null;
      };
    },
    enabled: !!employeeId,
  });

  const payCommission = profileQ.data?.profile?.payCommissionType;
  const designationId = profileQ.data?.profile?.designationId
    ?? employeesQ.data?.find((e) => String(e.id) === employeeId)?.generalInfo?.designationId;

  const tpl = useSalaryTemplate(designationId ?? "", payCommission ?? "FIFTH");
  const templateId = tpl.data?.template?.id;

  const existingRecordQ = useSalaryRecords(
    employeeId
      ? {
          employeeId: Number(employeeId),
          salaryMonth: Number(month),
          salaryYear: Number(year),
        }
      : undefined,
  );

  useEffect(() => {
    if (!employeeId || existingRecordQ.isLoading) return;
    const records = existingRecordQ.data ?? [];
    const rec = records.find((r) => r.status === "DRAFT") ?? records[0] ?? null;
    if (rec) {
      setRecordId(rec.id);
      const loaded: Record<string, number> = {};
      for (const cv of rec.columnValues ?? []) {
        if (cv.overrideValue != null) {
          loaded[`${cv.category}::${cv.columnIdentifier}`] = Number(cv.overrideValue);
        }
      }
      setOverrides(loaded);
    } else {
      setRecordId(null);
      setOverrides({});
    }
  }, [employeeId, month, year, existingRecordQ.data, existingRecordQ.isLoading]);

  const compute = useComputeSalary();
  const createRecord = useCreateSalaryRecord();
  const updateRecord = useUpdateSalaryRecord();
  const finalize = useFinalizeSalaryRecord();

  useEffect(() => {
    if (!templateId) return;
    compute.mutate({ templateId, overrides });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [templateId, overrides]);

  const computed = compute.data;
  const columns = computed?.columns ?? [];

  const earnings = columns.filter((c) => c.category === "EARNING" && c.column_identifier !== "gross_pay");
  const deductions = columns.filter(
    (c) =>
      c.category === "DEDUCTION" &&
      c.column_identifier !== "net_pay" &&
      c.column_identifier !== "total_deductions",
  );

  const employeeOptions: EmployeeOption[] = useMemo(
    () =>
      (employeesQ.data ?? []).map((e) => ({
        id: e.id,
        fullName: e.generalInfo?.fullName ?? `Employee #${e.id}`,
        designationId: e.generalInfo?.designationId,
      })),
    [employeesQ.data],
  );

  const setOverride = (key: string, value: number) => {
    setOverrides((prev) => ({ ...prev, [key]: value }));
  };

  const resetOverride = (key: string) => {
    setOverrides((prev) => {
      const next = { ...prev };
      delete next[key];
      return next;
    });
  };

  const handleSaveDraft = async () => {
    if (recordId) {
      await updateRecord.mutateAsync({ id: recordId, overrides });
      return;
    }
    const rec = await createRecord.mutateAsync({
      employeeId: Number(employeeId),
      salaryMonth: Number(month),
      salaryYear: Number(year),
    });
    setRecordId(rec.id);
    if (Object.keys(overrides).length) {
      await updateRecord.mutateAsync({ id: rec.id, overrides });
    }
  };

  const handleFinalize = async () => {
    if (!recordId) await handleSaveDraft();
    const id = recordId ?? "";
    if (id) await finalize.mutateAsync(id);
  };

  const renderColumnInput = (col: (typeof columns)[0]) => {
    const key = `${col.category}::${col.column_identifier}`;
    const isOverridden = key in overrides || col.column_identifier in overrides;
    const val = overrides[key] ?? overrides[col.column_identifier] ?? col.effective_value;

    return (
      <div key={key} className="space-y-1">
        <Label className="text-xs">{col.column_identifier.replace(/_/g, " ")}</Label>
        <p className="text-[10px] text-slate-400">{col.formula_preview}</p>
        <div className="flex gap-1">
          <Input
            type="number"
            value={val}
            onChange={(e) => setOverride(key, Number(e.target.value))}
            className="h-9"
          />
          {isOverridden && (
            <Button type="button" variant="ghost" size="icon" onClick={() => resetOverride(key)}>
              <RotateCcw className="w-4 h-4" />
            </Button>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-bold text-slate-800">Salary Entry</h1>
        <p className="text-sm text-slate-500">Monthly salary with per-column overrides.</p>
      </div>

      <Card className="p-4 grid grid-cols-1 md:grid-cols-4 gap-3">
        <div className="space-y-1">
          <Label>Employee</Label>
          <Select value={employeeId} onValueChange={setEmployeeId}>
            <SelectTrigger><SelectValue placeholder="Select employee" /></SelectTrigger>
            <SelectContent className="max-h-60">
              {employeeOptions.map((e) => (
                <SelectItem key={e.id} value={String(e.id)}>{e.fullName} (#{e.id})</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1">
          <Label>Month</Label>
          <Input type="number" min={1} max={12} value={month} onChange={(e) => setMonth(e.target.value)} />
        </div>
        <div className="space-y-1">
          <Label>Year</Label>
          <Input type="number" value={year} onChange={(e) => setYear(e.target.value)} />
        </div>
        <div className="space-y-1">
          <Label>Pay Commission</Label>
          <p className="text-sm pt-2">{payCommission ?? "—"}</p>
        </div>
      </Card>

      {employeeId && !payCommission && (
        <p className="text-sm text-amber-600">Set pay commission on employee salary profile first.</p>
      )}

      {recordId && (
        <p className="text-sm text-slate-500">
          Editing existing draft record. Per-employee overrides are saved when you click Save Draft.
        </p>
      )}

      {templateId && computed && (
        <>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <Card className="p-4">
              <h2 className="font-semibold text-emerald-700 mb-3">Earnings</h2>
              <div className="grid gap-3">{earnings.map(renderColumnInput)}</div>
            </Card>
            <Card className="p-4">
              <h2 className="font-semibold text-rose-700 mb-3">Deductions</h2>
              <div className="grid gap-3">{deductions.map(renderColumnInput)}</div>
            </Card>
          </div>

          <Card className="p-4 flex flex-wrap gap-6 items-center justify-between">
            <div className="flex gap-6 text-sm">
              <span>Gross: <strong>{formatINR(computed.gross_pay)}</strong></span>
              <span>Deductions: <strong>{formatINR(computed.total_deductions)}</strong></span>
              <span>Net: <strong>{formatINR(computed.net_pay)}</strong></span>
            </div>
            <div className="flex gap-2">
              <Button variant="outline" onClick={handleSaveDraft} disabled={createRecord.isPending || updateRecord.isPending}>
                Save Draft
              </Button>
              <Button onClick={handleFinalize} disabled={finalize.isPending}>
                Finalize
              </Button>
            </div>
          </Card>
        </>
      )}
    </div>
  );
}
