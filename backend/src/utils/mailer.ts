import nodemailer from 'nodemailer';
import { env } from '../config/env';

function createTransport() {
  if (!env.SMTP_HOST || !env.SMTP_USER || !env.SMTP_PASS) {
    return null;
  }
  return nodemailer.createTransport({
    host:   env.SMTP_HOST,
    port:   env.SMTP_PORT,
    secure: env.SMTP_SECURE ?? false,
    auth: {
      user: env.SMTP_USER,
      // Gmail app passwords are often pasted with spaces — strip them.
      pass: env.SMTP_PASS.replace(/\s+/g, ''),
    },
  });
}

// Lazily created so startup doesn't fail when SMTP is not configured
let _transporter: ReturnType<typeof nodemailer.createTransport> | null = null;

function getTransporter() {
  if (!_transporter) _transporter = createTransport();
  return _transporter;
}

export async function sendAccountCreatedEmail(
  to: string,
  employeeId: number,
  tempPassword: string
) {
  const t = getTransporter();
  if (!t || !to) return; // SMTP not configured or no email address — skip silently

  await t.sendMail({
    from:    `"HRMS – Gandhinagar University" <${env.SMTP_FROM ?? env.SMTP_USER}>`,
    to,
    subject: 'Your HRMS Account Has Been Created',
    html: `
      <h2>Welcome to HRMS</h2>
      <p>Your account has been created. Use the following credentials to log in:</p>
      <p><strong>Employee ID:</strong> ${employeeId}</p>
      <p><strong>Temporary Password:</strong> ${tempPassword}</p>
      <p>You will be required to change your password on first login.</p>
      <p>Login at: <a href="${env.FRONTEND_URL}">${env.FRONTEND_URL}</a></p>
    `,
  });
}

export async function sendPasswordResetEmail(
  to: string,
  employeeId: number,
  tempPassword: string
) {
  const t = getTransporter();
  if (!t || !to) return;

  await t.sendMail({
    from:    `"HRMS – Gandhinagar University" <${env.SMTP_FROM ?? env.SMTP_USER}>`,
    to,
    subject: 'Your HRMS Password Has Been Reset',
    html: `
      <h2>Password Reset</h2>
      <p>Your password has been reset by an administrator.</p>
      <p><strong>Employee ID:</strong> ${employeeId}</p>
      <p><strong>Temporary Password:</strong> ${tempPassword}</p>
      <p>Please log in and change your password immediately.</p>
      <p>Login at: <a href="${env.FRONTEND_URL}">${env.FRONTEND_URL}</a></p>
    `,
  });
}

/** Returns false when SMTP is not configured. */
export function isSmtpConfigured(): boolean {
  return !!(env.SMTP_HOST && env.SMTP_USER && env.SMTP_PASS);
}

function escapeHtml(value: string) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function toHtmlBlock(value: string) {
  return escapeHtml(value).replace(/\n/g, '<br/>');
}

export async function sendMeetingSummaryEmail(opts: {
  to: string[];
  title: string;
  code: string;
  when: string;
  agenda: string | null;
  summary: string;
  conversation?: string | null;
  joinUrl: string;
}) {
  const t = getTransporter();
  if (!t || opts.to.length === 0) return;
  const unique = [...new Set(opts.to.filter(Boolean))];
  if (unique.length === 0) return;
  const conversation = (opts.conversation || '').trim();
  const conversationHtml = conversation
    ? conversation
        .split('\n')
        .map((line) => {
          const match = line.match(/^\[([^\]]+)\]\s+([^:]+):\s*(.*)$/);
          if (!match) return `<p style="margin:0 0 10px;line-height:1.45;">${escapeHtml(line)}</p>`;
          return `<p style="margin:0 0 12px;line-height:1.45;"><span style="color:#64748b;font-size:12px;">${escapeHtml(match[1])}</span><br/><strong>${escapeHtml(match[2])}</strong> — ${escapeHtml(match[3])}</p>`;
        })
        .join('')
    : '';
  await t.sendMail({
    from: `"NB CRM Meetings" <${env.SMTP_FROM ?? env.SMTP_USER}>`,
    to: unique.join(', '),
    subject: `Meeting summary: ${opts.title}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 640px; margin: 0 auto;">
        <div style="background:#1d3459;color:#fff;padding:20px 24px;">
          <h1 style="margin:0;font-size:20px;">${escapeHtml(opts.title)}</h1>
          <p style="margin:8px 0 0;opacity:.9">Code ${escapeHtml(opts.code)} · ${escapeHtml(opts.when)}</p>
        </div>
        <div style="padding:24px;background:#f8fafc;color:#1e293b;">
          ${opts.agenda ? `<p><strong>Agenda:</strong> ${escapeHtml(opts.agenda)}</p>` : ''}
          <h2 style="font-size:16px;margin:0 0 8px;">AI summary</h2>
          <div style="background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:16px;line-height:1.5;">
            ${toHtmlBlock(opts.summary)}
          </div>
          ${
            conversation
              ? `<h2 style="font-size:16px;margin:24px 0 8px;">Conversation (person &amp; time)</h2>
          <div style="background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:16px;">
            ${conversationHtml}
          </div>`
              : ''
          }
          <p style="margin-top:20px;font-size:13px;color:#64748b;">
            Replay / details: <a href="${opts.joinUrl}">${opts.joinUrl}</a>
          </p>
        </div>
      </div>
    `,
  });
}

