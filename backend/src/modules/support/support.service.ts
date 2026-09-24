import {
  Prisma,
  SupportTicketStatus,
  EmployeeStatus,
} from '@prisma/client';
import { prisma } from '../../config/prisma';
import { emitPushNotify } from '../collaboration/socket';

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
  }) {
    const title = params.title.trim();
    const description = params.description.trim();
    if (!title) throw new Error('Title is required');
    if (!description) throw new Error('Description is required');

    const ticketNo = await nextTicketNo();
    const ticket = await prisma.supportTicket.create({
      data: {
        ticketNo,
        employeeId: params.employeeId,
        title,
        description,
        photoUrl: params.photoUrl?.trim() || null,
        status: SupportTicketStatus.OPEN,
        createdBy: params.createdBy,
        events: {
          create: {
            actorId: params.createdBy,
            fromStatus: null,
            toStatus: SupportTicketStatus.OPEN,
            note: 'Ticket raised',
          },
        },
      },
      include: ticketInclude,
    });

    const itIds = await resolveItUserIds();
    void notifyUsers(
      itIds.filter((id) => id !== params.createdBy),
      {
        title: 'New support ticket',
        body: `${employeeLabel(ticket)}: ${ticket.title} (${ticket.ticketNo})`,
        path: `/support/${ticket.id}`,
      },
    );

    return ticket;
  },

  async listMine(employeeId: number) {
    return prisma.supportTicket.findMany({
      where: { employeeId },
      include: ticketInclude,
      orderBy: { createdAt: 'desc' },
    });
  },

  async listQueue(opts?: { includeClosed?: boolean }) {
    return prisma.supportTicket.findMany({
      where: opts?.includeClosed
        ? undefined
        : { status: { not: SupportTicketStatus.CLOSED } },
      include: ticketInclude,
      orderBy: [{ status: 'asc' }, { createdAt: 'asc' }],
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

  async assertCanView(ticketId: string, opts: { userId: string; employeeId: number | null; isIt: boolean }) {
    const ticket = await this.getById(ticketId);
    if (opts.isIt) return ticket;
    if (opts.employeeId != null && ticket.employeeId === opts.employeeId) return ticket;
    throw new Error('Not allowed to view this ticket');
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

    return prisma.supportTicket.update({
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
};

export type SupportTicketWithRelations = Prisma.SupportTicketGetPayload<{
  include: typeof ticketInclude;
}>;
