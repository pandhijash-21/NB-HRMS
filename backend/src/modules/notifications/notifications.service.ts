import { prisma } from '../../config/prisma';
import {
  hasCompanyAdminPrivileges,
  isSuperAdminRole,
} from '../auth/permissions-map';
import { emitPushNotify } from '../collaboration/socket';

export type BroadcastActor = {
  id: string;
  role?: string | null;
  companyAdminGranted?: boolean | null;
  subOrganization?: string | null;
};

function canBroadcast(actor: BroadcastActor): boolean {
  return (
    isSuperAdminRole(actor.role) ||
    hasCompanyAdminPrivileges(actor.role, actor.companyAdminGranted)
  );
}

async function resolveAudienceUserIds(actor: BroadcastActor): Promise<string[]> {
  if (isSuperAdminRole(actor.role)) {
    const rows = await prisma.user.findMany({
      where: { isActive: true, deletedAt: null },
      select: { id: true },
    });
    return rows.map((r) => r.id);
  }

  const org = String(actor.subOrganization ?? '').trim();
  if (!org) {
    throw new Error('Your account is not linked to a company. Cannot broadcast.');
  }

  const rows = await prisma.user.findMany({
    where: {
      isActive: true,
      deletedAt: null,
      subOrganization: { equals: org, mode: 'insensitive' },
    },
    select: { id: true },
  });
  return rows.map((r) => r.id);
}

export const notificationsService = {
  canBroadcast,

  async listForUser(userId: string, limit = 50) {
    const take = Math.min(Math.max(Number(limit) || 50, 1), 100);
    return prisma.userNotification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take,
    });
  },

  async unreadCount(userId: string) {
    return prisma.userNotification.count({
      where: { userId, readAt: null },
    });
  },

  async markRead(userId: string, id: string) {
    const row = await prisma.userNotification.findFirst({
      where: { id, userId },
    });
    if (!row) throw new Error('Notification not found');
    if (row.readAt) return row;
    return prisma.userNotification.update({
      where: { id },
      data: { readAt: new Date() },
    });
  },

  async markAllRead(userId: string) {
    await prisma.userNotification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
    return { ok: true };
  },

  async broadcast(
    actor: BroadcastActor,
    input: { title: string; body: string; path?: string | null },
  ) {
    if (!canBroadcast(actor)) {
      throw Object.assign(new Error('Only System Admin can send company notifications'), {
        status: 403,
      });
    }

    const title = String(input.title ?? '').trim();
    const body = String(input.body ?? '').trim();
    if (title.length < 2) throw new Error('Title is required');
    if (body.length < 2) throw new Error('Message is required');
    if (title.length > 120) throw new Error('Title is too long (max 120)');
    if (body.length > 4000) throw new Error('Message is too long (max 4000)');

    const audience = await resolveAudienceUserIds(actor);
    const recipients = audience.filter((id) => id && id !== actor.id);
    if (recipients.length === 0) {
      throw new Error('No employees found to notify in your company.');
    }

    const path = input.path?.trim() || '/notifications';
    const kind = 'announce';

    // Batch insert
    const createdAt = new Date();
    await prisma.userNotification.createMany({
      data: recipients.map((userId) => ({
        userId,
        title,
        body,
        kind,
        path,
        senderId: actor.id,
        createdAt,
      })),
    });

    emitPushNotify(recipients, {
      kind,
      title,
      body,
      path,
      senderId: actor.id,
    });

    return {
      sent: recipients.length,
      title,
      body,
      path,
    };
  },

  /**
   * Notify company System Admins when an employee updates their profile.
   * Only ADMIN / System Admin / company-admin-granted users — not HR or staff.
   */
  async notifyProfileChange(input: {
    employeeId: number;
    actorUserId?: string | null;
    summary: string;
    fieldName?: string | null;
  }) {
    const emp = await prisma.employee.findUnique({
      where: { id: input.employeeId },
      select: {
        id: true,
        abbreviation: true,
        generalInfo: { select: { fullName: true } },
        user: { select: { id: true, subOrganization: true } },
      },
    });
    if (!emp) return;

    let actorLabel: string | null = null;
    if (input.actorUserId) {
      const actor = await prisma.user.findUnique({
        where: { id: input.actorUserId },
        select: {
          username: true,
          role: { select: { name: true } },
          employee: { select: { generalInfo: { select: { fullName: true } } } },
        },
      });
      actorLabel =
        actor?.employee?.generalInfo?.fullName?.trim() ||
        actor?.username?.trim() ||
        actor?.role?.name?.replace(/_/g, ' ') ||
        null;
    }

    const subject =
      emp.generalInfo?.fullName?.trim() ||
      emp.abbreviation ||
      `Employee #${emp.id}`;
    const title = 'Profile updated';
    // Prefer actor in the sentence so admin edits read clearly.
    const body = actorLabel
      ? `${actorLabel} ${input.summary}${subject !== actorLabel ? ` for ${subject}` : ''}`
      : `${subject} ${input.summary}`.trim();
    const path = `/workforce/employees/${emp.id}`;
    const kind = 'profile';

    const org = String(emp.user?.subOrganization ?? '').trim();
    const admins = await prisma.user.findMany({
      where: {
        isActive: true,
        deletedAt: null,
        id: input.actorUserId ? { not: input.actorUserId } : undefined,
        OR: [
          {
            role: {
              name: {
                in: [
                  'ADMIN',
                  'SYSTEMADMIN',
                  'SYSTEM_ADMIN',
                  'SYSTEM_ADMINISTRATOR',
                ],
              },
            },
          },
          { companyAdminGranted: true },
        ],
        ...(org
          ? { subOrganization: { equals: org, mode: 'insensitive' as const } }
          : {}),
      },
      select: { id: true },
      take: 200,
    });

    const recipients = [...new Set(admins.map((a) => a.id).filter(Boolean))];
    if (!recipients.length) return;

    const createdAt = new Date();
    await prisma.userNotification.createMany({
      data: recipients.map((userId) => ({
        userId,
        title,
        body,
        kind,
        path,
        senderId: input.actorUserId ?? emp.user?.id ?? null,
        createdAt,
      })),
    });

    emitPushNotify(recipients, {
      kind,
      title,
      body,
      path,
      senderId: input.actorUserId ?? emp.user?.id,
    });
  },
};
