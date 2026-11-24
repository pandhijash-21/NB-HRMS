import type { NextFunction, Request, Response } from 'express';
import { activityTracker } from './activity-tracker.service';

const EXCLUDE_PATHS_REGEX = /heartbeat|ping|health|socket|live-logs|notifications\/count|live-tracking\/stream|system-health|\.map$|\.ico$/i;

const EXCLUDE_PATHS = new Set([
  '/health',
  '/system-health',
  '/system-health.html',
  '/docs',
  '/api/ops/live-logs',
  '/api/ops/dashboard',
  '/api/admin/audit-logs/track',
  '/api/events',
  '/api/notifications/count',
]);

function shouldSkip(path: string): boolean {
  if (!path) return true;
  if (EXCLUDE_PATHS.has(path)) return true;
  if (EXCLUDE_PATHS_REGEX.test(path)) return true;
  if (path.startsWith('/socket') || path.startsWith('/static')) return true;
  return false;
}

function resolveActionLabel(method: string, path: string): { label: string; module: string } {
  const p = path.toLowerCase();

  // Attendance
  if (p.includes('/attendance/punch-in')) return { label: 'Punched In', module: 'ATTENDANCE' };
  if (p.includes('/attendance/punch-out')) return { label: 'Punched Out', module: 'ATTENDANCE' };
  if (p.includes('/attendance/break-start')) return { label: 'Started Break', module: 'ATTENDANCE' };
  if (p.includes('/attendance/break-end')) return { label: 'Ended Break', module: 'ATTENDANCE' };
  if (p.includes('/attendance/regularize')) return { label: 'Requested Attendance Regularization', module: 'ATTENDANCE' };
  if (p.includes('/attendance/my-day')) return { label: 'Viewed Daily Attendance', module: 'ATTENDANCE' };
  if (p.includes('/attendance')) return { label: `${method} Attendance Record`, module: 'ATTENDANCE' };

  // Leave & Holidays
  if (p.includes('/leave/applications') && method === 'POST') return { label: 'Applied for Leave', module: 'LEAVE' };
  if (p.includes('/leave/cancel')) return { label: 'Cancelled Leave Application', module: 'LEAVE' };
  if (p.includes('/leave/holidays') && method === 'POST') return { label: 'Added Official Holiday', module: 'LEAVE' };
  if (p.includes('/leave/holidays') && method === 'DELETE') return { label: 'Removed Official Holiday', module: 'LEAVE' };
  if (p.includes('/approvals/approve') || (p.includes('/approvals') && method === 'POST')) {
    return { label: 'Approved Request', module: 'APPROVALS' };
  }
  if (p.includes('/approvals/reject')) return { label: 'Rejected Request', module: 'APPROVALS' };
  if (p.includes('/leave')) return { label: `${method} Leave Management`, module: 'LEAVE' };

  // Profile & Documents
  if (p.includes('/employees') && p.includes('/upload')) return { label: 'Uploaded Profile Document', module: 'PROFILE' };
  if (p.includes('/employees') && method === 'PUT') return { label: 'Updated Employee Profile', module: 'PROFILE' };
  if (p.includes('/employees') && method === 'POST') return { label: 'Created Employee Record', module: 'PROFILE' };
  if (p.includes('/employees') && method === 'DELETE') return { label: 'Archived Employee Record', module: 'PROFILE' };

  // Tasks & Work Orders
  if (p.includes('/tasks') && method === 'POST') return { label: 'Created Work Task', module: 'TASKS' };
  if (p.includes('/tasks') && (method === 'PATCH' || method === 'PUT')) return { label: 'Updated Task Status', module: 'TASKS' };
  if (p.includes('/tasks') && method === 'DELETE') return { label: 'Deleted Work Task', module: 'TASKS' };

  // ERP, DPR & BOQ
  if (p.includes('/erp/dpr') && method === 'POST') return { label: 'Submitted Daily Progress Report (DPR)', module: 'ERP' };
  if (p.includes('/erp/dpr') && (method === 'PATCH' || method === 'PUT')) return { label: 'Updated DPR Record', module: 'ERP' };
  if (p.includes('/erp/boq') && method === 'POST') return { label: 'Created BOQ Item', module: 'ERP' };
  if (p.includes('/erp/purchase') && method === 'POST') return { label: 'Created Purchase Order', module: 'ERP' };
  if (p.includes('/erp/tender')) return { label: `${method} Tender Record`, module: 'ERP' };
  if (p.includes('/erp')) return { label: `${method} ERP Operation`, module: 'ERP' };

  // CRM & Sales
  if (p.includes('/crm/leads') && method === 'POST') return { label: 'Created CRM Lead', module: 'CRM' };
  if (p.includes('/crm/leads') && (method === 'PATCH' || method === 'PUT')) return { label: 'Updated CRM Lead', module: 'CRM' };
  if (p.includes('/crm/call-logs')) return { label: 'Logged Telephony Call', module: 'CRM' };
  if (p.includes('/crm/whatsapp')) return { label: 'Sent WhatsApp Template', module: 'CRM' };
  if (p.includes('/crm/proposals')) return { label: 'Generated CRM Proposal', module: 'CRM' };
  if (p.includes('/crm/stages')) return { label: 'Updated Lead Stage', module: 'CRM' };
  if (p.includes('/crm')) return { label: `${method} CRM Record`, module: 'CRM' };

  // Auth & Passwords
  if (p.includes('/auth/login')) return { label: 'User Login', module: 'AUTH' };
  if (p.includes('/auth/change-password')) return { label: 'Changed Account Password', module: 'AUTH' };
  if (p.includes('/auth/forgot-password')) return { label: 'Requested Password Reset', module: 'AUTH' };
  if (p.includes('/auth/logout')) return { label: 'User Logout', module: 'AUTH' };

  // User Management & Roles (RBAC)
  if (p.includes('/admin/roles') && (method === 'POST' || method === 'PUT' || method === 'PATCH')) {
    return { label: 'Modified Role Permissions Matrix', module: 'RBAC' };
  }
  if (p.includes('/admin/users') && method === 'POST') return { label: 'Created User Account', module: 'USER_MGMT' };
  if (p.includes('/admin/users') && (method === 'PATCH' || method === 'PUT')) return { label: 'Updated User Account', module: 'USER_MGMT' };
  if (p.includes('/admin/users') && method === 'DELETE') return { label: 'Deactivated User Account', module: 'USER_MGMT' };

  // Salary & Payroll
  if (p.includes('/salary/records') && p.includes('/slip')) return { label: 'Viewed / Downloaded Salary Slip', module: 'SALARY' };
  if (p.includes('/salary') && method === 'POST') return { label: 'Processed Salary / Payroll', module: 'SALARY' };

  // Reimbursements
  if (p.includes('/reimbursements') && method === 'POST') return { label: 'Submitted Expense Reimbursement', module: 'REIMBURSEMENTS' };
  if (p.includes('/reimbursements') && (method === 'PATCH' || method === 'PUT')) return { label: 'Updated Expense Claim', module: 'REIMBURSEMENTS' };

  // Letters & Documents
  if (p.includes('/letters/generate')) return { label: 'Generated Official Letter', module: 'LETTERS' };
  if (p.includes('/letters/templates')) return { label: 'Updated Letter Template', module: 'LETTERS' };

  // Organization Structure
  if (p.includes('/org/institutes') && method === 'POST') return { label: 'Created Institute Branch', module: 'ORGANIZATION' };
  if (p.includes('/org/designations') && method === 'POST') return { label: 'Created Designation', module: 'ORGANIZATION' };

  // Fallback to module extracted from path
  const segments = p.split('/').filter(Boolean);
  const detectedModule = segments[1] ? segments[1].toUpperCase() : 'SYSTEM';

  return { label: `${method} ${path}`, module: detectedModule };
}

