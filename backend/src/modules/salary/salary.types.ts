import type {
  ConditionComparator,
  ConditionResultType,
  RuleType,
  SalaryColumnCategory,
} from '@prisma/client';

export type PercentageReferenceColumn = {
  column_identifier: string;
  weight: number;
};

export type ConditionalConditionInput = {
  comparator: ConditionComparator;
  reference_column_identifier: string;
  threshold_value: number;
  result_type: ConditionResultType;
  result_value: number;
  result_reference_column_identifier?: string | null;
  result_reference_columns?: PercentageReferenceColumn[];
  sort_order: number;
  is_else_fallback: boolean;
};

/** Optional category prefix, e.g. EARNING::provident_fund */
export function parseColumnRef(ref: string): {
  category?: SalaryColumnCategory;
  identifier: string;
} {
  const idx = ref.indexOf('::');
  if (idx > 0) {
    const cat = ref.slice(0, idx) as SalaryColumnCategory;
    if (cat === 'EARNING' || cat === 'DEDUCTION') {
      return { category: cat, identifier: ref.slice(idx + 2) };
    }
  }
  return { identifier: ref };
}

export function formatColumnRef(category: SalaryColumnCategory, identifier: string): string {
  return `${category}::${identifier}`;
}

export type ColumnRuleInput = {
  rule_type: RuleType;
  default_value?: number;
  percentage_value?: number;
  reference_column_identifier?: string;
  percentage_reference_columns?: PercentageReferenceColumn[];
  conditions?: ConditionalConditionInput[];
};

export type ColumnValueMap = Record<string, number>;

export type ComputedColumn = {
  column_identifier: string;
  category: SalaryColumnCategory;
  rule_computed_value: number;
  effective_value: number;
  formula_preview: string;
};

export type ComputeResult = {
  columns: ComputedColumn[];
  gross_pay: number;
  total_deductions: number;
  net_pay: number;
};

export function columnKey(identifier: string, category: SalaryColumnCategory): string {
  return `${category}::${identifier}`;
}

/** Accepts `reimbursement` or `reimbursements` (UI often creates the plural form). */
export function isReimbursementColumnId(columnIdentifier: string): boolean {
  const id = columnIdentifier.trim().toLowerCase().replace(/_+/g, '_');
  return id === 'reimbursement' || id === 'reimbursements';
}

export function findReimbursementEarningColumn<
  T extends { columnIdentifier: string; category: string },
>(columns: T[]): T | undefined {
  return columns.find(
    (c) => isReimbursementColumnId(c.columnIdentifier) && String(c.category) === 'EARNING',
  );
}

export function resolveReferenceValue(
  values: ColumnValueMap,
  ref: string,
  preferCategory?: SalaryColumnCategory,
): number {
  const parsed = parseColumnRef(ref);
  if (parsed.category) {
    return values[columnKey(parsed.identifier, parsed.category)] ?? 0;
  }

  const identifier = parsed.identifier;
  if (preferCategory) {
    const key = columnKey(identifier, preferCategory);
    if (key in values) return values[key];
  }
  const earningKey = columnKey(identifier, 'EARNING');
  if (earningKey in values) return values[earningKey];
  const deductionKey = columnKey(identifier, 'DEDUCTION');
  if (deductionKey in values) return values[deductionKey];
  return values[identifier] ?? 0;
}

export function resolvePercentageBase(
  values: ColumnValueMap,
  refs: PercentageReferenceColumn[],
  defaultCategory?: SalaryColumnCategory,
): number {
  return refs.reduce((sum, r) => {
    return sum + resolveReferenceValue(values, r.column_identifier, defaultCategory) * (r.weight ?? 1);
  }, 0);
}
