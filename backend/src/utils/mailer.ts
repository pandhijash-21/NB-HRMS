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
      pass: env.SMTP_PASS,
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