export function userActivityTrackerMiddleware(req: Request, res: Response, next: NextFunction) {
  const path = req.path || req.url || '';
  if (shouldSkip(path)) return next();

  const t0 = Date.now();

  res.on('finish', () => {
    try {
      // NEVER track heartbeats under any circumstances
      if (shouldSkip(path)) return;

      const user = req.user;
      if (!user?.id) return; // Only log authenticated actions

      const isMutation = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method);
      const isSignificantGet = req.method === 'GET' && (
        path.includes('/slip') ||
        path.includes('/export') ||
        path.includes('/download') ||
        path.includes('/credentials') ||
        path.includes('/audit')
      );

      // Only track mutations and significant views to keep log volume high-quality
      if (!isMutation && !isSignificantGet) return;

      const durationMs = Date.now() - t0;
      const { label, module } = resolveActionLabel(req.method, path);

      activityTracker.enqueue({
        tableName: 'SYSTEM_ACTION',
        recordId: path,
        employeeId: typeof user.employeeId === 'number' ? user.employeeId : null,
        fieldName: label,
        oldValue: `Module: ${module}`,
        newValue: `HTTP ${res.statusCode} (${durationMs}ms)`,
        changedBy: user.id,
        changeReason: `${req.method} request completed with status ${res.statusCode}`,
        ipAddress: req.ip,
        userAgent: req.headers['user-agent'] ? String(req.headers['user-agent']) : null,
      });
    } catch {
      /* Tracking should never crash the request flow */
    }
  });

  next();
}
