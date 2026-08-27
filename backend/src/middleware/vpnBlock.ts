import type { NextFunction, Request, Response } from 'express';
import { env } from '../config/env';
import { connectRedis, redis } from '../config/redis';
import { fail } from '../utils/response';

const CACHE_PREFIX = 'vpnblock:v1:';
const ALLOW_TTL_SEC = 6 * 60 * 60;
const DENY_TTL_SEC = 5 * 60;
const LOOKUP_TIMEOUT_MS = 4000;

const VPN_ORG_RE =
  /\b(vpn|protonvpn|nordvpn|nord security|mullvad|expressvpn|surfshark|windscribe|cyberghost|hide\.me|hidemyass|private internet access|\bpia\b|ipvanish|tunnelbear|vyprvpn|hotspot shield|urban vpn|opera vpn|psiphon|tor[- ]exit|cloudflare warp| maglev |datacamp|m247)\b/i;

type Lookup = { blocked: boolean; reason: string };

const memory = new Map<string, { until: number; value: Lookup }>();

function vpnBlockEnabled(): boolean {
  if (env.VPN_BLOCK_ENABLED === true) return true;
  if (env.VPN_BLOCK_ENABLED === false) return false;
  return env.NODE_ENV === 'production';
}

function allowList(): Set<string> {
  return new Set(
    (env.VPN_ALLOW_IPS ?? '')
      .split(',')
      .map((s) => normalizeIp(s))
      .filter(Boolean),
  );
}

export function normalizeIp(raw: string): string {
  let ip = raw.trim().replace(/^::ffff:/i, '');
  if (ip.startsWith('[') && ip.includes(']')) {
    ip = ip.slice(1, ip.indexOf(']'));
  } else if (/^\d{1,3}(?:\.\d{1,3}){3}:\d+$/.test(ip)) {
    ip = ip.slice(0, ip.lastIndexOf(':'));
  }
  return ip;
}

export function clientIp(req: Request): string {
  const parts: string[] = [];
  const xf = req.headers['x-forwarded-for'];
  if (typeof xf === 'string') parts.push(...xf.split(','));
  else if (Array.isArray(xf)) parts.push(...xf.flatMap((s) => s.split(',')));
  const realIp = req.headers['x-real-ip'];
  if (typeof realIp === 'string') parts.push(realIp);
  if (req.ip) parts.push(req.ip);
  if (req.socket.remoteAddress) parts.push(req.socket.remoteAddress);

  const ips = parts.map(normalizeIp).filter(Boolean);
  return ips.find((ip) => !isPrivateOrLocalIp(ip)) ?? ips[0] ?? '';
}

export function isPrivateOrLocalIp(ip: string): boolean {
  if (!ip) return true;
  const v4 = ip.replace(/^::ffff:/i, '');
  if (v4 === '::1' || v4.toLowerCase() === 'localhost') return true;
  const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(v4);
  if (!m) {
    const lower = v4.toLowerCase();
    return lower.startsWith('fc') || lower.startsWith('fd') || lower.startsWith('fe80:');
  }
  const a = Number(m[1]);
  const b = Number(m[2]);
  if (a === 127 || a === 10 || a === 0) return true;
  if (a === 192 && b === 168) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 169 && b === 254) return true;
  return false;
}

function memoryGet(ip: string): Lookup | null {
  const row = memory.get(ip);
  if (!row) return null;
  if (row.until < Date.now()) {
    memory.delete(ip);
    return null;
  }
  return row.value;
}

function memorySet(ip: string, value: Lookup, ttlSec: number) {
  if (memory.size > 8000) memory.clear();
  memory.set(ip, { value, until: Date.now() + ttlSec * 1000 });
}

async function cachedLookup(ip: string): Promise<Lookup | null> {
  const mem = memoryGet(ip);
  if (mem) return mem;
  try {
    await connectRedis();
    const raw = await redis.get(CACHE_PREFIX + ip);
    if (raw === '0' || raw === '1') {
      const value: Lookup = {
        blocked: raw === '1',
        reason: raw === '1' ? 'cached' : 'cached-allow',
      };
      memorySet(ip, value, 60);
      return value;
    }
  } catch {
    // redis optional
  }
  return null;
}

async function storeLookup(ip: string, value: Lookup) {
  const ttl = value.blocked ? DENY_TTL_SEC : ALLOW_TTL_SEC;
  memorySet(ip, value, ttl);
  try {
    await connectRedis();
    await redis.set(CACHE_PREFIX + ip, value.blocked ? '1' : '0', { EX: ttl });
  } catch {
    // redis optional
  }
}

async function lookupIpApi(ip: string): Promise<Lookup> {
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), LOOKUP_TIMEOUT_MS);
  try {
    const url = `http://ip-api.com/json/${encodeURIComponent(ip)}?fields=status,message,proxy,hosting,query,isp,org,as`;
    const res = await fetch(url, {
      signal: ac.signal,
      headers: { 'User-Agent': 'nb-crm-vpn-gate/1.0' },
    });
    if (!res.ok) return { blocked: false, reason: `ip-api-http-${res.status}` };
    const data = (await res.json()) as {
      status?: string;
      proxy?: boolean;
      hosting?: boolean;
      isp?: string;
      org?: string;
      as?: string;
    };
    if (data.status !== 'success') return { blocked: false, reason: 'ip-api-unsuccessful' };

    const blob = `${data.org ?? ''} ${data.isp ?? ''} ${data.as ?? ''}`;
    if (data.proxy === true) return { blocked: true, reason: 'proxy' };
    if (data.hosting === true) return { blocked: true, reason: `hosting:${data.org || data.isp || 'unknown'}` };
    if (VPN_ORG_RE.test(blob)) return { blocked: true, reason: `org:${blob.trim().slice(0, 80)}` };
    return { blocked: false, reason: 'clear' };
  } catch {
    // Fail open so office access is not lost if the lookup API is down.
    return { blocked: false, reason: 'lookup-failed' };
  } finally {
    clearTimeout(timer);
  }
}

export async function isBlockedVpnIp(ip: string): Promise<Lookup> {
  if (!ip || isPrivateOrLocalIp(ip)) return { blocked: false, reason: 'private' };
  if (allowList().has(ip)) return { blocked: false, reason: 'allowlist' };

  const cached = await cachedLookup(ip);
  if (cached) return cached;

  const looked = await lookupIpApi(ip);
  if (looked.blocked || looked.reason === 'clear') {
    await storeLookup(ip, looked);
  }
  return looked;
}

function deny(res: Response, gate: boolean) {
  if (gate) return res.status(403).end();
  return res.status(403).json(fail('VPN and proxy connections are not allowed. Turn off your VPN and try again.'));
}

export async function vpnBlockMiddleware(req: Request, res: Response, next: NextFunction) {
  const gate = req.path === '/vpn-gate';
  try {
    const enabled = vpnBlockEnabled();

    if (!enabled) {
      if (gate) return res.status(204).end();
      return next();
    }

    if (req.method === 'OPTIONS') return next();
    if (req.path === '/health') return next();

    const ip = clientIp(req);
    const result = await isBlockedVpnIp(ip);
    if (result.blocked) {
      console.warn(`[vpn-block] ip=${ip} reason=${result.reason} path=${req.path}`);
      return deny(res, gate);
    }
    if (gate) return res.status(204).end();
    return next();
  } catch (err) {
    console.error('[vpn-block] failed', err);
    if (gate) return res.status(204).end();
    return next();
  }
}
