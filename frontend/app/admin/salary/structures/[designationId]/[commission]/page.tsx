"use client";

import { use, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import {
  useSalaryTemplate,
  useUpsertColumnRule,
  useComputeSalary,
  useUpdateTemplateColumnVisibility,
} from "@/lib/hooks/useSalary";
import { formatINR } from "@/lib/utils/currency";
import { RuleEditorDrawer } from "@/components/salary/RuleEditorDrawer";
import { SimpleRuleDialog } from "@/components/salary/SimpleRuleDialog";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import type { SalaryColumnDefinition, SalaryColumnRule } from "@/lib/hooks/useSalary";
import api from "@/lib/axios";
import { useQuery } from "@tanstack/react-query";
import { useAuthReady } from "@/lib/hooks/useAuthReady";
import axios from "axios";

export default function SalaryStructureDetailPage({
  params,
}: {
  params: Promise<{ designationId: string; commission: string }>;
}) {
  const { designationId, commission } = use(params);
  const commissionCode = commission.toUpperCase();
  const authReady = useAuthReady();
  const tpl = useSalaryTemplate(designationId, commissionCode);
  const upsertRule = useUpsertColumnRule();
  const updateVisibility = useUpdateTemplateColumnVisibility();
  const [editing, setEditing] = useState<SalaryColumnDefinition | null>(null);
  const [columnVisibility, setColumnVisibility] = useState<Record<string, boolean>>({});

  const templateId = tpl.data?.template?.id;
  const ruleEditorEnabled = tpl.data?.payCommission?.ruleEditorEnabled ?? true;

  const rulesQ = useQuery({
    queryKey: ["salary", "rules", templateId],
    queryFn: async () => {
      if (!templateId) return [];
      const { data } = await api.get(`salary/templates/${templateId}/rules`);
      return data.data as SalaryColumnRule[];
    },
    enabled: authReady && !!templateId,
    retry: 1,
  });

  const rules = rulesQ.data ?? [];

  const ruleMap = useMemo(() => {
    const m = new Map<string, SalaryColumnRule>();
    for (const r of rules) m.set(`${r.category}::${r.columnIdentifier}`, r);
    return m;
  }, [rules]);

  const columns = tpl.data?.columnDefinitions ?? [];
  const earnings = columns.filter((c) => c.category === "EARNING");
  const deductions = columns.filter((c) => c.category === "DEDUCTION");

  const compute = useComputeSalary();

  useEffect(() => {
    if (tpl.data?.template?.columnVisibility) {
      setColumnVisibility(tpl.data.template.columnVisibility);
    } else if (templateId) {
      setColumnVisibility({});
    }
  }, [templateId, tpl.data?.template?.columnVisibility]);

  useEffect(() => {
    if (templateId && !rulesQ.isLoading) {
      compute.mutate({ templateId });
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [templateId, rules, rulesQ.isLoading]);

  const isVisibleToEmployee = (key: string) => columnVisibility[key] !== false;

  const toggleEmployeeVisibility = async (key: string, visible: boolean) => {
    if (!templateId) return;
    const next = { ...columnVisibility, [key]: visible };
    setColumnVisibility(next);
    try {
      await updateVisibility.mutateAsync({ templateId, columnVisibility: next });
    } catch {
      setColumnVisibility(columnVisibility);
    }
  };

  const computedValueMap = useMemo(() => {
    const m = new Map<string, { amount: number; formula: string }>();
    for (const c of compute.data?.columns ?? []) {
      m.set(`${c.category}::${c.column_identifier}`, {
        amount: c.rule_computed_value,
        formula: c.formula_preview,
      });
    }
    return m;
  }, [compute.data]);

  const saveRule = async (body: Record<string, unknown>) => {
    if (!editing || !templateId) return;
    await upsertRule.mutateAsync({
      templateId,
      columnIdentifier: editing.columnIdentifier,
      category: editing.category,
      body,
    });
    rulesQ.refetch();
    compute.mutate({ templateId });
    setEditing(null);
  };

  const renderTable = (items: SalaryColumnDefinition[]) => (
    <table className="w-full text-sm">
      <thead>
        <tr className="border-b text-left text-slate-500">
          <th className="py-2">Column</th>
          <th className="py-2">Rule</th>
          <th className="py-2">Formula</th>
          <th className="py-2 text-right">Amount</th>
          <th className="py-2 text-center w-28" title="Whether employees see this line on their profile">Employee view</th>
          <th className="py-2 w-20" />
        </tr>
      </thead>
      <tbody>
        {items.map((col) => {
          const key = `${col.category}::${col.columnIdentifier}`;
          const rule = ruleMap.get(key);
          const computed = computedValueMap.get(key);
          const isTotalRow =
            col.columnIdentifier === "gross_pay" ||
            col.columnIdentifier === "total_deductions" ||
            col.columnIdentifier === "net_pay";
          return (
            <tr key={`${col.category}-${col.columnIdentifier}`} className="border-b border-slate-100">
              <td className="py-2 font-medium">{col.displayName}</td>
              <td className="py-2">
                {rule ? (
                  <Badge>{rule.ruleType}</Badge>
                ) : isTotalRow ? (
                  <Badge variant="outline">Auto</Badge>
                ) : col.isRuleConfigurable ? (
                  <Badge variant="secondary">Not set</Badge>
                ) : (
                  <Badge variant="outline">Computed</Badge>
                )}
              </td>
              <td className="py-2 text-slate-500 text-xs max-w-xs">
                {rule?.formulaPreview ?? computed?.formula ?? (col.isRuleConfigurable ? "—" : "Auto")}
              </td>
              <td className="py-2 text-right font-mono tabular-nums">
                {compute.isPending ? (
                  <span className="text-slate-400">…</span>
                ) : (
                  <span className={isTotalRow ? "font-semibold" : ""}>
                    {formatINR(computed?.amount ?? 0)}
                  </span>
                )}
              </td>
              <td className="py-2 text-center">
                <div className="flex flex-col items-center gap-0.5">
                  <Switch
                    checked={isVisibleToEmployee(key)}
                    onCheckedChange={(v) => toggleEmployeeVisibility(key, v)}
                    disabled={updateVisibility.isPending}
                    aria-label={`Show ${col.displayName} to employees`}
                  />
                  <span className="text-[9px] text-slate-400">
                    {isVisibleToEmployee(key) ? "Shown" : "Hidden"}
                  </span>
                </div>
              </td>
              <td className="py-2">
                {col.isRuleConfigurable && templateId && (
                  <Button size="sm" variant="ghost" onClick={() => setEditing(col)}>
                    {ruleEditorEnabled ? "Edit" : "Set amount"}
                  </Button>
                )}
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );

  const commissionLabel = tpl.data?.payCommission?.name ?? commissionCode;

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3 flex-wrap">
        <Link href="/admin/salary/structures" className="text-sm text-slate-500 hover:text-slate-800">← Structures</Link>
        <h1 className="text-xl font-bold text-slate-800">
          {commissionLabel} — {tpl.data?.designation?.name ?? tpl.data?.template?.designation?.name ?? "…"}
        </h1>
        {!ruleEditorEnabled && (
          <Badge variant="secondary">Fixed amounts only — rule editor disabled for this commission</Badge>
        )}
      </div>

      {tpl.isError && (
        <Card className="p-4 border-rose-200 bg-rose-50">
          <p className="text-sm text-rose-700">
            {axios.isAxiosError(tpl.error)
              ? (tpl.error.response?.data as { message?: string })?.message ?? "Failed to load template."
              : "Failed to load template."}
          </p>
        </Card>
      )}

      {!templateId && tpl.isLoading && <p className="text-sm text-slate-500">Loading…</p>}
      {!templateId && !tpl.isLoading && !tpl.isError && (
        <p className="text-sm text-rose-500">No template found. Go back and click Configure to create one.</p>
      )}

      {templateId && (
        <>
          <Card className="p-4 bg-blue-50/50 border-blue-100">
            <p className="text-xs text-slate-600">
              Use <strong>Employee view</strong> to show or hide each column on the employee portal salary tab.
              Hidden columns are still calculated in gross and net pay — employees simply do not see those line items.
            </p>
          </Card>
          <Card className="p-4">
            <h2 className="font-semibold text-emerald-700 mb-3">Earnings</h2>
            {renderTable(earnings)}
          </Card>
          <Card className="p-4">
            <h2 className="font-semibold text-rose-700 mb-3">Deductions</h2>
            {renderTable(deductions)}
          </Card>

          <Card className="p-4 bg-slate-50">
            <h2 className="font-semibold text-slate-800 mb-2">Pay Summary Preview</h2>
            {compute.isPending && <p className="text-sm text-slate-500">Calculating…</p>}
            {compute.data && (
              <div className="flex flex-wrap gap-6 text-sm">
                <div>
                  <span className="text-slate-500">Gross Pay</span>
                  <p className="text-lg font-semibold text-emerald-700">{formatINR(compute.data.gross_pay)}</p>
                </div>
                <div>
                  <span className="text-slate-500">Total Deductions</span>
                  <p className="text-lg font-semibold text-rose-700">{formatINR(compute.data.total_deductions)}</p>
                </div>
                <div>
                  <span className="text-slate-500">Net Pay</span>
                  <p className="text-lg font-bold text-slate-900">{formatINR(compute.data.net_pay)}</p>
                </div>
              </div>
            )}
          </Card>
        </>
      )}

      {editing && templateId && ruleEditorEnabled && (
        <RuleEditorDrawer
          open={!!editing}
          onOpenChange={(o) => !o && setEditing(null)}
          column={editing}
          existingRule={ruleMap.get(`${editing.category}::${editing.columnIdentifier}`)}
          allColumns={columns}
          onSave={saveRule}
        />
      )}

      {editing && templateId && !ruleEditorEnabled && (
        <SimpleRuleDialog
          open={!!editing}
          onOpenChange={(o) => !o && setEditing(null)}
          column={editing}
          defaultValue={
            ruleMap.get(`${editing.category}::${editing.columnIdentifier}`)?.fixedDefaultValue
              ? Number(ruleMap.get(`${editing.category}::${editing.columnIdentifier}`)!.fixedDefaultValue)
              : computedValueMap.get(`${editing.category}::${editing.columnIdentifier}`)?.amount
          }
          onSave={saveRule}
        />
      )}
    </div>
  );
}
