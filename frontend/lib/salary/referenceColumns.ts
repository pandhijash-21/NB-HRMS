import type { SalaryColumnDefinition } from "@/lib/hooks/useSalary";

export type ReferenceOption = {
  key: string;
  label: string;
  group: "earnings" | "deductions" | "computed";
};

/** Deduction rows that typically mirror a value from the Earnings section */
const EARNING_CROSS_REF = new Set(["gratuity", "provident_fund"]);

export function buildReferenceOptions(
  allColumns: SalaryColumnDefinition[],
  forColumn: SalaryColumnDefinition,
): ReferenceOption[] {
  const options: ReferenceOption[] = [];
  const seen = new Set<string>();

  const add = (key: string, label: string, group: ReferenceOption["group"]) => {
    if (seen.has(key)) return;
    seen.add(key);
    options.push({ key, label, group });
  };

  for (const c of allColumns) {
    if (c.category === forColumn.category && c.columnIdentifier === forColumn.columnIdentifier) {
      continue;
    }

    const isGrossPayRef =
      c.columnIdentifier === "gross_pay" &&
      c.category === "EARNING" &&
      forColumn.columnIdentifier !== "gross_pay";
    const isTotalDeductionsRef =
      c.columnIdentifier === "total_deductions" &&
      c.category === "DEDUCTION" &&
      forColumn.columnIdentifier !== "total_deductions";

    if (c.evaluationOrder >= forColumn.evaluationOrder && !isGrossPayRef && !isTotalDeductionsRef) {
      continue;
    }

    if (isGrossPayRef) {
      add("EARNING::gross_pay", "Gross Pay", "computed");
      continue;
    }
    if (isTotalDeductionsRef) {
      add("DEDUCTION::total_deductions", "Total Deductions", "computed");
      continue;
    }
    if (c.columnIdentifier === "net_pay" || c.columnIdentifier === "total_deductions") {
      continue;
    }

    if (
      forColumn.category === "DEDUCTION" &&
      c.category === "EARNING" &&
      c.columnIdentifier === forColumn.columnIdentifier &&
      EARNING_CROSS_REF.has(c.columnIdentifier)
    ) {
      continue;
    }

    const key = `${c.category}::${c.columnIdentifier}`;
    add(key, c.displayName, c.category === "EARNING" ? "earnings" : "deductions");
  }

  if (forColumn.category === "DEDUCTION") {
    for (const c of allColumns) {
      if (c.category !== "EARNING") continue;
      if (
        c.columnIdentifier === "gross_pay" ||
        c.columnIdentifier === "net_pay" ||
        c.columnIdentifier === "total_deductions"
      ) {
        continue;
      }
      if (!EARNING_CROSS_REF.has(c.columnIdentifier)) continue;

      const key = `EARNING::${c.columnIdentifier}`;
      add(key, `${c.displayName} (from Earnings)`, "earnings");
    }
  }

  return options;
}

export function buildPriorColumnOptions(
  allColumns: SalaryColumnDefinition[],
  forColumn: SalaryColumnDefinition,
): ReferenceOption[] {
  return buildReferenceOptions(allColumns, forColumn).filter(
    (o) =>
      o.group !== "computed" ||
      o.key === "EARNING::gross_pay" ||
      o.key === "DEDUCTION::total_deductions",
  );
}

export function isEarningsMirrorDeduction(column: SalaryColumnDefinition): boolean {
  return column.category === "DEDUCTION" && EARNING_CROSS_REF.has(column.columnIdentifier);
}

export function refsFromCondition(c: {
  result_reference_columns?: Array<{ column_identifier: string; weight: number }>;
  result_reference_column_identifier?: string | null;
}): Array<{ column_identifier: string; weight: number }> {
  if (c.result_reference_columns?.length) return c.result_reference_columns;
  if (c.result_reference_column_identifier) {
    return [{ column_identifier: c.result_reference_column_identifier, weight: 1 }];
  }
  return [{ column_identifier: "EARNING::basic", weight: 1 }];
}
