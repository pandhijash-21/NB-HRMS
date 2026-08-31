import { z } from 'zod';

/** Min 6, 1 uppercase, 1 lowercase, and at least one number (letters + numbers). */
export const PASSWORD_POLICY_HINT =
  'At least 6 characters, with 1 uppercase letter, 1 lowercase letter, and a number.';

export function passwordPolicyIssue(password: string): string | null {
  if (password.length < 6) return 'Minimum 6 characters';
  if (!/[A-Z]/.test(password)) return 'Must contain at least one uppercase letter';
  if (!/[a-z]/.test(password)) return 'Must contain at least one lowercase letter';
  if (!/[0-9]/.test(password)) return 'Must contain at least one number';
  if (!/[A-Za-z]/.test(password)) return 'Must contain letters';
  return null;
}

export function passwordMeetsPolicy(password: string): boolean {
  return passwordPolicyIssue(password) === null;
}

export const PasswordPolicySchema = z
  .string()
  .min(6, 'Minimum 6 characters')
  .regex(/[A-Z]/, 'Must contain at least one uppercase letter')
  .regex(/[a-z]/, 'Must contain at least one lowercase letter')
  .regex(/[0-9]/, 'Must contain at least one number');
