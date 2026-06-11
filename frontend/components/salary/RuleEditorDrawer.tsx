"use client";

import { useEffect, useMemo, useState } from "react";
import { Sheet, SheetContent, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Plus, Trash2 } from "lucide-react";
import type { SalaryColumnDefinition, SalaryColumnRule } from "@/lib/hooks/useSalary";
import {
  buildReferenceOptions,
  buildPriorColumnOptions,
  isEarningsMirrorDeduction,
  refsFromCondition,
  type ReferenceOption,
} from "@/lib/salary/referenceColumns";

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  column: SalaryColumnDefinition;
  existingRule?: SalaryColumnRule;
  allColumns: SalaryColumnDefinition[];
  onSave: (body: Record<string, unknown>) => Promise<void>;
  /** When true, rule is saved on the employee profile only (not the designation template). */
  employeeMode?: boolean;
  employeeLabel?: string;
};

type UiRuleType = "FIXED" | "SUM" | "PERCENTAGE" | "CONDITIONAL";

const COMPARATORS = [
  { value: "GREATER_THAN", label: ">" },
  { value: "LESS_THAN", label: "<" },
  { value: "GREATER_THAN_OR_EQUAL", label: "≥" },
  { value: "LESS_THAN_OR_EQUAL", label: "≤" },
  { value: "EQUAL", label: "=" },
];

type ConditionRow = {
  comparator: string;
  reference_column_identifier: string;
  threshold_value: number;
  result_type: "FIXED_AMOUNT" | "PERCENTAGE_OF_COLUMN";
  result_value: number;
  result_reference_column_identifier: string | null;
  result_reference_columns: Array<{ column_identifier: string; weight: number }>;
  sort_order: number;
  is_else_fallback: boolean;
};

function columnLabel(allColumns: SalaryColumnDefinition[], refKey: string, options?: ReferenceOption[]) {
  const fromOpt = options?.find((o) => o.key === refKey)?.label;
  if (fromOpt) return fromOpt;
  const bare = refKey.includes("::") ? refKey.split("::")[1] : refKey;
  return allColumns.find((c) => c.columnIdentifier === bare)?.displayName ?? bare;
}

function comparatorSymbol(comparator: string) {
  return COMPARATORS.find((c) => c.value === comparator)?.label ?? comparator;
}

function formatPayAmount(
  cond: Pick<ConditionRow, "result_type" | "result_value" | "result_reference_columns">,
  allColumns: SalaryColumnDefinition[],
  options: ReferenceOption[],
) {
  if (cond.result_type === "FIXED_AMOUNT") {
    return `₹${cond.result_value}`;
  }
  const parts = cond.result_reference_columns.map((r) => columnLabel(allColumns, r.column_identifier, options));
  const base = parts.length > 1 ? `(${parts.join(" + ")})` : parts[0] ?? "";
  return `${cond.result_value}% of ${base}`;
}

function buildConditionalPreview(
  conditions: ConditionRow[],
  allColumns: SalaryColumnDefinition[],
  options: ReferenceOption[],
) {
  const sorted = [...conditions].sort((a, b) => a.sort_order - b.sort_order);
  const parts = sorted.map((c) => {
    if (c.is_else_fallback) {
      return `Else → ${formatPayAmount(c, allColumns, options)}`;
    }
    const col = columnLabel(allColumns, c.reference_column_identifier, options);
    return `If ${col} ${comparatorSymbol(c.comparator)} ₹${c.threshold_value} → ${formatPayAmount(c, allColumns, options)}`;
  });
  return parts.join(" | ");
}

