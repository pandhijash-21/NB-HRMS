/// Mirrors backend `passwordPolicy.ts`.
const _upper = '[A-Z]';
const _lower = '[a-z]';
const _digit = '[0-9]';

const passwordPolicyHint =
    'At least 6 characters, with 1 uppercase letter, 1 lowercase letter, and a number.';

String? passwordPolicyIssue(String password) {
  if (password.length < 6) return 'Minimum 6 characters';
  if (!RegExp(_upper).hasMatch(password)) {
    return 'Must contain at least one uppercase letter';
  }
  if (!RegExp(_lower).hasMatch(password)) {
    return 'Must contain at least one lowercase letter';
  }
  if (!RegExp(_digit).hasMatch(password)) {
    return 'Must contain at least one number';
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
    return 'Must contain letters';
  }
  return null;
}

bool passwordMeetsPolicy(String password) =>
    passwordPolicyIssue(password) == null;

String? validateNewPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'New password is required';
  }
  return passwordPolicyIssue(value);
}
