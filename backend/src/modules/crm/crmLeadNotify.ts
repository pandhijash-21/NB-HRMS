import { prisma } from '../../config/prisma';
import { emitPushNotify } from '../collaboration/socket';
import { sseService } from '../events/sse.service';

export type CrmLeadNotifyReason =
  | 'webhook'
  | 'excel'
  | 'dispatch'
  | 'transfer'
  | 'manual'
  | 're_inquiry';

async function resolveAdminUserIds(_scope?: string): Promise<string[]> {
  const admins = await prisma.user.findMany({
    where: {
      isActive: true,
      deletedAt: null,
      OR: [
        {
          role: {
            name: {
              in: [
                'ADMIN',
                'SUPERADMIN',
                'SUPER_ADMIN',
                'SYSTEMADMIN',
                'SYSTEM_ADMIN',
                'SYSTEM_ADMINISTRATOR',
                'ITADMIN',
                'IT_ADMIN',
              ],
            },
          },
        },
        { companyAdminGranted: true },
      ],
    },
    select: { id: true },
    take: 250,
  });
  return [...new Set(admins.map((a) => a.id).filter(Boolean))];
}

async function resolveUserIdForEmployee(employeeId: number | null | undefined): Promise<string | null> {
  if (employeeId == null || !Number.isFinite(Number(employeeId))) return null;
  const emp = await prisma.employee.findUnique({
    where: { id: Number(employeeId) },
    select: { user: { select: { id: true } } },
  });
  return emp?.user?.id || null;
}

function reasonLabel(reason: CrmLeadNotifyReason): string {
  switch (reason) {
    case 'webhook':
      return 'Webhook / Ads';
    case 'excel':
      return 'Excel import';
    case 'dispatch':
      return 'Waiting list dispatch';
    case 'transfer':
      return 'Transfer';
    case 'manual':
      return 'Manual entry';
    case 're_inquiry':
      return 'Re-inquiry';
    default:
      return 'CRM';
  }
}

/**
 * Notify the allocated telecaller (if any) and all admins when a lead arrives or is allocated.
 */
export async function notifyNewOrAllocatedLead(opts: {
  leadId: string;
  leadName?: string | null;
  phone?: string | null;
  telecallerEmployeeId?: number | null;
  scope?: string;
  campaignName?: string | null;
  reason: CrmLeadNotifyReason;
}): Promise<void> {
  try {
    const name = String(opts.leadName || '').trim() || 'Unnamed lead';
    const phone = String(opts.phone || '').trim() || 'N/A';
    const campaign = String(opts.campaignName || '').trim();
    const allocated = opts.telecallerEmployeeId != null && Number(opts.telecallerEmployeeId) > 0;
    const title = allocated ? 'New lead allocated' : 'New lead received';
    const bodyParts = [
      name,
      phone !== 'N/A' ? `(${phone})` : null,
      campaign ? `· ${campaign}` : null,
      `· ${reasonLabel(opts.reason)}`,
      allocated ? '' : '· Waiting List',
    ].filter(Boolean);
    const body = bodyParts.join(' ');
    const scopeQ = opts.scope ? `&scope=${encodeURIComponent(String(opts.scope))}` : '';
    const path = `/crm/pre-sales?leadId=${encodeURIComponent(opts.leadId)}${scopeQ}`;
    const kind = 'crm_lead';

    const recipientIds = new Set<string>();
    const telecallerUserId = await resolveUserIdForEmployee(opts.telecallerEmployeeId);
    if (telecallerUserId) recipientIds.add(telecallerUserId);

    for (const adminId of await resolveAdminUserIds(opts.scope)) {
      recipientIds.add(adminId);
    }

    const recipients = [...recipientIds];
    if (!recipients.length) return;

    const createdAt = new Date();
    await prisma.userNotification.createMany({
      data: recipients.map((userId) => ({
        userId,
        title,
        body,
        kind,
        path,
        createdAt,
      })),
    });

    const payload = { kind, title, body, path, leadId: opts.leadId };
    emitPushNotify(recipients, payload);
    for (const userId of recipients) {
      try {
        sseService.toUser(userId, 'push_notify', payload);
      } catch (_) {}
    }
  } catch (err) {
    console.error('[CRM Lead Notify Error]:', err);
  }
}

/** Batch-friendly admin+assignee notify for many Excel rows (still one inbox row per lead). */
export async function notifyLeadsBatch(
  leads: Array<{
    leadId: string;
    leadName?: string | null;
    phone?: string | null;
    telecallerEmployeeId?: number | null;
    campaignName?: string | null;
  }>,
  opts: { scope?: string; reason: CrmLeadNotifyReason },
): Promise<void> {
  for (const lead of leads) {
    await notifyNewOrAllocatedLead({
      ...lead,
      scope: opts.scope,
      reason: opts.reason,
    });
  }
}