function defaultSumRefs(column: SalaryColumnDefinition, priorOptions: ReferenceOption[]) {
  if (column.columnIdentifier === "new_basic") {
    const basic = priorOptions.find((o) => o.key === "EARNING::basic");
    const agp = priorOptions.find((o) => o.key === "EARNING::academic_grade_pay");
    const dp = priorOptions.find((o) => o.key === "EARNING::dearness_pay");
    const refs = [basic, agp ?? dp].filter(Boolean) as ReferenceOption[];
    if (refs.length > 0) {
      return refs.map((o) => ({ column_identifier: o.key, weight: 1 }));
    }
  }
  if (isEarningsMirrorDeduction(column)) {
    const earningKey = `EARNING::${column.columnIdentifier}`;
    if (priorOptions.some((o) => o.key === earningKey)) {
      return [{ column_identifier: earningKey, weight: 1 }];
    }
  }
  if (column.columnIdentifier === "gross_pay") {
    return priorOptions
      .filter((o) => o.group === "earnings")
      .map((o) => ({ column_identifier: o.key, weight: 1 }));
  }
  if (column.columnIdentifier === "total_deductions") {
    return priorOptions
      .filter((o) => o.group === "deductions")
      .map((o) => ({ column_identifier: o.key, weight: 1 }));
  }
  if (column.columnIdentifier === "net_pay") {
    const gross = priorOptions.find((o) => o.key === "EARNING::gross_pay");
    const totalDed = priorOptions.find((o) => o.key === "DEDUCTION::total_deductions");
    if (gross && totalDed) {
      return [
        { column_identifier: gross.key, weight: 1 },
        { column_identifier: totalDed.key, weight: -1 },
      ];
    }
    const deductions = priorOptions.filter((o) => o.group === "deductions");
    const refs: Array<{ column_identifier: string; weight: number }> = [];
    if (gross) refs.push({ column_identifier: gross.key, weight: 1 });
    for (const d of deductions) refs.push({ column_identifier: d.key, weight: -1 });
    if (refs.length > 0) return refs;
  }
  if (priorOptions.length > 0) {
    return [{ column_identifier: priorOptions[0].key, weight: 1 }];
  }
  return [{ column_identifier: "EARNING::basic", weight: 1 }];
}

function buildLivePreview(
  ruleType: UiRuleType,
  fixedValue: string,
  percentageValue: string,
  sumRefs: Array<{ column_identifier: string; weight: number }>,
  allColumns: SalaryColumnDefinition[],
  conditions: ConditionRow[],
  referenceOptions: ReferenceOption[],
): string {
  const label = (id: string) => columnLabel(allColumns, id, referenceOptions);

  if (ruleType === "FIXED") return `Fixed: ₹${Number(fixedValue) || 0}`;
  if (ruleType === "SUM") {
    const parts = sumRefs.map((r) => {
      const lbl = label(r.column_identifier);
      if (r.weight === 1) return lbl;
      if (r.weight === -1) return `− ${lbl}`;
      return `${r.weight} × ${lbl}`;
    });
    return parts.length > 1 ? parts.join(" ").replace(/\+ −/g, "−") : parts[0] ?? "";
  }
  if (ruleType === "PERCENTAGE") {
    const pct = Number(percentageValue) || 0;
    const parts = sumRefs.map((r) => label(r.column_identifier));
    const base = parts.length > 1 ? `(${parts.join(" + ")})` : parts[0] ?? "";
    return `${pct}% of ${base}`;
  }
  if (ruleType === "CONDITIONAL" && conditions.length > 0) {
    return buildConditionalPreview(conditions, allColumns, referenceOptions);
  }
  return "";
}

