/** Shared company-profile + bank fields for Organization and Institute. */

export type CompanyProfileInput = {
  registrationNo?: string | null;
  establishmentYear?: number | null;
  contactPerson?: string | null;
  mobileNo?: string | null;
  contactNo?: string | null;
  email?: string | null;
  webAddress?: string | null;
  panNo?: string | null;
  gstNo?: string | null;
  cinNo?: string | null;
  country?: string | null;
  state?: string | null;
  city?: string | null;
  address1?: string | null;
  address2?: string | null;
  pinCode?: string | null;
  tagLine?: string | null;
  hostingUrl?: string | null;
  pageSize?: string | null;
  dateFormat?: string | null;
  timeZone?: string | null;
  socialPostUrl?: string | null;
  bankName?: string | null;
  accountHolderName?: string | null;
  bankAccountNo?: string | null;
  ifscCode?: string | null;
  bankBranch?: string | null;
};

const OPTIONAL_STRING_KEYS = [
  'registrationNo',
  'contactPerson',
  'mobileNo',
  'contactNo',
  'email',
  'webAddress',
  'panNo',
  'gstNo',
  'cinNo',
  'country',
  'state',
  'city',
  'address1',
  'address2',
  'pinCode',
  'tagLine',
  'hostingUrl',
  'pageSize',
  'dateFormat',
  'timeZone',
  'socialPostUrl',
  'bankName',
  'accountHolderName',
  'bankAccountNo',
  'ifscCode',
  'bankBranch',
] as const;

export const REQUIRED_COMPANY_FIELDS: Array<{ key: keyof CompanyProfileInput; label: string }> = [
  { key: 'contactPerson', label: 'Contact Person' },
  { key: 'mobileNo', label: 'Mobile No.' },
  { key: 'panNo', label: 'PAN No.' },
  { key: 'gstNo', label: 'GST No.' },
  { key: 'email', label: 'Email' },
  { key: 'country', label: 'Country' },
  { key: 'state', label: 'State' },
  { key: 'city', label: 'City' },
  { key: 'address1', label: 'Address 1' },
  { key: 'pinCode', label: 'Pin Code' },
];

function trimOrNull(v: unknown): string | null {
  if (v == null) return null;
  const s = String(v).trim();
  return s.length ? s : null;
}

export function parseCompanyProfileFromBody(body: Record<string, unknown>): CompanyProfileInput {
  const out: CompanyProfileInput = {};
  for (const key of OPTIONAL_STRING_KEYS) {
    if (Object.prototype.hasOwnProperty.call(body, key)) {
      (out as Record<string, string | null>)[key] = trimOrNull(body[key]);
    }
  }
  if (Object.prototype.hasOwnProperty.call(body, 'establishmentYear')) {
    const raw = body.establishmentYear;
    if (raw === null || raw === '' || raw === undefined) {
      out.establishmentYear = null;
    } else {
      const n = Number(raw);
      if (!Number.isFinite(n) || n < 1800 || n > 2100) {
        throw new Error('Invalid establishment year');
      }
      out.establishmentYear = Math.trunc(n);
    }
  }
  return out;
}

export function assertRequiredCompanyFields(profile: CompanyProfileInput, opts?: { requireAll?: boolean }) {
  if (!opts?.requireAll) return;
  const missing: string[] = [];
  for (const { key, label } of REQUIRED_COMPANY_FIELDS) {
    const v = profile[key];
    if (v == null || String(v).trim() === '') missing.push(label);
  }
  if (missing.length) {
    throw new Error(`Missing required fields: ${missing.join(', ')}`);
  }
}

/** Build Prisma data object from parsed profile (only keys present). */
export function companyProfileToPrismaData(profile: CompanyProfileInput): Record<string, unknown> {
  const data: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(profile)) {
    if (v !== undefined) data[k] = v;
  }
  return data;
}
