import { prisma } from '../../config/prisma';
import { env } from '../../config/env';
import { sseService } from '../events/sse.service';
import { getRedisClient } from '../../config/redis';
import nodemailer from 'nodemailer';

const ADMIN_ROLES = [
  'ADMIN',
  'SUPERADMIN',
  'SUPER_ADMIN',
  'SYSTEMADMIN',
  'SYSTEM_ADMIN',
  'HR',
  'DEVELOPER',
];

const ALERTS_KEY = 'admin:location_alerts';
const ACTIVE_ALERTS_KEY = 'admin:location_alerts_active';
const ALERTS_MAX = 50;

export type LocationUnavailableAlert = {
  id: string;
  employeeId: number;
  fullName: string;
  employeeCode: string | null;
  designation: string | null;
  department: string | null;
  punchIn: string | null;
  punchOut: string | null;
  unavailableSince: string;
  durationSeconds: number;
  reason: string | null;
  confidence: string | null;
  lastKnownLatitude: number | null;
  lastKnownLongitude: number | null;
  lastKnownAt: string | null;
  tripId: string | null;
  notifiedAt: string;
  resolvedAt?: string | null;
  active?: boolean;
};

function createTransport() {
  if (!env.SMTP_HOST || !env.SMTP_USER || !env.SMTP_PASS) return null;
  return nodemailer.createTransport({
    host: env.SMTP_HOST,
    port: env.SMTP_PORT,
    secure: env.SMTP_SECURE ?? false,
    auth: { user: env.SMTP_USER, pass: env.SMTP_PASS },
  });
}

let _t: ReturnType<typeof nodemailer.createTransport> | null = null;
function getTransport() {
  if (!_t) _t = createTransport();
  return _t;
}

function formatDuration(seconds: number) {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m`;
  return `${seconds}s`;
}

function formatLocal(iso: string | null) {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
  } catch {
    return iso;
  }
}

async function resolveAdminEmails(): Promise<string[]> {
  const users = await prisma.user.findMany({
    where: {
      isActive: true,
      role: { name: { in: ADMIN_ROLES } },
    },
    select: {
      employee: {
        select: {
          addresses: {
            select: { instituteEmail: true, personalEmail: true },
          },
        },
      },
    },
  });

  const emails = new Set<string>();
  for (const u of users) {
    for (const addr of u.employee?.addresses ?? []) {
      const email = addr.instituteEmail || addr.personalEmail;
      if (email && email.includes('@')) emails.add(email.trim());
    }
  }
  return [...emails];
}

export async function pushRecentAlert(alert: LocationUnavailableAlert) {
  try {
    const redis = getRedisClient();
    const payload = JSON.stringify({ ...alert, active: true, resolvedAt: null });
    await redis.hSet(ACTIVE_ALERTS_KEY, String(alert.employeeId), payload);
    await redis.expire(ACTIVE_ALERTS_KEY, 60 * 60 * 24);
    await redis.lPush(ALERTS_KEY, payload);
    await redis.lTrim(ALERTS_KEY, 0, ALERTS_MAX - 1);
    await redis.expire(ALERTS_KEY, 60 * 60 * 24);
  } catch (err) {
    console.warn('[tracking-alert] redis push failed', err);
  }
}

export async function getActiveLocationAlerts(): Promise<LocationUnavailableAlert[]> {
  try {
    const redis = getRedisClient();
    const raw = await redis.hVals(ACTIVE_ALERTS_KEY);
    return raw
      .map((item) => {
        try {
          return JSON.parse(item) as LocationUnavailableAlert;
        } catch {
          return null;
        }
      })
      .filter((x): x is LocationUnavailableAlert => x != null && x.active !== false)
      .sort((a, b) => String(b.notifiedAt).localeCompare(String(a.notifiedAt)));
  } catch {
    return [];
  }
}

export async function getRecentLocationAlerts(): Promise<LocationUnavailableAlert[]> {
  return getActiveLocationAlerts();
}

export async function resolveLocationAlert(employeeId: number): Promise<LocationUnavailableAlert | null> {
  try {
    const redis = getRedisClient();
    await redis.del(`alert:loc_off:${employeeId}`);
    const existing = await redis.hGet(ACTIVE_ALERTS_KEY, String(employeeId));
    if (!existing) return null;
    const parsed = JSON.parse(existing) as LocationUnavailableAlert;
    const resolved: LocationUnavailableAlert = {
      ...parsed,
      active: false,
      resolvedAt: new Date().toISOString(),
    };
    await redis.hDel(ACTIVE_ALERTS_KEY, String(employeeId));
    sseService.toAdmins('location_available', resolved);
    return resolved;
  } catch (err) {
    console.warn('[tracking-alert] resolve failed', err);
    return null;
  }
}

export async function notifyAdminsLocationUnavailable(alert: LocationUnavailableAlert) {
  await pushRecentAlert(alert);

  sseService.toAdmins('location_unavailable', alert);

  const emails = await resolveAdminEmails();
  const t = getTransport();
  if (!t || emails.length === 0) return;

  const mapsLink =
    alert.lastKnownLatitude != null && alert.lastKnownLongitude != null
      ? `https://www.google.com/maps?q=${alert.lastKnownLatitude},${alert.lastKnownLongitude}`
      : null;

  const html = `
    <h2>Live location unavailable</h2>
    <p>An employee stopped reporting GPS while on duty (between punch-in and punch-out).</p>
    <table cellpadding="6" style="border-collapse:collapse">
      <tr><td><strong>Employee</strong></td><td>${alert.fullName}</td></tr>
      <tr><td><strong>Employee ID</strong></td><td>${alert.employeeId}</td></tr>
      <tr><td><strong>Code</strong></td><td>${alert.employeeCode ?? '—'}</td></tr>
      <tr><td><strong>Designation</strong></td><td>${alert.designation ?? '—'}</td></tr>
      <tr><td><strong>Department</strong></td><td>${alert.department ?? '—'}</td></tr>
      <tr><td><strong>Punch in</strong></td><td>${formatLocal(alert.punchIn)}</td></tr>
      <tr><td><strong>Punch out</strong></td><td>${formatLocal(alert.punchOut)}</td></tr>
      <tr><td><strong>Unavailable since</strong></td><td>${formatLocal(alert.unavailableSince)}</td></tr>
      <tr><td><strong>Duration so far</strong></td><td>${formatDuration(alert.durationSeconds)}</td></tr>
      <tr><td><strong>Reason</strong></td><td>${(alert.reason ?? 'NO_LOCATION_PING').replace(/_/g, ' ')}</td></tr>
      <tr><td><strong>Confidence</strong></td><td>${alert.confidence ?? '—'}</td></tr>
      <tr><td><strong>Last known location</strong></td><td>${
        mapsLink
          ? `<a href="${mapsLink}">${alert.lastKnownLatitude}, ${alert.lastKnownLongitude}</a>`
          : 'Unknown'
      }</td></tr>
      <tr><td><strong>Last ping</strong></td><td>${formatLocal(alert.lastKnownAt)}</td></tr>
    </table>
    <p><a href="${env.FRONTEND_URL}/admin/tracking-hub">Open Tracking Hub</a></p>
  `;

  try {
    await t.sendMail({
      from: `"HRMS Tracking" <${env.SMTP_FROM ?? env.SMTP_USER}>`,
      to: emails.join(', '),
      subject: `Location unavailable — ${alert.fullName} (#${alert.employeeId})`,
      html,
    });
  } catch (err) {
    console.warn('[tracking-alert] email failed', err);
  }
}
