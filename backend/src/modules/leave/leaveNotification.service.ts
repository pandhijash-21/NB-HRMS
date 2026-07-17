import { prisma } from '../../config/prisma';
import { env } from '../../config/env';
import nodemailer from 'nodemailer';

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

async function getEmployeeEmail(employeeId: number): Promise<string | null> {
  const row = await prisma.employeeAddress.findFirst({
    where: { employeeId },
    select: { instituteEmail: true, personalEmail: true },
  });
  return row?.instituteEmail ?? row?.personalEmail ?? null;
}

async function getUserEmployeeId(userId: string): Promise<number | null> {
  const row = await prisma.user.findUnique({
    where: { id: userId },
    select: { employeeId: true },
  });
  return row?.employeeId ?? null;
}

async function getEmployeeName(employeeId: number): Promise<string> {
  const row = await prisma.employeeGeneralInfo.findUnique({
    where: { employeeId },
    select: { fullName: true },
  });
  return row?.fullName ?? `Employee #${employeeId}`;
}

async function send(to: string, subject: string, html: string) {
  const t = getTransport();
  if (!t || !to) return;
  try {
    await t.sendMail({
      from: `"HRMS – Gandhinagar University" <${env.SMTP_FROM ?? env.SMTP_USER}>`,
      to,
      subject,
      html,
    });
  } catch (err) {
    console.warn('[Leave Notification] Email failed:', err);
  }
}

const BASE = env.FRONTEND_URL ?? 'http://localhost:3000';

export const leaveNotificationService = {
  async notifyApplied(applicationId: string) {
    const app = await prisma.leaveApplication.findUnique({
      where: { id: applicationId },
      include: { leaveType: { select: { name: true } }, employee: { select: { id: true } } },
    });
    if (!app) return;
    const email = await getEmployeeEmail(app.employeeId);
    const name = await getEmployeeName(app.employeeId);
    if (!email) return;
    await send(
      email,
      `Leave Application Submitted — ${app.leaveType.name}`,
      `
      <h2>Leave Application Submitted</h2>
      <p>Dear ${name},</p>
      <p>Your leave application (<strong>${app.applicationNo}</strong>) has been submitted successfully.</p>
      <p><strong>Type:</strong> ${app.leaveType.name}<br/>
      <strong>From:</strong> ${app.fromDate.toDateString()}<br/>
      <strong>To:</strong> ${app.toDate.toDateString()}<br/>
      <strong>Days:</strong> ${app.totalDays}</p>
      <p>It is currently pending approval.</p>
      <a href="${BASE}/leave/history">View Application</a>
      `,
    );
  },

  async notifyApproverPendingStep(stepId: string) {
    const step = await prisma.leaveApprovalStep.findUnique({
      where: { id: stepId },
      include: {
        application: {
          include: { leaveType: { select: { name: true } }, employee: { select: { id: true } } },
        },
      },
    });
    if (!step || !step.approverUserId) return;
    const approverEmployeeId = await getUserEmployeeId(step.approverUserId);
    // Position accounts may not have an employeeId/email — skip email notifications for them.
    if (!approverEmployeeId) return;
    const approverEmail = await getEmployeeEmail(approverEmployeeId);
    const approverName = await getEmployeeName(approverEmployeeId);
    const empName = await getEmployeeName(step.application.employeeId);
    if (!approverEmail) return;
    await send(
      approverEmail,
      `Leave Approval Required — ${empName}`,
      `
      <h2>Leave Approval Action Required</h2>
      <p>Dear ${approverName},</p>
      <p><strong>${empName}</strong> has applied for ${step.application.leaveType.name} leave.</p>
      <p><strong>From:</strong> ${step.application.fromDate.toDateString()}<br/>
      <strong>To:</strong> ${step.application.toDate.toDateString()}<br/>
      <strong>Days:</strong> ${step.application.totalDays}<br/>
      <strong>Reason:</strong> ${step.application.reason}</p>
      <a href="${BASE}/approvals">Review &amp; Approve</a>
      `,
    );
  },

  async notifyApplicantDecision(applicationId: string, approved: boolean) {
    const app = await prisma.leaveApplication.findUnique({
      where: { id: applicationId },
      include: { leaveType: { select: { name: true } } },
    });
    if (!app) return;
    const email = await getEmployeeEmail(app.employeeId);
    const name = await getEmployeeName(app.employeeId);
    if (!email) return;
    const status = approved ? 'Approved ✅' : 'Rejected ❌';
    await send(
      email,
      `Leave Application ${approved ? 'Approved' : 'Rejected'} — ${app.leaveType.name}`,
      `
      <h2>Leave Application ${status}</h2>
      <p>Dear ${name},</p>
      <p>Your leave application (<strong>${app.applicationNo}</strong>) has been <strong>${approved ? 'approved' : 'rejected'}</strong>.</p>
      <p><strong>Type:</strong> ${app.leaveType.name}<br/>
      <strong>From:</strong> ${app.fromDate.toDateString()}<br/>
      <strong>To:</strong> ${app.toDate.toDateString()}</p>
      <a href="${BASE}/leave/history">View Details</a>
      `,
    );
  },

  async notifyLwpConverted(employeeId: number, date: Date) {
    const email = await getEmployeeEmail(employeeId);
    const name = await getEmployeeName(employeeId);
    if (!email) return;
    await send(
      email,
      'Leave Without Pay Applied for Absence',
      `
      <h2>LWP Applied for Absence</h2>
      <p>Dear ${name},</p>
      <p>You were marked absent on <strong>${date.toDateString()}</strong> and the window to apply leave has expired.</p>
      <p>One day of <strong>Leave Without Pay (LWP)</strong> has been recorded for that date.</p>
      <a href="${BASE}/leave/history">View Details</a>
      `,
    );
  },

  async notifyAbsenceWindowExpiring(employeeId: number, date: Date, hoursLeft: number) {
    const email = await getEmployeeEmail(employeeId);
    const name = await getEmployeeName(employeeId);
    if (!email) return;
    await send(
      email,
      'Action Required: Apply Leave for Your Absence',
      `
      <h2>Absence Window Expiring Soon</h2>
      <p>Dear ${name},</p>
      <p>You were marked absent on <strong>${date.toDateString()}</strong>.</p>
      <p>You have <strong>${hoursLeft} hours</strong> remaining to apply leave for that date.</p>
      <p>If no leave application is submitted, LWP will be automatically applied.</p>
      <a href="${BASE}/leave/apply">Apply Leave Now</a>
      `,
    );
  },
};
