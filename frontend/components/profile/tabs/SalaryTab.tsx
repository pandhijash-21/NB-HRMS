"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from "@/components/ui/select";
import { RotateCcw, Pencil, Shield, User } from "lucide-react";
import api from "@/lib/axios";
import { formatINR } from "@/lib/utils/currency";
import {
  useEmployeeSalaryPreview,
  useUpdateEmployeePayCommission,
  useSalaryComputeLive,
  usePayCommissions,
  type SalaryColumnDefinition,
  type SalaryColumnRule,
} from "@/lib/hooks/useSalary";
import { useAuthReady } from "@/lib/hooks/useAuthReady";
import { RuleEditorDrawer } from "@/components/salary/RuleEditorDrawer";
import { employeeRuleBodyToColumnRule } from "@/lib/salary/employeeRules";

interface SalaryTabProps {
  employee: Record<string, unknown>;
  isAdmin?: boolean;
}

const TOTAL_ROWS = new Set(["gross_pay", "total_deductions", "net_pay"]);

function Field({ label, value }: { label: string; value?: string | number | null }) {
  return (
    <div>
      <p className="text-xs text-slate-500 mb-0.5">{label}</p>
      <p className="text-sm font-medium text-slate-800">{value || "—"}</p>
    </div>
  );
}

function SummaryCard({
  label,
  value,
  tone,
}: {
  label: string;
  value: number;
  tone: "emerald" | "rose" | "slate";
}) {
  const tones = {
    emerald: "border-emerald-200 bg-emerald-50 text-emerald-800",
    rose: "border-rose-200 bg-rose-50 text-rose-800",
    slate: "border-slate-200 bg-slate-50 text-slate-900",
  };
  return (
    <div className={`rounded-xl border px-4 py-3 ${tones[tone]}`}>
      <p className="text-xs font-medium opacity-80">{label}</p>
      <p className="text-lg font-bold tabular-nums mt-0.5">{formatINR(value)}</p>
    </div>
  );
}

