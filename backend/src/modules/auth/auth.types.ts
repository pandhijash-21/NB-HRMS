import { z } from 'zod';
import { PasswordPolicySchema } from '../../utils/passwordPolicy';

export const LoginSchema = z.object({
  identifier: z.string().min(1, 'Employee ID or Username is required'),
  password: z.string().min(1, 'Password is required'),
  portal: z.enum(['superadmin', 'standard']).optional(),
  platform: z.enum(['app', 'browser', 'mobile', 'web']).optional(),
});

export const ChangePasswordSchema = z.object({
  currentPassword: z.string().min(1),
  newPassword: PasswordPolicySchema,
});

export const ForgotPasswordRequestSchema = z.object({
  identifier: z.string().min(1, 'Employee ID or Username is required'),
});

export const ForgotPasswordVerifySchema = z.object({
  identifier: z.string().min(1, 'Employee ID or Username is required'),
  otp: z.string().min(4, 'OTP is required'),
});

export const ForgotPasswordResetSchema = z.object({
  resetToken: z.string().min(16, 'Reset token is required'),
  newPassword: PasswordPolicySchema,
  confirmPassword: z.string().min(1, 'Confirm password is required'),
}).refine((d) => d.newPassword === d.confirmPassword, {
  message: 'Passwords do not match',
  path: ['confirmPassword'],
});

export type LoginInput = z.infer<typeof LoginSchema>;
export type ChangePasswordInput = z.infer<typeof ChangePasswordSchema>;
export type ForgotPasswordRequestInput = z.infer<typeof ForgotPasswordRequestSchema>;
export type ForgotPasswordVerifyInput = z.infer<typeof ForgotPasswordVerifySchema>;
export type ForgotPasswordResetInput = z.infer<typeof ForgotPasswordResetSchema>;
