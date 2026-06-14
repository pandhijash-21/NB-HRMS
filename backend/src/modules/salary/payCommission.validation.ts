import { z } from 'zod';

export const createPayCommissionSchema = z.object({
  code: z.string().min(1).max(40),
  name: z.string().min(1).max(120),
  description: z.string().max(500).optional().nullable(),
  ruleEditorEnabled: z.boolean().optional(),
  sortOrder: z.number().int().optional(),
  cloneFromCommissionId: z.string().uuid().optional().nullable(),
});

export const updatePayCommissionSchema = z.object({
  name: z.string().min(1).max(120).optional(),
  description: z.string().max(500).optional().nullable(),
  isActive: z.boolean().optional(),
  ruleEditorEnabled: z.boolean().optional(),
  sortOrder: z.number().int().optional(),
});

export const createColumnSchema = z.object({
  columnIdentifier: z.string().min(1).max(80),
  displayName: z.string().min(1).max(120),
  category: z.enum(['EARNING', 'DEDUCTION']),
  evaluationOrder: z.number().int(),
  isRuleConfigurable: z.boolean().optional(),
});

export const updateColumnSchema = z.object({
  displayName: z.string().min(1).max(120).optional(),
  evaluationOrder: z.number().int().optional(),
  isRuleConfigurable: z.boolean().optional(),
});
