import {
  Prisma,
  SupportTicketStatus,
  EmployeeStatus,
} from '@prisma/client';
import { prisma } from '../../config/prisma';
import { emitPushNotify } from '../collaboration/socket';
import { issueLiveKitToken, livekitPublicUrl } from '../collaboration/livekit';
import {
  sendSupportTicketNotificationEmail,
  type SupportTicketEmailParams,
} from '../../utils/mailer';

const ticketInclude = {
  employee: {
    include: {
      generalInfo: {
        select: {
          fullName: true,
          employeeCode: true,
          designation: true,
          department: true,
        },
      },
      user: { select: { id: true } },
    },
  },
  events: { orderBy: { createdAt: 'asc' as const } },
  messages: { orderBy: { createdAt: 'asc' as const } },
  remoteSessions: {
    where: { status: { in: ['REQUESTED', 'ACCEPTED', 'ACTIVE'] } },
    orderBy: { createdAt: 'desc' as const },
    take: 1,
  },
};

async function nextTicketNo(): Promise<string> {
  const year = new Date().getFullYear();
  const prefix = `SUP-${year}-`;
  const latest = await prisma.supportTicket.findFirst({
    where: { ticketNo: { startsWith: prefix } },
    orderBy: { ticketNo: 'desc' },
    select: { ticketNo: true },
  });
  const seq = latest ? Number(latest.ticketNo.slice(prefix.length)) + 1 : 1;
  return `${prefix}${String(seq).padStart(4, '0')}`;
}

async function notifyUsers(
  userIds: string[],
  payload: { title: string; body: string; path?: string },
) {
  const unique = [...new Set(userIds.filter(Boolean))];
  if (unique.length === 0) return;
  try {
    await prisma.userNotification.createMany({
      data: unique.map((userId) => ({
        userId,
        title: payload.title,
        body: payload.body,
        kind: 'support',
        path: payload.path ?? '/support',
      })),
    });
  } catch {
    // non-fatal
  }
  emitPushNotify(unique, {
    kind: 'support',
    title: payload.title,
    body: payload.body,
    path: payload.path ?? '/support',
  });
}

async function resolveEmployeeEmail(employeeId: number): Promise<string | null> {
  const addr = await prisma.employeeAddress.findFirst({
    where: { employeeId, addressType: 'LOCAL' },
    select: { personalEmail: true, instituteEmail: true },
  });
  return addr?.personalEmail?.trim() || addr?.instituteEmail?.trim() || null;
}

async function resolveUserEmails(userIds: string[]): Promise<string[]> {
  const users = await prisma.user.findMany({
    where: { id: { in: userIds } },
    select: { employeeId: true },
  });
  const empIds = users.map((u) => u.employeeId).filter((id): id is number => id != null);
  if (empIds.length === 0) return [];
  const addresses = await prisma.employeeAddress.findMany({
    where: { employeeId: { in: empIds }, addressType: 'LOCAL' },
    select: { personalEmail: true, instituteEmail: true },
  });
  const emails: string[] = [];
  for (const a of addresses) {
    const e = a.personalEmail?.trim() || a.instituteEmail?.trim();
    if (e && e.includes('@')) emails.push(e);
  }
  return [...new Set(emails)];
}

function buildEmailTicketParams(ticket: any, remarks?: string | null): SupportTicketEmailParams {
  return {
    ticketId: ticket.id,
    ticketNo: ticket.ticketNo,
    title: ticket.title,
    description: ticket.description,
    raisedByName: ticket.employee?.generalInfo?.fullName?.trim() || `Employee #${ticket.employeeId}`,
    raisedByCode: ticket.employee?.generalInfo?.employeeCode?.trim() || null,
    department: ticket.employee?.generalInfo?.department?.trim() || null,
    designation: ticket.employee?.generalInfo?.designation?.trim() || null,
    createdAt: ticket.createdAt,
    status: ticket.status,
    etaAt: ticket.etaAt,
    remarks: remarks || ticket.resolveRemarks || ticket.denyRemarks || null,
    photoUrl: ticket.photoUrl,
  };
}

async function findAvailableHandler(excludeEmployeeId?: number | null): Promise<{ employeeId: number; load: number } | null> {
  const assignees = await prisma.supportItAssignee.findMany({
    where: {
      isActive: true,
      ...(excludeEmployeeId != null && Number.isFinite(excludeEmployeeId)
        ? { employeeId: { not: excludeEmployeeId } }
        : {}),
    },
    select: { employeeId: true, maxConcurrentTickets: true },
  });

  if (assignees.length === 0) {
    // Fallback when no explicit assignees are configured: auto-assign to IT/Admin users with employeeId
    const fallbackUsers = await prisma.user.findMany({
      where: {
        isActive: true,
        deletedAt: null,
        employeeId: { not: null },
        OR: [
          {
            role: {
              name: {
                in: [
                  'ADMIN',
                  'HR',
                  'HR_MANAGER',
                  'SYSTEMADMIN',
                  'SYSTEM_ADMIN',
                  'SYSTEM_ADMINISTRATOR',
                  'SUPERADMIN',
                ],
              },
            },
          },
          { companyAdminGranted: true },
          {
            role: {
              permissions: {
                some: {
                  moduleKey: 'SUPPORT',
                  canApprove: true,
                },
              },
            },
          },
        ],
      },
      select: { employeeId: true },
      take: 20,
    });

    const candidateIds = fallbackUsers
      .map((u) => u.employeeId)
      .filter((id): id is number => id != null && id !== excludeEmployeeId);

    if (candidateIds.length === 0) return null;

    const candidateLoads = await Promise.all(
      candidateIds.map(async (empId) => {
        const count = await prisma.supportTicket.count({
          where: {
            assignedHandlerId: empId,
            status: { in: [SupportTicketStatus.OPEN, SupportTicketStatus.IN_REVIEW] },
          },
        });
        return { employeeId: empId, load: count };
      }),
    );

    candidateLoads.sort((a, b) => a.load - b.load);
    return candidateLoads[0];
  }

  const handlerLoads = await Promise.all(
    assignees.map(async (a) => {
      const activeCount = await prisma.supportTicket.count({
        where: {
          assignedHandlerId: a.employeeId,
          status: { in: [SupportTicketStatus.OPEN, SupportTicketStatus.IN_REVIEW] },
        },
      });
      const maxLimit = a.maxConcurrentTickets ?? 3;
      return {
        employeeId: a.employeeId,
        load: activeCount,
        maxLimit,
        hasCapacity: activeCount < maxLimit,
      };
    }),
  );

  const available = handlerLoads.filter((h) => h.hasCapacity);
  if (available.length === 0) return null;

  available.sort((a, b) => a.load - b.load);
  return { employeeId: available[0].employeeId, load: available[0].load };
}

