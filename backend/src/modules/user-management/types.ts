import { z } from 'zod';

export const CreateUserSchema = z.object({
  employeeId: z.coerce.number().int().positive().optional(),
  username: z.string().min(2).max(64).optional(),
  password: z.string().min(8).optional(),
  subOrganization: z.string().min(1).max(64).optional(),
  roleId:     z.string().uuid(),
}).refine((d) => d.employeeId !== undefined || d.username !== undefined, {
  message: 'Either employeeId or username is required',
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
});

export const UpdateRoleSchema = z.object({
  name:        z.string().min(2).max(50).regex(/^[A-Z][A-Z0-9_]*$/).optional(),
  description: z.string().optional(),
}).refine((d) => d.name !== undefined || d.description !== undefined, {
  message: 'At least one field must be provided',
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
});

export type CreateUserInput      = z.infer<typeof CreateUserSchema>;
export type UpdateUserInput      = z.infer<typeof UpdateUserSchema>;
export type CreateRoleInput      = z.infer<typeof CreateRoleSchema>;
export type UpdateRoleInput      = z.infer<typeof UpdateRoleSchema>;
export type UpdatePermissionsInput = z.infer<typeof UpdatePermissionsSchema>;
export type PatchPermissionInput = z.infer<typeof PatchPermissionSchema>;
