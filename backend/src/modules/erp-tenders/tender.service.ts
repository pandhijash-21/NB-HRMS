import { Prisma } from '@prisma/client';
import { prisma } from '../../config/prisma';

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
  if (v == null || v === '') return null;
  const d = new Date(String(v));
  if (Number.isNaN(d.getTime())) return null;
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

function todayUtc(): Date {
  const n = new Date();
  return new Date(Date.UTC(n.getUTCFullYear(), n.getUTCMonth(), n.getUTCDate()));
}

function jsonStr(v: unknown): string | null {
  if (v == null) return null;
  if (typeof v === 'string') return v;
  return JSON.stringify(v);
}

type LineInput = {
  activityId?: string | null;
  activityName: string;
  boqTaskId?: string | null;
  taskId?: string | null;
  taskName: string;
  taskDescription?: string | null;
  towerIds?: unknown;
  floorNos?: unknown;
  unitIds?: unknown;
  quantity?: number | null;
  unitCode?: string | null;
  rate?: number | null;
  amount?: number | null;
  sortOrder?: number;
};

function parseLines(raw: unknown): LineInput[] {
  if (!Array.isArray(raw)) return [];
  const lines: LineInput[] = [];
  for (let i = 0; i < raw.length; i++) {
    const t = (raw[i] ?? {}) as Record<string, unknown>;
    const activityName = str(t.activityName);
    const taskName = str(t.taskName);
    if (!activityName || !taskName) continue;
    const qty = num(t.quantity);
    const rate = num(t.rate);
    const amount = num(t.amount) ?? (qty != null && rate != null ? qty * rate : null);
    lines.push({
      activityId: str(t.activityId),
      activityName,
      boqTaskId: str(t.boqTaskId),
      taskId: str(t.taskId),
      taskName,
      taskDescription: str(t.taskDescription),
      towerIds: t.towerIds,
      floorNos: t.floorNos,
      unitIds: t.unitIds,
      quantity: qty,
      unitCode: str(t.unitCode),
      rate,
      amount,
      sortOrder: num(t.sortOrder) ?? i,
    });
  }
  return lines;
}

const includeDetail = {
  project: { select: { id: true, name: true, projectNo: true } },
  boq: { select: { id: true, boqNo: true, title: true } },
  lines: { orderBy: [{ sortOrder: 'asc' as const }] },
  applications: { orderBy: [{ createdAt: 'desc' as const }], take: 20 },
};

const applicationInclude = {
  tender: {
    select: {
      id: true,
      tenderNo: true,
      projectId: true,
      project: { select: { id: true, name: true } },
    },
  },
  contractor: { select: { id: true, name: true, phone: true, email: true } },
};

async function replaceLines(tenderId: string, lines: LineInput[]) {
  await prisma.erpTenderLine.deleteMany({ where: { tenderId } });
  if (!lines.length) return;
  await prisma.erpTenderLine.createMany({
    data: lines.map((l, i) => ({
      tenderId,
      activityId: l.activityId,
      activityName: l.activityName,
      boqTaskId: l.boqTaskId,
      taskId: l.taskId,
      taskName: l.taskName,
      taskDescription: l.taskDescription,
      towerIds: jsonStr(l.towerIds),
      floorNos: jsonStr(l.floorNos),
      unitIds: jsonStr(l.unitIds),
      quantity: dec(l.quantity),
      unitCode: l.unitCode,
      rate: dec(l.rate),
      amount: dec(l.amount),
      sortOrder: l.sortOrder ?? i,
    })),
  });
}

