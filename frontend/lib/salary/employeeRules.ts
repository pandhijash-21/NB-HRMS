import type { SalaryColumnRule } from "@/lib/hooks/useSalary";

/** Convert stored employee rule payload to RuleEditorDrawer shape */
export function employeeRuleBodyToColumnRule(
  key: string,
  body: Record<string, unknown>,
): SalaryColumnRule {
  const [category, ...rest] = key.split("::");
  const columnIdentifier = rest.join("::");
  const ruleType = body.rule_type as string;
  const isSum =
    ruleType === "PERCENTAGE" &&
    Number(body.percentage_value) === 100 &&
    Array.isArray(body.percentage_reference_columns) &&
    (body.percentage_reference_columns as unknown[]).length > 0;

  return {
    id: `employee-${key}`,
    columnIdentifier,
    category: category as "EARNING" | "DEDUCTION",
    ruleType: ruleType === "CONDITIONAL" ? "CONDITIONAL" : isSum ? "PERCENTAGE" : (ruleType as SalaryColumnRule["ruleType"]),
    formulaPreview: "",
    fixedDefaultValue:
      ruleType === "FIXED" && body.default_value != null ? String(body.default_value) : null,
    percentageValue:
      ruleType === "PERCENTAGE" && body.percentage_value != null
        ? String(body.percentage_value)
        : null,
    percentageReferenceColumns:
      ruleType === "PERCENTAGE" && Array.isArray(body.percentage_reference_columns)
        ? (body.percentage_reference_columns as SalaryColumnRule["percentageReferenceColumns"])
        : null,
    conditions: Array.isArray(body.conditions)
      ? (body.conditions as Array<Record<string, unknown>>).map((c, i) => ({
          id: `ec-${i}`,
          comparator: String(c.comparator),
          referenceColumnIdentifier: String(c.reference_column_identifier),
          thresholdValue: String(c.threshold_value),
          resultType: String(c.result_type),
          resultValue: String(c.result_value),
          resultReferenceColumnIdentifier:
            (c.result_reference_column_identifier as string | null) ?? null,
          resultReferenceColumns:
            (c.result_reference_columns as SalaryColumnRule["conditions"][0]["resultReferenceColumns"]) ?? null,
          sortOrder: Number(c.sort_order ?? i),
          isElseFallback: Boolean(c.is_else_fallback),
        }))
      : [],
  };
}
