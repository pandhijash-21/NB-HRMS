import { prisma } from '../../config/prisma';
import { env } from '../../config/env';
import { sseService } from '../events/sse.service';
import nodemailer from 'nodemailer';
import type { WebAttendanceGateResult } from './webAttendanceGate';

const ADMIN_ROLES = [
  'ADMIN',
  'SUPERADMIN',
  'SUPER_ADMIN',
  'SYSTEMADMIN',
  'SYSTEM_ADMIN',
  'HR',
  'DEVELOPER',
];

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

export type WebAttendanceAdminAlert = {
  type: 'web_punch' | 'web_register';
  employeeId: number;
  fullName: string;
  employeeCode: string | null;
  deviceLabel: string;
  browserLabel: string;
  userAgent: string;
  punchAt: string | null;
  notifiedAt: string;
};

async function loadEmployeeBrief(employeeId: number) {
  const emp = await prisma.employee.findUnique({
    where: { id: employeeId },
    select: {
      id: true,
      generalInfo: { select: { fullName: true, employeeCode: true } },
    },
  });
  return {
    fullName: emp?.generalInfo?.fullName ?? `Employee #${employeeId}`,
    employeeCode: emp?.generalInfo?.employeeCode ?? null,
  };
}

/** Fire-and-forget admin SSE + optional email when someone uses iOS Safari web attendance. */
export async function notifyAdminsWebAttendance(opts: {
  type: 'web_punch' | 'web_register';
  employeeId: number;
  gate: WebAttendanceGateResult;
  punchAt?: string | null;
}) {
  try {
    const brief = await loadEmployeeBrief(opts.employeeId);
    const alert: WebAttendanceAdminAlert = {
      type: opts.type,
      employeeId: opts.employeeId,
      fullName: brief.fullName,
      employeeCode: brief.employeeCode,
      deviceLabel: opts.gate.deviceLabel,
      browserLabel: opts.gate.browserLabel,
      userAgent: opts.gate.userAgent,
      punchAt: opts.punchAt ?? null,
      notifiedAt: new Date().toISOString(),
    };

    sseService.toAdmins('attendance_web_client', alert);

    const emails = await resolveAdminEmails();
    const t = getTransport();
    if (!t || emails.length === 0) return;

    const action =
      opts.type === 'web_punch'
        ? 'punched in/out from a browser'
        : 'registered a browser for attendance';

    const html = `
      <h2>Web attendance activity</h2>
      <p><strong>${alert.fullName}</strong> ${action}.</p>
      <table cellpadding="6" style="border-collapse:collapse">
        <tr><td><strong>Employee</strong></td><td>${alert.fullName}</td></tr>
        <tr><td><strong>Employee ID</strong></td><td>${alert.employeeId}</td></tr>
        <tr><td><strong>Code</strong></td><td>${alert.employeeCode ?? '—'}</td></tr>
        <tr><td><strong>Device</strong></td><td>${alert.deviceLabel}</td></tr>
        <tr><td><strong>Browser</strong></td><td>${alert.browserLabel}</td></tr>
        <tr><td><strong>When</strong></td><td>${alert.punchAt ?? alert.notifiedAt}</td></tr>
        <tr><td><strong>User-Agent</strong></td><td style="font-size:12px">${alert.userAgent || '—'}</td></tr>
      </table>
    `;

    await t.sendMail({
      from: env.SMTP_FROM || env.SMTP_USER,
      to: emails.join(','),
      subject: `[Attendance] ${alert.fullName} — ${alert.browserLabel} on ${alert.deviceLabel}`,
      html,
    });
  } catch (err) {
    console.warn('[attendance-web] admin notify failed', err);
  }
}
