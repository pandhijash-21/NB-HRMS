import { env } from '../../config/env';

export type EtimePunchRow = {
  Name?: string | null;
  Empcode: string;
  PunchDate: string;
  M_Flag?: string | null;
  mcid?: string | null;
};

export type EtimeInOutRow = {
  Empcode: string;
  Name?: string | null;
  INTime?: string | null;
  OUTTime?: string | null;
  WorkTime?: string | null;
  OverTime?: string | null;
  Status?: string | null;
  DateString?: string | null;
  Remark?: string | null;
  Late_In?: string | null;
  Erl_Out?: string | null;
};

export type EtimeLastPunchResponse = {
  Error: boolean;
  Msg?: string;
  IsAdmin?: boolean;
  PunchData?: EtimePunchRow[];
  /** Some responses include MaxRecord / LastRecord for cursor */
  MaxRecord?: string;
  LastRecord?: string;
};

function authHeader(): string {
  const raw = `${env.ETIMEOFFICE_CORPORATE_ID}:${env.ETIMEOFFICE_USERNAME}:${env.ETIMEOFFICE_PASSWORD}:true`;
  return `Basic ${Buffer.from(raw, 'utf8').toString('base64')}`;
}

function baseUrl(): string {
  return env.ETIMEOFFICE_BASE_URL.replace(/\/$/, '');
}

async function getJson<T>(pathAndQuery: string): Promise<T> {
  const url = `${baseUrl()}${pathAndQuery.startsWith('/') ? '' : '/'}${pathAndQuery}`;
  const res = await fetch(url, {
    method: 'GET',
    headers: {
      Authorization: authHeader(),
      Accept: 'application/json',
    },
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`eTimeOffice HTTP ${res.status}: ${text || res.statusText}`);
  }
  return (await res.json()) as T;
}

/** Parse "dd/MM/yyyy HH:mm:ss" (or with single space variants) as IST → UTC Date. */
export function parseEtimePunchDate(raw: string): Date {
  const s = raw.trim().replace(/\s+/g, ' ');
  const m = /^(\d{2})\/(\d{2})\/(\d{4})[ T](\d{2}):(\d{2})(?::(\d{2}))?$/.exec(s);
  if (!m) throw new Error(`Invalid PunchDate: ${raw}`);
  const dd = m[1];
  const MM = m[2];
  const yyyy = m[3];
  const hh = m[4];
  const mm = m[5];
  const ss = m[6] ?? '00';
  const iso = `${yyyy}-${MM}-${dd}T${hh}:${mm}:${ss}+05:30`;
  const d = new Date(iso);
  if (!Number.isFinite(d.getTime())) throw new Error(`Invalid PunchDate: ${raw}`);
  return d;
}

/** Format Date → dd/MM/yyyy_HH:mm for FromDate/ToDate query params. */
export function formatEtimeRange(d: Date): string {
  const shifted = new Date(d.getTime() + 330 * 60 * 1000);
  const yyyy = shifted.getUTCFullYear();
  const MM = String(shifted.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(shifted.getUTCDate()).padStart(2, '0');
  const hh = String(shifted.getUTCHours()).padStart(2, '0');
  const mm = String(shifted.getUTCMinutes()).padStart(2, '0');
  return `${dd}/${MM}/${yyyy}_${hh}:${mm}`;
}

/** Format YYYY-MM-DD (IST calendar day) → start/end of day for API. */
export function ymdToEtimeFrom(ymd: string): string {
  return `${ymd.slice(8, 10)}/${ymd.slice(5, 7)}/${ymd.slice(0, 4)}_00:00`;
}
export function ymdToEtimeTo(ymd: string): string {
  return `${ymd.slice(8, 10)}/${ymd.slice(5, 7)}/${ymd.slice(0, 4)}_23:59`;
}

export function isEtimeofficeConfigured(): boolean {
  return Boolean(
    env.ETIMEOFFICE_CORPORATE_ID?.trim() &&
      env.ETIMEOFFICE_USERNAME?.trim() &&
      env.ETIMEOFFICE_PASSWORD?.trim(),
  );
}

/**
 * Incremental raw punches. First call: LastRecord like `092020$0` or empty;
 * sheet says first call use Mmyyyy$ID style — we use cursor from DB or `010100$0`.
 */
export async function fetchLastPunchData(lastRecord: string | null): Promise<{
  punches: EtimePunchRow[];
  nextCursor: string | null;
  msg?: string;
  error: boolean;
}> {
  const cursor = lastRecord && lastRecord.trim() ? lastRecord.trim() : '010100$0';
  const q = `/api/DownloadLastPunchData?Empcode=ALL&LastRecord=${encodeURIComponent(cursor)}`;
  const data = await getJson<EtimeLastPunchResponse & Record<string, unknown>>(q);
  if (data.Error) {
    throw new Error(data.Msg || 'eTimeOffice LastPunch error');
  }
  const punches = Array.isArray(data.PunchData) ? data.PunchData : [];
  const next =
    (typeof data.MaxRecord === 'string' && data.MaxRecord) ||
    (typeof data.LastRecord === 'string' && data.LastRecord) ||
    (typeof (data as unknown as { maxRecord?: string }).maxRecord === 'string'
      ? (data as unknown as { maxRecord: string }).maxRecord
      : null) ||
    null;
  return { punches, nextCursor: next, msg: data.Msg, error: false };
}

export async function fetchPunchDataMcid(params: {
  empcode?: string;
  fromYmd: string;
  toYmd: string;
}): Promise<EtimePunchRow[]> {
  const emp = params.empcode?.trim() || 'ALL';
  const from = ymdToEtimeFrom(params.fromYmd);
  const to = ymdToEtimeTo(params.toYmd);
  const q = `/api/DownloadPunchDataMCID?Empcode=${encodeURIComponent(emp)}&FromDate=${encodeURIComponent(from)}&ToDate=${encodeURIComponent(to)}`;
  const data = await getJson<EtimeLastPunchResponse>(q);
  if (data.Error) throw new Error(data.Msg || 'eTimeOffice PunchDataMCID error');
  return Array.isArray(data.PunchData) ? data.PunchData : [];
}

export async function fetchInOutPunchData(params: {
  empcode?: string;
  fromYmd: string;
  toYmd: string;
}): Promise<EtimeInOutRow[]> {
  const emp = params.empcode?.trim() || 'ALL';
  // InOut API uses date-only in the sample sheet
  const from = `${params.fromYmd.slice(8, 10)}/${params.fromYmd.slice(5, 7)}/${params.fromYmd.slice(0, 4)}`;
  const to = `${params.toYmd.slice(8, 10)}/${params.toYmd.slice(5, 7)}/${params.toYmd.slice(0, 4)}`;
  const q = `/api/DownloadInOutPunchData?Empcode=${encodeURIComponent(emp)}&FromDate=${encodeURIComponent(from)}&ToDate=${encodeURIComponent(to)}`;
  const data = await getJson<{
    Error: boolean;
    Msg?: string;
    InOutPunchData?: EtimeInOutRow[];
  }>(q);
  if (data.Error) throw new Error(data.Msg || 'eTimeOffice InOut error');
  return Array.isArray(data.InOutPunchData) ? data.InOutPunchData : [];
}

export function buildExternalKey(row: EtimePunchRow): string {
  const code = String(row.Empcode ?? '').trim();
  const when = String(row.PunchDate ?? '').trim();
  const mcid = String(row.mcid ?? row.M_Flag ?? '').trim() || '0';
  return `ETIME|${code}|${when}|${mcid}`;
}
