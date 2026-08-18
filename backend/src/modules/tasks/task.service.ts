import { prisma } from '../../config/prisma';
import type { WorkTaskStatus } from '@prisma/client';

const CLOSED: WorkTaskStatus[] = ['APPROVED', 'REJECTED'];

function personName(row: {
  employee?: { generalInfo?: { fullName?: string | null } | null } | null;
  username?: string | null;
} | null | undefined) {
  return row?.employee?.generalInfo?.fullName || row?.username || 'Unknown';
}

function mapUser(row: {
  id: string;
  employeeId: number | null;
  username: string | null;
  employee?: { generalInfo?: { fullName?: string | null } | null } | null;
} | null | undefined) {
  if (!row) return null;
  return {
    id: row.id,
    employeeId: row.employeeId,
    name: personName(row),
  };
}

function mapTask(row: Awaited<ReturnType<typeof loadTask>>) {
  if (!row) return null;
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    status: row.status,
    deadline: row.deadline.toISOString(),
    startedAt: row.startedAt?.toISOString() ?? null,
    completedAt: row.completedAt?.toISOString() ?? null,
    reviewedAt: row.reviewedAt?.toISOString() ?? null,
    attachmentUrl: row.attachmentUrl,
    attachmentName: row.attachmentName,
    attachmentMime: row.attachmentMime,
    extraApproverUserId: row.extraApproverUserId,
    extraApprovalStatus: row.extraApprovalStatus,
    extraApprovalRemarks: row.extraApprovalRemarks,
    extraApprovalDecidedAt: row.extraApprovalDecidedAt?.toISOString() ?? null,
    reviewRemarks: row.reviewRemarks,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
    assigner: mapUser(row.assigner),
    assignee: mapUser(row.assignee),
    extraApprover: mapUser(row.extraApprover),
    events: row.events.map((e) => ({
      id: e.id,
      type: e.type,
      fromStatus: e.fromStatus,
      toStatus: e.toStatus,
      remarks: e.remarks,
      newDeadline: e.newDeadline?.toISOString() ?? null,
      createdAt: e.createdAt.toISOString(),
      actor: mapUser(e.actor),
    })),
  };
}

const taskInclude = {
  assigner: {
    select: {
      id: true,
      employeeId: true,
      username: true,
      employee: { select: { generalInfo: { select: { fullName: true } } } },
    },
  },
  assignee: {
    select: {
      id: true,
      employeeId: true,
      username: true,
      employee: { select: { generalInfo: { select: { fullName: true } } } },
    },
  },
  extraApprover: {
    select: {
      id: true,
      employeeId: true,
      username: true,
      employee: { select: { generalInfo: { select: { fullName: true } } } },
    },
  },
  events: {
    orderBy: { createdAt: 'asc' as const },
    include: {
      actor: {
        select: {
          id: true,
          employeeId: true,
          username: true,
          employee: { select: { generalInfo: { select: { fullName: true } } } },
        },
      },
    },
  },
};

async function loadTask(id: string) {
  return prisma.workTask.findUnique({
    where: { id },
    include: taskInclude,
  });
}

async function assertReportee(managerUserId: string, assigneeUserId: string) {
  const gi = await prisma.employeeGeneralInfo.findFirst({
    where: {
      employee: { userId: assigneeUserId },
      firstApproverUserId: managerUserId,
    },
    select: { employeeId: true, employee: { select: { userId: true } } },
  });
  if (!gi) {
    throw new Error('Only the 1st reporting manager can assign a task to this person');
  }
  return gi.employeeId;
}

