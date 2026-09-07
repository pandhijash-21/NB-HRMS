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

async function machineInUseMap(): Promise<Map<string, number>> {
  const activeIssues = await prisma.erpMachineIssue.findMany({
    where: { status: { in: ['ACTIVE', 'PARTIALLY_RETURNED'] } },
    select: { machineId: true, quantityInUse: true },
  });
  const map = new Map<string, number>();
  for (const issue of activeIssues) {
    const qty = Number(issue.quantityInUse) || 0;
    map.set(issue.machineId, (map.get(issue.machineId) ?? 0) + qty);
  }
  return map;
}

function withMachineStockFields<T extends { id: string; qtyOnHand: Prisma.Decimal }>(
  row: T,
  boqUsed: number,
  inUse: number,
): T & { qtyTotal: number; qtyUsed: number; qtyInUse: number; qtyAvailable: number } {
  const total = Number(row.qtyOnHand);
  const totalUsed = boqUsed + inUse;
  return {
    ...row,
    qtyTotal: total,
    qtyInUse: inUse,
    qtyUsed: totalUsed,
    qtyAvailable: Math.max(0, total - inUse - boqUsed),
  };
}

async function stockSummary(
  kind: 'material' | 'machine',
  projectId?: string,
) {
  const globalUsage = await boqUsageMaps();
  const projectUsage = projectId ? await boqUsageMaps(projectId) : null;
  const inUseMap = kind === 'machine' ? await machineInUseMap() : new Map<string, number>();

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
    const boqUsed = globalUsage.machines.get(m.id) ?? 0;
    const inUse = inUseMap.get(m.id) ?? 0;
    const occupied = projectId ? (projectUsage?.machines.get(m.id) ?? 0) : boqUsed;
    return {
      ...withMachineStockFields(m, boqUsed, inUse),
      qtyOccupiedOnProject: occupied + inUse,
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
        stockLogs: {
          orderBy: { createdAt: 'desc' },
          take: 10,
          include: { contractor: { select: { id: true, name: true, phone: true } } },
        },
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

  async dispatchMaterialOutward(
    id: string,
    body: Record<string, unknown>,
    userId?: string,
  ) {
    const qty = dec(body.quantity);
    const numQty = Number(qty);
    if (numQty <= 0) throw new Error('Quantity must be positive');
    const contractorId = str(body.contractorId);
    if (!contractorId) throw new Error('Contractor (used by) is required');

    const contractor = await prisma.erpContractor.findUnique({
      where: { id: contractorId },
      select: { id: true, name: true },
    });
    if (!contractor) throw new Error('Contractor not found');

    const material = await prisma.erpMaterial.findUniqueOrThrow({
      where: { id },
    });

    const currentOnHand = Number(material.qtyOnHand);
    const usage = await boqUsageMaps();
    const boqUsed = usage.materials.get(id) ?? 0;
    const available = Math.max(0, currentOnHand - boqUsed);

    if (numQty > available) {
      throw new Error(`Insufficient available stock. Requested: ${numQty}, Available: ${available}`);
    }

    return prisma.$transaction(async (tx) => {
      const updated = await tx.erpMaterial.update({
        where: { id },
        data: { qtyOnHand: { decrement: qty } },
      });

      const log = await tx.erpMaterialStockLog.create({
        data: {
          materialId: id,
          logType: 'CONSUMPTION',
          quantity: qty,
          contractorId: contractor.id,
          contractorName: contractor.name,
          remarks: str(body.remarks),
          createdBy: userId ?? null,
        },
        include: {
          contractor: { select: { id: true, name: true, phone: true } },
        },
      });

      return { material: updated, log };
    });
  },

  async getMaterialLogs(materialId: string) {
    await prisma.erpMaterial.findUniqueOrThrow({ where: { id: materialId } });
    return prisma.erpMaterialStockLog.findMany({
      where: { materialId },
      orderBy: { createdAt: 'desc' },
      include: {
        contractor: { select: { id: true, name: true, phone: true } },
      },
    });
  },

  async removeMaterial(id: string) {
    await prisma.erpMaterial.delete({ where: { id } });
    return { ok: true };
  },

  // ── Machines ────────────────────────────────────────────────────────────────
  async listMachines(opts?: { includeInactive?: boolean; projectId?: string }) {
    const usage = await boqUsageMaps();
    const inUseMap = await machineInUseMap();
    const rows = await prisma.erpMachine.findMany({
      where: opts?.includeInactive ? undefined : { isActive: true },
      orderBy: [{ name: 'asc' }],
      include: {
        activity: { select: { id: true, name: true } },
        subtask: { select: { id: true, name: true } },
        stockLogs: {
          orderBy: { createdAt: 'desc' },
          take: 10,
          include: { contractor: { select: { id: true, name: true, phone: true } } },
        },
        issues: {
          where: { status: { in: ['ACTIVE', 'PARTIALLY_RETURNED'] } },
          include: {
            contractor: { select: { id: true, name: true, phone: true } },
            returnLogs: { orderBy: { returnDate: 'desc' } },
          },
          orderBy: { issueDate: 'desc' },
        },
      },
    });
    return rows.map((m) =>
      withMachineStockFields(
        m,
        usage.machines.get(m.id) ?? 0,
        inUseMap.get(m.id) ?? 0,
      ),
    );
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

  async issueMachine(
    id: string,
    body: Record<string, unknown>,
    userId?: string,
  ) {
    const qty = dec(body.quantity);
    const numQty = Number(qty);
    if (numQty <= 0) throw new Error('Quantity must be positive');
    const contractorId = str(body.contractorId);
    if (!contractorId) throw new Error('Contractor (Used by) is required');

    const contractor = await prisma.erpContractor.findUnique({
      where: { id: contractorId },
      select: { id: true, name: true },
    });
    if (!contractor) throw new Error('Contractor not found');

    const machine = await prisma.erpMachine.findUniqueOrThrow({
      where: { id },
    });

    const currentOnHand = Number(machine.qtyOnHand);
    const inUseMap = await machineInUseMap();
    const inUse = inUseMap.get(id) ?? 0;
    const usage = await boqUsageMaps();
    const boqUsed = usage.machines.get(id) ?? 0;
    const available = Math.max(0, currentOnHand - inUse - boqUsed);

    if (numQty > available) {
      throw new Error(`Cannot issue more than available machines (Requested: ${numQty}, Available: ${available})`);
    }

    const issueDate = body.issueDate ? new Date(String(body.issueDate)) : new Date();

    return prisma.$transaction(async (tx) => {
      const issue = await tx.erpMachineIssue.create({
        data: {
          machineId: id,
          contractorId: contractor.id,
          contractorName: contractor.name,
          quantityTaken: qty,
          quantityReturned: new Prisma.Decimal(0),
          quantityInUse: qty,
          issueDate,
          status: 'ACTIVE',
          remarks: str(body.remarks),
          createdBy: userId ?? null,
        },
        include: {
          contractor: { select: { id: true, name: true, phone: true } },
        },
      });

      await tx.erpMachineStockLog.create({
        data: {
          machineId: id,
          logType: 'CONSUMPTION',
          quantity: qty,
          contractorId: contractor.id,
          contractorName: contractor.name,
          remarks: `Issued to ${contractor.name}: ${numQty} ${machine.unitCode ?? 'units'}${body.remarks ? ` (${body.remarks})` : ''}`,
          createdBy: userId ?? null,
        },
      });

      return issue;
    });
  },

  async returnMachine(
    issueId: string,
    body: Record<string, unknown>,
    userId?: string,
  ) {
    const qty = dec(body.quantity);
    const numQty = Number(qty);
    if (numQty <= 0) throw new Error('Return quantity must be positive');

    const issue = await prisma.erpMachineIssue.findUniqueOrThrow({
      where: { id: issueId },
      include: {
        machine: true,
        contractor: { select: { id: true, name: true } },
      },
    });

    if (issue.status === 'RETURNED') {
      throw new Error('This equipment issue is already fully returned');
    }

    const currentInUse = Number(issue.quantityInUse);
    if (numQty > currentInUse) {
      throw new Error(`Cannot return more than quantity currently in use (In use: ${currentInUse}, Returned: ${numQty})`);
    }

    const returnDate = body.returnDate ? new Date(String(body.returnDate)) : new Date();
    const newReturned = Number(issue.quantityReturned) + numQty;
    const newInUse = currentInUse - numQty;
    const newStatus = newInUse <= 0 ? 'RETURNED' : 'PARTIALLY_RETURNED';

    return prisma.$transaction(async (tx) => {
      const returnLog = await tx.erpMachineReturnLog.create({
        data: {
          machineIssueId: issue.id,
          machineId: issue.machineId,
          contractorId: issue.contractorId,
          quantityReturned: qty,
          returnDate,
          remarks: str(body.remarks),
          createdBy: userId ?? null,
        },
      });

      const updatedIssue = await tx.erpMachineIssue.update({
        where: { id: issue.id },
        data: {
          quantityReturned: new Prisma.Decimal(newReturned),
          quantityInUse: new Prisma.Decimal(newInUse),
          status: newStatus,
        },
        include: {
          contractor: { select: { id: true, name: true, phone: true } },
          returnLogs: { orderBy: { returnDate: 'desc' } },
        },
      });

      await tx.erpMachineStockLog.create({
        data: {
          machineId: issue.machineId,
          logType: 'ADJUSTMENT',
          quantity: qty,
          contractorId: issue.contractorId,
          contractorName: issue.contractorName,
          remarks: `Returned by ${issue.contractorName}: ${numQty} ${issue.machine.unitCode ?? 'units'}${body.remarks ? ` (${body.remarks})` : ''}`,
          createdBy: userId ?? null,
        },
      });

      return { issue: updatedIssue, returnLog };
    });
  },

  async listActiveMachineIssues(opts?: { contractorId?: string; machineId?: string }) {
    return prisma.erpMachineIssue.findMany({
      where: {
        status: { in: ['ACTIVE', 'PARTIALLY_RETURNED'] },
        quantityInUse: { gt: 0 },
        ...(opts?.contractorId ? { contractorId: opts.contractorId } : {}),
        ...(opts?.machineId ? { machineId: opts.machineId } : {}),
      },
      orderBy: { issueDate: 'desc' },
      include: {
        machine: { select: { id: true, name: true, brand: true, unitCode: true, size: true } },
        contractor: { select: { id: true, name: true, phone: true } },
        returnLogs: { orderBy: { returnDate: 'desc' } },
      },
    });
  },

  async getMachineLogs(machineId: string) {
    await prisma.erpMachine.findUniqueOrThrow({ where: { id: machineId } });
    const [issues, stockLogs] = await Promise.all([
      prisma.erpMachineIssue.findMany({
        where: { machineId },
        orderBy: { issueDate: 'desc' },
        include: {
          contractor: { select: { id: true, name: true, phone: true } },
          returnLogs: { orderBy: { returnDate: 'desc' } },
        },
      }),
      prisma.erpMachineStockLog.findMany({
        where: { machineId },
        orderBy: { createdAt: 'desc' },
        include: {
          contractor: { select: { id: true, name: true, phone: true } },
        },
      }),
    ]);
    return { issues, stockLogs };
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
