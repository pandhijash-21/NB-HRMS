/**
 * Phone and Country Code Normalization Utility for CRM Deduplication and Telephony
 * 
 * Provides unified, canonical phone number parsing, country code extraction,
 * deduplication key generation, and telephony dialing formatting.
 */

export interface NormalizedPhone {
  raw: string;
  countryCode: string;       // e.g. "91", "1", "971", "44"
  nationalNumber: string;    // e.g. "9876543210", "501234567"
  e164: string;              // e.g. "+919876543210", "+971501234567"
  dedupeKey: string;         // e.g. "+91:9876543210", "+971:501234567"
  dialDigits: string;        // telephony dialable digits (10 digits for domestic 91, full for intl)
  isStandard: boolean;
}

// Map of common country names, ISO codes, and aliases to dialing codes
const COUNTRY_NAME_TO_CODE: Record<string, string> = {
  india: '91',
  in: '91',
  ind: '91',
  uae: '971',
  ae: '971',
  are: '971',
  'united arab emirates': '971',
  dubai: '971',
  'abu dhabi': '971',
  'saudi arabia': '966',
  sa: '966',
  sau: '966',
  ksa: '966',
  qatar: '974',
  qa: '974',
  qat: '974',
  oman: '968',
  om: '968',
  omn: '968',
  kuwait: '965',
  kw: '965',
  kwt: '965',
  bahrain: '973',
  bh: '973',
  bhr: '973',
  'united states': '1',
  usa: '1',
  us: '1',
  canada: '1',
  ca: '1',
  can: '1',
  'united kingdom': '44',
  uk: '44',
  gb: '44',
  gbr: '44',
  'great britain': '44',
  singapore: '65',
  sg: '65',
  sgp: '65',
  australia: '61',
  au: '61',
  aus: '61',
  malaysia: '60',
  my: '60',
  mys: '60',
  germany: '49',
  de: '49',
  deu: '49',
  france: '33',
  fr: '33',
  fra: '33',
  spain: '34',
  es: '34',
  esp: '34',
  italy: '39',
  it: '39',
  ita: '39',
  netherlands: '31',
  nl: '31',
  nld: '31',
  switzerland: '41',
  ch: '41',
  che: '41',
  'south africa': '27',
  za: '27',
  zaf: '27',
  'new zealand': '64',
  nz: '64',
  nzl: '64',
  china: '86',
  cn: '86',
  chn: '86',
  japan: '81',
  jp: '81',
  jpn: '81',
  philippines: '63',
  ph: '63',
  phl: '63',
  indonesia: '62',
  id: '62',
  idn: '62',
  thailand: '66',
  th: '66',
  tha: '66',
  bangladesh: '880',
  bd: '880',
  bgd: '880',
  nepal: '977',
  np: '977',
  npl: '977',
  'sri lanka': '94',
  lk: '94',
  lka: '94',
  pakistan: '92',
  pk: '92',
  pak: '92',
  egypt: '20',
  eg: '20',
  egy: '20',
  nigeria: '234',
  ng: '234',
  nga: '234',
  kenya: '254',
  ke: '254',
  ken: '254',
};

// Recognized international dialing prefixes sorted longest first for prefix matching
const KNOWN_COUNTRY_CODES = [
  // 3-digit
  '971', '966', '974', '968', '965', '973', '852', '880', '977', '353', '358', '351', '352',
  '354', '356', '357', '370', '371', '372', '380', '381', '385', '386', '387', '234', '254',
  '255', '256', '233', '502', '503', '504', '505', '506', '507',
  // 2-digit
  '91', '44', '61', '65', '60', '62', '66', '63', '81', '82', '86', '49', '33', '39', '34',
  '31', '32', '41', '43', '46', '47', '45', '48', '20', '27', '64', '94', '92', '90', '55',
  '52', '54', '56', '57', '58',
  // 1-digit
  '1', '7',
];

/** Clean string to digits only. */
export function digitsOnly(val: any): string {
  if (val === null || val === undefined) return '';
  return String(val).replace(/\D/g, '');
}

/**
 * Resolves a raw country code string or name into numeric calling code (e.g. "+91" -> "91", "UAE" -> "971").
 */
