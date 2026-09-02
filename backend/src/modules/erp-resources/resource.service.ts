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
  const n = num(v) ?? 0;
  return new Prisma.Decimal(n);
}

type UsageMaps = { materials: Map<string, number>; machines: Map<string, number> };

async function boqUsageMaps(projectId?: string): Promise<UsageMaps> {
  const rows = await prisma.erpBoqTaskResource.findMany({
    where: {
      resourceType: { in: ['MATERIAL', 'MACHINE'] },
      task: { boq: { isActive: true, ...(projectId ? { projectId } : {}) } },
    },
    select: {
      resourceType: true,
      configMaterialId: true,
      configMachineId: true,
      quantity: true,
    },
  });

  const materials = new Map<string, number>();
  const machines = new Map<string, number>();
  for (const r of rows) {
    const qty = Number(r.quantity) || 0;
    if (qty <= 0) continue;
    if (r.resourceType === 'MATERIAL' && r.configMaterialId) {
      materials.set(r.configMaterialId, (materials.get(r.configMaterialId) ?? 0) + qty);
    }
    if (r.resourceType === 'MACHINE' && r.configMachineId) {
      machines.set(r.configMachineId, (machines.get(r.configMachineId) ?? 0) + qty);
    }
  }
  return { materials, machines };
}

function withStockFields<T extends { id: string; qtyOnHand: Prisma.Decimal }>(
  row: T,
  used: number,
): T & { qtyTotal: number; qtyUsed: number; qtyAvailable: number } {
  const total = Number(row.qtyOnHand);
  return {
    ...row,
    qtyTotal: total,
    qtyUsed: used,
    qtyAvailable: Math.max(0, total - used),
  };
}

async function stockSummary(
  kind: 'material' | 'machine',
  projectId?: string,
) {
  const globalUsage = await boqUsageMaps();
  const projectUsage = projectId ? await boqUsageMaps(projectId) : null;

  if (kind === 'material') {
    const rows = await prisma.erpMaterial.findMany({
      where: { isActive: true },
      orderBy: [{ name: 'asc' }],
      include: {
        activity: { select: { id: true, name: true } },
        subtask: { select: { id: true, name: true } },
      },
    });
    return rows.map((m) => {
      const used = globalUsage.materials.get(m.id) ?? 0;
      const occupied = projectId ? (projectUsage?.materials.get(m.id) ?? 0) : used;
      return {
        ...withStockFields(m, used),
        qtyOccupiedOnProject: occupied,
      };
    });
  }

  const rows = await prisma.erpMachine.findMany({
    where: { isActive: true },
    orderBy: [{ name: 'asc' }],
    include: {
      activity: { select: { id: true, name: true } },
      subtask: { select: { id: true, name: true } },
    },
  });
  return rows.map((m) => {
    const used = globalUsage.machines.get(m.id) ?? 0;
    const occupied = projectId ? (projectUsage?.machines.get(m.id) ?? 0) : used;
    return {
      ...withStockFields(m, used),
      qtyOccupiedOnProject: occupied,
    };
  });
}