export function SalaryTab({ employee, isAdmin }: SalaryTabProps) {
  const [editingCommission, setEditingCommission] = useState(false);
  const [overrides, setOverrides] = useState<Record<string, number>>({});
  const [employeeColumnRules, setEmployeeColumnRules] = useState<Record<string, Record<string, unknown>>>({});
  const [dirty, setDirty] = useState(false);
  const [editingColumn, setEditingColumn] = useState<SalaryColumnDefinition | null>(null);
  const employeeId = Number(employee.id);
  const employeeName = String(employee.fullName ?? employee.name ?? `Employee #${employeeId}`);
  const authReady = useAuthReady();

  const profileQ = useQuery({
    queryKey: ["salary-profile", employeeId],
    queryFn: async () => {
      const { data } = await api.get(`salary/employees/${employeeId}/profile`);
      return data.data as {
        profile: {
          payCommission: string | null;
          payCommissionRef?: { code: string; name: string } | null;
        } | null;
        latestFinalizedRecord: {
          id: string;
          salaryMonth: number;
          salaryYear: number;
          grossPay: string;
          netPay: string;
        } | null;
      };
    },
    enabled: authReady && Number.isFinite(employeeId),
  });

  const previewQ = useEmployeeSalaryPreview(employeeId);
  const commissionsQ = usePayCommissions();
  const updateProfile = useUpdateEmployeePayCommission();
  const activeCommissions = (commissionsQ.data ?? []).filter((c) => c.isActive);

  const templateId = previewQ.data?.templateId ?? null;
  const columnDefinitions = previewQ.data?.columnDefinitions ?? [];

  useEffect(() => {
    if (!previewQ.data) return;
    setOverrides(previewQ.data.columnOverrides ?? {});
    setEmployeeColumnRules(previewQ.data.employeeColumnRules ?? {});
    setDirty(false);
  }, [previewQ.data?.columnOverrides, previewQ.data?.employeeColumnRules, previewQ.data?.payCommissionCode]);

  const computeQ = useSalaryComputeLive({
    templateId: isAdmin ? templateId : null,
    employeeId,
    overrides: isAdmin ? overrides : {},
    employeeRules: isAdmin ? employeeColumnRules : {},
  });

  const computed = computeQ.data ?? previewQ.data?.computed;

  const templateRuleMap = useMemo(() => {
    const m = new Map<string, SalaryColumnRule>();
    for (const r of previewQ.data?.templateRules ?? []) {
      m.set(`${r.category}::${r.columnIdentifier}`, r);
    }
    return m;
  }, [previewQ.data?.templateRules]);

  const computedByKey = useMemo(() => {
    const m = new Map<string, NonNullable<typeof computed>["columns"][0]>();
    for (const c of computed?.columns ?? []) m.set(`${c.category}::${c.column_identifier}`, c);
    return m;
  }, [computed]);

  const profile = profileQ.data?.profile;
  const latest = profileQ.data?.latestFinalizedRecord;
  const preview = previewQ.data;

  const customizationCount =
    Object.keys(employeeColumnRules).length + Object.keys(overrides).length;

  const setOverride = (key: string, value: number) => {
    setOverrides((prev) => ({ ...prev, [key]: value }));
    setDirty(true);
  };

  const resetOverride = (key: string) => {
    setOverrides((prev) => {
      const next = { ...prev };
      delete next[key];
      return next;
    });
    setDirty(true);
  };

  const persistEmployeeRules = async (rules: Record<string, Record<string, unknown>>) => {
    await updateProfile.mutateAsync({
      employeeId,
      columnRules: Object.keys(rules).length ? rules : null,
    });
    previewQ.refetch();
  };

  const resetEmployeeRule = async (key: string) => {
    const next = { ...employeeColumnRules };
    delete next[key];
    setEmployeeColumnRules(next);
    setDirty(true);
    await persistEmployeeRules(next);
  };

  const handleSaveAll = async () => {
    await updateProfile.mutateAsync({
      employeeId,
      columnOverrides: Object.keys(overrides).length ? overrides : null,
      columnRules: Object.keys(employeeColumnRules).length ? employeeColumnRules : null,
    });
    setDirty(false);
    previewQ.refetch();
  };

  const handleCommissionChange = async (v: string) => {
    await updateProfile.mutateAsync({
      employeeId,
      payCommissionCode: v,
      columnOverrides: null,
      columnRules: null,
    });
    setOverrides({});
    setEmployeeColumnRules({});
    setDirty(false);
    setEditingCommission(false);
    previewQ.refetch();
  };

  const getEffectiveRule = (key: string): SalaryColumnRule | undefined => {
    const custom = employeeColumnRules[key];
    if (custom) return employeeRuleBodyToColumnRule(key, custom);
    return templateRuleMap.get(key);
  };

  const handleSaveEmployeeRule = async (body: Record<string, unknown>) => {
    if (!editingColumn) return;
    const key = `${editingColumn.category}::${editingColumn.columnIdentifier}`;
    const nextRules = { ...employeeColumnRules, [key]: body };
    const clearedOverrides = { ...overrides };
    delete clearedOverrides[key];
    setEmployeeColumnRules(nextRules);
    setOverrides(clearedOverrides);
    setDirty(Object.keys(clearedOverrides).length > 0);
    await updateProfile.mutateAsync({
      employeeId,
      columnRules: nextRules,
      columnOverrides: Object.keys(clearedOverrides).length ? clearedOverrides : null,
    });
    setEditingColumn(null);
    previewQ.refetch();
  };

  const renderSection = (
    title: string,
    items: SalaryColumnDefinition[],
    accent: "emerald" | "rose",
  ) => {
    const accentCls = accent === "emerald" ? "text-emerald-700" : "text-rose-700";
    const headerBg = accent === "emerald" ? "bg-emerald-50/80" : "bg-rose-50/80";

    return (
      <div className="rounded-xl border border-slate-200 overflow-hidden">
        <div className={`px-4 py-2.5 border-b border-slate-200 ${headerBg}`}>
          <h4 className={`text-xs font-semibold uppercase tracking-wide ${accentCls}`}>{title}</h4>
        </div>
        <div className="overflow-x-auto">
          <table className={`w-full text-sm ${isAdmin ? "min-w-[520px]" : "min-w-[280px]"}`}>
            <thead>
              <tr className="border-b border-slate-100 text-left text-[11px] uppercase tracking-wide text-slate-400">
                <th className="px-4 py-2 font-medium">Column</th>
                {isAdmin && <th className="px-2 py-2 font-medium w-24">Source</th>}
                {isAdmin && <th className="px-2 py-2 font-medium">Formula</th>}
                <th className="px-4 py-2 font-medium text-right w-36">Amount</th>
                {isAdmin && <th className="px-2 py-2 w-20" />}
              </tr>
            </thead>
            <tbody>
              {items.map((col) => {
                const key = `${col.category}::${col.columnIdentifier}`;
                const row = computedByKey.get(key);
                const rule = getEffectiveRule(key);
                const hasCustomRule = !!employeeColumnRules[key];
                const hasOverride = key in overrides;
                const isTotal = TOTAL_ROWS.has(col.columnIdentifier);
                const canEditAmount = isAdmin && !isTotal;
                const canEditRule = isAdmin && col.isRuleConfigurable;
                const displayAmount = row?.effective_value ?? 0;
                const formula = rule?.formulaPreview ?? row?.formula_preview ?? "—";

                return (
                  <tr
                    key={key}
                    className={`border-b border-slate-50 last:border-0 hover:bg-slate-50/50 ${
                      isTotal ? "bg-slate-50/90" : ""
                    } ${isAdmin && hasCustomRule ? "border-l-2 border-l-blue-400" : isAdmin && hasOverride ? "border-l-2 border-l-amber-400" : ""}`}
                  >
                    <td className="px-4 py-2.5">
                      <span className={`${isTotal ? "font-semibold text-slate-900" : "font-medium text-slate-800"}`}>
                        {col.displayName}
                      </span>
                    </td>
                    {isAdmin && (
                      <td className="px-2 py-2.5">
                        {hasCustomRule ? (
                          <Badge className="bg-blue-100 text-blue-800 hover:bg-blue-100 text-[10px]">Employee</Badge>
                        ) : hasOverride ? (
                          <Badge className="bg-amber-100 text-amber-800 hover:bg-amber-100 text-[10px]">Override</Badge>
                        ) : rule ? (
                          <Badge variant="secondary" className="text-[10px]">Default</Badge>
                        ) : (
                          <Badge variant="outline" className="text-[10px]">{isTotal ? "Auto" : "—"}</Badge>
                        )}
                      </td>
                    )}
                    {isAdmin && (
                      <td className="px-2 py-2.5 text-xs text-slate-500 max-w-[220px]" title={formula}>
                        <span className="line-clamp-2">{formula}</span>
                      </td>
                    )}
                    <td className="px-4 py-2.5 text-right">
                      {canEditAmount ? (
                        <div className="flex items-center justify-end gap-1">
                          <Input
                            type="number"
                            value={hasOverride ? overrides[key] : displayAmount}
                            onChange={(e) => setOverride(key, Number(e.target.value))}
                            className={`h-8 w-32 text-right font-mono text-sm ${
                              hasOverride ? "ring-1 ring-amber-300 bg-amber-50/50" : ""
                            }`}
                          />
                          {hasOverride && (
                            <Button
                              type="button"
                              variant="ghost"
                              size="icon"
                              className="h-8 w-8 shrink-0"
                              onClick={() => resetOverride(key)}
                              title="Revert to calculated amount"
                            >
                              <RotateCcw className="w-3.5 h-3.5" />
                            </Button>
                          )}
                        </div>
                      ) : (
                        <span className={`font-mono tabular-nums text-sm ${isTotal ? "font-bold" : ""}`}>
                          {computeQ.isFetching && !row ? "…" : formatINR(displayAmount)}
                        </span>
                      )}
                    </td>
                    {isAdmin && (
                      <td className="px-2 py-2.5">
                        {canEditRule && (
                          <div className="flex justify-end gap-0.5">
                            <Button
                              type="button"
                              variant="ghost"
                              size="icon"
                              className="h-8 w-8 text-slate-500 hover:text-[#1d3459]"
                              onClick={() => setEditingColumn(col)}
                              title="Custom rule for this employee only"
                            >
                              <Pencil className="w-3.5 h-3.5" />
                            </Button>
                            {hasCustomRule && (
                              <Button
                                type="button"
                                variant="ghost"
                                size="icon"
                                className="h-8 w-8 text-slate-400"
                                onClick={() => resetEmployeeRule(key)}
                                title="Remove employee rule — use designation default"
                              >
                                <RotateCcw className="w-3.5 h-3.5" />
                              </Button>
                            )}
                          </div>
                        )}
                      </td>
                    )}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    );
  };

  const columnVisibility = preview?.columnVisibility ?? {};
  const filterForEmployeeView = (items: SalaryColumnDefinition[]) => {
    if (isAdmin) return items;
    return items.filter((col) => {
      const key = `${col.category}::${col.columnIdentifier}`;
      return columnVisibility[key] !== false;
    });
  };

  const earnings = filterForEmployeeView(
    columnDefinitions.filter((c) => c.category === "EARNING"),
  );
  const deductions = filterForEmployeeView(
    columnDefinitions.filter((c) => c.category === "DEDUCTION"),
  );

  if (profileQ.isLoading || previewQ.isLoading) {
    return <p className="text-sm text-slate-500 p-4">Loading salary…</p>;
  }

  return (
    <div className="space-y-4">
      {!isAdmin && (
        <div className="flex items-start gap-3 rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-700">
          <Shield className="w-5 h-5 shrink-0 mt-0.5 text-slate-500" />
          <div>
            <p className="font-medium">View only</p>
            <p className="text-xs text-slate-500 mt-0.5">
              In case of any disperancies, please contact admin department.
            </p>
          </div>
        </div>
      )}

      {isAdmin && preview?.configured && (
        <div className="flex items-start gap-3 rounded-xl border border-blue-200 bg-blue-50/80 px-4 py-3 text-sm text-blue-900">
          <Shield className="w-5 h-5 shrink-0 mt-0.5 text-blue-600" />
          <div>
            <p className="font-medium">Employee-specific salary only</p>
            <p className="text-xs text-blue-800/90 mt-0.5">
              Changes on this page are saved to <strong>{employeeName}</strong> only.
              Designation rules in <Link href="/admin/salary/structures" className="underline font-medium">Salary Structures</Link> are never modified.
            </p>
          </div>
        </div>
      )}

      <Card>
        <CardContent className="pt-5 space-y-4">
          <div className="flex justify-between items-center flex-wrap gap-2">
            <div className="flex items-center gap-2">
              <User className="w-4 h-4 text-slate-400" />
              <h3 className="text-sm font-semibold text-slate-700">Salary Information</h3>
            </div>
            {isAdmin && !editingCommission && (
              <Button
                size="sm"
                variant="outline"
                onClick={() => setEditingCommission(true)}
                className="text-xs"
              >
                Edit Commission
              </Button>
            )}
          </div>

          {editingCommission ? (
            <div className="space-y-2 max-w-xs">
              <Label>Pay Commission</Label>
              <Select
                defaultValue={
                  profile?.payCommissionRef?.code
                  ?? preview?.payCommissionCode
                  ?? ""
                }
                onValueChange={handleCommissionChange}
              >
                <SelectTrigger><SelectValue placeholder="Select" /></SelectTrigger>
                <SelectContent>
                  {activeCommissions.map((c) => (
                    <SelectItem key={c.id} value={c.code}>{c.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <Button size="sm" variant="ghost" onClick={() => setEditingCommission(false)}>Cancel</Button>
            </div>
          ) : (
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
              <Field
                label="Pay Commission"
                value={
                  profile?.payCommissionRef?.name
                  ?? preview?.payCommission?.name
                  ?? (employee.payCommission as string)
                }
              />
              <Field label="Designation" value={preview?.designation?.name ?? (employee.designation as string)} />
              {latest && (
                <>
                  <Field label="Latest Finalized" value={`${latest.salaryMonth}/${latest.salaryYear}`} />
                  <Field label="Net Pay (Latest)" value={formatINR(latest.netPay)} />
                </>
              )}
            </div>
          )}

          {latest && isAdmin && !editingCommission && (
            <Link href={`/admin/salary/records/${latest.id}/slip`}>
              <Button size="sm" variant="outline">View Latest Salary Slip</Button>
            </Link>
          )}
        </CardContent>
      </Card>

      {!editingCommission && preview && !preview.configured && (
        <Card>
          <CardContent className="pt-5">
            <p className="text-sm text-amber-700">
              {preview.reason === "NO_COMMISSION" && "Set a pay commission above to see salary breakdown."}
              {preview.reason === "NO_DESIGNATION" && "Employee designation is required before salary can be calculated."}
              {preview.reason === "NO_TEMPLATE" && `No salary structure template for ${preview.designation?.name ?? "this designation"}.`}
              {preview.reason === "NO_RULES" && "Salary structure exists but no rules are configured yet."}
            </p>
            {isAdmin && preview.reason === "NO_RULES" && preview.templateId && (
              <Link href={`/admin/salary/structures/${preview.designation?.id}/${(preview.payCommissionCode ?? "fifth").toLowerCase()}`}>
                <Button size="sm" className="mt-3">Configure Designation Rules</Button>
              </Link>
            )}
          </CardContent>
        </Card>
      )}

      {!editingCommission && preview?.configured && computed && (
        <div className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <SummaryCard label="Gross Pay" value={computed.gross_pay} tone="emerald" />
            <SummaryCard label="Total Deductions" value={computed.total_deductions} tone="rose" />
            <SummaryCard label="Net Pay" value={computed.net_pay} tone="slate" />
          </div>

          <Card className="overflow-hidden">
            <CardContent className="pt-5 space-y-4 pb-4">
              <div className="flex justify-between items-start flex-wrap gap-3">
                <div>
                  <h3 className="text-sm font-semibold text-slate-800">Salary Breakdown</h3>
                  <p className="text-xs text-slate-500 mt-1">
                    {isAdmin
                      ? (computeQ.isFetching ? "Recalculating dependent columns…" : "Amounts update automatically when you edit a value.")
                      : "Your monthly salary breakdown as configured by the institution."}
                    {isAdmin && customizationCount > 0 && (
                      <span className="text-blue-700"> · {customizationCount} employee customization(s)</span>
                    )}
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-1 gap-4">
                {renderSection("Earnings", earnings, "emerald")}
                {renderSection("Deductions", deductions, "rose")}
              </div>

              {isAdmin && (
                <div className="flex flex-wrap gap-4 text-xs text-slate-500 pt-2 border-t">
                  <span className="flex items-center gap-1.5"><span className="w-2 h-2 rounded-full bg-blue-400" /> Employee custom rule</span>
                  <span className="flex items-center gap-1.5"><span className="w-2 h-2 rounded-full bg-amber-400" /> Amount override</span>
                  <span className="flex items-center gap-1.5"><Badge variant="secondary" className="text-[9px] py-0">Default</Badge> From designation structure</span>
                </div>
              )}
            </CardContent>
          </Card>

          {isAdmin && dirty && (
            <div className="sticky bottom-4 z-10 flex justify-end">
              <div className="flex items-center gap-3 rounded-xl border border-slate-200 bg-white shadow-lg px-4 py-3">
                <span className="text-sm text-slate-600">Unsaved changes for this employee</span>
                <Button size="sm" onClick={handleSaveAll} disabled={updateProfile.isPending}>
                  {updateProfile.isPending ? "Saving…" : "Save for this employee"}
                </Button>
              </div>
            </div>
          )}
        </div>
      )}

      {editingColumn && (
        <RuleEditorDrawer
          open={!!editingColumn}
          onOpenChange={(o) => !o && setEditingColumn(null)}
          column={editingColumn}
          existingRule={getEffectiveRule(`${editingColumn.category}::${editingColumn.columnIdentifier}`)}
          allColumns={columnDefinitions}
          onSave={handleSaveEmployeeRule}
          employeeMode
          employeeLabel={employeeName}
        />
      )}
    </div>
  );
}
