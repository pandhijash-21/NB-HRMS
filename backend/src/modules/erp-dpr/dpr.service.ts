import { Prisma } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { buildDprDailyReportXlsx } from './dpr.export';
import { emitErpUpdate } from '../collaboration/socket';

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

type MachineTimeSlot = { from: string; to: string };

type MachineInput = {
  machineId?: string | null;
  itemName: string;
  brand?: string | null;
  unitCode?: string | null;
  size?: string | null;
  consumedQty?: number | null;
  timeSlots?: MachineTimeSlot[] | null;
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

function parseTimeSlots(raw: unknown): MachineTimeSlot[] | null {
  if (!Array.isArray(raw)) return null;
  const out: MachineTimeSlot[] = [];
  for (const row of raw) {
    const t = (row ?? {}) as Record<string, unknown>;
    const from = str(t.from) ?? str(t.start) ?? str(t.fromTime);
    const to = str(t.to) ?? str(t.end) ?? str(t.toTime);
    if (!from || !to) continue;
    out.push({ from, to });
  }
  return out.length ? out : null;
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
      timeSlots: parseTimeSlots(t.timeSlots),
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

function formatDprDateStamp(d: Date): string {
  const dd = String(d.getUTCDate()).padStart(2, '0');
  const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
  const yyyy = String(d.getUTCFullYear());
  return `${dd}${mm}${yyyy}`;
}

/** Auto name: DPR-DDMMYYYY, with -2 / -3 suffix on collision. */
async function nextDprNo(reportDate?: Date | null): Promise<string> {
  const day = reportDate ?? todayUtc();
  const stamp = formatDprDateStamp(day);
  const base = `DPR-${stamp}`;
  const existing = await prisma.erpDpr.findMany({
    where: { dprNo: { startsWith: base } },
    select: { dprNo: true },
  });
  if (!existing.length) return base;
  const taken = new Set(existing.map((e) => e.dprNo));
  if (!taken.has(base)) return base;
  for (let i = 2; i < 1000; i++) {
    const candidate = `${base}-${i}`;
    if (!taken.has(candidate)) return candidate;
  }
  return `${base}-${Date.now()}`;
}

async function getEditWindowDays(): Promise<number> {
  const row = await prisma.erpDprSettings.findUnique({ where: { key: 'DEFAULT' } });
  const days = row?.editWindowDays ?? 10;
  return Math.max(0, Math.min(365, days));
}

function assertWithinEditWindow(reportDate: Date, editWindowDays: number) {
  const report = new Date(
    Date.UTC(reportDate.getUTCFullYear(), reportDate.getUTCMonth(), reportDate.getUTCDate()),
  );
  const today = todayUtc();
  const diffMs = today.getTime() - report.getTime();
  const diffDays = Math.floor(diffMs / (24 * 60 * 60 * 1000));
  if (diffDays < 0) return; // future-dated allowed
  if (diffDays > editWindowDays) {
    throw new Error(
      `DPR edit window of ${editWindowDays} day(s) has expired for this report date`,
    );
  }
}

function isMaterialInwardOnlyLine(l: LineInput): boolean {
  const name = (l.activityName || '').toLowerCase();
  return name.includes('material inward') && (l.materials?.length ?? 0) > 0;
}

function validateTaskLine(l: LineInput) {
  if (isMaterialInwardOnlyLine(l)) {
    if (!l.unitCode) l.unitCode = 'NOS';
    if (l.completionPct == null) l.completionPct = 0;
    return;
  }
  if (!l.contractorId) throw new Error('Contractor is required on each task');
  if (!l.activityId && !l.activityName) throw new Error('Activity is required on each task');
  if (!l.unitCode) throw new Error('Unit (UOM) is required on each task');
  // Today's consumed work qty is optional (defaults to 0 via dec())
  if (l.completionPct == null) throw new Error('Total task completion % is required');
}

async function applyResourceConsumption(
  tx: Prisma.TransactionClient,
  lines: LineInput[],
  projectId: string,
  _userId?: string,
) {
  for (const line of lines) {
    for (const m of line.materials ?? []) {
      const qty = Number(m.consumedQty ?? 0);
      if (!m.materialId || qty <= 0) continue;
      // Store outward already decremented qtyOnHand from Store inventory.
      // We only update erpMaterialProjectUse to track cumulative usage against Project BOQ.
      await tx.erpMaterialProjectUse.upsert({
        where: { materialId_projectId: { materialId: m.materialId, projectId } },
        create: { materialId: m.materialId, projectId, qtyUsed: new Prisma.Decimal(qty) },
        update: { qtyUsed: { increment: qty } },
      });
    }
    for (const m of line.machines ?? []) {
      const qty = Number(m.consumedQty ?? 0);
      if (!m.machineId || qty <= 0) continue;
      // Store equipment issue tracks in-use machines. We update erpMachineProjectUse for BOQ tracking.
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
          timeSlots: m.timeSlots ? (m.timeSlots as Prisma.InputJsonValue) : undefined,
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
    const materialReport = await this.listStoreInwardsForDpr(
      row.projectId,
      row.reportDate,
      row.project?.name,
    );
    return { ...row, materialReport };
  },

  /**
   * Store goods inward (challans) for the DPR project + report date.
   * Used in Daily Report "MATERIAL REPORT" and TODAY RECEIVE columns.
   */
  async listStoreInwardsForDpr(
    projectId: string,
    reportDate: Date,
    projectName?: string | null,
  ) {
    const day = new Date(
      Date.UTC(reportDate.getUTCFullYear(), reportDate.getUTCMonth(), reportDate.getUTCDate()),
    );
    const next = new Date(day);
    next.setUTCDate(next.getUTCDate() + 1);

    const inwards = await prisma.erpStoreInward.findMany({
      where: {
        inwardDate: { gte: day, lt: next },
        purchaseOrder: { projectId },
      },
      include: {
        store: { select: { id: true, name: true } },
        purchaseOrder: {
          select: {
            id: true,
            poNumber: true,
            vendorName: true,
            projectId: true,
          },
        },
        lines: {
          orderBy: { sortOrder: 'asc' },
          select: {
            id: true,
            itemName: true,
            brand: true,
            size: true,
            unitCode: true,
            quantityReceived: true,
            quantityAccepted: true,
            quantityRejected: true,
            materialId: true,
          },
        },
      },
      orderBy: [{ inwardDate: 'asc' }, { createdAt: 'asc' }],
    });

    const siteFallback = projectName || 'Site';
    const rows: Array<{
      srNo: number;
      date: string;
      site: string;
      supplierName: string;
      challanNumber: string | null;
      material: string;
      detailGrade: string;
      vehicleNo: string | null;
      time: string | null;
      qtyReceived: number;
      qtyAccepted: number;
      unitCode: string | null;
      poNumber: string | null;
      qcStatus: string;
      inwardId: string;
    }> = [];

    let sr = 0;
    for (const inv of inwards) {
      const site = siteFallback || inv.store?.name || 'Site';
      const time =
        inv.createdAt != null ? inv.createdAt.toISOString().slice(11, 16) : null;
      for (const line of inv.lines) {
        sr += 1;
        const detail = [line.brand, line.size].filter(Boolean).join(' / ');
        rows.push({
          srNo: sr,
          date: day.toISOString().slice(0, 10),
          site,
          supplierName: inv.purchaseOrder?.vendorName || inv.vendorName || '—',
          challanNumber: inv.challanNumber,
          material: line.itemName,
          detailGrade: detail,
          vehicleNo: inv.truckNumber,
          time,
          qtyReceived: Number(line.quantityReceived),
          qtyAccepted: Number(line.quantityAccepted),
          unitCode: line.unitCode,
          poNumber: inv.purchaseOrder?.poNumber ?? 'NA',
          qcStatus: inv.qcStatus,
          inwardId: inv.id,
        });
      }
    }

    const receiveByMaterial: Record<string, number> = {};
    for (const r of rows) {
      const key = r.material.trim().toLowerCase();
      if (!key) continue;
      receiveByMaterial[key] =
        (receiveByMaterial[key] || 0) + (r.qtyAccepted || r.qtyReceived || 0);
    }

    return { rows, receiveByMaterial, inwardCount: inwards.length };
  },

  /** Excel Daily Report in the legacy NBLT DPR layout. */
  async exportDailyReportXlsx(id: string) {
    const row = await this.getById(id);
    return buildDprDailyReportXlsx(row);
  },

  async getSettings() {
    const row =
      (await prisma.erpDprSettings.findUnique({ where: { key: 'DEFAULT' } })) ??
      (await prisma.erpDprSettings.create({
        data: { key: 'DEFAULT', editWindowDays: 10 },
      }));
    return row;
  },

  async updateSettings(body: Record<string, unknown>) {
    const days = num(body.editWindowDays);
    if (days == null || days < 0 || days > 365) {
      throw new Error('editWindowDays must be between 0 and 365');
    }
    const row = await prisma.erpDprSettings.upsert({
      where: { key: 'DEFAULT' },
      create: { key: 'DEFAULT', editWindowDays: Math.floor(days) },
      update: { editWindowDays: Math.floor(days) },
    });
    emitErpUpdate({ module: 'dpr', id: 'settings', action: 'updated' });
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
      validateTaskLine(l);
    }

    const reportDate = dateOnly(body.reportDate) ?? todayUtc();
    const dprNo = str(body.dprNo) ?? (await nextDprNo(reportDate));
    const existing = await prisma.erpDpr.findUnique({ where: { dprNo } });
    if (existing) throw new Error(`DPR number ${dprNo} already exists`);

    const id = await prisma.$transaction(async (tx) => {
      await applyResourceConsumption(tx, lines, projectId, userId);
      const header = await tx.erpDpr.create({
        data: {
          dprNo,
          reportDate,
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

    emitErpUpdate({ module: 'dpr', id, action: 'created', projectId });
    return this.getById(id);
  },

  async update(id: string, body: Record<string, unknown>, userId?: string) {
    const existing = await prisma.erpDpr.findUnique({
      where: { id },
      include: { lines: { select: { id: true } } },
    });
    if (!existing) throw new Error('DPR not found');

    const editWindowDays = await getEditWindowDays();
    assertWithinEditWindow(existing.reportDate, editWindowDays);

    const projectId = str(body.projectId) ?? existing.projectId;
    const project = await prisma.erpProject.findUnique({ where: { id: projectId } });
    if (!project) throw new Error('Project not found');

    const lines = parseLines(body.lines);
    if (!lines.length) throw new Error('Add at least one task line before submitting');

    for (const l of lines) {
      validateTaskLine(l);
    }

    const reportDate = dateOnly(body.reportDate) ?? existing.reportDate;

    await prisma.$transaction(async (tx) => {
      await tx.erpDprLine.deleteMany({ where: { dprId: id } });
      await applyResourceConsumption(tx, lines, projectId, userId);
      await tx.erpDpr.update({
        where: { id },
        data: {
          reportDate,
          projectId,
          createdByName: str(body.createdByName) ?? existing.createdByName,
          remarks: str(body.remarks) ?? existing.remarks,
          updatedBy: userId ?? null,
        },
      });
      await createLines(tx, id, lines);
    });

    emitErpUpdate({ module: 'dpr', id, action: 'updated', projectId });
    return this.getById(id);
  },

  /**
   * When store material inward happens for a project+date with no DPR yet,
   * auto-create a DPR named DPR-DDMMYYYY containing only those materials.
   * If a DPR already exists for that day, append materials onto a material-inward line.
   */
  async ensureFromMaterialInward(opts: {
    projectId: string;
    inwardDate: Date;
    vendorId?: string | null;
    vendorName?: string | null;
    materials: Array<{
      materialId?: string | null;
      itemName: string;
      brand?: string | null;
      unitCode?: string | null;
      size?: string | null;
      consumedQty?: number | null;
      remarks?: string | null;
    }>;
    userId?: string;
  }) {
    const projectId = opts.projectId;
    if (!projectId || !opts.materials.length) return null;

    const day = new Date(
      Date.UTC(
        opts.inwardDate.getUTCFullYear(),
        opts.inwardDate.getUTCMonth(),
        opts.inwardDate.getUTCDate(),
      ),
    );
    const next = new Date(day);
    next.setUTCDate(next.getUTCDate() + 1);

    const materials = opts.materials.map((m, i) => ({
      materialId: m.materialId ?? null,
      itemName: m.itemName,
      brand: m.brand ?? null,
      unitCode: m.unitCode ?? null,
      size: m.size ?? null,
      consumedQty: m.consumedQty ?? 0,
      remarks: m.remarks ?? 'Auto from store inward',
      sortOrder: i,
    }));

    const existing = await prisma.erpDpr.findFirst({
      where: { projectId, reportDate: { gte: day, lt: next } },
      include: {
        lines: {
          orderBy: { sortOrder: 'asc' },
          include: { materials: true },
        },
      },
    });

    if (existing) {
      // Prefer a line tagged as material inward; else append to first line; else create a line.
      const found =
        existing.lines.find((l) => (l.activityName || '').toLowerCase().includes('material inward')) ??
        existing.lines[0];

      let targetLineId = found?.id;
      let existingMatCount = found?.materials?.length ?? 0;

      if (!targetLineId) {
        const created = await prisma.erpDprLine.create({
          data: {
            dprId: existing.id,
            contractorId: opts.vendorId ?? null,
            contractorName: opts.vendorName ?? null,
            activityName: 'Material Inward',
            taskName: 'Auto from store inward',
            unitCode: materials[0]?.unitCode ?? 'NOS',
            consumedQty: new Prisma.Decimal(0),
            completionPct: new Prisma.Decimal(0),
            remarks: 'Auto-created from material inward',
            sortOrder: 0,
          },
        });
        targetLineId = created.id;
        existingMatCount = 0;
      }

      await prisma.erpDprMaterialLine.createMany({
        data: materials.map((m, mi) => ({
          dprLineId: targetLineId!,
          materialId: m.materialId,
          itemName: m.itemName,
          brand: m.brand,
          unitCode: m.unitCode,
          size: m.size,
          consumedQty: dec(m.consumedQty),
          remarks: m.remarks,
          sortOrder: existingMatCount + mi,
        })),
      });

      emitErpUpdate({ module: 'dpr', id: existing.id, action: 'updated', projectId });
      return this.getById(existing.id);
    }

    const dprNo = await nextDprNo(day);
    const id = await prisma.$transaction(async (tx) => {
      const header = await tx.erpDpr.create({
        data: {
          dprNo,
          reportDate: day,
          projectId,
          createdByName: 'System (Material Inward)',
          remarks: 'Auto-created from material inward — edit to add tasks',
          createdBy: opts.userId ?? null,
          updatedBy: opts.userId ?? null,
        },
      });
      const line = await tx.erpDprLine.create({
        data: {
          dprId: header.id,
          contractorId: opts.vendorId ?? null,
          contractorName: opts.vendorName ?? null,
          activityName: 'Material Inward',
          taskName: 'Auto from store inward',
          unitCode: materials[0]?.unitCode ?? 'NOS',
          consumedQty: new Prisma.Decimal(0),
          completionPct: new Prisma.Decimal(0),
          remarks: 'Auto-created from material inward',
          sortOrder: 0,
        },
      });
      await tx.erpDprMaterialLine.createMany({
        data: materials.map((m, mi) => ({
          dprLineId: line.id,
          materialId: m.materialId,
          itemName: m.itemName,
          brand: m.brand,
          unitCode: m.unitCode,
          size: m.size,
          consumedQty: dec(m.consumedQty),
          remarks: m.remarks,
          sortOrder: mi,
        })),
      });
      return header.id;
    });

    emitErpUpdate({ module: 'dpr', id, action: 'created', projectId });
    return this.getById(id);
  },

  async remove(id: string) {
    await this.getById(id);
    await prisma.erpDpr.delete({ where: { id } });
    emitErpUpdate({ module: 'dpr', id, action: 'deleted' });
    return { ok: true };
  },

  async getContractorResourcesForDpr(contractorId: string, dateStr?: string) {
    if (!contractorId) throw new Error('Contractor ID is required');

    const target = dateStr ? new Date(String(dateStr)) : new Date();
    const localY = target.getFullYear();
    const localM = target.getMonth();
    const localD = target.getDate();
    const dayStart = new Date(localY, localM, localD, 0, 0, 0, 0);
    const dayEnd = new Date(localY, localM, localD, 23, 59, 59, 999);

    const [materialLogs, activeIssues] = await Promise.all([
      prisma.erpMaterialStockLog.findMany({
        where: {
          contractorId,
          logType: 'CONSUMPTION',
          createdAt: {
            gte: new Date(dayStart.getTime() - 4 * 3600 * 1000),
            lte: new Date(dayEnd.getTime() + 4 * 3600 * 1000),
          },
        },
        include: {
          material: true,
        },
        orderBy: { createdAt: 'asc' },
      }),
      prisma.erpMachineIssue.findMany({
        where: {
          contractorId,
          status: { in: ['ACTIVE', 'PARTIALLY_RETURNED'] },
          quantityInUse: { gt: 0 },
          issueDate: { lte: dayEnd },
        },
        include: {
          machine: true,
        },
        orderBy: { issueDate: 'asc' },
      }),
    ]);

    // Aggregate materials by materialId
    const materialMap = new Map<string, {
      materialId: string;
      itemCode: string | null;
      category: string | null;
      itemName: string;
      brand: string | null;
      unitCode: string | null;
      size: string | null;
      consumedQty: number;
      remarks: string | null;
    }>();

    for (const log of materialLogs) {
      const m = log.material;
      const qty = Number(log.quantity);
      const existing = materialMap.get(log.materialId);
      if (existing) {
        existing.consumedQty += qty;
        if (log.remarks && !existing.remarks?.includes(log.remarks)) {
          existing.remarks = existing.remarks ? `${existing.remarks}; ${log.remarks}` : log.remarks;
        }
      } else {
        materialMap.set(log.materialId, {
          materialId: m.id,
          itemCode: null,
          category: null,
          itemName: m.name,
          brand: m.brand,
          unitCode: m.unitCode,
          size: m.size,
          consumedQty: qty,
          remarks: log.remarks ?? 'Store outward dispatch',
        });
      }
    }

    // Aggregate machines by machineId
    const machineMap = new Map<string, {
      machineId: string;
      itemName: string;
      brand: string | null;
      unitCode: string | null;
      size: string | null;
      consumedQty: number;
      remarks: string;
      isCumulative: boolean;
    }>();

    for (const issue of activeIssues) {
      const mac = issue.machine;
      const inUse = Number(issue.quantityInUse);
      const taken = Number(issue.quantityTaken);
      const existing = machineMap.get(issue.machineId);
      if (existing) {
        existing.consumedQty += inUse;
        existing.remarks = `Cumulative use (Total in use: ${existing.consumedQty} ${mac.unitCode ?? 'units'})`;
      } else {
        machineMap.set(issue.machineId, {
          machineId: mac.id,
          itemName: mac.name,
          brand: mac.brand,
          unitCode: mac.unitCode,
          size: mac.size,
          consumedQty: inUse,
          remarks: `Cumulative use (Taken: ${taken}, In use: ${inUse} ${mac.unitCode ?? 'units'})`,
          isCumulative: true,
        });
      }
    }

    return {
      materials: Array.from(materialMap.values()),
      machines: Array.from(machineMap.values()),
    };
  },
};
