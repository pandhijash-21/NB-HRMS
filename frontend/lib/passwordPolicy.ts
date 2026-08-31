/** Mirrors backend `src/utils/passwordPolicy.ts`. */
export const PASSWORD_POLICY_HINT =
  "At least 6 characters, with 1 uppercase letter, 1 lowercase letter, and a number.";

export function passwordPolicyIssue(password: string): string | null {
  if (password.length < 6) return "Minimum 6 characters";
  if (!/[A-Z]/.test(password)) return "Must contain at least one uppercase letter";
  if (!/[a-z]/.test(password)) return "Must contain at least one lowercase letter";
  if (!/[0-9]/.test(password)) return "Must contain at least one number";
  if (!/[A-Za-z]/.test(password)) return "Must contain letters";
  return null;
}
