import { z } from 'zod';

const percentageRefSchema = z.object({
  column_identifier: z.string().min(1),
  weight: z.number().default(1),
});

const conditionSchema = z.object({
  comparator: z.enum([
    'GREATER_THAN',
    'LESS_THAN',
    'GREATER_THAN_OR_EQUAL',
    'LESS_THAN_OR_EQUAL',
    'EQUAL',
  ]),
  reference_column_identifier: z.string().min(1),
  threshold_value: z.number(),
  result_type: z.enum(['FIXED_AMOUNT', 'PERCENTAGE_OF_COLUMN']),
  result_value: z.number(),
  result_reference_column_identifier: z.string().nullable().optional(),
  result_reference_columns: z.array(percentageRefSchema).optional(),
  sort_order: z.number().int(),
  is_else_fallback: z.boolean(),
});

export const columnRuleSchema = z.discriminatedUnion('rule_type', [
  z.object({
    rule_type: z.literal('FIXED'),
    default_value: z.number(),
  }),
  z.object({
    rule_type: z.literal('PERCENTAGE'),
    percentage_value: z.number(),
    reference_column_identifier: z.string().optional(),
    percentage_reference_columns: z.array(percentageRefSchema).optional(),
  }),
  z.object({
    rule_type: z.literal('CONDITIONAL'),
    conditions: z.array(conditionSchema).min(1),
  }),
]);

export const createTemplateSchema = z.object({
  designationId: z.string().uuid(),
  payCommissionType: z.enum(['FIFTH', 'SIXTH']),
});

export const createRecordSchema = z.object({
  employeeId: z.number().int().positive(),
  salaryMonth: z.number().int().min(1).max(12),
  salaryYear: z.number().int().min(2000).max(2100),
});

export const updateRecordSchema = z.object({
  overrides: z.record(z.string(), z.number()).optional(),
});

export function validateConditionalConditions(
  conditions: z.infer<typeof conditionSchema>[],
): void {
  const elseRows = conditions.filter((c) => c.is_else_fallback);
  if (elseRows.length !== 1) {
    throw new Error('Conditional rule must have exactly one else fallback row');
  }
  const maxSort = Math.max(...conditions.map((c) => c.sort_order));
  if (!elseRows.some((c) => c.sort_order === maxSort)) {
    throw new Error('Else fallback must be the last condition in sort order');
  }
  for (const c of conditions) {
    if (c.result_type === 'PERCENTAGE_OF_COLUMN') {
      const hasCols = (c.result_reference_columns?.length ?? 0) > 0 || !!c.result_reference_column_identifier;
      if (!hasCols) {
        throw new Error('Percentage result requires at least one reference column');
      }
    }
  }
}