export const taskService = {
  async listReportees(managerUserId: string) {
    const rows = await prisma.employeeGeneralInfo.findMany({
      where: { firstApproverUserId: managerUserId },
      select: {
        employeeId: true,
        fullName: true,
        designation: true,
        employeeCode: true,
        employee: { select: { userId: true, photoUrl: true } },
      },
      orderBy: { fullName: 'asc' },
    });

    return rows
      .filter((r) => r.employee.userId)
      .map((r) => ({
        userId: r.employee.userId,
        employeeId: r.employeeId,
        fullName: r.fullName,
        designation: r.designation,
        employeeCode: r.employeeCode,
        photoUrl: r.employee.photoUrl,
        reportingLayer: 1,
      }));
  },

  async create(params: {
    assignerUserId: string;
    assigneeUserId: string;
    title: string;
    description?: string | null;
    deadline: Date | string;
    extraApproverUserId?: string | null;
    attachmentUrl?: string | null;
    attachmentName?: string | null;
    attachmentMime?: string | null;
  }) {
    const title = params.title.trim();
    if (!title) throw new Error('Title is required');
    const deadline = new Date(params.deadline);
    if (Number.isNaN(deadline.getTime())) throw new Error('Deadline is required');

    const employeeId = await assertReportee(params.assignerUserId, params.assigneeUserId);
    if (params.assigneeUserId === params.assignerUserId) {
      throw new Error('You cannot assign a task to yourself');
    }

    let extraApproverUserId = params.extraApproverUserId?.trim() || null;
    if (extraApproverUserId === params.assignerUserId || extraApproverUserId === params.assigneeUserId) {
      extraApproverUserId = null;
    }

    const created = await prisma.workTask.create({
      data: {
        title,
        description: params.description?.trim() || null,
        assignerUserId: params.assignerUserId,
        assigneeUserId: params.assigneeUserId,
        assigneeEmployeeId: employeeId,
        deadline,
        extraApproverUserId,
        extraApprovalStatus: extraApproverUserId ? 'PENDING' : null,
        attachmentUrl: params.attachmentUrl ?? null,
        attachmentName: params.attachmentName ?? null,
        attachmentMime: params.attachmentMime ?? null,
        events: {
          create: {
            actorUserId: params.assignerUserId,
            type: 'CREATED',
            toStatus: 'ASSIGNED',
          },
        },
      },
    });

    return mapTask(await loadTask(created.id));
  },

  async listMine(userId: string, filter?: 'inbox' | 'assigned' | 'review' | 'extra' | 'all') {
    const where =
      filter === 'inbox'
        ? { assigneeUserId: userId, status: { in: ['ASSIGNED', 'ONGOING', 'CHANGES_REQUESTED'] as WorkTaskStatus[] } }
        : filter === 'assigned'
          ? { assignerUserId: userId }
          : filter === 'review'
            ? { assignerUserId: userId, status: 'COMPLETED' as const }
            : filter === 'extra'
              ? { extraApproverUserId: userId, extraApprovalStatus: 'PENDING' as const }
              : {
                  OR: [
                    { assigneeUserId: userId },
                    { assignerUserId: userId },
                    { extraApproverUserId: userId },
                  ],
                };

    const rows = await prisma.workTask.findMany({
      where,
      include: taskInclude,
      orderBy: [{ deadline: 'asc' }, { createdAt: 'desc' }],
    });
    return rows.map((r) => mapTask(r));
  },

  async summary(userId: string) {
    const [inbox, review, extra, changes] = await Promise.all([
      prisma.workTask.count({
        where: {
          assigneeUserId: userId,
          status: { in: ['ASSIGNED', 'ONGOING', 'CHANGES_REQUESTED'] },
        },
      }),
      prisma.workTask.count({
        where: { assignerUserId: userId, status: 'COMPLETED' },
      }),
      prisma.workTask.count({
        where: { extraApproverUserId: userId, extraApprovalStatus: 'PENDING' },
      }),
      prisma.workTask.count({
        where: { assigneeUserId: userId, status: 'CHANGES_REQUESTED' },
      }),
    ]);
    return { inbox, review, extra, changes };
  },

  async getById(id: string, userId: string) {
    const row = await loadTask(id);
    if (!row) throw new Error('Task not found');
    const allowed =
      row.assignerUserId === userId ||
      row.assigneeUserId === userId ||
      row.extraApproverUserId === userId;
    if (!allowed) throw new Error('You cannot view this task');
    return mapTask(row);
  },

  async setStatus(params: { taskId: string; actorUserId: string; status: WorkTaskStatus }) {
    const row = await prisma.workTask.findUnique({ where: { id: params.taskId } });
    if (!row) throw new Error('Task not found');
    if (row.assigneeUserId !== params.actorUserId) {
      throw new Error('Only the assignee can update task progress');
    }
    if (CLOSED.includes(row.status)) throw new Error('This task is already closed');

    const allowed: Record<WorkTaskStatus, WorkTaskStatus[]> = {
      ASSIGNED: ['ONGOING'],
      ONGOING: ['COMPLETED'],
      CHANGES_REQUESTED: ['ONGOING', 'COMPLETED'],
      COMPLETED: [],
      APPROVED: [],
      REJECTED: [],
    };
    if (!allowed[row.status].includes(params.status)) {
      throw new Error(`Cannot move from ${row.status} to ${params.status}`);
    }

    const now = new Date();
    const updated = await prisma.workTask.update({
      where: { id: row.id },
      data: {
        status: params.status,
        startedAt:
          params.status === 'ONGOING' || params.status === 'COMPLETED'
            ? row.startedAt ?? now
            : row.startedAt,
        completedAt: params.status === 'COMPLETED' ? now : row.completedAt,
        events: {
          create: {
            actorUserId: params.actorUserId,
            type: 'STATUS_CHANGED',
            fromStatus: row.status,
            toStatus: params.status,
          },
        },
      },
    });
    return mapTask(await loadTask(updated.id));
  },

  async requestExtraApproval(params: {
    taskId: string;
    actorUserId: string;
    extraApproverUserId: string;
  }) {
    const row = await prisma.workTask.findUnique({ where: { id: params.taskId } });
    if (!row) throw new Error('Task not found');
    if (row.assigneeUserId !== params.actorUserId && row.assignerUserId !== params.actorUserId) {
      throw new Error('Only the assignee or assigner can request extra approval');
    }
    if (CLOSED.includes(row.status)) throw new Error('This task is already closed');
    if (params.extraApproverUserId === row.assigneeUserId || params.extraApproverUserId === row.assignerUserId) {
      throw new Error('Pick someone other than the assignee or assigner');
    }

    const updated = await prisma.workTask.update({
      where: { id: row.id },
      data: {
        extraApproverUserId: params.extraApproverUserId,
        extraApprovalStatus: 'PENDING',
        extraApprovalRemarks: null,
        extraApprovalDecidedAt: null,
        events: {
          create: {
            actorUserId: params.actorUserId,
            type: 'EXTRA_APPROVAL_REQUESTED',
            remarks: 'Extra approval requested',
          },
        },
      },
    });
    return mapTask(await loadTask(updated.id));
  },

  async decideExtraApproval(params: {
    taskId: string;
    actorUserId: string;
    approve: boolean;
    remarks?: string | null;
  }) {
    const row = await prisma.workTask.findUnique({ where: { id: params.taskId } });
    if (!row) throw new Error('Task not found');
    if (row.extraApproverUserId !== params.actorUserId) {
      throw new Error('Only the requested approver can decide this');
    }
    if (row.extraApprovalStatus !== 'PENDING') throw new Error('No pending extra approval');

    const updated = await prisma.workTask.update({
      where: { id: row.id },
      data: {
        extraApprovalStatus: params.approve ? 'APPROVED' : 'REJECTED',
        extraApprovalRemarks: params.remarks?.trim() || null,
        extraApprovalDecidedAt: new Date(),
        events: {
          create: {
            actorUserId: params.actorUserId,
            type: 'EXTRA_APPROVAL_DECIDED',
            remarks: params.remarks?.trim() || (params.approve ? 'Approved' : 'Rejected'),
          },
        },
      },
    });
    return mapTask(await loadTask(updated.id));
  },

  async review(params: {
    taskId: string;
    actorUserId: string;
    action: 'approve' | 'reject' | 'changes';
    remarks?: string | null;
    newDeadline?: Date | string | null;
  }) {
    const row = await prisma.workTask.findUnique({ where: { id: params.taskId } });
    if (!row) throw new Error('Task not found');
    if (row.assignerUserId !== params.actorUserId) {
      throw new Error('Only the person who assigned this task can review it');
    }
    if (row.status !== 'COMPLETED') {
      throw new Error('Review is only available after the assignee marks the task completed');
    }

    if (params.action === 'approve') {
      const updated = await prisma.workTask.update({
        where: { id: row.id },
        data: {
          status: 'APPROVED',
          reviewedAt: new Date(),
          reviewRemarks: params.remarks?.trim() || null,
          events: {
            create: {
              actorUserId: params.actorUserId,
              type: 'REVIEWED',
              fromStatus: row.status,
              toStatus: 'APPROVED',
              remarks: params.remarks?.trim() || 'Approved',
            },
          },
        },
      });
      return mapTask(await loadTask(updated.id));
    }

    if (params.action === 'reject') {
      const remarks = params.remarks?.trim();
      if (!remarks) throw new Error('Remarks are required when rejecting a task');
      const updated = await prisma.workTask.update({
        where: { id: row.id },
        data: {
          status: 'REJECTED',
          reviewedAt: new Date(),
          reviewRemarks: remarks,
          events: {
            create: {
              actorUserId: params.actorUserId,
              type: 'REVIEWED',
              fromStatus: row.status,
              toStatus: 'REJECTED',
              remarks,
            },
          },
        },
      });
      return mapTask(await loadTask(updated.id));
    }

    const remarks = params.remarks?.trim();
    if (!remarks) throw new Error('Remarks are required when asking for changes');
    if (!params.newDeadline) throw new Error('A new deadline date and time is required');
    const newDeadline = new Date(params.newDeadline);
    if (Number.isNaN(newDeadline.getTime())) throw new Error('Invalid new deadline');

    const updated = await prisma.workTask.update({
      where: { id: row.id },
      data: {
        status: 'CHANGES_REQUESTED',
        deadline: newDeadline,
        completedAt: null,
        reviewedAt: new Date(),
        reviewRemarks: remarks,
        events: {
          create: {
            actorUserId: params.actorUserId,
            type: 'REVIEWED',
            fromStatus: row.status,
            toStatus: 'CHANGES_REQUESTED',
            remarks,
            newDeadline,
          },
        },
      },
    });
    return mapTask(await loadTask(updated.id));
  },
};
