/** Format birth date as default login password DDMMYYYY (UTC calendar day). */
export function passwordFromBirthDate(dob: Date): string {
  const d = String(dob.getUTCDate()).padStart(2, '0');
  const m = String(dob.getUTCMonth() + 1).padStart(2, '0');
  const y = dob.getUTCFullYear();
  return `${d}${m}${y}`;
}

/** Parse YYYY-MM-DD or ISO into a UTC date (avoids timezone day-shift). */
export function parseBirthDateInput(input: string | Date): Date {
  if (input instanceof Date) {
    return new Date(Date.UTC(input.getUTCFullYear(), input.getUTCMonth(), input.getUTCDate()));
  }
  const ymd = /^(\d{4})-(\d{2})-(\d{2})/.exec(input.trim());
  if (ymd) {
    return new Date(Date.UTC(Number(ymd[1]), Number(ymd[2]) - 1, Number(ymd[3])));
  }
  const parsed = new Date(input);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error('Invalid birth date');
  }
  return new Date(Date.UTC(parsed.getUTCFullYear(), parsed.getUTCMonth(), parsed.getUTCDate()));
}
