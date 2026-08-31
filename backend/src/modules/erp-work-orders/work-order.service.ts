import { prisma } from '../../config/prisma';
import { Prisma } from '@prisma/client';

function str(v: unknown): string | null {
  if (v == null) return null;
  const s = String(v).trim();
  return s.length ? s : null;
}

function num(v: unknown): number | null {
  if (v == null || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function dec(v: unknown): Prisma.Decimal | null {
  const n = num(v);
  return n == null ? null : new Prisma.Decimal(n);
}

function dateOnly(v: unknown): Date | null {
  const s = str(v);
  if (!s) return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
}

function jsonStr(v: unknown): string | null {
  if (v == null) return null;
  if (typeof v === 'string') return v;
  return JSON.stringify(v);
}

type LineInput = {
  workDetail: string;
  towerIds?: unknown;
  floorNos?: unknown;
  unitIds?: unknown;
  quantity?: unknown;
  unitCode?: string | null;
  rate?: unknown;
  amount?: unknown;
  sortOrder?: number;
};

type GroupInput = {
  activityId?: string | null;
  activityName: string;
  sortOrder?: number;
  lines: LineInput[];
};

const includeDetail = {
  project: {
    select: {
      id: true,
      name: true,
      projectNo: true,
      imageUrl: true,
      categoryCode: true,
      statusCode: true,
    },
  },
  contractor: true,
  owner: {
    select: {
      id: true,
      abbreviation: true,
      photoUrl: true,
      generalInfo: { select: { fullName: true } },
    },
  },
  approver: {
    select: {
      id: true,
      abbreviation: true,
      photoUrl: true,
      generalInfo: { select: { fullName: true } },
    },
  },
  activities: {
    orderBy: [{ sortOrder: 'asc' as const }],
    include: {
      lines: { orderBy: [{ sortOrder: 'asc' as const }] },
      activity: { select: { id: true, name: true } },
    },
  },
};

function parseGroups(raw: unknown): GroupInput[] {
  if (!Array.isArray(raw)) return [];
  const groups: GroupInput[] = [];
  for (let gi = 0; gi < raw.length; gi++) {
    const g = (raw[gi] ?? {}) as Record<string, unknown>;
    const activityName = str(g.activityName);
    if (!activityName) continue;
    const linesRaw = Array.isArray(g.lines) ? g.lines : [];
    const lines: LineInput[] = [];
    for (let li = 0; li < linesRaw.length; li++) {
      const l = (linesRaw[li] ?? {}) as Record<string, unknown>;
      const workDetail = str(l.workDetail);
      if (!workDetail) continue;
      const qty = num(l.quantity);
      const rate = num(l.rate);
      const amount = num(l.amount) ?? (qty != null && rate != null ? qty * rate : null);
      lines.push({
        workDetail,
        towerIds: l.towerIds,
        floorNos: l.floorNos,
        unitIds: l.unitIds,
        quantity: qty,
        unitCode: str(l.unitCode),
        rate,
        amount,
        sortOrder: num(l.sortOrder) ?? li,
      });
    }
    groups.push({
      activityId: str(g.activityId),
      activityName,
      sortOrder: num(g.sortOrder) ?? gi,
      lines,
    });
  }
  return groups;
}

function calcTotal(groups: GroupInput[]): Prisma.Decimal {
  let total = 0;
  for (const g of groups) {
    for (const l of g.lines) {
      total += Number(l.amount) || 0;
    }
  }
  return new Prisma.Decimal(total);
}

async function replaceGroups(workOrderId: string, groups: GroupInput[]) {
  await prisma.erpWorkOrderLine.deleteMany({
    where: { group: { workOrderId } },
  });
  await prisma.erpWorkOrderActivityGroup.deleteMany({ where: { workOrderId } });

  for (const g of groups) {
    await prisma.erpWorkOrderActivityGroup.create({
      data: {
        workOrderId,
        activityId: g.activityId,
        activityName: g.activityName,
        sortOrder: g.sortOrder ?? 0,
        lines: {
          create: g.lines.map((l, i) => ({
            workDetail: l.workDetail,
            towerIds: jsonStr(l.towerIds),
            floorNos: jsonStr(l.floorNos),
            unitIds: jsonStr(l.unitIds),
            quantity: dec(l.quantity),
            unitCode: l.unitCode,
            rate: dec(l.rate),
            amount: dec(l.amount),
            sortOrder: l.sortOrder ?? i,
          })),
        },
      },
    });
  }
}

export const workOrderService = {
  async list() {
    return prisma.erpWorkOrder.findMany({
      orderBy: [{ orderDate: 'desc' }, { createdAt: 'desc' }],
      include: {
        project: { select: { id: true, name: true, projectNo: true, imageUrl: true } },
        contractor: { select: { id: true, name: true } },
        owner: {
          select: {
            id: true,
            abbreviation: true,
            photoUrl: true,
            generalInfo: { select: { fullName: true } },
          },
        },
      },
    });
  },

  async getById(id: string) {
    const row = await prisma.erpWorkOrder.findUnique({
      where: { id },
      include: includeDetail,
    });
    if (!row) throw new Error('Work order not found');
    return row;
  },

  async create(body: Record<string, unknown>, userId?: string) {
    const workOrderId = str(body.workOrderId);
    if (!workOrderId) throw new Error('Work Order ID is required');
    const projectId = str(body.projectId);
    if (!projectId) throw new Error('Project is required');
    const orderDate = dateOnly(body.orderDate);
    if (!orderDate) throw new Error('Date is required');

    const groups = parseGroups(body.activities);
    const totalAmount = calcTotal(groups);

    const created = await prisma.erpWorkOrder.create({
      data: {
        workOrderId,
        orderDate,
        dueDate: dateOnly(body.dueDate),
        projectId,
        tenderRef: str(body.tenderRef),
        contractorId: str(body.contractorId),
        categoryCode: str(body.categoryCode),
        status: (str(body.status) as never) ?? 'ISSUED',
        approvalStatus: (str(body.approvalStatus) as never) ?? 'PENDING',
        approverEmployeeId: num(body.approverEmployeeId),
        ownerEmployeeId: num(body.ownerEmployeeId),
        totalAmount,
        createdBy: userId ?? null,
        updatedBy: userId ?? null,
      },
    });

    await replaceGroups(created.id, groups);
    return this.getById(created.id);
  },

  async update(id: string, body: Record<string, unknown>, userId?: string) {
    await this.getById(id);
    const groups = body.activities != null ? parseGroups(body.activities) : null;
    const totalAmount = groups ? calcTotal(groups) : undefined;

    await prisma.erpWorkOrder.update({
      where: { id },
      data: {
        ...(body.workOrderId != null ? { workOrderId: str(body.workOrderId) ?? undefined } : {}),
        ...(body.orderDate != null ? { orderDate: dateOnly(body.orderDate) ?? undefined } : {}),
        ...(body.dueDate !== undefined ? { dueDate: dateOnly(body.dueDate) } : {}),
        ...(body.projectId != null ? { projectId: str(body.projectId) ?? undefined } : {}),
        ...(body.tenderRef !== undefined ? { tenderRef: str(body.tenderRef) } : {}),
        ...(body.contractorId !== undefined ? { contractorId: str(body.contractorId) } : {}),
        ...(body.categoryCode !== undefined ? { categoryCode: str(body.categoryCode) } : {}),
        ...(body.approverEmployeeId !== undefined ? { approverEmployeeId: num(body.approverEmployeeId) } : {}),
        ...(body.ownerEmployeeId !== undefined ? { ownerEmployeeId: num(body.ownerEmployeeId) } : {}),
        ...(totalAmount != null ? { totalAmount } : {}),
        updatedBy: userId ?? null,
      },
    });

    if (groups) await replaceGroups(id, groups);
    return this.getById(id);
  },

  async updateStatus(id: string, status: string, userId?: string) {
    const allowed = ['ISSUED', 'IN_PROGRESS', 'COMPLETED', 'COMPLETED_DELAYED', 'CANCELLED'];
    if (!allowed.includes(status)) throw new Error('Invalid status');
    await prisma.erpWorkOrder.update({
      where: { id },
      data: { status: status as never, updatedBy: userId ?? null },
    });
    return this.getById(id);
  },

  async updateApproval(id: string, approvalStatus: string, userId?: string) {
    const allowed = ['PENDING', 'APPROVED', 'REJECTED', 'NOT_APPLICABLE'];
    if (!allowed.includes(approvalStatus)) throw new Error('Invalid approval status');
    await prisma.erpWorkOrder.update({
      where: { id },
      data: { approvalStatus: approvalStatus as never, updatedBy: userId ?? null },
    });
    return this.getById(id);
  },

  async remove(id: string) {
    await this.getById(id);
    await prisma.erpWorkOrder.delete({ where: { id } });
    return { ok: true };
  },
};
