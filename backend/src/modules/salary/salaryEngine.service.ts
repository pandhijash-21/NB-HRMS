import type {
  ConditionalRuleCondition,
  SalaryColumnDefinition,
  SalaryColumnRule,
} from '@prisma/client';
import {
  columnKey,
  parseColumnRef,
  resolvePercentageBase,
  resolveReferenceValue,
  type ColumnRuleInput,
  type ColumnValueMap,
  type ComputeResult,
  type ComputedColumn,
  type PercentageReferenceColumn,
} from './salary.types';
import type { SalaryColumnCategory } from '@prisma/client';

const COMPARATOR_LABELS: Record<string, string> = {
  GREATER_THAN: '>',
  LESS_THAN: '<',
  GREATER_THAN_OR_EQUAL: '≥',
  LESS_THAN_OR_EQUAL: '≤',
  EQUAL: '=',
};

const DISPLAY_NAMES: Record<string, string> = {
  basic: 'Basic',
  dearness_pay: 'Dearness Pay',
  new_basic: 'New Basic',
  dearness_allowance: 'Dearness Allowance',
  house_rent_allowance: 'House Rent Allowance',
  city_compensatory_allowance: 'City Compensatory Allowance',
  medical_allowance: 'Medical Allowance',
  travel_allowance: 'Travel Allowance',
  academic_grade_pay: 'Academic Grade Pay',
  special_allowance: 'Special Allowance',
  other_allowance: 'Other Allowance',
  gratuity: 'Gratuity',
  provident_fund: 'Provident Fund',
  gross_pay: 'Gross Pay',
  professional_tax: 'Professional Tax',
  tax_deducted_at_source: 'Tax Deducted at Source',
  tax_deducted_at_source_against_proof: 'Tax Deducted at Source Against Proof',
  other_deductions: 'Other Deductions',
  total_deductions: 'Total Deductions',
  net_pay: 'Net Pay',
};

function displayName(identifier: string, definitions?: SalaryColumnDefinition[]): string {
  const parsed = parseColumnRef(identifier);
  const def = definitions?.find((d) => d.columnIdentifier === parsed.identifier);
  const base = def?.displayName ?? DISPLAY_NAMES[parsed.identifier] ?? parsed.identifier;
  if (parsed.category === 'EARNING') return `${base} (Earnings)`;
  if (parsed.category === 'DEDUCTION') return `${base} (Deductions)`;
  return base;
}

