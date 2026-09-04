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

function dec(v: unknown): Prisma.Decimal {
  const n = num(v);
  return new Prisma.Decimal(n ?? 0);
}

function decOpt(v: unknown): Prisma.Decimal | null {
  if (v == null || v === '') return null;
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

const lineInclude = {
  materials: { orderBy: [{ sortOrder: 'asc' as const }] },
  labour: { orderBy: [{ sortOrder: 'asc' as const }] },
  machines: { orderBy: [{ sortOrder: 'asc' as const }] },
  contractor: { select: { id: true, name: true } },
};

const detailInclude = {
  project: { select: { id: true, name: true, projectNo: true } },
  lines: {
    orderBy: [{ sortOrder: 'asc' as const }],
    include: lineInclude,
  },
};

type MaterialInput = {
  materialId?: string | null;
  itemCode?: string | null;
  category?: string | null;
  itemName: string;
  brand?: string | null;
  unitCode?: string | null;
  size?: string | null;
  consumedQty?: number | null;
  remarks?: string | null;
  sortOrder?: number;
};

type LabourInput = {
  labourId?: string | null;
  name: string;
  unitCode?: string | null;
  consumedQty?: number | null;
  remarks?: string | null;
  sortOrder?: number;
};

type MachineInput = {
  machineId?: string | null;
  itemName: string;
  brand?: string | null;
  unitCode?: string | null;
  size?: string | null;
  consumedQty?: number | null;
  remarks?: string | null;
  sortOrder?: number;
};

type LineInput = {
  contractorId?: string | null;
  contractorName?: string | null;
  activityId?: string | null;
  activityName?: string | null;
  subtaskId?: string | null;
  taskName?: string | null;
  towerId?: string | null;
  towerName?: string | null;
  floorNo?: number | null;
  unitId?: string | null;
  unitLabel?: string | null;
  unitCode?: string | null;
  consumedQty?: number | null;
  gradeCode?: string | null;
  remarks?: string | null;
  statusCode?: string | null;
  completionPct?: number | null;
  actualStartDate?: string | null;
  actualEndDate?: string | null;
  materialRateText?: string | null;
  labourRateText?: string | null;
  machineRateText?: string | null;
  sortOrder?: number;
  materials?: MaterialInput[];
  labour?: LabourInput[];
  machines?: MachineInput[];
};

function parseMaterials(raw: unknown): MaterialInput[] {
  if (!Array.isArray(raw)) return [];
  const out: MaterialInput[] = [];
  for (let i = 0; i < raw.length; i++) {
    const t = (raw[i] ?? {}) as Record<string, unknown>;
    const itemName = str(t.itemName) ?? str(t.name);
    if (!itemName) continue;
    out.push({
      materialId: str(t.materialId),
      itemCode: str(t.itemCode),
      category: str(t.category),
      itemName,
      brand: str(t.brand),
      unitCode: str(t.unitCode),
      size: str(t.size),
      consumedQty: num(t.consumedQty),
      remarks: str(t.remarks),
      sortOrder: num(t.sortOrder) ?? i,
    });
  }
  return out;
}

function parseLabour(raw: unknown): LabourInput[] {
  if (!Array.isArray(raw)) return [];
  const out: LabourInput[] = [];
  for (let i = 0; i < raw.length; i++) {
    const t = (raw[i] ?? {}) as Record<string, unknown>;
    const name = str(t.name) ?? str(t.itemName);
    if (!name) continue;
    out.push({
      labourId: str(t.labourId),
      name,
      unitCode: str(t.unitCode),
      consumedQty: num(t.consumedQty),
      remarks: str(t.remarks),
      sortOrder: num(t.sortOrder) ?? i,
    });
  }
  return out;
}

function parseMachines(raw: unknown): MachineInput[] {
  if (!Array.isArray(raw)) return [];
  const out: MachineInput[] = [];
  for (let i = 0; i < raw.length; i++) {
    const t = (raw[i] ?? {}) as Record<string, unknown>;
    const itemName = str(t.itemName) ?? str(t.name);
    if (!itemName) continue;
    out.push({
      machineId: str(t.machineId),
      itemName,
      brand: str(t.brand),
      unitCode: str(t.unitCode),
      size: str(t.size),
      consumedQty: num(t.consumedQty),
      remarks: str(t.remarks),
      sortOrder: num(t.sortOrder) ?? i,
    });
  }
  return out;
}

function parseLines(raw: unknown): LineInput[] {
  if (!Array.isArray(raw)) return [];
  const out: LineInput[] = [];
  for (let i = 0; i < raw.length; i++) {
    const t = (raw[i] ?? {}) as Record<string, unknown>;
    out.push({
      contractorId: str(t.contractorId),
      contractorName: str(t.contractorName),
      activityId: str(t.activityId),
      activityName: str(t.activityName),
      subtaskId: str(t.subtaskId),
      taskName: str(t.taskName),
      towerId: str(t.towerId),
      towerName: str(t.towerName),
      floorNo: num(t.floorNo),
      unitId: str(t.unitId),
      unitLabel: str(t.unitLabel),
      unitCode: str(t.unitCode),
      consumedQty: num(t.consumedQty),
      gradeCode: str(t.gradeCode),
      remarks: str(t.remarks),
      statusCode: str(t.statusCode),
      completionPct: num(t.completionPct),
      actualStartDate: str(t.actualStartDate),
      actualEndDate: str(t.actualEndDate),
      materialRateText: str(t.materialRateText) ?? 'No',
      labourRateText: str(t.labourRateText) ?? 'No',
      machineRateText: str(t.machineRateText) ?? 'No',
      sortOrder: num(t.sortOrder) ?? i,
      materials: parseMaterials(t.materials),
      labour: parseLabour(t.labour),
      machines: parseMachines(t.machines),
    });
  }
  return out;
}

async function nextDprNo(): Promise<string> {
  const count = await prisma.erpDpr.count();
  return `DPR${String(count + 1).padStart(5, '0')}`;
}

async function applyResourceConsumption(
  tx: Prisma.TransactionClient,
  lines: LineInput[],
  projectId: string,
  userId?: string,
) {
  for (const line of lines) {
    for (const m of line.materials ?? []) {
      const qty = Number(m.consumedQty ?? 0);
      if (!m.materialId || qty <= 0) continue;
      const mat = await tx.erpMaterial.findUnique({ where: { id: m.materialId } });
      if (!mat) throw new Error(`Material not found: ${m.itemName}`);
      if (Number(mat.qtyOnHand) < qty) {
        throw new Error(`Insufficient stock for material "${mat.name}". Available: ${mat.qtyOnHand}`);
      }
      await tx.erpMaterial.update({
        where: { id: m.materialId },
        data: { qtyOnHand: { decrement: qty } },
      });
      await tx.erpMaterialStockLog.create({
        data: {
          materialId: m.materialId,
          logType: 'CONSUMPTION',
          quantity: new Prisma.Decimal(qty),
          remarks: `DPR consumption${m.remarks ? `: ${m.remarks}` : ''}`,
          createdBy: userId ?? null,
        },
      });
      await tx.erpMaterialProjectUse.upsert({
        where: { materialId_projectId: { materialId: m.materialId, projectId } },
        create: { materialId: m.materialId, projectId, qtyUsed: new Prisma.Decimal(qty) },
        update: { qtyUsed: { increment: qty } },
      });
    }
    for (const m of line.machines ?? []) {
      const qty = Number(m.consumedQty ?? 0);
      if (!m.machineId || qty <= 0) continue;
      const mac = await tx.erpMachine.findUnique({ where: { id: m.machineId } });
      if (!mac) throw new Error(`Machine not found: ${m.itemName}`);
      if (Number(mac.qtyOnHand) < qty) {
        throw new Error(`Insufficient stock for machine "${mac.name}". Available: ${mac.qtyOnHand}`);
      }
      await tx.erpMachine.update({
        where: { id: m.machineId },
        data: { qtyOnHand: { decrement: qty } },
      });
      await tx.erpMachineStockLog.create({
        data: {
          machineId: m.machineId,
          logType: 'CONSUMPTION',
          quantity: new Prisma.Decimal(qty),
          remarks: `DPR consumption${m.remarks ? `: ${m.remarks}` : ''}`,
          createdBy: userId ?? null,
        },
      });
      await tx.erpMachineProjectUse.upsert({
        where: { machineId_projectId: { machineId: m.machineId, projectId } },
        create: { machineId: m.machineId, projectId, qtyUsed: new Prisma.Decimal(qty) },
        update: { qtyUsed: { increment: qty } },
      });
    }
  }
}

async function createLines(tx: Prisma.TransactionClient, dprId: string, lines: LineInput[]) {
  for (let i = 0; i < lines.length; i++) {
    const l = lines[i];
    const row = await tx.erpDprLine.create({
      data: {
        dprId,
        contractorId: l.contractorId,
        contractorName: l.contractorName,
        activityId: l.activityId,
        activityName: l.activityName,
        subtaskId: l.subtaskId,
        taskName: l.taskName,
        towerId: l.towerId,
        towerName: l.towerName,
        floorNo: l.floorNo,
        unitId: l.unitId,
        unitLabel: l.unitLabel,
        unitCode: l.unitCode,
        consumedQty: dec(l.consumedQty),
        gradeCode: l.gradeCode,
        remarks: l.remarks,
        statusCode: l.statusCode,
        completionPct: decOpt(l.completionPct),
        actualStartDate: dateOnly(l.actualStartDate),
        actualEndDate: dateOnly(l.actualEndDate),
        materialRateText: l.materialRateText ?? 'No',
        labourRateText: l.labourRateText ?? 'No',
        machineRateText: l.machineRateText ?? 'No',
        sortOrder: l.sortOrder ?? i,
      },
    });
    if (l.materials?.length) {
      await tx.erpDprMaterialLine.createMany({
        data: l.materials.map((m, mi) => ({
          dprLineId: row.id,
          materialId: m.materialId,
          itemCode: m.itemCode,
          category: m.category,
          itemName: m.itemName,
          brand: m.brand,
          unitCode: m.unitCode,
          size: m.size,
          consumedQty: dec(m.consumedQty),
          remarks: m.remarks,
          sortOrder: m.sortOrder ?? mi,
        })),
      });
    }
    if (l.labour?.length) {
      await tx.erpDprLabourLine.createMany({
        data: l.labour.map((lb, li) => ({
          dprLineId: row.id,
          labourId: lb.labourId,
          name: lb.name,
          unitCode: lb.unitCode,
          consumedQty: dec(lb.consumedQty),
          remarks: lb.remarks,
          sortOrder: lb.sortOrder ?? li,
        })),
      });
    }
    if (l.machines?.length) {
      await tx.erpDprMachineLine.createMany({
        data: l.machines.map((m, mi) => ({
          dprLineId: row.id,
          machineId: m.machineId,
          itemName: m.itemName,
          brand: m.brand,
          unitCode: m.unitCode,
          size: m.size,
          consumedQty: dec(m.consumedQty),
          remarks: m.remarks,
          sortOrder: m.sortOrder ?? mi,
        })),
      });
    }
  }
}

export const dprService = {
  async list(opts?: { projectId?: string }) {
    return prisma.erpDpr.findMany({
      where: opts?.projectId ? { projectId: opts.projectId } : undefined,
      orderBy: [{ reportDate: 'desc' }, { createdAt: 'desc' }],
      include: {
        project: { select: { id: true, name: true, projectNo: true } },
        _count: { select: { lines: true } },
      },
    });
  },

  async getById(id: string) {
    const row = await prisma.erpDpr.findUnique({
      where: { id },
      include: detailInclude,
    });
    if (!row) throw new Error('DPR not found');
    return row;
  },

  async create(body: Record<string, unknown>, userId?: string) {
    const projectId = str(body.projectId);
    if (!projectId) throw new Error('Project is required');
    const project = await prisma.erpProject.findUnique({ where: { id: projectId } });
    if (!project) throw new Error('Project not found');

    const lines = parseLines(body.lines);
    if (!lines.length) throw new Error('Add at least one task line before submitting');

    for (const l of lines) {
      if (!l.contractorId) throw new Error('Contractor is required on each task');
      if (!l.activityId && !l.activityName) throw new Error('Activity is required on each task');
      if (!l.unitCode) throw new Error('Unit (UOM) is required on each task');
      if (l.consumedQty == null) throw new Error("Today's consumed work qty is required");
      if (l.completionPct == null) throw new Error('Total task completion % is required');
    }

    const dprNo = str(body.dprNo) ?? (await nextDprNo());
    const existing = await prisma.erpDpr.findUnique({ where: { dprNo } });
    if (existing) throw new Error(`DPR number ${dprNo} already exists`);

    const id = await prisma.$transaction(async (tx) => {
      await applyResourceConsumption(tx, lines, projectId, userId);
      const header = await tx.erpDpr.create({
        data: {
          dprNo,
          reportDate: dateOnly(body.reportDate) ?? todayUtc(),
          projectId,
          createdByName: str(body.createdByName),
          remarks: str(body.remarks),
          createdBy: userId ?? null,
          updatedBy: userId ?? null,
        },
      });
      await createLines(tx, header.id, lines);
      return header.id;
    });

    return this.getById(id);
  },

  async remove(id: string) {
    await this.getById(id);
    await prisma.erpDpr.delete({ where: { id } });
    return { ok: true };
  },
};