export const resourceService = {
  // ── Materials ─────────────────────────────────────────────────────────────
  async listMaterials(opts?: { includeInactive?: boolean; projectId?: string }) {
    const includeInactive = opts?.includeInactive === true;
    const usage = await boqUsageMaps();
    const rows = await prisma.erpMaterial.findMany({
      where: includeInactive ? undefined : { isActive: true },
      orderBy: [{ name: 'asc' }],
      include: {
        activity: { select: { id: true, name: true } },
        subtask: { select: { id: true, name: true } },
        stockLogs: { orderBy: { createdAt: 'desc' }, take: 5 },
      },
    });
    return rows.map((m) => withStockFields(m, usage.materials.get(m.id) ?? 0));
  },

  async materialStockSummary(projectId?: string) {
    const items = await stockSummary('material', projectId);
    const projects = projectId
      ? []
      : await prisma.erpProject.findMany({
          where: { isActive: true },
          select: { id: true, name: true, projectNo: true },
        });
    const withOccupancy = await Promise.all(
      items.map(async (item) => {
        const uses = await prisma.erpMaterialProjectUse.findMany({
          where: { materialId: item.id, qtyUsed: { gt: 0 } },
          include: { project: { select: { id: true, name: true, projectNo: true } } },
        });
        return { ...item, occupiedProjects: uses };
      }),
    );
    return { items: withOccupancy, projects };
  },

  async createMaterial(body: Record<string, unknown>, userId?: string) {
    const name = str(body.name);
    if (!name) throw new Error('Material name is required');
    const qtyOnHand = dec(body.qtyOnHand);
    const row = await prisma.erpMaterial.create({
      data: {
        brand: str(body.brand),
        name,
        unitCode: str(body.unitCode),
        size: str(body.size),
        activityId: str(body.activityId),
        subtaskId: str(body.subtaskId),
        qtyOnHand,
        isActive: body.isActive !== false,
      },
      include: { activity: true, subtask: true },
    });
    if (Number(qtyOnHand) > 0) {
      await prisma.erpMaterialStockLog.create({
        data: {
          materialId: row.id,
          logType: 'INITIAL',
          quantity: qtyOnHand,
          remarks: 'Initial stock',
          createdBy: userId ?? null,
        },
      });
    }
    return row;
  },

  async updateMaterial(id: string, body: Record<string, unknown>) {
    await prisma.erpMaterial.findUniqueOrThrow({ where: { id } });
    return prisma.erpMaterial.update({
      where: { id },
      data: {
        ...(body.brand !== undefined ? { brand: str(body.brand) } : {}),
        ...(body.name != null ? { name: str(body.name) ?? undefined } : {}),
        ...(body.unitCode !== undefined ? { unitCode: str(body.unitCode) } : {}),
        ...(body.size !== undefined ? { size: str(body.size) } : {}),
        ...(body.activityId !== undefined ? { activityId: str(body.activityId) } : {}),
        ...(body.subtaskId !== undefined ? { subtaskId: str(body.subtaskId) } : {}),
        ...(body.isActive != null ? { isActive: Boolean(body.isActive) } : {}),
      },
      include: { activity: true, subtask: true },
    });
  },

  async addMaterialStock(id: string, body: Record<string, unknown>, userId?: string) {
    const qty = dec(body.quantity);
    if (Number(qty) <= 0) throw new Error('Quantity must be positive');
    const logType = (str(body.logType) ?? 'PURCHASE') as 'PURCHASE' | 'ADJUSTMENT' | 'INITIAL';
    const material = await prisma.$transaction(async (tx) => {
      const updated = await tx.erpMaterial.update({
        where: { id },
        data: { qtyOnHand: { increment: qty } },
      });
      await tx.erpMaterialStockLog.create({
        data: {
          materialId: id,
          logType,
          quantity: qty,
          remarks: str(body.remarks),
          createdBy: userId ?? null,
        },
      });
      return updated;
    });
    return material;
  },

  async removeMaterial(id: string) {
    await prisma.erpMaterial.delete({ where: { id } });
    return { ok: true };
  },

  // ── Machines ────────────────────────────────────────────────────────────────
  async listMachines(opts?: { includeInactive?: boolean; projectId?: string }) {
    const usage = await boqUsageMaps();
    const rows = await prisma.erpMachine.findMany({
      where: opts?.includeInactive ? undefined : { isActive: true },
      orderBy: [{ name: 'asc' }],
      include: {
        activity: { select: { id: true, name: true } },
        subtask: { select: { id: true, name: true } },
        stockLogs: { orderBy: { createdAt: 'desc' }, take: 5 },
      },
    });
    return rows.map((m) => withStockFields(m, usage.machines.get(m.id) ?? 0));
  },

  async machineStockSummary(projectId?: string) {
    const items = await stockSummary('machine', projectId);
    const withOccupancy = await Promise.all(
      items.map(async (item) => {
        const uses = await prisma.erpMachineProjectUse.findMany({
          where: { machineId: item.id, qtyUsed: { gt: 0 } },
          include: { project: { select: { id: true, name: true, projectNo: true } } },
        });
        return { ...item, occupiedProjects: uses };
      }),
    );
    return { items: withOccupancy };
  },

  async createMachine(body: Record<string, unknown>, userId?: string) {
    const name = str(body.name);
    if (!name) throw new Error('Machine name is required');
    const qtyOnHand = dec(body.qtyOnHand);
    const row = await prisma.erpMachine.create({
      data: {
        brand: str(body.brand),
        name,
        unitCode: str(body.unitCode),
        size: str(body.size),
        activityId: str(body.activityId),
        subtaskId: str(body.subtaskId),
        qtyOnHand,
        isActive: body.isActive !== false,
      },
      include: { activity: true, subtask: true },
    });
    if (Number(qtyOnHand) > 0) {
      await prisma.erpMachineStockLog.create({
        data: {
          machineId: row.id,
          logType: 'INITIAL',
          quantity: qtyOnHand,
          remarks: 'Initial stock',
          createdBy: userId ?? null,
        },
      });
    }
    return row;
  },

  async updateMachine(id: string, body: Record<string, unknown>) {
    await prisma.erpMachine.findUniqueOrThrow({ where: { id } });
    return prisma.erpMachine.update({
      where: { id },
      data: {
        ...(body.brand !== undefined ? { brand: str(body.brand) } : {}),
        ...(body.name != null ? { name: str(body.name) ?? undefined } : {}),
        ...(body.unitCode !== undefined ? { unitCode: str(body.unitCode) } : {}),
        ...(body.size !== undefined ? { size: str(body.size) } : {}),
        ...(body.activityId !== undefined ? { activityId: str(body.activityId) } : {}),
        ...(body.subtaskId !== undefined ? { subtaskId: str(body.subtaskId) } : {}),
        ...(body.isActive != null ? { isActive: Boolean(body.isActive) } : {}),
      },
      include: { activity: true, subtask: true },
    });
  },

  async addMachineStock(id: string, body: Record<string, unknown>, userId?: string) {
    const qty = dec(body.quantity);
    if (Number(qty) <= 0) throw new Error('Quantity must be positive');
    const logType = (str(body.logType) ?? 'PURCHASE') as 'PURCHASE' | 'ADJUSTMENT' | 'INITIAL';
    return prisma.$transaction(async (tx) => {
      const updated = await tx.erpMachine.update({
        where: { id },
        data: { qtyOnHand: { increment: qty } },
      });
      await tx.erpMachineStockLog.create({
        data: {
          machineId: id,
          logType,
          quantity: qty,
          remarks: str(body.remarks),
          createdBy: userId ?? null,
        },
      });
      return updated;
    });
  },

  async removeMachine(id: string) {
    await prisma.erpMachine.delete({ where: { id } });
    return { ok: true };
  },

  // ── Labour ──────────────────────────────────────────────────────────────────
  async listLabour(opts?: { includeInactive?: boolean }) {
    return prisma.erpLabour.findMany({
      where: opts?.includeInactive ? undefined : { isActive: true },
      orderBy: [{ name: 'asc' }],
      include: {
        activity: { select: { id: true, name: true } },
        subtask: { select: { id: true, name: true } },
      },
    });
  },

  async createLabour(body: Record<string, unknown>) {
    const name = str(body.name);
    if (!name) throw new Error('Labour name is required');
    return prisma.erpLabour.create({
      data: {
        name,
        unitCode: str(body.unitCode),
        defaultRate: num(body.defaultRate) != null ? dec(body.defaultRate) : null,
        activityId: str(body.activityId),
        subtaskId: str(body.subtaskId),
        isActive: body.isActive !== false,
      },
      include: { activity: true, subtask: true },
    });
  },

  async updateLabour(id: string, body: Record<string, unknown>) {
    await prisma.erpLabour.findUniqueOrThrow({ where: { id } });
    return prisma.erpLabour.update({
      where: { id },
      data: {
        ...(body.name != null ? { name: str(body.name) ?? undefined } : {}),
        ...(body.unitCode !== undefined ? { unitCode: str(body.unitCode) } : {}),
        ...(body.defaultRate !== undefined
          ? { defaultRate: num(body.defaultRate) != null ? dec(body.defaultRate) : null }
          : {}),
        ...(body.activityId !== undefined ? { activityId: str(body.activityId) } : {}),
        ...(body.subtaskId !== undefined ? { subtaskId: str(body.subtaskId) } : {}),
        ...(body.isActive != null ? { isActive: Boolean(body.isActive) } : {}),
      },
      include: { activity: true, subtask: true },
    });
  },

  async removeLabour(id: string) {
    await prisma.erpLabour.delete({ where: { id } });
    return { ok: true };
  },

  /** Rebuild per-project usage rows from active BOQ resources. */
  async recalculateProjectResourceUsage(projectId: string) {
    const { materials, machines } = await boqUsageMaps(projectId);

    await prisma.$transaction(async (tx) => {
      await tx.erpMaterialProjectUse.deleteMany({ where: { projectId } });
      await tx.erpMachineProjectUse.deleteMany({ where: { projectId } });

      for (const [materialId, qtyUsed] of materials) {
        await tx.erpMaterialProjectUse.create({
          data: { materialId, projectId, qtyUsed: new Prisma.Decimal(qtyUsed) },
        });
      }
      for (const [machineId, qtyUsed] of machines) {
        await tx.erpMachineProjectUse.create({
          data: { machineId, projectId, qtyUsed: new Prisma.Decimal(qtyUsed) },
        });
      }
    });
  },

  /** @deprecated Use recalculateProjectResourceUsage — kept for compatibility. */
  async syncBoqResourceUsage(
    projectId: string,
    _resources: Array<{
      resourceType: string;
      configMaterialId?: string | null;
      configMachineId?: string | null;
      quantity: number;
    }>,
  ) {
    await this.recalculateProjectResourceUsage(projectId);
  },
};
