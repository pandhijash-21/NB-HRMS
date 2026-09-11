import { z } from 'zod';
import { PasswordPolicySchema } from '../../utils/passwordPolicy';

export const LoginSchema = z.object({
  identifier: z.string().min(1, 'Employee ID or Username is required'),
  password: z.string().min(1, 'Password is required'),
  portal: z.enum(['superadmin', 'standard']).optional(),
});

export const ChangePasswordSchema = z.object({
  currentPassword: z.string().min(1),
  newPassword: PasswordPolicySchema,
});

export type LoginInput = z.infer<typeof LoginSchema>;
export type ChangePasswordInput = z.infer<typeof ChangePasswordSchema>;