export async function sendMeetingInviteEmail(opts: {
  to: string[];
  title: string;
  code: string;
  when: string;
  agenda: string | null;
  hostName: string;
  joinUrl: string;
}) {
  const t = getTransporter();
  if (!t || opts.to.length === 0) return;
  const unique = [...new Set(opts.to.filter(Boolean))];
  if (unique.length === 0) return;
  await t.sendMail({
    from: `"NB CRM Meetings" <${env.SMTP_FROM ?? env.SMTP_USER}>`,
    to: unique.join(', '),
    subject: `Meeting invite: ${opts.title}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 640px; margin: 0 auto;">
        <div style="background:#2563eb;color:#fff;padding:20px 24px;">
          <h1 style="margin:0;font-size:20px;">You're invited</h1>
          <p style="margin:8px 0 0;opacity:.9">${opts.title}</p>
        </div>
        <div style="padding:24px;background:#f8fafc;color:#1e293b;">
          <p><strong>Host:</strong> ${opts.hostName}</p>
          <p><strong>When:</strong> ${opts.when}</p>
          <p><strong>Code:</strong> ${opts.code}</p>
          ${opts.agenda ? `<p><strong>Agenda:</strong> ${opts.agenda}</p>` : ''}
          <p style="margin-top:20px;">
            <a href="${opts.joinUrl}" style="background:#2563eb;color:#fff;padding:10px 16px;border-radius:8px;text-decoration:none;">Join meeting</a>
          </p>
        </div>
      </div>
    `,
  });
}

export async function sendOtpEmail(to: string, otp: string): Promise<void> {
  const t = getTransporter();
  if (!t) {
    const err = new Error(
      'SMTP is not configured. Set SMTP_HOST, SMTP_USER, and SMTP_PASS in backend/.env',
    ) as Error & { status?: number };
    err.status = 503;
    throw err;
  }
  if (!to) return;

  await t.sendMail({
    from: `"NB CRM" <${env.SMTP_FROM ?? env.SMTP_USER}>`,
    to,
    subject: 'Email verification code',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <div style="background: #1d3459; padding: 24px; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 22px;">NB Developer CRM</h1>
          <p style="color: rgba(255,255,255,0.85); margin: 8px 0 0;">Email verification</p>
        </div>
        <div style="padding: 28px; background: #f8fafc;">
          <p style="font-size: 16px; color: #333;">Your one-time password (OTP) is:</p>
          <div style="background: white; border: 2px dashed #1d3459; border-radius: 8px; padding: 20px; text-align: center; margin: 20px 0;">
            <span style="font-size: 36px; font-weight: bold; color: #1d3459; letter-spacing: 8px;">${otp}</span>
          </div>
          <p style="font-size: 14px; color: #666;">Valid for <strong>5 minutes</strong>. Do not share this code.</p>
          <p style="font-size: 12px; color: #999; margin-top: 20px;">If you did not request this, ignore this email.</p>
        </div>
      </div>
    `,
  });
}
