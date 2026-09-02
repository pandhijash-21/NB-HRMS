import { Prisma } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { resourceService } from '../erp-resources/resource.service';

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

function jsonStr(v: unknown): string | null {
  if (v == null) return null;
  if (typeof v === 'string') return v;
  return JSON.stringify(v);
}

type ResourceInput = {
  resourceType: string;
  configMaterialId?: string | null;
  configMachineId?: string | null;
  configLabourId?: string | null;
  name: string;
  brand?: string | null;
  unitCode?: string | null;
  size?: string | null;
  quantity: number;
  unitPrice: number;
  totalPrice: number;
  remarks?: string | null;
  sortOrder?: number;
};

type TaskInput = {
  taskId?: string | null;
  activityId?: string | null;
  activityName: string;
  subtaskId?: string | null;
  taskName: string;
  taskDescription?: string | null;
  isCustomSubtask?: boolean;
  towerIds?: unknown;
  floorNos?: unknown;
  unitIds?: unknown;
  quantity?: number | null;
  unitCode?: string | null;
  rate?: number | null;
  amount?: number | null;
  materialAmount?: number;
  machineAmount?: number;
  labourAmount?: number;
  sortOrder?: number;
  resources?: ResourceInput[];
};

const includeDetail = {
  project: {
    select: { id: true, name: true, projectNo: true, imageUrl: true },
  },
  tasks: {
    orderBy: [{ sortOrder: 'asc' as const }],
    include: {
      resources: { orderBy: [{ sortOrder: 'asc' as const }] },
    },
  },
};

function sumResources(resources: ResourceInput[], type: string): number {
  return resources
    .filter((r) => r.resourceType === type)
    .reduce((s, r) => s + (Number(r.totalPrice) || 0), 0);
}

function parseTasks(raw: unknown): TaskInput[] {
  if (!Array.isArray(raw)) return [];
  const tasks: TaskInput[] = [];
  for (let i = 0; i < raw.length; i++) {
    const t = (raw[i] ?? {}) as Record<string, unknown>;
    const activityName = str(t.activityName);
    const taskName = str(t.taskName);
    if (!activityName || !taskName) continue;
    const qty = num(t.quantity);
    const rate = num(t.rate);
    const amount = num(t.amount) ?? (qty != null && rate != null ? qty * rate : null);
    const resources: ResourceInput[] = [];
    if (Array.isArray(t.resources)) {
      for (let ri = 0; ri < t.resources.length; ri++) {
        const r = (t.resources[ri] ?? {}) as Record<string, unknown>;
        const name = str(r.name);
        const resourceType = str(r.resourceType);
        if (!name || !resourceType) continue;
        const rq = num(r.quantity) ?? 0;
        const up = num(r.unitPrice) ?? 0;
        resources.push({
          resourceType,
          configMaterialId: str(r.configMaterialId),
          configMachineId: str(r.configMachineId),
          configLabourId: str(r.configLabourId),
          name,
          brand: str(r.brand),
          unitCode: str(r.unitCode),
          size: str(r.size),
          quantity: rq,
          unitPrice: up,
          totalPrice: num(r.totalPrice) ?? rq * up,
          remarks: str(r.remarks),
          sortOrder: num(r.sortOrder) ?? ri,
        });
      }
    }
    tasks.push({
      taskId: str(t.taskId),
      activityId: str(t.activityId),
      activityName,
      subtaskId: str(t.subtaskId),
      taskName,
      taskDescription: str(t.taskDescription),
      isCustomSubtask: t.isCustomSubtask === true,
      towerIds: t.towerIds,
      floorNos: t.floorNos,
      unitIds: t.unitIds,
      quantity: qty,
      unitCode: str(t.unitCode),
      rate,
      amount,
      materialAmount: sumResources(resources, 'MATERIAL'),
      machineAmount: sumResources(resources, 'MACHINE'),
      labourAmount: sumResources(resources, 'LABOUR'),
      sortOrder: num(t.sortOrder) ?? i,
      resources,
    });
  }
  return tasks;
}

async function nextTaskId(boqId: string, startIndex: number): Promise<string> {
  const count = await prisma.erpBoqTask.count({ where: { boqId } });
  const n = count + startIndex + 1;
  return `TI${String(n).padStart(4, '0')}`;
}