async function popNextQueuedTicket(freedHandlerEmployeeId?: number): Promise<void> {
  try {
    let targetHandlerId = freedHandlerEmployeeId;
    if (!targetHandlerId) {
      const avail = await findAvailableHandler();
      targetHandlerId = avail?.employeeId;
    }
    if (!targetHandlerId) return;

    // Find the next queued ticket that was NOT raised by this handler
    const nextQueued = await prisma.supportTicket.findFirst({
      where: {
        status: SupportTicketStatus.QUEUED,
        employeeId: { not: targetHandlerId },
      },
      orderBy: { createdAt: 'asc' },
    });
    if (!nextQueued) return;

    const updated = await prisma.supportTicket.update({
      where: { id: nextQueued.id },
      data: {
        status: SupportTicketStatus.OPEN,
        assignedHandlerId: targetHandlerId,
        assignedAt: new Date(),
        queuePosition: null,
        events: {
          create: {
            actorId: 'system',
            fromStatus: SupportTicketStatus.QUEUED,
            toStatus: SupportTicketStatus.OPEN,
            note: 'Promoted from waiting queue and assigned to handler',
          },
        },
      },
      include: ticketInclude,
    });

    // Re-index remaining queued tickets
    const remainingQueued = await prisma.supportTicket.findMany({
      where: { status: SupportTicketStatus.QUEUED },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    for (let i = 0; i < remainingQueued.length; i++) {
      await prisma.supportTicket.update({
        where: { id: remainingQueued[i].id },
        data: { queuePosition: i + 1 },
      });
    }

    const raiserUserId = updated.employee?.user?.id;
    if (raiserUserId) {
      void notifyUsers([raiserUserId], {
        title: 'Support ticket assigned',
        body: `Your ticket #${updated.ticketNo} has been assigned to an IT specialist`,
        path: `/support/${updated.id}`,
      });
    }

    const handlerUser = await prisma.user.findFirst({
      where: { employeeId: targetHandlerId },
      select: { id: true },
    });
    if (handlerUser) {
      void notifyUsers([handlerUser.id], {
        title: 'New ticket assigned from queue',
        body: `Ticket #${updated.ticketNo}: ${updated.title}`,
        path: `/support/${updated.id}`,
      });
    }
  } catch (err) {
    console.error('[SUPPORT QUEUE POP ERROR]', err);
  }
}

const assigneeInclude = {
  employee: {
    include: {
      generalInfo: {
        select: {
          fullName: true,
          employeeCode: true,
          designation: true,
          department: true,
        },
      },
      user: { select: { id: true, isActive: true, deletedAt: true } },
    },
  },
} as const;

/** When Admin has assigned handlers, only those users get ticket notifications. */
async function resolveItUserIds(): Promise<string[]> {
  const assignees = await prisma.supportItAssignee.findMany({
    include: assigneeInclude,
  });
  if (assignees.length > 0) {
    return assignees
      .map((a) => a.employee.user)
      .filter((u): u is { id: string; isActive: boolean; deletedAt: Date | null } => !!u)
      .filter((u) => u.isActive && u.deletedAt == null)
      .map((u) => u.id);
  }

  // Fallback until Admin configures assignees: privileged roles + SUPPORT APPROVE.
  const users = await prisma.user.findMany({
    where: {
      isActive: true,
      deletedAt: null,
      OR: [
        {
          role: {
            name: {
              in: [
                'ADMIN',
                'HR',
                'HR_MANAGER',
                'SYSTEMADMIN',
                'SYSTEM_ADMIN',
                'SYSTEM_ADMINISTRATOR',
                'SUPERADMIN',
              ],
            },
          },
        },
        { companyAdminGranted: true },
        {
          role: {
            permissions: {
              some: {
                moduleKey: 'SUPPORT',
                canApprove: true,
              },
            },
          },
        },
      ],
    },
    select: { id: true },
  });
  return users.map((u) => u.id);
}

async function assignedEmployeeIds(): Promise<number[]> {
  const rows = await prisma.supportItAssignee.findMany({
    select: { employeeId: true },
  });
  return rows.map((r) => r.employeeId);
}

export async function isAssignedSupportHandler(employeeId: number | null | undefined): Promise<boolean> {
  if (employeeId == null || !Number.isFinite(employeeId)) return false;
  const row = await prisma.supportItAssignee.findUnique({
    where: { employeeId },
    select: { id: true },
  });
  return !!row;
}

function employeeLabel(ticket: {
  employee?: {
    generalInfo?: { fullName?: string | null; employeeCode?: string | null } | null;
  } | null;
  employeeId: number;
}): string {
  const name = ticket.employee?.generalInfo?.fullName?.trim();
  const code = ticket.employee?.generalInfo?.employeeCode?.trim();
  if (name && code) return `${name} (${code})`;
  if (name) return name;
  return `Employee #${ticket.employeeId}`;
}

export const supportService = {
  async create(params: {
    employeeId: number;
    createdBy: string;
    title: string;
    description: string;
    photoUrl?: string | null;
    assignedHandlerId?: number | null;
  }) {
    const title = params.title.trim();
    const description = params.description.trim();
    if (!title) throw new Error('Title is required');
    if (!description) throw new Error('Description is required');

    const ticketNo = await nextTicketNo();
    let initialStatus: SupportTicketStatus = SupportTicketStatus.OPEN;
    let queuePosition: number | null = null;
    let assignedHandlerId: number | null = null;

    if (params.assignedHandlerId != null && Number.isFinite(params.assignedHandlerId)) {
      if (params.assignedHandlerId === params.employeeId) {
        throw new Error('A ticket cannot be assigned to the employee raising it');
      }
      const requestedAssignee = await prisma.supportItAssignee.findUnique({
        where: { employeeId: params.assignedHandlerId },
      });
      if (!requestedAssignee || !requestedAssignee.isActive) {
        throw new Error('Selected IT handler is currently inactive or not found');
      }
      const activeCount = await prisma.supportTicket.count({
        where: {
          assignedHandlerId: params.assignedHandlerId,
          status: { in: [SupportTicketStatus.OPEN, SupportTicketStatus.IN_REVIEW] },
        },
      });
      const limit = requestedAssignee.maxConcurrentTickets ?? 3;
      if (activeCount < limit) {
        assignedHandlerId = params.assignedHandlerId;
        initialStatus = SupportTicketStatus.OPEN;
      } else {
        assignedHandlerId = params.assignedHandlerId;
        initialStatus = SupportTicketStatus.QUEUED;
        const queuedCount = await prisma.supportTicket.count({ where: { status: SupportTicketStatus.QUEUED } });
        queuePosition = queuedCount + 1;
      }
    } else {
      const available = await findAvailableHandler(params.employeeId);
      const totalAssignees = await prisma.supportItAssignee.count({
        where: {
          isActive: true,
          employeeId: { not: params.employeeId },
        },
      });
      if (totalAssignees > 0 && !available) {
        initialStatus = SupportTicketStatus.QUEUED;
        const queuedCount = await prisma.supportTicket.count({ where: { status: SupportTicketStatus.QUEUED } });
        queuePosition = queuedCount + 1;
      } else if (available) {
        assignedHandlerId = available.employeeId;
      }
    }

    const ticket = await prisma.supportTicket.create({
      data: {
        ticketNo,
        employeeId: params.employeeId,
        title,
        description,
        photoUrl: params.photoUrl?.trim() || null,
        status: initialStatus,
        assignedHandlerId,
        assignedAt: assignedHandlerId ? new Date() : null,
        queuePosition,
        createdBy: params.createdBy,
        events: {
          create: {
            actorId: params.createdBy,
            fromStatus: null,
            toStatus: initialStatus,
            note:
              initialStatus === SupportTicketStatus.QUEUED
                ? `All handlers occupied. Ticket placed in queue (Position #${queuePosition})`
                : 'Ticket raised',
          },
        },
      },
      include: ticketInclude,
    });

    const itIds = await resolveItUserIds();
    const itRecipients = itIds.filter((id) => id !== params.createdBy);
    void notifyUsers(
      itRecipients,
      {
        title: 'New support ticket',
        body: `${employeeLabel(ticket)}: ${ticket.title} (${ticket.ticketNo})`,
        path: `/support/${ticket.id}`,
      },
    );

    // Confirmation in-app notification to the raiser
    const raiserUserId = ticket.employee?.user?.id;
    if (raiserUserId && raiserUserId === params.createdBy) {
      void notifyUsers([raiserUserId], {
        title: 'Support ticket submitted',
        body: `Ticket #${ticket.ticketNo} has been received by IT Helpdesk`,
        path: `/support/${ticket.id}`,
      });
    }

    // Dispatch emails in background
    void (async () => {
      try {
        const emailParams = buildEmailTicketParams(ticket);
        // 1. Email to ticket raiser
        const employeeEmail = await resolveEmployeeEmail(params.employeeId);
        if (employeeEmail) {
          await sendSupportTicketNotificationEmail({
            to: employeeEmail,
            isHandler: false,
            action: 'CREATED',
            ticket: emailParams,
          });
        }
        // 2. Email to IT handlers
        const itEmails = await resolveUserEmails(itRecipients);
        if (itEmails.length > 0) {
          await sendSupportTicketNotificationEmail({
            to: itEmails,
            isHandler: true,
            action: 'CREATED',
            ticket: emailParams,
          });
        }
      } catch (err) {
        console.error('[SUPPORT SERVICE] Error dispatching ticket creation emails:', err);
      }
    })();

    return ticket;
  },

  async listMine(employeeId: number) {
    return prisma.supportTicket.findMany({
      where: { employeeId },
      include: ticketInclude,
      orderBy: { createdAt: 'desc' },
    });
  },

  async listQueue(opts?: {
    includeClosed?: boolean;
    employeeId?: number | null;
    isAdmin?: boolean;
  }) {
    const where: any = opts?.includeClosed
      ? {}
      : { status: { not: SupportTicketStatus.CLOSED } };

    if (!opts?.isAdmin) {
      if (opts?.employeeId != null && Number.isFinite(opts.employeeId)) {
        where.OR = [
          { assignedHandlerId: opts.employeeId },
          { transferTargetHandlerId: opts.employeeId },
        ];
      } else {
        return [];
      }
    }

    return prisma.supportTicket.findMany({
      where,
      include: ticketInclude,
      orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
    });
  },

  async getById(id: string) {
    const ticket = await prisma.supportTicket.findUnique({
      where: { id },
      include: ticketInclude,
    });
    if (!ticket) throw new Error('Ticket not found');
    return ticket;
  },

  async assertCanView(ticketId: string, opts: { userId: string; employeeId: number | null; isIt: boolean; isAdmin?: boolean }) {
    const ticket = await this.getById(ticketId);
    if (opts.isAdmin) return ticket;
    if (opts.employeeId != null && ticket.employeeId === opts.employeeId) return ticket;
    if (opts.isIt) {
      if (
        opts.employeeId != null &&
        (ticket.assignedHandlerId === opts.employeeId ||
          ticket.transferTargetHandlerId === opts.employeeId ||
          ticket.assignedHandlerId == null)
      ) {
        return ticket;
      }
    }
    throw new Error('Not allowed to view this ticket');
  },

  async reassignTicket(params: {
    ticketId: string;
    newHandlerId: number;
    actorId: string;
    note?: string | null;
  }) {
    const ticket = await this.getById(params.ticketId);
    if (params.newHandlerId === ticket.employeeId) {
      throw new Error('Cannot assign ticket to the employee who raised it');
    }
    const handlerEmployee = await prisma.employee.findUnique({
      where: { id: params.newHandlerId },
      include: { generalInfo: true, user: true },
    });
    if (!handlerEmployee) throw new Error('Target IT handler not found');

    const updated = await prisma.supportTicket.update({
      where: { id: params.ticketId },
      data: {
        assignedHandlerId: params.newHandlerId,
        assignedAt: new Date(),
        transferStatus: 'NONE',
        transferTargetHandlerId: null,
        transferReason: null,
        events: {
          create: {
            actorId: params.actorId,
            fromStatus: ticket.status,
            toStatus: ticket.status,
            note: params.note?.trim() || `Ticket assigned to ${handlerEmployee.generalInfo?.fullName || '#' + params.newHandlerId}`,
          },
        },
      },
      include: ticketInclude,
    });
    if (handlerEmployee.user?.id) {
      emitPushNotify([handlerEmployee.user.id], {
        kind: 'SUPPORT',
        title: `Ticket Assigned: ${ticket.ticketNo}`,
        body: `You have been assigned to handle support ticket "${ticket.title}".`,
        path: `/support/${ticket.id}`,
      });
    }
    return updated;
  },

  async setInReview(params: {
    ticketId: string;
    actorId: string;
    etaAt: string | Date;
    note?: string | null;
  }) {
    const ticket = await this.getById(params.ticketId);
    if (ticket.status === SupportTicketStatus.CLOSED) {
      throw new Error('Ticket is already closed');
    }
    const etaAt = new Date(params.etaAt);
    if (Number.isNaN(etaAt.getTime())) throw new Error('Invalid ETA date/time');

    const updated = await prisma.supportTicket.update({
      where: { id: ticket.id },
      data: {
        status: SupportTicketStatus.IN_REVIEW,
        etaAt,
        events: {
          create: {
            actorId: params.actorId,
            fromStatus: ticket.status,
            toStatus: SupportTicketStatus.IN_REVIEW,
            note:
              params.note?.trim() ||
              `In review · ETA ${etaAt.toISOString()}`,
          },
        },
      },
      include: ticketInclude,
    });

    const raiserUserId = updated.employee?.user?.id;
    if (raiserUserId) {
      void notifyUsers([raiserUserId], {
        title: 'Support ticket in review',
        body: `${updated.ticketNo}: IT set ETA for resolution`,
        path: `/support/${updated.id}`,
      });
    }

    // Email employee about In-Review with ETA
    void (async () => {
      try {
        const employeeEmail = await resolveEmployeeEmail(updated.employeeId);
        if (employeeEmail) {
          await sendSupportTicketNotificationEmail({
            to: employeeEmail,
            isHandler: false,
            action: 'IN_REVIEW',
            ticket: buildEmailTicketParams(updated, params.note),
          });
        }
      } catch (err) {
        console.error('[SUPPORT SERVICE] Error dispatching in-review email:', err);
      }
    })();

    return updated;
  },

  async markResolved(params: {
    ticketId: string;
    actorId: string;
    remarks: string;
  }) {
    const ticket = await this.getById(params.ticketId);
    if (ticket.status === SupportTicketStatus.CLOSED) {
      throw new Error('Ticket is already closed');
    }
    if (
      ticket.status !== SupportTicketStatus.IN_REVIEW &&
      ticket.status !== SupportTicketStatus.OPEN
    ) {
      throw new Error('Only open or in-review tickets can be marked resolved');
    }
    const remarks = params.remarks.trim();
    if (!remarks) throw new Error('Resolve remarks are required');

    // If still OPEN, require ETA so employee gets a review record first.
    if (ticket.status === SupportTicketStatus.OPEN && !ticket.etaAt) {
      throw new Error('Set an ETA (Start review) before marking resolved');
    }

    const updated = await prisma.supportTicket.update({
      where: { id: ticket.id },
      data: {
        status: SupportTicketStatus.RESOLVED,
        resolveRemarks: remarks,
        events: {
          create: {
            actorId: params.actorId,
            fromStatus: ticket.status,
            toStatus: SupportTicketStatus.RESOLVED,
            note: remarks,
          },
        },
      },
      include: ticketInclude,
    });

    const raiserUserId = updated.employee?.user?.id;
    if (raiserUserId) {
      void notifyUsers([raiserUserId], {
        title: 'Support ticket resolved — please confirm',
        body: `${updated.ticketNo}: ${remarks}`,
        path: `/support/${updated.id}`,
      });
    }

    // Email employee about Resolution
    void (async () => {
      try {
        const employeeEmail = await resolveEmployeeEmail(updated.employeeId);
        if (employeeEmail) {
          await sendSupportTicketNotificationEmail({
            to: employeeEmail,
            isHandler: false,
            action: 'RESOLVED',
            ticket: buildEmailTicketParams(updated, remarks),
          });
        }
      } catch (err) {
        console.error('[SUPPORT SERVICE] Error dispatching resolved email:', err);
      }
    })();

    // Pop queued ticket if any
    void popNextQueuedTicket(updated.assignedHandlerId ?? undefined);

    return updated;
  },

  async confirm(params: { ticketId: string; actorId: string; employeeId: number }) {
    const ticket = await this.getById(params.ticketId);
    if (ticket.employeeId !== params.employeeId) {
      throw new Error('Only the ticket owner can confirm');
    }
    if (ticket.status !== SupportTicketStatus.RESOLVED) {
      throw new Error('Only resolved tickets can be confirmed');
    }

    const updated = await prisma.supportTicket.update({
      where: { id: ticket.id },
      data: {
        status: SupportTicketStatus.CLOSED,
        closedAt: new Date(),
        forceClosed: false,
        events: {
          create: {
            actorId: params.actorId,
            fromStatus: SupportTicketStatus.RESOLVED,
            toStatus: SupportTicketStatus.CLOSED,
            note: 'Confirmed by employee',
          },
        },
      },
      include: ticketInclude,
    });

    const itIds = await resolveItUserIds();
    void notifyUsers(itIds, {
      title: 'Support ticket closed (confirmed)',
      body: `${updated.ticketNo}: Confirmed resolved by ${employeeLabel(updated)}`,
      path: `/support/${updated.id}`,
    });

    // Email IT handlers about confirmation
    void (async () => {
      try {
        const itEmails = await resolveUserEmails(itIds);
        if (itEmails.length > 0) {
          await sendSupportTicketNotificationEmail({
            to: itEmails,
            isHandler: true,
            action: 'CONFIRMED',
            ticket: buildEmailTicketParams(updated, 'Confirmed by employee'),
          });
        }
      } catch (err) {
        console.error('[SUPPORT SERVICE] Error dispatching confirmed email:', err);
      }
    })();

    void popNextQueuedTicket(updated.assignedHandlerId ?? undefined);

    return updated;
  },

  async deny(params: {
    ticketId: string;
    actorId: string;
    employeeId: number;
    note?: string | null;
  }) {
    const ticket = await this.getById(params.ticketId);
    if (ticket.employeeId !== params.employeeId) {
      throw new Error('Only the ticket owner can deny');
    }
    if (ticket.status !== SupportTicketStatus.RESOLVED) {
      throw new Error('Only resolved tickets can be denied');
    }
    const note = params.note?.trim() || 'Denied by employee — back to IT review';

    const updated = await prisma.supportTicket.update({
      where: { id: ticket.id },
      data: {
        status: SupportTicketStatus.IN_REVIEW,
        denyRemarks: note,
        resolveRemarks: null,
        events: {
          create: {
            actorId: params.actorId,
            fromStatus: SupportTicketStatus.RESOLVED,
            toStatus: SupportTicketStatus.IN_REVIEW,
            note,
          },
        },
      },
      include: ticketInclude,
    });

    const itIds = await resolveItUserIds();
    void notifyUsers(itIds, {
      title: 'Support ticket denied',
      body: `${updated.ticketNo}: ${employeeLabel(updated)} asked for more work`,
      path: `/support/${updated.id}`,
    });

    // Email IT handlers about denial
    void (async () => {
      try {
        const itEmails = await resolveUserEmails(itIds);
        if (itEmails.length > 0) {
          await sendSupportTicketNotificationEmail({
            to: itEmails,
            isHandler: true,
            action: 'DENIED',
            ticket: buildEmailTicketParams(updated, note),
          });
        }
      } catch (err) {
        console.error('[SUPPORT SERVICE] Error dispatching denied email:', err);
      }
    })();

    return updated;
  },

  async forceClose(params: {
    ticketId: string;
    actorId: string;
    remarks: string;
  }) {
    const ticket = await this.getById(params.ticketId);
    if (ticket.status === SupportTicketStatus.CLOSED) {
      throw new Error('Ticket is already closed');
    }
    const remarks = params.remarks.trim();
    if (!remarks) throw new Error('Force-close remarks are required');

    const updated = await prisma.supportTicket.update({
      where: { id: ticket.id },
      data: {
        status: SupportTicketStatus.CLOSED,
        forceClosed: true,
        closedAt: new Date(),
        resolveRemarks: remarks,
        events: {
          create: {
            actorId: params.actorId,
            fromStatus: ticket.status,
            toStatus: SupportTicketStatus.CLOSED,
            note: `Force closed by IT: ${remarks}`,
          },
        },
      },
      include: ticketInclude,
    });

    const raiserUserId = updated.employee?.user?.id;
    if (raiserUserId) {
      void notifyUsers([raiserUserId], {
        title: 'Support ticket force-closed',
        body: `${updated.ticketNo}: ${remarks}`,
        path: `/support/${updated.id}`,
      });
    }

    // Email employee about force-close
    void (async () => {
      try {
        const employeeEmail = await resolveEmployeeEmail(updated.employeeId);
        if (employeeEmail) {
          await sendSupportTicketNotificationEmail({
            to: employeeEmail,
            isHandler: false,
            action: 'FORCE_CLOSED',
            ticket: buildEmailTicketParams(updated, remarks),
          });
        }
      } catch (err) {
        console.error('[SUPPORT SERVICE] Error dispatching force-closed email:', err);
      }
    })();

    void popNextQueuedTicket(updated.assignedHandlerId ?? undefined);

    return updated;
  },

  async listHandlers() {
    const rows = await prisma.supportItAssignee.findMany({
      include: assigneeInclude,
      orderBy: { createdAt: 'asc' },
    });
    return rows.map((row) => ({
      id: row.id,
      employeeId: row.employeeId,
      createdAt: row.createdAt,
      createdBy: row.createdBy,
      fullName: row.employee.generalInfo?.fullName ?? null,
      employeeCode: row.employee.generalInfo?.employeeCode ?? null,
      designation: row.employee.generalInfo?.designation ?? null,
      department: row.employee.generalInfo?.department ?? null,
      userId: row.employee.user?.id ?? null,
    }));
  },

  async setHandlers(params: { employeeIds: number[]; actorId: string }) {
    const unique = [
      ...new Set(
        params.employeeIds
          .map((id) => Number(id))
          .filter((id) => Number.isFinite(id) && id > 0),
      ),
    ];

    if (unique.length > 0) {
      const found = await prisma.employee.findMany({
        where: { id: { in: unique }, status: EmployeeStatus.ACTIVE },
        select: { id: true },
      });
      const foundIds = new Set(found.map((e) => e.id));
      const missing = unique.filter((id) => !foundIds.has(id));
      if (missing.length > 0) {
        throw new Error(`Unknown or inactive employee id(s): ${missing.join(', ')}`);
      }
    }

    await prisma.$transaction(async (tx) => {
      await tx.supportItAssignee.deleteMany({});
      if (unique.length > 0) {
        await tx.supportItAssignee.createMany({
          data: unique.map((employeeId) => ({
            employeeId,
            createdBy: params.actorId,
          })),
        });
      }
    });

    return this.listHandlers();
  },

  async capabilities(opts: {
    employeeId: number | null;
    rolePrivileged: boolean;
    canManageHandlers: boolean;
  }) {
    const assignedIds = await assignedEmployeeIds();
    const handlersConfigured = assignedIds.length > 0;
    const isAssigned =
      opts.employeeId != null && assignedIds.includes(opts.employeeId);

    let isIt = false;
    if (handlersConfigured) {
      // Only assigned employees + Admins who can manage the list.
      isIt = isAssigned || opts.canManageHandlers;
    } else {
      isIt = opts.rolePrivileged || isAssigned;
    }

    return {
      isIt,
      canManageHandlers: opts.canManageHandlers,
      handlersConfigured,
      isAssignedHandler: isAssigned,
    };
  },

  async getQueueStatus() {
    const queuedCount = await prisma.supportTicket.count({
      where: { status: SupportTicketStatus.QUEUED },
    });
    const activeAssignees = await prisma.supportItAssignee.findMany({
      where: { isActive: true },
      include: assigneeInclude,
    });
    const handlerLoads = await Promise.all(
      activeAssignees.map(async (a) => {
        const load = await prisma.supportTicket.count({
          where: {
            assignedHandlerId: a.employeeId,
            status: { in: [SupportTicketStatus.OPEN, SupportTicketStatus.IN_REVIEW] },
          },
        });
        return {
          employeeId: a.employeeId,
          name: a.employee.generalInfo?.fullName ?? `Handler #${a.employeeId}`,
          load,
          max: a.maxConcurrentTickets ?? 3,
          isFull: load >= (a.maxConcurrentTickets ?? 3),
        };
      }),
    );
    return {
      queuedCount,
      handlers: handlerLoads,
      allBusy: handlerLoads.length > 0 && handlerLoads.every((h) => h.isFull),
    };
  },

  // ==========================================
  // LIVE CHAT
  // ==========================================
  async listMessages(ticketId: string) {
    return prisma.supportTicketMessage.findMany({
      where: { ticketId },
      orderBy: { createdAt: 'asc' },
    });
  },

  async sendMessage(params: {
    ticketId: string;
    senderId: string;
    senderRole: string; // "EMPLOYEE" or "IT_HANDLER"
    senderName?: string | null;
    message: string;
    attachmentUrl?: string | null;
    attachmentName?: string | null;
  }) {
    const msgText = params.message.trim();
    if (!msgText && !params.attachmentUrl) {
      throw new Error('Message text or attachment required');
    }

    const ticket = await this.getById(params.ticketId);
    const msg = await prisma.supportTicketMessage.create({
      data: {
        ticketId: params.ticketId,
        senderId: params.senderId,
        senderRole: params.senderRole,
        senderName: params.senderName,
        message: msgText,
        attachmentUrl: params.attachmentUrl?.trim() || null,
        attachmentName: params.attachmentName?.trim() || null,
      },
    });

    const raiserUserId = ticket.employee?.user?.id;
    const itIds = await resolveItUserIds();
    const recipientIds =
      params.senderRole === 'EMPLOYEE'
        ? itIds.filter((id) => id !== params.senderId)
        : raiserUserId && raiserUserId !== params.senderId
        ? [raiserUserId]
        : [];

    if (recipientIds.length > 0) {
      void notifyUsers(recipientIds, {
        title: `Message on ${ticket.ticketNo}`,
        body: `${params.senderName ?? 'Support'}: ${msgText || 'Sent an attachment'}`,
        path: `/support/${ticket.id}`,
      });
    }

    return msg;
  },

  // ==========================================
  // TICKET TRANSFER WITH APPROVAL
  // ==========================================
  async requestTransfer(params: {
    ticketId: string;
    actorId: string;
    targetHandlerEmployeeId: number;
    reason: string;
  }) {
    const ticket = await this.getById(params.ticketId);
    if (ticket.status === SupportTicketStatus.CLOSED) {
      throw new Error('Cannot transfer closed ticket');
    }
    const reason = params.reason.trim();
    if (!reason) throw new Error('Transfer reason is required');

    const targetEmp = await prisma.employee.findUnique({
      where: { id: params.targetHandlerEmployeeId },
      include: {
        generalInfo: { select: { fullName: true } },
        user: { select: { id: true } },
      },
    });
    if (!targetEmp) throw new Error('Target handler employee not found');

    const updated = await prisma.supportTicket.update({
      where: { id: ticket.id },
      data: {
        transferStatus: 'PENDING',
        transferTargetHandlerId: params.targetHandlerEmployeeId,
        transferReason: reason,
        transferRequestedBy: params.actorId,
        transferRequestedAt: new Date(),
        events: {
          create: {
            actorId: params.actorId,
            fromStatus: ticket.status,
            toStatus: ticket.status,
            note: `Transfer requested to ${targetEmp.generalInfo?.fullName ?? 'Handler'}: ${reason}`,
          },
        },
      },
      include: ticketInclude,
    });

    if (targetEmp.user?.id) {
      void notifyUsers([targetEmp.user.id], {
        title: 'Ticket Transfer Request',
        body: `Ticket #${updated.ticketNo} transferred to you: ${reason}`,
        path: `/support/${updated.id}`,
      });
    }

    return updated;
  },

  async respondTransfer(params: {
    ticketId: string;
    actorId: string;
    accept: boolean;
    remarks?: string | null;
  }) {
    const ticket = await this.getById(params.ticketId);
    if (ticket.transferStatus !== 'PENDING') {
      throw new Error('No pending transfer on this ticket');
    }

    if (params.accept) {
      const updated = await prisma.supportTicket.update({
        where: { id: ticket.id },
        data: {
          assignedHandlerId: ticket.transferTargetHandlerId,
          transferStatus: 'APPROVED',
          events: {
            create: {
              actorId: params.actorId,
              fromStatus: ticket.status,
              toStatus: ticket.status,
              note: `Transfer accepted by handler. ${params.remarks ? `Remarks: ${params.remarks}` : ''}`,
            },
          },
        },
        include: ticketInclude,
      });

      if (ticket.transferRequestedBy) {
        void notifyUsers([ticket.transferRequestedBy], {
          title: 'Transfer Accepted',
          body: `Ticket #${updated.ticketNo} transfer was accepted`,
          path: `/support/${updated.id}`,
        });
      }
      return updated;
    } else {
      const updated = await prisma.supportTicket.update({
        where: { id: ticket.id },
        data: {
          transferStatus: 'REJECTED',
          events: {
            create: {
              actorId: params.actorId,
              fromStatus: ticket.status,
              toStatus: ticket.status,
              note: `Transfer rejected: ${params.remarks ?? 'Declined by handler'}`,
            },
          },
        },
        include: ticketInclude,
      });

      if (ticket.transferRequestedBy) {
        void notifyUsers([ticket.transferRequestedBy], {
          title: 'Transfer Declined',
          body: `Ticket #${updated.ticketNo} transfer was declined: ${params.remarks ?? ''}`,
          path: `/support/${updated.id}`,
        });
      }
      return updated;
    }
  },

  // ==========================================
  // CUSTOM NB REMOTE OPERATOR SIGNALING
  // ==========================================
  async requestRemoteSession(params: {
    ticketId: string;
    handlerUserId: string;
    accessLevel?: string;
    uacEnabled?: boolean;
  }) {
    const ticket = await this.getById(params.ticketId);
    const employeeUserId = ticket.employee?.user?.id;
    if (!employeeUserId) {
      throw new Error('Ticket owner does not have an active user account');
    }

    await prisma.supportRemoteSession.updateMany({
      where: {
        ticketId: ticket.id,
        status: { in: ['REQUESTED', 'ACCEPTED', 'ACTIVE'] },
      },
      data: { status: 'ENDED', endedAt: new Date() },
    });

    const roomName = `remote-${ticket.ticketNo.toLowerCase()}-${Date.now().toString(36)}`;
    const session = await prisma.supportRemoteSession.create({
      data: {
        ticketId: ticket.id,
        roomName,
        handlerUserId: params.handlerUserId,
        employeeUserId,
        status: 'REQUESTED',
        accessLevel: params.accessLevel ?? 'FULL_CONTROL',
        uacEnabled: params.uacEnabled ?? true,
      },
    });

    void notifyUsers([employeeUserId], {
      title: 'Remote Support Request',
      body: 'IT Specialist is requesting remote access to your computer. Tap to grant permission.',
      path: `/support/${ticket.id}?remote=1`,
    });

    return session;
  },

  async respondRemoteSession(params: {
    sessionId: string;
    employeeUserId: string;
    accept: boolean;
  }) {
    const session = await prisma.supportRemoteSession.findUnique({
      where: { id: params.sessionId },
    });
    if (!session) throw new Error('Remote session not found');

    const updated = await prisma.supportRemoteSession.update({
      where: { id: session.id },
      data: {
        status: params.accept ? 'ACCEPTED' : 'REJECTED',
        startedAt: params.accept ? new Date() : null,
      },
    });

    void notifyUsers([session.handlerUserId], {
      title: params.accept ? 'Remote Session Granted' : 'Remote Session Declined',
      body: params.accept
        ? 'The employee accepted the remote control request.'
        : 'The employee declined the remote control request.',
      path: `/support/${session.ticketId}?remote=1`,
    });

    return updated;
  },

  async endRemoteSession(params: {
    sessionId: string;
    endedByUserId: string;
  }) {
    const session = await prisma.supportRemoteSession.findUnique({
      where: { id: params.sessionId },
    });
    if (!session) throw new Error('Remote session not found');

    const updated = await prisma.supportRemoteSession.update({
      where: { id: session.id },
      data: {
        status: 'ENDED',
        endedAt: new Date(),
        endedBy: params.endedByUserId,
      },
    });

    const otherUser =
      params.endedByUserId === session.handlerUserId
        ? session.employeeUserId
        : session.handlerUserId;

    void notifyUsers([otherUser], {
      title: 'Remote Session Ended',
      body: 'The remote desktop session has been terminated.',
      path: `/support/${session.ticketId}`,
    });

    return updated;
  },

  async getActiveRemoteSession(ticketId: string) {
    return prisma.supportRemoteSession.findFirst({
      where: {
        ticketId,
        status: { in: ['REQUESTED', 'ACCEPTED', 'ACTIVE'] },
      },
      orderBy: { createdAt: 'desc' },
    });
  },

  async generateRemoteToken(params: {
    ticketId: string;
    userId: string;
    userName: string;
  }) {
    const session = await this.getActiveRemoteSession(params.ticketId);
    if (!session) throw new Error('No active remote session for this ticket');
    let token = '';
    let livekitUrl = '';
    try {
      token = await issueLiveKitToken({
        roomName: session.roomName,
        identity: params.userId,
        name: params.userName,
        metadata: {
          ticketId: params.ticketId,
          sessionId: session.id,
          isHandler: session.handlerUserId === params.userId,
        },
      });
      livekitUrl = livekitPublicUrl();
    } catch (err) {
      console.warn('[SUPPORT] Failed to issue LiveKit token:', err);
    }
    return {
      session,
      token,
      livekitUrl,
      roomName: session.roomName,
    };
  },

  // Remote Desktop Control Command Queue for Windows Agent
  pushRemoteCommand(ticketId: string, cmd: { type: string; x?: number; y?: number; button?: string; key?: string; text?: string }) {
    if (!remoteCommandQueues.has(ticketId)) {
      remoteCommandQueues.set(ticketId, []);
    }
    const q = remoteCommandQueues.get(ticketId)!;
    q.push({
      id: Math.random().toString(36).substring(2, 9),
      ...cmd,
      timestamp: Date.now(),
    });
    // keep at most 50 recent commands
    if (q.length > 50) q.splice(0, q.length - 50);
    return { ok: true };
  },

  popRemoteCommands(ticketId: string) {
    agentStatusMap.set(ticketId, { lastHeartbeat: Date.now(), online: true });
    const q = remoteCommandQueues.get(ticketId) || [];
    remoteCommandQueues.set(ticketId, []);
    return q;
  },

  getAgentStatus(ticketId: string) {
    const status = agentStatusMap.get(ticketId);
    if (!status) return { online: false, lastSeen: 0 };
    const online = Date.now() - status.lastHeartbeat < 15000;
    return { online, lastSeen: status.lastHeartbeat };
  },

  generateAgentScript(ticketId: string, serverUrl: string): string {
    return `# NB-HRMS Remote Desktop Control Agent
# Ticket: ${ticketId}
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$code = @"
using System;
using System.Runtime.InteropServices;
namespace NBAgent {
    public class Native {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint cButtons, uint dwExtraInfo);
    }
}
"@
Add-Type -TypeDefinition $code -Language CSharp -ErrorAction SilentlyContinue

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "       NB-HRMS IT Support Remote Agent (Option 1)        " -ForegroundColor Yellow
Write-Host "       Ticket ID: ${ticketId}" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "[*] Windows OS Input Bridge Loaded." -ForegroundColor Green
Write-Host "[*] Connected to Server: ${serverUrl}" -ForegroundColor Green
Write-Host "[+] ACTIVE: IT Support now has real mouse and keyboard control." -ForegroundColor Cyan
Write-Host "[!] Press Ctrl+C in this console window to disconnect anytime." -ForegroundColor Gray
Write-Host ""

$screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
$screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height

while ($true) {
    try {
        $url = "${serverUrl}/api/support/${ticketId}/remote/commands"
        $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 4
        if ($resp -and $resp.data) {
            foreach ($cmd in $resp.data) {
                if ($cmd.type -eq "mouse_move" -and $cmd.x -ne $null -and $cmd.y -ne $null) {
                    $x = [int]($cmd.x * $screenWidth)
                    $y = [int]($cmd.y * $screenHeight)
                    [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($x, $y)
                }
                elseif ($cmd.type -eq "mouse_click") {
                    if ($cmd.x -ne $null -and $cmd.y -ne $null) {
                        $x = [int]($cmd.x * $screenWidth)
                        $y = [int]($cmd.y * $screenHeight)
                        [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($x, $y)
                    }
                    if ($cmd.button -eq "right") {
                        [NBAgent.Native]::mouse_event(0x08, 0, 0, 0, 0)
                        Start-Sleep -Milliseconds 15
                        [NBAgent.Native]::mouse_event(0x10, 0, 0, 0, 0)
                    } else {
                        [NBAgent.Native]::mouse_event(0x02, 0, 0, 0, 0)
                        Start-Sleep -Milliseconds 15
                        [NBAgent.Native]::mouse_event(0x04, 0, 0, 0, 0)
                    }
                }
                elseif ($cmd.type -eq "key" -and $cmd.key) {
                    [System.Windows.Forms.SendKeys]::SendWait($cmd.key)
                }
                elseif ($cmd.type -eq "special_key") {
                    if ($cmd.key -eq "Win+R") {
                        [System.Windows.Forms.SendKeys]::SendWait("^{ESC}r")
                    } elseif ($cmd.key -eq "TaskMgr") {
                        Start-Process "taskmgr.exe"
                    } elseif ($cmd.key -eq "Win+X") {
                        [System.Windows.Forms.SendKeys]::SendWait("^{ESC}x")
                    } elseif ($cmd.key -eq "Alt+Tab") {
                        [System.Windows.Forms.SendKeys]::SendWait("%{TAB}")
                    }
                }
                elseif ($cmd.type -eq "clipboard" -and $cmd.text) {
                    [System.Windows.Forms.Clipboard]::SetText($cmd.text)
                }
            }
        }
    } catch {}
    Start-Sleep -Milliseconds 50
}
`;
  },
};

interface RemoteControlCommand {
  id: string;
  type: string;
  x?: number;
  y?: number;
  button?: string;
  key?: string;
  text?: string;
  timestamp: number;
}

const remoteCommandQueues = new Map<string, RemoteControlCommand[]>();
const agentStatusMap = new Map<string, { lastHeartbeat: number; online: boolean }>();

export type SupportTicketWithRelations = Prisma.SupportTicketGetPayload<{
  include: typeof ticketInclude;
}>;
