import { z } from 'zod';
import { PasswordPolicySchema } from '../../utils/passwordPolicy';

export const CreateUserSchema = z.object({
  employeeId: z.coerce.number().int().positive().optional(),
  employeeCode: z.string().min(1).max(64).optional(),
  username: z.string().min(2).max(64).optional(),
  password: PasswordPolicySchema.optional(),
  subOrganization: z.string().min(1).max(64).optional(),
  roleId:     z.string().uuid(),
}).refine((d) => d.employeeId !== undefined || d.employeeCode !== undefined || d.username !== undefined, {
  message: 'Either employeeId, employeeCode, or username is required',
}).refine((d) => (d.username ? !!d.password : true), {
  message: 'Password is required when creating a username-based account',
});

export const UpdateUserSchema = z.object({
  roleId:   z.string().uuid().optional(),
  isActive: z.boolean().optional(),
}).refine((d) => d.roleId !== undefined || d.isActive !== undefined, {
  message: 'At least one field (roleId or isActive) must be provided',
});

export const CreateRoleSchema = z.object({
  name: z
    .string()
    .min(2)
    .max(50)
    .regex(/^[A-Z][A-Z0-9_]*$/, 'Role name must be uppercase with underscores only'),
  description: z.string().optional(),
  cloneRoleId: z.string().uuid().optional(),
});

export const UpdateRoleSchema = z.object({
  name:        z.string().min(2).max(50).regex(/^[A-Z][A-Z0-9_]*$/).optional(),
  description: z.string().optional(),
}).refine((d) => d.name !== undefined || d.description !== undefined, {
  message: 'At least one field must be provided',
});

export const CreateModuleSchema = z.object({
  key: z
    .string()
    .min(2)
    .max(64)
    .regex(/^[A-Z][A-Z0-9_]*$/, 'Module key must be uppercase letters, numbers, and underscores (e.g. INVOICES)'),
  name: z.string().min(2).max(100),
  description: z.string().max(500).optional(),
  category: z.enum(['HRMS', 'CRM', 'ERP', 'COLLABORATION', 'SYSTEM']).default('HRMS'),
  sortOrder: z.coerce.number().int().default(0),
});

export const UpdateModuleSchema = z.object({
  name: z.string().min(2).max(100).optional(),
  description: z.string().max(500).optional(),
  category: z.enum(['HRMS', 'CRM', 'ERP', 'COLLABORATION', 'SYSTEM']).optional(),
  sortOrder: z.coerce.number().int().optional(),
  isActive: z.boolean().optional(),
}).refine((d) => Object.keys(d).length > 0, {
  message: 'At least one field must be provided to update',
});

export const UpdatePermissionsSchema = z.object({
  permissions: z
    .array(
      z.object({
        moduleKey:  z.string().min(1),
        canRead:    z.boolean(),
        canWrite:   z.boolean(),
        canApprove: z.boolean(),
        canDelete:  z.boolean(),
        canExport:  z.boolean(),
        employeeViewScope: z.enum(['NONE', 'SELF', 'INSTITUTE', 'UNIVERSITY']).optional(),
      })
    )
    .min(1),
});

export const PatchPermissionSchema = z.object({
  canRead:    z.boolean().optional(),
  canWrite:   z.boolean().optional(),
  canApprove: z.boolean().optional(),
  canDelete:  z.boolean().optional(),
  canExport:  z.boolean().optional(),
  employeeViewScope: z.enum(['NONE', 'SELF', 'INSTITUTE', 'UNIVERSITY']).optional(),
});

export type CreateUserInput        = z.infer<typeof CreateUserSchema>;
export type UpdateUserInput        = z.infer<typeof UpdateUserSchema>;
export type CreateRoleInput        = z.infer<typeof CreateRoleSchema>;
export type UpdateRoleInput        = z.infer<typeof UpdateRoleSchema>;
export type CreateModuleInput      = z.infer<typeof CreateModuleSchema>;
export type UpdateModuleInput      = z.infer<typeof UpdateModuleSchema>;
export type UpdatePermissionsInput = z.infer<typeof UpdatePermissionsSchema>;
export type PatchPermissionInput   = z.infer<typeof PatchPermissionSchema>;