async function replaceTasks(boqId: string, projectId: string, tasks: TaskInput[]) {
  await prisma.erpBoqTaskResource.deleteMany({ where: { task: { boqId } } });
  await prisma.erpBoqTask.deleteMany({ where: { boqId } });

  for (let i = 0; i < tasks.length; i++) {
    const t = tasks[i];
    const taskId = t.taskId ?? (await nextTaskId(boqId, i));
    const resources = t.resources ?? [];
    const materialAmount = t.materialAmount ?? sumResources(resources, 'MATERIAL');
    const machineAmount = t.machineAmount ?? sumResources(resources, 'MACHINE');
    const labourAmount = t.labourAmount ?? sumResources(resources, 'LABOUR');

    await prisma.erpBoqTask.create({
      data: {
        boqId,
        taskId,
        activityId: t.activityId,
        activityName: t.activityName,
        subtaskId: t.subtaskId,
        taskName: t.taskName,
        taskDescription: t.taskDescription,
        isCustomSubtask: t.isCustomSubtask === true,
        towerIds: jsonStr(t.towerIds),
        floorNos: jsonStr(t.floorNos),
        unitIds: jsonStr(t.unitIds),
        quantity: dec(t.quantity),
        unitCode: t.unitCode,
        rate: dec(t.rate),
        amount: dec(t.amount),
        materialAmount: new Prisma.Decimal(materialAmount),
        machineAmount: new Prisma.Decimal(machineAmount),
        labourAmount: new Prisma.Decimal(labourAmount),
        sortOrder: t.sortOrder ?? i,
        resources: {
          create: resources.map((r, ri) => ({
            resourceType: r.resourceType as 'MATERIAL' | 'MACHINE' | 'LABOUR',
            configMaterialId: r.configMaterialId,
            configMachineId: r.configMachineId,
            configLabourId: r.configLabourId,
            name: r.name,
            brand: r.brand,
            unitCode: r.unitCode,
            size: r.size,
            quantity: new Prisma.Decimal(r.quantity),
            unitPrice: new Prisma.Decimal(r.unitPrice),
            totalPrice: new Prisma.Decimal(r.totalPrice),
            remarks: r.remarks,
            sortOrder: r.sortOrder ?? ri,
          })),
        },
      },
    });
  }

  await resourceService.recalculateProjectResourceUsage(projectId);
}

export const boqService = {
  async list(opts?: { projectId?: string }) {
    return prisma.erpBoq.findMany({
      where: {
        isActive: true,
        ...(opts?.projectId ? { projectId: opts.projectId } : {}),
      },
      orderBy: [{ createdAt: 'desc' }],
      include: {
        project: { select: { id: true, name: true, projectNo: true } },
        tasks: {
          orderBy: [{ sortOrder: 'asc' }],
          select: {
            id: true,
            taskId: true,
            activityId: true,
            activityName: true,
            subtaskId: true,
            taskName: true,
            taskDescription: true,
            isCustomSubtask: true,
            quantity: true,
            unitCode: true,
            rate: true,
            amount: true,
            materialAmount: true,
            machineAmount: true,
            labourAmount: true,
            sortOrder: true,
            towerIds: true,
            floorNos: true,
            unitIds: true,
          },
        },
      },
    });
  },

  async getById(id: string) {
    const row = await prisma.erpBoq.findUnique({
      where: { id },
      include: includeDetail,
    });
    if (!row) throw new Error('BOQ not found');
    return row;
  },

  async create(body: Record<string, unknown>, userId?: string) {
    const boqNo = str(body.boqNo);
    if (!boqNo) throw new Error('BOQ No is required');
    const title = str(body.title);
    if (!title) throw new Error('Title is required');
    const projectId = str(body.projectId);
    if (!projectId) throw new Error('Project is required');

    const existing = await prisma.erpBoq.findUnique({ where: { boqNo } });
    if (existing) throw new Error('BOQ No already exists');

    const rateSource = str(body.rateSource) === 'CURRENT_RATE' ? 'CURRENT_RATE' : 'ESTIMATED_RATE';
    const tasks = parseTasks(body.tasks);

    const created = await prisma.erpBoq.create({
      data: {
        boqNo,
        title,
        rateSource,
        projectId,
        createdBy: userId ?? null,
        updatedBy: userId ?? null,
      },
    });

    await replaceTasks(created.id, projectId, tasks);
    return this.getById(created.id);
  },

  async update(id: string, body: Record<string, unknown>, userId?: string) {
    const existing = await this.getById(id);
    const tasks = body.tasks != null ? parseTasks(body.tasks) : null;

    if (body.boqNo != null) {
      const boqNo = str(body.boqNo);
      if (!boqNo) throw new Error('BOQ No is required');
      const dup = await prisma.erpBoq.findFirst({ where: { boqNo, NOT: { id } } });
      if (dup) throw new Error('BOQ No already exists');
    }

    await prisma.erpBoq.update({
      where: { id },
      data: {
        ...(body.boqNo != null ? { boqNo: str(body.boqNo) ?? undefined } : {}),
        ...(body.title != null ? { title: str(body.title) ?? undefined } : {}),
        ...(body.rateSource != null
          ? { rateSource: str(body.rateSource) === 'CURRENT_RATE' ? 'CURRENT_RATE' : 'ESTIMATED_RATE' }
          : {}),
        ...(body.projectId != null ? { projectId: str(body.projectId) ?? undefined } : {}),
        ...(body.isActive != null ? { isActive: Boolean(body.isActive) } : {}),
        updatedBy: userId ?? null,
      },
    });

    if (tasks) {
      const projectId = str(body.projectId) ?? existing.projectId;
      await replaceTasks(id, projectId, tasks);
    }

    return this.getById(id);
  },

  async remove(id: string) {
    const existing = await this.getById(id);
    const projectId = existing.projectId;
    await prisma.erpBoq.delete({ where: { id } });
    await resourceService.recalculateProjectResourceUsage(projectId);
    return { ok: true };
  },
};