export const tenderService = {
  async list(opts?: { projectId?: string }) {
    return prisma.erpTender.findMany({
      where: {
        isActive: true,
        ...(opts?.projectId ? { projectId: opts.projectId } : {}),
      },
      orderBy: [{ createdAt: 'desc' }],
      include: {
        project: { select: { id: true, name: true, projectNo: true } },
        boq: { select: { id: true, boqNo: true, title: true } },
        _count: { select: { lines: true, applications: true } },
      },
    });
  },

  async getById(id: string) {
    const row = await prisma.erpTender.findUnique({
      where: { id },
      include: includeDetail,
    });
    if (!row) throw new Error('Tender not found');
    return row;
  },

  /** Distinct activities present on a BOQ (for tender activity dropdown). */
  async activitiesFromBoq(boqId: string) {
    const tasks = await prisma.erpBoqTask.findMany({
      where: { boqId },
      orderBy: [{ sortOrder: 'asc' }],
      select: { activityId: true, activityName: true },
    });
    const seen = new Set<string>();
    const out: Array<{ id: string | null; name: string }> = [];
    for (const t of tasks) {
      const key = t.activityId ?? `name:${t.activityName}`;
      if (seen.has(key)) continue;
      seen.add(key);
      out.push({ id: t.activityId, name: t.activityName });
    }
    return out;
  },

  /** BOQ task rows for a given activity — used when user clicks Add. */
  async linesFromBoq(boqId: string, activityId?: string) {
    const tasks = await prisma.erpBoqTask.findMany({
      where: {
        boqId,
        ...(activityId ? { activityId } : {}),
      },
      orderBy: [{ sortOrder: 'asc' }],
    });
    return tasks.map((t, i) => {
      const qty = t.quantity != null ? Number(t.quantity) : null;
      const rate = t.rate != null ? Number(t.rate) : null;
      const amount = t.amount != null ? Number(t.amount) : qty != null && rate != null ? qty * rate : null;
      return {
        activityId: t.activityId,
        activityName: t.activityName,
        boqTaskId: t.id,
        taskId: t.taskId,
        taskName: t.taskName,
        taskDescription: t.taskDescription,
        towerIds: t.towerIds,
        floorNos: t.floorNos,
        unitIds: t.unitIds,
        quantity: qty,
        unitCode: t.unitCode,
        rate,
        amount,
        sortOrder: i,
      };
    });
  },

  /** Activity subtasks when no BOQ is linked. */
  async linesFromActivity(activityId: string) {
    const activity = await prisma.erpActivity.findUnique({
      where: { id: activityId },
      include: { subtasks: { orderBy: [{ sortOrder: 'asc' }] } },
    });
    if (!activity) throw new Error('Activity not found');
    if (!activity.subtasks.length) {
      return [
        {
          activityId: activity.id,
          activityName: activity.name,
          boqTaskId: null,
          taskId: null,
          taskName: activity.name,
          taskDescription: null,
          towerIds: null,
          floorNos: null,
          unitIds: null,
          quantity: null,
          unitCode: null,
          rate: null,
          amount: null,
          sortOrder: 0,
        },
      ];
    }
    return activity.subtasks.map((s, i) => ({
      activityId: activity.id,
      activityName: activity.name,
      boqTaskId: null,
      taskId: null,
      taskName: s.name,
      taskDescription: s.description,
      towerIds: null,
      floorNos: null,
      unitIds: null,
      quantity: null,
      unitCode: null,
      rate: null,
      amount: null,
      sortOrder: i,
    }));
  },

  async create(body: Record<string, unknown>, userId?: string) {
    const tenderNo = str(body.tenderNo);
    if (!tenderNo) throw new Error('Tender Id is required');
    const projectId = str(body.projectId);
    if (!projectId) throw new Error('Project is required');
    const startDate = dateOnly(body.startDate);
    const endDate = dateOnly(body.endDate);
    if (!startDate) throw new Error('Tender Start Date is required');
    if (!endDate) throw new Error('Tender Last Date is required');
    if (endDate < startDate) throw new Error('Last Date must be on or after Start Date');

    const existing = await prisma.erpTender.findUnique({ where: { tenderNo } });
    if (existing) throw new Error('Tender Id already exists');

    const boqId = str(body.boqId);
    if (boqId) {
      const boq = await prisma.erpBoq.findUnique({ where: { id: boqId } });
      if (!boq) throw new Error('BOQ not found');
      if (boq.projectId !== projectId) throw new Error('BOQ does not belong to the selected project');
    }

    const lines = parseLines(body.lines);
    const created = await prisma.erpTender.create({
      data: {
        tenderNo,
        tenderDate: dateOnly(body.tenderDate) ?? todayUtc(),
        createdByName: str(body.createdByName),
        projectId,
        boqId,
        startDate,
        endDate,
        status: (str(body.status) as 'DRAFT' | 'OPEN' | 'CLOSED' | 'CANCELLED' | null) ?? 'OPEN',
        remarks: str(body.remarks),
        createdBy: userId ?? null,
        updatedBy: userId ?? null,
      },
    });
    await replaceLines(created.id, lines);
    return this.getById(created.id);
  },

  async update(id: string, body: Record<string, unknown>, userId?: string) {
    const existing = await this.getById(id);
    if (body.tenderNo != null) {
      const tenderNo = str(body.tenderNo);
      if (!tenderNo) throw new Error('Tender Id is required');
      const dup = await prisma.erpTender.findFirst({ where: { tenderNo, NOT: { id } } });
      if (dup) throw new Error('Tender Id already exists');
    }

    const projectId = body.projectId != null ? str(body.projectId) : existing.projectId;
    const boqId = body.boqId !== undefined ? str(body.boqId) : existing.boqId;
    if (boqId && projectId) {
      const boq = await prisma.erpBoq.findUnique({ where: { id: boqId } });
      if (!boq) throw new Error('BOQ not found');
      if (boq.projectId !== projectId) throw new Error('BOQ does not belong to the selected project');
    }

    const startDate = body.startDate != null ? dateOnly(body.startDate) : existing.startDate;
    const endDate = body.endDate != null ? dateOnly(body.endDate) : existing.endDate;
    if (!startDate || !endDate) throw new Error('Start and Last dates are required');
    if (endDate < startDate) throw new Error('Last Date must be on or after Start Date');

    await prisma.erpTender.update({
      where: { id },
      data: {
        ...(body.tenderNo != null ? { tenderNo: str(body.tenderNo) ?? undefined } : {}),
        ...(body.tenderDate != null ? { tenderDate: dateOnly(body.tenderDate) ?? undefined } : {}),
        ...(body.createdByName !== undefined ? { createdByName: str(body.createdByName) } : {}),
        ...(body.projectId != null ? { projectId: projectId ?? undefined } : {}),
        ...(body.boqId !== undefined ? { boqId } : {}),
        ...(body.startDate != null ? { startDate } : {}),
        ...(body.endDate != null ? { endDate } : {}),
        ...(body.status != null
          ? { status: (str(body.status) as 'DRAFT' | 'OPEN' | 'CLOSED' | 'CANCELLED') ?? undefined }
          : {}),
        ...(body.remarks !== undefined ? { remarks: str(body.remarks) } : {}),
        ...(body.isActive != null ? { isActive: Boolean(body.isActive) } : {}),
        updatedBy: userId ?? null,
      },
    });

    if (body.lines != null) {
      await replaceLines(id, parseLines(body.lines));
    }
    return this.getById(id);
  },

  async remove(id: string) {
    await this.getById(id);
    await prisma.erpTender.delete({ where: { id } });
    return { ok: true };
  },

  // ── Applications ──────────────────────────────────────────────────────────
  async listApplications(opts?: { tenderId?: string }) {
    return prisma.erpTenderApplication.findMany({
      where: opts?.tenderId ? { tenderId: opts.tenderId } : undefined,
      orderBy: [{ createdAt: 'desc' }],
      include: applicationInclude,
    });
  },

  async getApplication(id: string) {
    const row = await prisma.erpTenderApplication.findUnique({
      where: { id },
      include: applicationInclude,
    });
    if (!row) throw new Error('Tender application not found');
    return row;
  },

  async createApplication(body: Record<string, unknown>, userId?: string) {
    const applicationNo = str(body.applicationNo);
    if (!applicationNo) throw new Error('Tender application number is required');
    const tenderId = str(body.tenderId);
    if (!tenderId) throw new Error('Tender is required');
    const contractorId = str(body.contractorId);
    if (!contractorId) throw new Error('Contractor is required');
    const activityName = str(body.activityName);
    if (!activityName) throw new Error('Activity is required');

    const tender = await this.getById(tenderId);
    const contractor = await prisma.erpContractor.findUnique({ where: { id: contractorId } });
    if (!contractor) throw new Error('Contractor not found');

    const existing = await prisma.erpTenderApplication.findUnique({
      where: { applicationNo },
    });
    if (existing) throw new Error(`Application number ${applicationNo} already exists`);

    const vendorName = str(body.vendorName) ?? contractor.name;
    const projectId = str(body.projectId) ?? tender.projectId;

    return prisma.erpTenderApplication.create({
      data: {
        applicationNo,
        tenderId,
        projectId,
        activityId: str(body.activityId),
        activityName,
        contractorId,
        vendorName,
        vendorContact: str(body.vendorContact) ?? contractor.phone ?? contractor.email,
        applicationDate: dateOnly(body.applicationDate) ?? todayUtc(),
        quotedAmount: dec(body.quotedAmount),
        status:
          (str(body.status) as 'SUBMITTED' | 'UNDER_REVIEW' | 'ACCEPTED' | 'REJECTED' | null) ??
          'SUBMITTED',
        remarks: str(body.remarks),
        createdByName: str(body.createdByName),
        createdBy: userId ?? null,
        updatedBy: userId ?? null,
      },
      include: applicationInclude,
    });
  },

  async updateApplication(id: string, body: Record<string, unknown>, userId?: string) {
    await this.getApplication(id);

    let vendorName: string | undefined;
    let vendorContact: string | null | undefined;
    const contractorId = body.contractorId !== undefined ? str(body.contractorId) : undefined;
    if (contractorId) {
      const contractor = await prisma.erpContractor.findUnique({ where: { id: contractorId } });
      if (!contractor) throw new Error('Contractor not found');
      vendorName = str(body.vendorName) ?? contractor.name;
      if (body.vendorContact !== undefined) {
        vendorContact = str(body.vendorContact);
      } else {
        vendorContact = contractor.phone ?? contractor.email ?? null;
      }
    }

    return prisma.erpTenderApplication.update({
      where: { id },
      data: {
        ...(body.applicationNo != null
          ? { applicationNo: str(body.applicationNo) ?? undefined }
          : {}),
        ...(body.tenderId != null ? { tenderId: str(body.tenderId) ?? undefined } : {}),
        ...(body.projectId !== undefined ? { projectId: str(body.projectId) } : {}),
        ...(body.activityId !== undefined ? { activityId: str(body.activityId) } : {}),
        ...(body.activityName != null ? { activityName: str(body.activityName) ?? undefined } : {}),
        ...(contractorId !== undefined ? { contractorId } : {}),
        ...(vendorName != null || body.vendorName != null
          ? { vendorName: vendorName ?? str(body.vendorName) ?? undefined }
          : {}),
        ...(vendorContact !== undefined
          ? { vendorContact }
          : body.vendorContact !== undefined
            ? { vendorContact: str(body.vendorContact) }
            : {}),
        ...(body.applicationDate != null
          ? { applicationDate: dateOnly(body.applicationDate) ?? undefined }
          : {}),
        ...(body.quotedAmount !== undefined ? { quotedAmount: dec(body.quotedAmount) } : {}),
        ...(body.status != null
          ? {
              status:
                (str(body.status) as 'SUBMITTED' | 'UNDER_REVIEW' | 'ACCEPTED' | 'REJECTED') ??
                undefined,
            }
          : {}),
        ...(body.remarks !== undefined ? { remarks: str(body.remarks) } : {}),
        ...(body.createdByName !== undefined ? { createdByName: str(body.createdByName) } : {}),
        updatedBy: userId ?? null,
      },
      include: applicationInclude,
    });
  },

  async removeApplication(id: string) {
    await this.getApplication(id);
    await prisma.erpTenderApplication.delete({ where: { id } });
    return { ok: true };
  },
};