export function parseCountryDialCode(rawCountryCode: any): string {
  if (!rawCountryCode) return '';
  const str = String(rawCountryCode).trim().toLowerCase();
  if (COUNTRY_NAME_TO_CODE[str]) {
    return COUNTRY_NAME_TO_CODE[str];
  }
  const clean = str.replace(/[^\w\s]/g, '').trim();
  if (COUNTRY_NAME_TO_CODE[clean]) {
    return COUNTRY_NAME_TO_CODE[clean];
  }
  const digits = digitsOnly(rawCountryCode);
  if (digits.startsWith('00')) return digits.slice(2);
  return digits;
}

/**
 * Normalizes any phone number with optional explicit country code.
 * Guaranteed behavior:
 * 1. Domestic variations (+91 9876543210, 919876543210, 09876543210, 9876543210) produce "+91:9876543210".
 * 2. Cross-country collisions are eliminated: US (+1 9876543210) -> "+1:9876543210" !== "+91:9876543210".
 * 3. International non-10-digit numbers (UAE +971 50 1234567, SG +65 9123 4567) are preserved cleanly.
 * 4. Generates dialDigits optimized for CRM telephony providers.
 */
export function normalizePhoneWithCountryCode(
  rawPhone: any,
  rawCountryCode?: any,
): NormalizedPhone {
  const rawStr = String(rawPhone || '').trim();
  if (!rawStr) {
    return {
      raw: '',
      countryCode: '',
      nationalNumber: '',
      e164: '',
      dedupeKey: '',
      dialDigits: '',
      isStandard: false,
    };
  }

  const explicitCc = parseCountryDialCode(rawCountryCode);
  const cleanPhoneDigits = digitsOnly(rawStr);
  const hasLeadingPlus = rawStr.startsWith('+') || rawStr.startsWith('00');
  const digitsWithoutTrunkIntl = rawStr.startsWith('00') ? cleanPhoneDigits.slice(2) : cleanPhoneDigits;

  let countryCode = '';
  let nationalNumber = '';

  if (explicitCc) {
    countryCode = explicitCc;
    let national = digitsWithoutTrunkIntl;
    // Strip duplicated country code from phone start if already present
    if (national.startsWith(explicitCc) && national.length > explicitCc.length + 5) {
      national = national.slice(explicitCc.length);
    }
    // Strip leading trunk zero (e.g. 09876543210 -> 9876543210)
    if (national.startsWith('0') && national.length >= 10) {
      national = national.replace(/^0+/, '');
    }
    nationalNumber = national;
  } else if (hasLeadingPlus) {
    // Matched prefix from known international country codes
    const matchedPrefix = KNOWN_COUNTRY_CODES.find((code) => digitsWithoutTrunkIntl.startsWith(code));
    if (matchedPrefix && digitsWithoutTrunkIntl.length > matchedPrefix.length) {
      countryCode = matchedPrefix;
      nationalNumber = digitsWithoutTrunkIntl.slice(matchedPrefix.length);
      // Strip trunk zero if present in national part
      if (nationalNumber.startsWith('0') && nationalNumber.length > 7) {
        nationalNumber = nationalNumber.replace(/^0+/, '');
      }
    } else {
      // Fallback for unknown prefix: if > 10 digits, assume prefix is everything before last 10
      if (digitsWithoutTrunkIntl.length > 10) {
        countryCode = digitsWithoutTrunkIntl.slice(0, digitsWithoutTrunkIntl.length - 10);
        nationalNumber = digitsWithoutTrunkIntl.slice(-10);
      } else {
        countryCode = '91';
        nationalNumber = digitsWithoutTrunkIntl;
      }
    }
  } else {
    // No leading plus and no explicit country code
    if (cleanPhoneDigits.length === 10) {
      // Standard Indian 10-digit mobile or landline
      countryCode = '91';
      nationalNumber = cleanPhoneDigits;
    } else if (cleanPhoneDigits.length === 11 && cleanPhoneDigits.startsWith('0')) {
      // Indian domestic with trunk 0: 09876543210
      countryCode = '91';
      nationalNumber = cleanPhoneDigits.slice(1);
    } else if (cleanPhoneDigits.length === 12 && cleanPhoneDigits.startsWith('91')) {
      // Indian phone with 91 prefix: 919876543210
      countryCode = '91';
      nationalNumber = cleanPhoneDigits.slice(2);
    } else if (cleanPhoneDigits.length === 11 && cleanPhoneDigits.startsWith('1')) {
      // US/Canada phone with 1 prefix: 14155552671
      countryCode = '1';
      nationalNumber = cleanPhoneDigits.slice(1);
    } else if (cleanPhoneDigits.length === 12 && cleanPhoneDigits.startsWith('971')) {
      // UAE phone with 971 prefix: 971501234567
      countryCode = '971';
      nationalNumber = cleanPhoneDigits.slice(3);
    } else if (cleanPhoneDigits.length === 12 && cleanPhoneDigits.startsWith('966')) {
      // Saudi phone with 966 prefix
      countryCode = '966';
      nationalNumber = cleanPhoneDigits.slice(3);
    } else if (cleanPhoneDigits.length === 12 && cleanPhoneDigits.startsWith('44')) {
      // UK phone with 44 prefix
      countryCode = '44';
      nationalNumber = cleanPhoneDigits.slice(2);
    } else if (cleanPhoneDigits.length === 10 && cleanPhoneDigits.startsWith('65')) {
      // Singapore phone with 65 prefix
      countryCode = '65';
      nationalNumber = cleanPhoneDigits.slice(2);
    } else {
      // Check any known prefix
      const matchedPrefix = KNOWN_COUNTRY_CODES.find((code) => cleanPhoneDigits.startsWith(code));
      if (matchedPrefix && cleanPhoneDigits.length >= matchedPrefix.length + 7) {
        countryCode = matchedPrefix;
        nationalNumber = cleanPhoneDigits.slice(matchedPrefix.length);
        if (nationalNumber.startsWith('0') && nationalNumber.length > 7) {
          nationalNumber = nationalNumber.replace(/^0+/, '');
        }
      } else {
        // Fallback default country India
        countryCode = '91';
        nationalNumber = cleanPhoneDigits.length >= 10 ? cleanPhoneDigits.slice(-10) : cleanPhoneDigits;
      }
    }
  }

  // Final cleanup of national number
  nationalNumber = digitsOnly(nationalNumber);

  const isStandard = Boolean(countryCode && nationalNumber && nationalNumber.length >= 7);
  const e164 = isStandard ? `+${countryCode}${nationalNumber}` : rawStr;
  const dedupeKey = isStandard ? `+${countryCode}:${nationalNumber}` : cleanPhoneDigits;

  // Dial digits for telephony:
  // For Indian domestic calls (countryCode '91'): 10-digit national number is standard for Indian PSTN/SIP trunks
  // For international calls: full international digits (country code + national number)
  const dialDigits =
    countryCode === '91' && nationalNumber.length === 10
      ? nationalNumber
      : `${countryCode}${nationalNumber}` || cleanPhoneDigits;

  return {
    raw: rawStr,
    countryCode,
    nationalNumber,
    e164,
    dedupeKey,
    dialDigits,
    isStandard,
  };
}

/**
 * Checks if a header column name corresponds to country / dial code in Excel
 */
export function isCountryCodeHeader(headerName: string): boolean {
  const l = String(headerName || '').trim().toLowerCase();
  if (!l) return false;
  return (
    l === 'country code' ||
    l === 'country_code' ||
    l === 'countrycode' ||
    l === 'isd' ||
    l === 'isd code' ||
    l === 'isd_code' ||
    l === 'isdcode' ||
    l === 'dial code' ||
    l === 'dial_code' ||
    l === 'dialcode' ||
    l === 'country dial code' ||
    l === 'country_dial_code' ||
    l === 'phone code' ||
    l === 'phone_code' ||
    l === 'calling code' ||
    l === 'calling_code'
  );
}

/**
 * Checks if a phone number string is an obvious dummy/placeholder
 */
export function isDummyOrPlaceholderPhone(digits: string): boolean {
  if (!digits || digits.length < 7) return true;
  // Repeating identical digit (0000000000, 1111111111, 9999999999)
  if (/^(\d)\1+$/.test(digits)) return true;
  // Sequential ascending or descending patterns
  if (['1234567890', '0123456789', '9876543210', '0000000000'].includes(digits)) return true;
  return false;
}