export function RuleEditorDrawer({
  open,
  onOpenChange,
  column,
  existingRule,
  allColumns,
  onSave,
  employeeMode,
  employeeLabel,
}: Props) {
  const [ruleType, setRuleType] = useState<UiRuleType>("FIXED");
  const [fixedValue, setFixedValue] = useState("");
  const [percentageValue, setPercentageValue] = useState("100");
  const [sumRefs, setSumRefs] = useState<Array<{ column_identifier: string; weight: number }>>([]);
  const [conditions, setConditions] = useState<ConditionRow[]>([]);
  const [saving, setSaving] = useState(false);

  const referenceOptions = useMemo(
    () => buildReferenceOptions(allColumns, column),
    [allColumns, column],
  );

  const sumColumnOptions = useMemo(
    () => buildPriorColumnOptions(allColumns, column),
    [allColumns, column],
  );

  useEffect(() => {
    if (!open) return;

    const refs = defaultSumRefs(column, sumColumnOptions);
    const firstRef = referenceOptions[0]?.key ?? refs[0]?.column_identifier ?? "EARNING::basic";

    if (existingRule) {
      const isSum =
        existingRule.ruleType === "PERCENTAGE" &&
        Number(existingRule.percentageValue) === 100 &&
        (existingRule.percentageReferenceColumns?.length ?? 0) > 0;

      setRuleType(
        existingRule.ruleType === "FIXED"
          ? "FIXED"
          : existingRule.ruleType === "CONDITIONAL"
            ? "CONDITIONAL"
            : isSum
              ? "SUM"
              : "PERCENTAGE",
      );
      setFixedValue(existingRule.fixedDefaultValue ? String(existingRule.fixedDefaultValue) : "");
      setPercentageValue(existingRule.percentageValue ? String(existingRule.percentageValue) : "100");
      setSumRefs(
        existingRule.percentageReferenceColumns?.length
          ? existingRule.percentageReferenceColumns
          : refs,
      );

      if (existingRule.conditions?.length) {
        setConditions(
          existingRule.conditions.map((c) => {
            const resultRefs = (c as { resultReferenceColumns?: Array<{ column_identifier: string; weight: number }> }).resultReferenceColumns?.length
              ? (c as { resultReferenceColumns: Array<{ column_identifier: string; weight: number }> }).resultReferenceColumns
              : refsFromCondition({
                  result_reference_column_identifier: c.resultReferenceColumnIdentifier,
                });
            return {
              comparator: c.comparator,
              reference_column_identifier: c.referenceColumnIdentifier,
              threshold_value: Number(c.thresholdValue),
              result_type: c.resultType as "FIXED_AMOUNT" | "PERCENTAGE_OF_COLUMN",
              result_value: Number(c.resultValue),
              result_reference_column_identifier: c.resultReferenceColumnIdentifier,
              result_reference_columns: resultRefs,
              sort_order: c.sortOrder,
              is_else_fallback: c.isElseFallback,
            };
          }),
        );
      }
      return;
    }

    const suggestedType: UiRuleType = isEarningsMirrorDeduction(column)
      ? "PERCENTAGE"
      : column.columnIdentifier === "new_basic" ||
          column.columnIdentifier === "gross_pay" ||
          column.columnIdentifier === "total_deductions" ||
          column.columnIdentifier === "net_pay"
        ? "SUM"
        : "FIXED";
    const defaultElseRefs = column.category === "DEDUCTION"
      ? [{ column_identifier: "EARNING::new_basic", weight: 1 }]
      : [{ column_identifier: firstRef, weight: 1 }];
    setRuleType(suggestedType);
    setFixedValue("");
    setPercentageValue("100");
    setSumRefs(refs);
    setConditions([
      {
        comparator: "GREATER_THAN_OR_EQUAL",
        reference_column_identifier: firstRef,
        threshold_value: 0,
        result_type: "FIXED_AMOUNT",
        result_value: 0,
        result_reference_column_identifier: null,
        result_reference_columns: [],
        sort_order: 0,
        is_else_fallback: false,
      },
      {
        comparator: "EQUAL",
        reference_column_identifier: firstRef,
        threshold_value: 0,
        result_type: "PERCENTAGE_OF_COLUMN",
        result_value: 0,
        result_reference_column_identifier: defaultElseRefs[0].column_identifier,
        result_reference_columns: defaultElseRefs,
        sort_order: 1,
        is_else_fallback: true,
      },
    ]);
  }, [open, existingRule, column, sumColumnOptions, referenceOptions]);

  const formulaPreview = buildLivePreview(
    ruleType,
    fixedValue,
    percentageValue,
    sumRefs,
    allColumns,
    conditions,
    referenceOptions,
  );

  const updateConditionByIndex = (idx: number, patch: Partial<ConditionRow>) => {
    setConditions((prev) =>
      prev.map((c) => {
        if (c.is_else_fallback) return c;
        const ifIndex = prev.filter((x) => !x.is_else_fallback).indexOf(c);
        return ifIndex === idx ? { ...c, ...patch } : c;
      }),
    );
  };

  const updateElse = (patch: Partial<ConditionRow>) => {
    setConditions((prev) => prev.map((c) => (c.is_else_fallback ? { ...c, ...patch } : c)));
  };

  const buildPayload = (): Record<string, unknown> => {
    if (ruleType === "FIXED") {
      return { rule_type: "FIXED", default_value: Number(fixedValue) || 0 };
    }
    if (ruleType === "SUM") {
      return {
        rule_type: "PERCENTAGE",
        percentage_value: 100,
        percentage_reference_columns: sumRefs.filter((r) => r.column_identifier),
      };
    }
    if (ruleType === "PERCENTAGE") {
      return {
        rule_type: "PERCENTAGE",
        percentage_value: Number(percentageValue) || 0,
        percentage_reference_columns: sumRefs.filter((r) => r.column_identifier),
      };
    }
    return {
      rule_type: "CONDITIONAL",
      conditions: conditions.map((c) => ({
        ...c,
        result_reference_column_identifier:
          c.result_type === "PERCENTAGE_OF_COLUMN"
            ? c.result_reference_columns[0]?.column_identifier ?? c.result_reference_column_identifier
            : null,
        result_reference_columns:
          c.result_type === "PERCENTAGE_OF_COLUMN" ? c.result_reference_columns : undefined,
      })),
    };
  };

  const handleSave = async () => {
    if ((ruleType === "SUM" || ruleType === "PERCENTAGE") && sumRefs.length === 0) {
      alert("Add at least one column to the formula.");
      return;
    }
    if (ruleType === "CONDITIONAL") {
      for (const c of conditions) {
        if (c.result_type === "PERCENTAGE_OF_COLUMN" && c.result_reference_columns.length === 0) {
          alert(c.is_else_fallback
            ? "Else branch: add at least one column for the percentage."
            : "Each percentage result must specify at least one column.");
          return;
        }
      }
    }
    setSaving(true);
    try {
      await onSave(buildPayload());
      onOpenChange(false);
    } finally {
      setSaving(false);
    }
  };

  const addCondition = () => {
    const firstRef = referenceOptions[0]?.key ?? "EARNING::basic";
    const nonElse = conditions.filter((c) => !c.is_else_fallback);
    const elseRow = conditions.find((c) => c.is_else_fallback);
    const newCond: ConditionRow = {
      comparator: "GREATER_THAN_OR_EQUAL",
      reference_column_identifier: firstRef,
      threshold_value: 0,
      result_type: "FIXED_AMOUNT",
      result_value: 0,
      result_reference_column_identifier: null,
      result_reference_columns: [],
      sort_order: nonElse.length,
      is_else_fallback: false,
    };
    const updated = [...nonElse, newCond];
    if (elseRow) updated.push({ ...elseRow, sort_order: updated.length });
    setConditions(updated);
  };

  const renderColumnPicker = (
    refs: Array<{ column_identifier: string; weight: number }>,
    onChange: (next: Array<{ column_identifier: string; weight: number }>) => void,
    options: ReferenceOption[],
    showWeight = false,
  ) => (
    <div className="space-y-2">
      {refs.map((ref, idx) => (
        <div key={idx} className="flex gap-2 items-end">
          <div className="flex-1 space-y-1">
            <Label className="text-xs">Column {idx + 1}</Label>
            <Select
              value={ref.column_identifier || undefined}
              onValueChange={(v) => {
                const next = [...refs];
                next[idx] = { ...next[idx], column_identifier: v };
                onChange(next);
              }}
            >
              <SelectTrigger><SelectValue placeholder="Select column…" /></SelectTrigger>
              <SelectContent>
                {options.map((o) => (
                  <SelectItem key={o.key} value={o.key}>
                    {o.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          {showWeight && (
            <div className="w-20 space-y-1">
              <Label className="text-xs">Weight</Label>
              <Input
                type="number"
                value={ref.weight}
                onChange={(e) => {
                  const next = [...refs];
                  next[idx] = { ...next[idx], weight: Number(e.target.value) || 1 };
                  onChange(next);
                }}
              />
            </div>
          )}
          {refs.length > 1 && (
            <Button
              type="button"
              variant="ghost"
              size="icon"
              onClick={() => onChange(refs.filter((_, i) => i !== idx))}
            >
              <Trash2 className="w-4 h-4" />
            </Button>
          )}
        </div>
      ))}
      <Button
        type="button"
        variant="outline"
        size="sm"
        onClick={() => {
          const nextKey = options[refs.length]?.key ?? options[0]?.key ?? "";
          onChange([...refs, { column_identifier: nextKey, weight: 1 }]);
        }}
        disabled={options.length === 0}
      >
        <Plus className="w-4 h-4 mr-1" /> Add column
      </Button>
      {options.length === 0 && (
        <p className="text-xs text-amber-600">No prior columns available. Configure earlier columns first (e.g. Basic).</p>
      )}
    </div>
  );

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="w-full sm:max-w-lg overflow-y-auto">
        <SheetHeader>
          <SheetTitle>
            {employeeMode ? `${column.displayName} — this employee only` : column.displayName}
          </SheetTitle>
        </SheetHeader>

        {employeeMode && (
          <div className="mt-4 rounded-lg border border-blue-200 bg-blue-50 px-3 py-2 text-xs text-blue-800">
            Saved only for <strong>{employeeLabel ?? "this employee"}</strong>. Designation-wide rules in
            Salary Structures are <strong>not</strong> changed.
          </div>
        )}

        <div className="mt-6 space-y-4">
          <div className="space-y-2">
            <Label>Rule Type</Label>
            <Select value={ruleType} onValueChange={(v) => setRuleType(v as UiRuleType)}>
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="FIXED">Fixed amount</SelectItem>
                <SelectItem value="SUM">Sum of columns</SelectItem>
                <SelectItem value="PERCENTAGE">Percentage of columns</SelectItem>
                <SelectItem value="CONDITIONAL">Conditional</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {isEarningsMirrorDeduction(column) && !existingRule && (
            <p className="text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded-lg px-3 py-2">
              Use <strong>Percentage of columns</strong> at 100% and pick{" "}
              <strong>{column.displayName} (from Earnings)</strong> to copy the earnings value.
            </p>
          )}

          {!existingRule && (column.columnIdentifier === "gross_pay" || column.columnIdentifier === "total_deductions" || column.columnIdentifier === "net_pay") && (
            <p className="text-xs text-slate-600 bg-slate-50 border rounded-lg px-3 py-2">
              {column.columnIdentifier === "gross_pay" && (
                <>Default columns are pre-filled. Choose <strong>Sum of columns</strong> and click Save to set your formula.</>
              )}
              {column.columnIdentifier === "total_deductions" && (
                <>Default sums all deduction rows. Adjust columns or weights, then Save.</>
              )}
              {column.columnIdentifier === "net_pay" && (
                <>Default is <strong>Gross Pay − Total Deductions</strong>. Use weight −1 to subtract.</>
              )}
            </p>
          )}

          {formulaPreview && (
            <div className="rounded-lg bg-slate-50 border px-3 py-2 text-sm text-slate-600">
              <span className="text-xs uppercase tracking-wide text-slate-400 block mb-1">Preview</span>
              {formulaPreview}
            </div>
          )}

          {ruleType === "FIXED" && (
            <div className="space-y-2">
              <Label>Default Value (₹)</Label>
              <Input type="number" value={fixedValue} onChange={(e) => setFixedValue(e.target.value)} />
              <p className="text-xs text-slate-500">
                Pre-fills for all employees of this designation; can be overridden per employee.
              </p>
            </div>
          )}

          {ruleType === "SUM" && (
            <div className="space-y-3">
              <p className="text-xs text-slate-500">
                {column.columnIdentifier === "net_pay"
                  ? "Combine columns — use weight −1 to subtract deductions from Gross Pay."
                  : "Add columns to combine — e.g. New Basic = Basic + Academic Grade Pay"}
              </p>
              {renderColumnPicker(
                sumRefs,
                setSumRefs,
                sumColumnOptions,
                column.columnIdentifier === "net_pay" || column.columnIdentifier === "total_deductions",
              )}
            </div>
          )}

          {ruleType === "PERCENTAGE" && (
            <div className="space-y-3">
              <div className="space-y-2">
                <Label>Percentage (%)</Label>
                <Input type="number" value={percentageValue} onChange={(e) => setPercentageValue(e.target.value)} />
              </div>
              {isEarningsMirrorDeduction(column) && (
                <p className="text-xs text-slate-500">
                  Pick <strong>{column.displayName} (from Earnings)</strong> below.
                </p>
              )}
              {renderColumnPicker(sumRefs, setSumRefs, referenceOptions, true)}
            </div>
          )}

          {ruleType === "CONDITIONAL" && (
            <div className="space-y-3">
              {conditions
                .filter((c) => !c.is_else_fallback)
                .map((cond, idx) => (
                  <div key={idx} className="border rounded-lg p-3 space-y-3">
                    <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide">
                      {idx === 0 ? "If" : "Else if"}
                    </p>

                    <div className="grid grid-cols-3 gap-2">
                      <div className="space-y-1">
                        <Label className="text-xs text-slate-500">Condition</Label>
                        <Select
                          value={cond.comparator}
                          onValueChange={(v) => updateConditionByIndex(idx, { comparator: v })}
                        >
                          <SelectTrigger><SelectValue /></SelectTrigger>
                          <SelectContent>
                            {COMPARATORS.map((c) => (
                              <SelectItem key={c.value} value={c.value}>{c.label}</SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                      <div className="space-y-1">
                        <Label className="text-xs text-slate-500">Column</Label>
                        <Select
                          value={cond.reference_column_identifier || undefined}
                          onValueChange={(v) => updateConditionByIndex(idx, { reference_column_identifier: v })}
                        >
                          <SelectTrigger><SelectValue placeholder="Select…" /></SelectTrigger>
                          <SelectContent>
                            {referenceOptions.map((o) => (
                              <SelectItem key={o.key} value={o.key}>
                                {o.label}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                      <div className="space-y-1">
                        <Label className="text-xs text-slate-500">Threshold (₹)</Label>
                        <Input
                          type="number"
                          value={cond.threshold_value}
                          onChange={(e) => updateConditionByIndex(idx, { threshold_value: Number(e.target.value) })}
                        />
                      </div>
                    </div>

                    <div className="border-t pt-3 space-y-2">
                      <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide">Then pay</p>
                      <div className="space-y-1">
                        <Label className="text-xs text-slate-500">Amount type</Label>
                        <Select
                          value={cond.result_type}
                          onValueChange={(v) =>
                            updateConditionByIndex(idx, {
                              result_type: v as "FIXED_AMOUNT" | "PERCENTAGE_OF_COLUMN",
                            })
                          }
                        >
                          <SelectTrigger><SelectValue /></SelectTrigger>
                          <SelectContent>
                            <SelectItem value="FIXED_AMOUNT">Fixed amount (₹)</SelectItem>
                            <SelectItem value="PERCENTAGE_OF_COLUMN">Percentage of a column</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>

                      {cond.result_type === "FIXED_AMOUNT" ? (
                        <div className="space-y-1">
                          <Label className="text-xs text-slate-500">Amount (₹)</Label>
                          <Input
                            type="number"
                            value={cond.result_value}
                            onChange={(e) => updateConditionByIndex(idx, { result_value: Number(e.target.value) })}
                          />
                        </div>
                      ) : (
                        <div className="space-y-2">
                          <div className="space-y-1">
                            <Label className="text-xs text-slate-500">Percentage (%)</Label>
                            <Input
                              type="number"
                              value={cond.result_value}
                              onChange={(e) => updateConditionByIndex(idx, { result_value: Number(e.target.value) })}
                              placeholder="e.g. 12"
                            />
                          </div>
                          <Label className="text-xs text-slate-500">Of column(s)</Label>
                          {renderColumnPicker(
                            cond.result_reference_columns,
                            (next) => updateConditionByIndex(idx, { result_reference_columns: next }),
                            referenceOptions,
                          )}
                        </div>
                      )}
                    </div>
                  </div>
                ))}

              <Button type="button" variant="outline" size="sm" onClick={addCondition}>
                <Plus className="w-4 h-4 mr-1" /> Add Condition
              </Button>

              {conditions.filter((c) => c.is_else_fallback).map((elseRow) => (
                <div key="else" className="border rounded-lg p-3 space-y-3 bg-slate-50">
                  <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide">Else (default)</p>
                  <p className="text-xs text-slate-400">Used when no condition above matches.</p>

                  <div className="space-y-1">
                    <Label className="text-xs text-slate-500">Amount type</Label>
                    <Select
                      value={elseRow.result_type}
                      onValueChange={(v) =>
                        updateElse({ result_type: v as "FIXED_AMOUNT" | "PERCENTAGE_OF_COLUMN" })
                      }
                    >
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="FIXED_AMOUNT">Fixed amount (₹)</SelectItem>
                        <SelectItem value="PERCENTAGE_OF_COLUMN">Percentage of a column</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  {elseRow.result_type === "FIXED_AMOUNT" ? (
                    <div className="space-y-1">
                      <Label className="text-xs text-slate-500">Amount (₹)</Label>
                      <Input
                        type="number"
                        value={elseRow.result_value}
                        onChange={(e) => updateElse({ result_value: Number(e.target.value) })}
                      />
                    </div>
                  ) : (
                    <div className="space-y-2">
                      <div className="space-y-1">
                        <Label className="text-xs text-slate-500">Percentage (%)</Label>
                        <Input
                          type="number"
                          value={elseRow.result_value}
                          onChange={(e) => updateElse({ result_value: Number(e.target.value) })}
                          placeholder="e.g. 12"
                        />
                      </div>
                      <Label className="text-xs text-slate-500">Of column(s) — use &quot;from Earnings&quot; for PF / Gratuity</Label>
                      {renderColumnPicker(
                        elseRow.result_reference_columns,
                        (next) => updateElse({ result_reference_columns: next }),
                        referenceOptions,
                      )}
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}

          <Button onClick={handleSave} disabled={saving} className="w-full">
            {saving ? "Saving…" : employeeMode ? "Save for this employee" : "Save Rule"}
          </Button>
        </div>
      </SheetContent>
    </Sheet>
  );
}