function formatINR(amount: number): string {
  return `₹${amount.toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;
}

function compare(comparator: string, left: number, right: number): boolean {
  switch (comparator) {
    case 'GREATER_THAN': return left > right;
    case 'LESS_THAN': return left < right;
    case 'GREATER_THAN_OR_EQUAL': return left >= right;
    case 'LESS_THAN_OR_EQUAL': return left <= right;
    case 'EQUAL': return left === right;
    default: return false;
  }
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

function buildPercentageBaseLabel(
  refs: PercentageReferenceColumn[],
  definitions?: SalaryColumnDefinition[],
): string {
  if (refs.length === 1 && refs[0].weight === 1) {
    return displayName(refs[0].column_identifier, definitions);
  }
  const parts = refs.map((r) => {
    const label = displayName(r.column_identifier, definitions);
    if (r.weight === 1) return label;
    if (r.weight === -1) return `− ${label}`;
    return `${r.weight} × ${label}`;
  });
  const joined = parts.join(' ').replace(/\+ −/g, '−');
  return refs.length > 1 ? `(${joined})` : joined;
}

export function buildFormulaPreview(
  input: ColumnRuleInput,
  definitions?: SalaryColumnDefinition[],
): string {
  if (input.rule_type === 'FIXED') {
    return `Fixed: ${formatINR(input.default_value ?? 0)}`;
  }

  if (input.rule_type === 'PERCENTAGE') {
    const refs: PercentageReferenceColumn[] =
      input.percentage_reference_columns?.length
        ? input.percentage_reference_columns
        : input.reference_column_identifier
          ? [{ column_identifier: input.reference_column_identifier, weight: 1 }]
          : [];
    const pct = input.percentage_value ?? 0;
    const baseLabel = buildPercentageBaseLabel(refs, definitions);
    if (pct === 100) {
      return refs.length === 1 && refs[0].weight === 1
        ? baseLabel
        : baseLabel.replace(/^\(|\)$/g, '');
    }
    return `${pct}% of ${baseLabel}`;
  }

  if (input.rule_type === 'CONDITIONAL' && input.conditions?.length) {
    const sorted = [...input.conditions].sort((a, b) => a.sort_order - b.sort_order);
    return sorted
      .map((c) => {
        if (c.is_else_fallback) {
          if (c.result_type === 'FIXED_AMOUNT') {
            return `Else → ${formatINR(c.result_value)}`;
          }
          const refs = c.result_reference_columns?.length
            ? c.result_reference_columns
            : c.result_reference_column_identifier
              ? [{ column_identifier: c.result_reference_column_identifier, weight: 1 }]
              : [];
          return `Else → ${c.result_value}% of ${buildPercentageBaseLabel(refs, definitions)}`;
        }
        const sym = COMPARATOR_LABELS[c.comparator] ?? c.comparator;
        const ref = displayName(c.reference_column_identifier, definitions);
        const cond = `If ${ref} ${sym} ${formatINR(c.threshold_value)}`;
        if (c.result_type === 'FIXED_AMOUNT') {
          return `${cond} → ${formatINR(c.result_value)}`;
        }
        const refs = c.result_reference_columns?.length
          ? c.result_reference_columns
          : c.result_reference_column_identifier
            ? [{ column_identifier: c.result_reference_column_identifier, weight: 1 }]
            : [];
        return `${cond} → ${c.result_value}% of ${buildPercentageBaseLabel(refs, definitions)}`;
      })
      .join(' | ');
  }

  return '';
}

export type RuleWithConditions = SalaryColumnRule & { conditions: ConditionalRuleCondition[] };

export function columnRuleInputToEvalRule(
  key: string,
  input: ColumnRuleInput,
  columnDefinitions: SalaryColumnDefinition[],
): RuleWithConditions {
  const parsed = parseColumnRef(key);
  const def = columnDefinitions.find(
    (d) =>
      d.columnIdentifier === parsed.identifier &&
      (!parsed.category || d.category === parsed.category),
  );
  const category = (parsed.category ?? def?.category ?? 'EARNING') as SalaryColumnCategory;
  const columnIdentifier = parsed.identifier;

  return {
    id: `employee-rule-${key}`,
    templateId: '',
    columnIdentifier,
    category,
    ruleType: input.rule_type,
    formulaPreview: buildFormulaPreview(input, columnDefinitions),
    fixedDefaultValue: input.rule_type === 'FIXED' ? String(input.default_value ?? 0) : null,
    percentageValue: input.rule_type === 'PERCENTAGE' ? String(input.percentage_value ?? 0) : null,
    percentageReferenceColumns:
      input.rule_type === 'PERCENTAGE' ? (input.percentage_reference_columns ?? null) : null,
    createdAt: new Date(),
    updatedAt: new Date(),
    conditions: (input.conditions ?? []).map((c, i) => ({
      id: `employee-cond-${key}-${i}`,
      columnRuleId: `employee-rule-${key}`,
      comparator: c.comparator,
      referenceColumnIdentifier: c.reference_column_identifier,
      thresholdValue: String(c.threshold_value),
      resultType: c.result_type,
      resultValue: String(c.result_value),
      resultReferenceColumnIdentifier: c.result_reference_column_identifier ?? null,
      resultReferenceColumns: c.result_reference_columns ?? null,
      sortOrder: c.sort_order,
      isElseFallback: c.is_else_fallback,
    })),
  } as any;
}

export function mergeEmployeeRules(
  templateRules: RuleWithConditions[],
  employeeRules: Record<string, ColumnRuleInput> | null | undefined,
  columnDefinitions: SalaryColumnDefinition[],
): RuleWithConditions[] {
  if (!employeeRules || Object.keys(employeeRules).length === 0) {
    return templateRules;
  }
  const merged = new Map(
    templateRules.map((r) => [columnKey(r.columnIdentifier, r.category), r]),
  );
  for (const [key, input] of Object.entries(employeeRules)) {
    merged.set(key, columnRuleInputToEvalRule(key, input, columnDefinitions));
  }
  return Array.from(merged.values());
}

function ruleFormulaPreview(rule: RuleWithConditions, definitions?: SalaryColumnDefinition[]): string {
  if (rule.formulaPreview) return rule.formulaPreview;
  return buildFormulaPreview(
    {
      rule_type: rule.ruleType,
      default_value: rule.fixedDefaultValue ? Number(rule.fixedDefaultValue) : undefined,
      percentage_value: rule.percentageValue ? Number(rule.percentageValue) : undefined,
      percentage_reference_columns: rule.percentageReferenceColumns as PercentageReferenceColumn[] | undefined,
      conditions: rule.conditions.map((c) => ({
        comparator: c.comparator,
        reference_column_identifier: c.referenceColumnIdentifier,
        threshold_value: Number(c.thresholdValue),
        result_type: c.resultType,
        result_value: Number(c.resultValue),
        result_reference_column_identifier: c.resultReferenceColumnIdentifier,
        result_reference_columns: c.resultReferenceColumns as PercentageReferenceColumn[] | undefined,
        sort_order: c.sortOrder,
        is_else_fallback: c.isElseFallback,
      })),
    },
    definitions,
  );
}

function defaultGrossPay(
  sorted: SalaryColumnDefinition[],
  values: ColumnValueMap,
): number {
  return round2(
    sorted
      .filter(
        (d) =>
          d.category === 'EARNING' &&
          d.columnIdentifier !== 'gross_pay' &&
          d.columnIdentifier !== 'gross_salary' &&
          d.columnIdentifier !== 'net_pay',
      )
      .reduce((sum, d) => sum + (values[columnKey(d.columnIdentifier, d.category)] ?? 0), 0),
  );
}

function defaultTotalDeductions(
  sorted: SalaryColumnDefinition[],
  values: ColumnValueMap,
): number {
  return round2(
    sorted
      .filter(
        (d) =>
          d.category === 'DEDUCTION' &&
          d.columnIdentifier !== 'net_pay' &&
          d.columnIdentifier !== 'total_deductions',
      )
      .reduce((sum, d) => sum + (values[columnKey(d.columnIdentifier, d.category)] ?? 0), 0),
  );
}

function defaultNetPay(sorted: SalaryColumnDefinition[], values: ColumnValueMap): number {
  const gross = values[columnKey('gross_pay', 'EARNING')] ?? 0;
  const totalDedKey = columnKey('total_deductions', 'DEDUCTION');
  if (totalDedKey in values) {
    return round2(gross - (values[totalDedKey] ?? 0));
  }
  return round2(gross - defaultTotalDeductions(sorted, values));
}

export function evaluateColumnRule(
  rule: RuleWithConditions | ColumnRuleInput,
  columnValues: ColumnValueMap,
  category: 'EARNING' | 'DEDUCTION',
  definitions?: SalaryColumnDefinition[],
): number {
  const ruleType = 'ruleType' in rule ? rule.ruleType : rule.rule_type;

  if (ruleType === 'FIXED') {
    const val = 'fixedDefaultValue' in rule
      ? Number(rule.fixedDefaultValue ?? 0)
      : (rule as ColumnRuleInput).default_value ?? 0;
    return round2(val);
  }

  if (ruleType === 'PERCENTAGE') {
    const pct = 'percentageValue' in rule
      ? Number(rule.percentageValue ?? 0)
      : (rule as ColumnRuleInput).percentage_value ?? 0;

    let refs: PercentageReferenceColumn[] = [];
    if ('percentageReferenceColumns' in rule && rule.percentageReferenceColumns) {
      refs = rule.percentageReferenceColumns as PercentageReferenceColumn[];
    } else if ((rule as ColumnRuleInput).percentage_reference_columns?.length) {
      refs = (rule as ColumnRuleInput).percentage_reference_columns!;
    } else {
      const refId = 'percentageReferenceColumns' in rule
        ? null
        : (rule as ColumnRuleInput).reference_column_identifier;
      if (refId) refs = [{ column_identifier: refId, weight: 1 }];
    }

    const base = resolvePercentageBase(columnValues, refs, category);
    return round2((base * pct) / 100);
  }

  if (ruleType === 'CONDITIONAL') {
    const conditions = 'conditions' in rule && Array.isArray(rule.conditions)
      ? [...rule.conditions].sort((a, b) => {
          const aOrder = 'sortOrder' in a ? a.sortOrder : a.sort_order;
          const bOrder = 'sortOrder' in b ? b.sortOrder : b.sort_order;
          return aOrder - bOrder;
        })
      : [...((rule as ColumnRuleInput).conditions ?? [])].sort((a, b) => a.sort_order - b.sort_order);

    for (const c of conditions) {
      const isElse = 'isElseFallback' in c ? c.isElseFallback : c.is_else_fallback;
      if (isElse) {
        return evaluateConditionResult(c, columnValues, category, definitions);
      }

      const refId = 'referenceColumnIdentifier' in c
        ? c.referenceColumnIdentifier
        : c.reference_column_identifier;
      const comparator = c.comparator;
      const threshold = Number('thresholdValue' in c ? c.thresholdValue : c.threshold_value);
      const refVal = resolveReferenceValue(columnValues, refId, category);

      if (compare(comparator, refVal, threshold)) {
        return evaluateConditionResult(c, columnValues, category, definitions);
      }
    }
  }

  return 0;
}

function evaluateConditionResult(
  c: ConditionalRuleCondition | import('./salary.types').ConditionalConditionInput,
  columnValues: ColumnValueMap,
  category: 'EARNING' | 'DEDUCTION',
  _definitions?: SalaryColumnDefinition[],
): number {
  const resultType = 'resultType' in c ? c.resultType : c.result_type;
  const resultValue = Number('resultValue' in c ? c.resultValue : c.result_value);

  if (resultType === 'FIXED_AMOUNT') return round2(resultValue);

  let refs: PercentageReferenceColumn[] = [];
  if ('resultReferenceColumns' in c && c.resultReferenceColumns) {
    refs = c.resultReferenceColumns as PercentageReferenceColumn[];
  } else if ((c as import('./salary.types').ConditionalConditionInput).result_reference_columns?.length) {
    refs = (c as import('./salary.types').ConditionalConditionInput).result_reference_columns!;
  } else {
    const refCol = 'resultReferenceColumnIdentifier' in c
      ? c.resultReferenceColumnIdentifier
      : c.result_reference_column_identifier;
    if (refCol) refs = [{ column_identifier: refCol, weight: 1 }];
  }

  const base = resolvePercentageBase(columnValues, refs, category);
  return round2((base * resultValue) / 100);
}

export function computeFullSalary(
  columnDefinitions: SalaryColumnDefinition[],
  rules: RuleWithConditions[],
  overrides?: Record<string, number>,
): ComputeResult {
  const sorted = [...columnDefinitions].sort((a, b) => a.evaluationOrder - b.evaluationOrder);
  const values: ColumnValueMap = {};
  const columns: ComputedColumn[] = [];
  const ruleByKey = new Map(
    rules.map((r) => [columnKey(r.columnIdentifier, r.category), r]),
  );

  for (const def of sorted) {
    const key = columnKey(def.columnIdentifier, def.category);
    let ruleComputed = 0;
    let formulaPreview = '';

    if (def.columnIdentifier === 'gross_pay' && def.category === 'EARNING') {
      const rule = ruleByKey.get(key);
      if (rule) {
        ruleComputed = evaluateColumnRule(rule, values, def.category, sorted);
        formulaPreview = ruleFormulaPreview(rule, sorted);
      } else {
        ruleComputed = defaultGrossPay(sorted, values);
        formulaPreview = 'Sum of all earnings (default)';
      }
    } else if (def.columnIdentifier === 'total_deductions' && def.category === 'DEDUCTION') {
      const rule = ruleByKey.get(key);
      if (rule) {
        ruleComputed = evaluateColumnRule(rule, values, def.category, sorted);
        formulaPreview = ruleFormulaPreview(rule, sorted);
      } else {
        ruleComputed = defaultTotalDeductions(sorted, values);
        formulaPreview = 'Sum of all deductions (default)';
      }
    } else if (def.columnIdentifier === 'net_pay') {
      const rule = ruleByKey.get(key);
      if (rule) {
        ruleComputed = evaluateColumnRule(rule, values, def.category, sorted);
        formulaPreview = ruleFormulaPreview(rule, sorted);
      } else {
        ruleComputed = defaultNetPay(sorted, values);
        formulaPreview = 'Gross Pay − Total Deductions (default)';
      }
    } else if (def.isRuleConfigurable) {
      const rule = ruleByKey.get(key);
      if (rule) {
        ruleComputed = evaluateColumnRule(rule, values, def.category, sorted);
        formulaPreview = ruleFormulaPreview(rule, sorted);
      }
    }

    const overrideKey = key;
    const overrideVal = overrides?.[overrideKey] ?? overrides?.[def.columnIdentifier];
    const effective = overrideVal !== undefined ? round2(overrideVal) : ruleComputed;

    values[key] = effective;
    columns.push({
      column_identifier: def.columnIdentifier,
      category: def.category,
      rule_computed_value: ruleComputed,
      effective_value: effective,
      formula_preview: formulaPreview,
    });
  }

  const gross_pay = values[columnKey('gross_pay', 'EARNING')] ?? 0;
  const totalDedKey = columnKey('total_deductions', 'DEDUCTION');
  const total_deductions =
    values[totalDedKey] ?? defaultTotalDeductions(sorted, values);
  const net_pay = values[columnKey('net_pay', 'DEDUCTION')] ?? round2(gross_pay - total_deductions);

  return { columns, gross_pay, total_deductions: round2(total_deductions), net_pay };
}

const AGGREGATE_COLUMNS = new Set(['gross_pay', 'total_deductions', 'net_pay', 'gross_salary']);

/**
 * Build override amounts for columns with cutOnAbsent / cutOnLeave.
 * Caller should recompute salary with these overrides so dependent formulas
 * (gross_salary, gross_pay, deduction mirrors, etc.) stay consistent.
 *
 * payable = A * (D - cutDays) / D
 * cutDays = (cutOnAbsent ? absentDays : 0) + (cutOnLeave ? unpaidLeaveDays : 0)
 */
export function buildAttendanceCutOverrides(
  result: ComputeResult,
  columnDefinitions: SalaryColumnDefinition[],
  opts: { daysInMonth: number; absentDays: number; unpaidLeaveDays: number },
): Record<string, number> {
  const D = Math.max(1, Math.floor(opts.daysInMonth));
  const X = Math.max(0, opts.absentDays);
  const L = Math.max(0, opts.unpaidLeaveDays);
  const defByKey = new Map(
    columnDefinitions.map((d) => [columnKey(d.columnIdentifier, d.category), d]),
  );

  const overrides: Record<string, number> = {};
  for (const c of result.columns) {
    const key = columnKey(c.column_identifier, c.category);
    const def = defByKey.get(key);
    if (!def || AGGREGATE_COLUMNS.has(c.column_identifier)) continue;
    const cutOnLeave = Boolean((def as { cutOnLeave?: boolean }).cutOnLeave);
    const cutOnAbsent = Boolean((def as { cutOnAbsent?: boolean }).cutOnAbsent);
    const cutDays = (cutOnAbsent ? X : 0) + (cutOnLeave ? L : 0);
    if (cutDays <= 0) continue;
    const payable = round2((c.effective_value * (D - cutDays)) / D);
    overrides[key] = payable;
    overrides[c.column_identifier] = payable;
  }
  return overrides;
}

/**
 * Prorate leaf columns by attendance cut flags, then rebuild gross / deductions / net
 * by re-evaluating formulas when rules are provided. Prefer
 * buildAttendanceCutOverrides + computeFullSalary for full formula chains.
 */
export function applyAttendanceProration(
  result: ComputeResult,
  columnDefinitions: SalaryColumnDefinition[],
  opts: { daysInMonth: number; absentDays: number; unpaidLeaveDays: number },
  rules?: RuleWithConditions[],
): ComputeResult {
  const cutOverrides = buildAttendanceCutOverrides(result, columnDefinitions, opts);
  if (!Object.keys(cutOverrides).length) return result;

  if (rules?.length) {
    // Recompute entire sheet with cut amounts locked — keeps gross_salary / gross_pay / mirrors correct.
    const baseOverrides: Record<string, number> = {};
    for (const c of result.columns) {
      // Preserve only explicit prior overrides is handled by caller; here lock cut leaves.
      const key = columnKey(c.column_identifier, c.category);
      if (cutOverrides[key] != null) baseOverrides[key] = cutOverrides[key]!;
    }
    // Merge: cut overrides win; use pre-cut effective for non-cut configurable leaves only if they were overrides?
    // Safer: pass only cut overrides and let rules recompute the rest from template defaults + those cuts.
    return computeFullSalary(columnDefinitions, rules, cutOverrides);
  }

  // Fallback (no rules): mutate leaves then rebuild aggregates without double-counting gross_salary.
  const D = Math.max(1, Math.floor(opts.daysInMonth));
  const X = Math.max(0, opts.absentDays);
  const L = Math.max(0, opts.unpaidLeaveDays);
  const defByKey = new Map(
    columnDefinitions.map((d) => [columnKey(d.columnIdentifier, d.category), d]),
  );

  const values: ColumnValueMap = {};
  const columns: ComputedColumn[] = result.columns.map((c) => {
    const key = columnKey(c.column_identifier, c.category);
    const def = defByKey.get(key);
    if (!def || AGGREGATE_COLUMNS.has(c.column_identifier)) {
      values[key] = c.effective_value;
      return c;
    }
    const cutOnLeave = Boolean((def as { cutOnLeave?: boolean }).cutOnLeave);
    const cutOnAbsent = Boolean((def as { cutOnAbsent?: boolean }).cutOnAbsent);
    const cutDays = (cutOnAbsent ? X : 0) + (cutOnLeave ? L : 0);
    if (cutDays <= 0) {
      values[key] = c.effective_value;
      return c;
    }
    const payable = round2((c.effective_value * (D - cutDays)) / D);
    values[key] = payable;
    return {
      ...c,
      effective_value: payable,
      formula_preview: `${c.formula_preview || c.column_identifier} × (${D}−${cutDays})/${D} (attendance cut)`,
    };
  });

  const sorted = [...columnDefinitions].sort((a, b) => a.evaluationOrder - b.evaluationOrder);

  for (let i = 0; i < columns.length; i++) {
    const c = columns[i]!;
    if (c.column_identifier === 'gross_pay' && c.category === 'EARNING') {
      const gross = round2(defaultGrossPay(sorted, values));
      columns[i] = {
        ...c,
        rule_computed_value: gross,
        effective_value: gross,
        formula_preview: 'Sum of earnings after attendance cut',
      };
      values[columnKey('gross_pay', 'EARNING')] = gross;
    } else if (c.column_identifier === 'total_deductions' && c.category === 'DEDUCTION') {
      const total = round2(defaultTotalDeductions(sorted, values));
      columns[i] = {
        ...c,
        rule_computed_value: total,
        effective_value: total,
        formula_preview: 'Sum of deductions after attendance cut',
      };
      values[columnKey('total_deductions', 'DEDUCTION')] = total;
    } else if (c.column_identifier === 'net_pay') {
      const gross = values[columnKey('gross_pay', 'EARNING')] ?? 0;
      const total =
        values[columnKey('total_deductions', 'DEDUCTION')] ??
        defaultTotalDeductions(sorted, values);
      const net = round2(gross - total);
      columns[i] = {
        ...c,
        rule_computed_value: net,
        effective_value: net,
        formula_preview: 'Gross − Total Deductions after attendance cut',
      };
      values[columnKey('net_pay', c.category)] = net;
    }
  }

  const gross_pay = values[columnKey('gross_pay', 'EARNING')] ?? 0;
  const total_deductions =
    values[columnKey('total_deductions', 'DEDUCTION')] ??
    defaultTotalDeductions(sorted, values);
  const net_pay =
    values[columnKey('net_pay', 'DEDUCTION')] ??
    values[columnKey('net_pay', 'EARNING')] ??
    round2(gross_pay - total_deductions);

  return {
    columns,
    gross_pay: round2(gross_pay),
    total_deductions: round2(total_deductions),
    net_pay: round2(net_pay),
  };
}
