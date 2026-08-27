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

function int(v: unknown): number | null {
  const n = num(v);
  return n == null ? null : Math.trunc(n);
}

function bool(v: unknown, fallback = false): boolean {
  if (v == null) return fallback;
  if (typeof v === 'boolean') return v;
  const s = String(v).toLowerCase();
  if (s === 'true' || s === '1') return true;
  if (s === 'false' || s === '0') return false;
  return fallback;
}

function dec(v: unknown): Prisma.Decimal | null {
  const n = num(v);
  return n == null ? null : new Prisma.Decimal(n);
}

function towerPrefix(name: string): string {
  const token = name.trim().toUpperCase().split(/\s+/)[0] ?? 'T';
  const cleaned = token.replace(/[^A-Z0-9]/g, '');
  return cleaned.slice(0, 8) || 'T';
}

/** Floor numbers for generated flats.
 * hasGround = true  → flats on GF, numbering 0..floorCount-1
 * hasGround = false → GF is parking, numbering 1..floorCount
 * Total units always = floorCount × flatsPerFloor.
 */
export function floorNumbers(floorCount: number, hasGround: boolean): number[] {
  if (floorCount < 1) return [];
  if (hasGround) return Array.from({ length: floorCount }, (_, i) => i);
  return Array.from({ length: floorCount }, (_, i) => i + 1);
}

export function expectedUnitCount(floorCount: number, flatsPerFloor: number): number {
  return Math.max(0, floorCount) * Math.max(0, flatsPerFloor);
}

export function buildUnitNo(prefix: string, floorNo: number, flatIndex: number): string {
  const seq = String(flatIndex).padStart(2, '0');
  if (floorNo === 0) return `${prefix}-G${seq}`;
  if (floorNo < 0) return `${prefix}-B${Math.abs(floorNo)}${seq}`;
  return `${prefix}-${floorNo}${seq}`;
}

function plannedUnits(opts: {
  name: string;
  floorCount: number;
  flatsPerFloor: number;
  hasGround: boolean;
  areaUnitCode?: string | null;
}) {
  const prefix = towerPrefix(opts.name);
  const floors = floorNumbers(opts.floorCount, opts.hasGround);
  const rows: Array<{
    unitNo: string;
    floorNo: number;
    areaUnitCode: string | null;
    statusCode: string;
    sortOrder: number;
  }> = [];
  let sort = 0;
  for (const floorNo of floors) {
    for (let flat = 1; flat <= opts.flatsPerFloor; flat++) {
      rows.push({
        unitNo: buildUnitNo(prefix, floorNo, flat),
        floorNo,
        areaUnitCode: opts.areaUnitCode ?? 'SQ_FT',
        statusCode: 'AVAILABLE',
        sortOrder: sort++,
      });
    }
  }
  return rows;
}

const towerInclude = {
  units: { orderBy: [{ floorNo: 'asc' as const }, { sortOrder: 'asc' as const }] },
  _count: { select: { units: true } },
};

const towerListInclude = {
  _count: { select: { units: true } },
};

function mapTowerBody(body: Record<string, unknown>) {
  return {
    name: str(body.name),
    phase: str(body.phase),
    basementCount: int(body.basementCount) ?? 0,
    floorCount: int(body.floorCount),
    flatsPerFloor: int(body.flatsPerFloor),
    hasGround: bool(body.hasGround, false),
    sequence: int(body.sequence) ?? 0,
    statusCode: str(body.statusCode) ?? 'ACTIVE',
    remarks: str(body.remarks),
  };
}

function mapUnitBody(body: Record<string, unknown>) {
  const superBuiltUp = dec(body.superBuiltUp);
  const baseRate = dec(body.baseRate);
  let totalValue = dec(body.totalValue);
  if (superBuiltUp != null && baseRate != null) {
    totalValue = new Prisma.Decimal(Number(superBuiltUp) * Number(baseRate));
  }
  return {
    unitNo: str(body.unitNo),
    unitTypeCode: str(body.unitTypeCode),
    floorNo: int(body.floorNo),
    superBuiltUp,
    carpetArea: dec(body.carpetArea),
    areaUnitCode: str(body.areaUnitCode),
    statusCode: str(body.statusCode) ?? 'AVAILABLE',
    facingCode: str(body.facingCode),
    categoryCode: str(body.categoryCode),
    builtUpArea: dec(body.builtUpArea),
    balconyArea: dec(body.balconyArea),
    terraceArea: dec(body.terraceArea),
    plotArea: dec(body.plotArea),
    parkingAllocation: str(body.parkingAllocation),
    plc: dec(body.plc),
    baseRate,
    totalValue,
    remarks: str(body.remarks),
  };
}

function requireUnit(data: ReturnType<typeof mapUnitBody>) {
  if (!data.unitNo) throw new Error('Unit No is required');
  if (!data.unitTypeCode) throw new Error('Unit type is required');
  if (data.floorNo == null) throw new Error('Floor No is required');
  if (data.superBuiltUp == null) throw new Error('Super built-up is required');
  if (data.carpetArea == null) throw new Error('Carpet (RERA) is required');
  if (!data.areaUnitCode) throw new Error('Area unit is required');
  if (!data.statusCode) throw new Error('Unit status is required');
  if (!data.facingCode) throw new Error('Facing is required');
  if (!data.categoryCode) throw new Error('Unit category is required');
  if (data.builtUpArea == null) throw new Error('Built-up area is required');
  if (data.balconyArea == null) throw new Error('Balcony area is required');
  if (data.terraceArea == null) throw new Error('Terrace area is required');
  if (data.plotArea == null) throw new Error('Plot area is required');
  if (!data.parkingAllocation) throw new Error('Parking allocation is required');
  if (data.plc == null) throw new Error('PLC is required');
  if (data.baseRate == null) throw new Error('Base rate is required');
  if (data.totalValue == null) throw new Error('Total unit value is required');
  if (!data.remarks) throw new Error('Remarks is required');
}

export const towerService = {
  async list(projectId: string) {
    await prisma.erpProject.findUniqueOrThrow({ where: { id: projectId } });
    return prisma.erpProjectTower.findMany({
      where: { projectId },
      include: towerListInclude,
      orderBy: [{ sequence: 'asc' }, { createdAt: 'asc' }],
    });
  },

  async getById(projectId: string, towerId: string) {
    const row = await prisma.erpProjectTower.findFirst({
      where: { id: towerId, projectId },
      include: towerInclude,
    });
    if (!row) throw new Error('Tower not found');
    return {
      ...row,
      expectedUnits: expectedUnitCount(row.floorCount, row.flatsPerFloor),
    };
  },

  async create(projectId: string, body: Record<string, unknown>) {
    const project = await prisma.erpProject.findUnique({ where: { id: projectId } });
    if (!project) throw new Error('Project not found');
    const data = mapTowerBody(body);
    if (!data.name) throw new Error('Tower / Block name is required');
    if (data.floorCount == null || data.floorCount < 1) throw new Error('Number of floors is required');
    if (data.flatsPerFloor == null || data.flatsPerFloor < 1) {
      throw new Error('Number of flats in a floor is required');
    }
    if (data.basementCount < 0) throw new Error('Number of basements cannot be negative');

    const units = plannedUnits({
      name: data.name,
      floorCount: data.floorCount,
      flatsPerFloor: data.flatsPerFloor,
      hasGround: data.hasGround,
      areaUnitCode: project.areaUnitCode,
    });

    return prisma.erpProjectTower.create({
      data: {
        projectId,
        name: data.name,
        phase: data.phase,
        basementCount: data.basementCount,
        floorCount: data.floorCount,
        flatsPerFloor: data.flatsPerFloor,
        hasGround: data.hasGround,
        sequence: data.sequence,
        statusCode: data.statusCode,
        remarks: data.remarks,
        units: { create: units },
      },
      include: towerInclude,
    });
  },

  async update(projectId: string, towerId: string, body: Record<string, unknown>) {
    const existing = await this.getById(projectId, towerId);
    const data = mapTowerBody(body);
    if (!data.name) throw new Error('Tower / Block name is required');
    if (data.floorCount == null || data.floorCount < 1) throw new Error('Number of floors is required');
    if (data.flatsPerFloor == null || data.flatsPerFloor < 1) {
      throw new Error('Number of flats in a floor is required');
    }

    return prisma.erpProjectTower.update({
      where: { id: existing.id },
      data: {
        name: data.name,
        phase: data.phase,
        basementCount: data.basementCount,
        floorCount: data.floorCount,
        flatsPerFloor: data.flatsPerFloor,
        hasGround: data.hasGround,
        sequence: data.sequence,
        statusCode: data.statusCode,
        remarks: data.remarks,
      },
      include: towerInclude,
    });
  },

  async remove(projectId: string, towerId: string) {
    const existing = await this.getById(projectId, towerId);
    await prisma.erpProjectTower.delete({ where: { id: existing.id } });
    return { id: existing.id, deleted: true };
  },

  async regenerateUnits(projectId: string, towerId: string) {
    const existing = await this.getById(projectId, towerId);
    const project = await prisma.erpProject.findUnique({ where: { id: projectId } });
    const units = plannedUnits({
      name: existing.name,
      floorCount: existing.floorCount,
      flatsPerFloor: existing.flatsPerFloor,
      hasGround: existing.hasGround,
      areaUnitCode: project?.areaUnitCode,
    });
    await prisma.$transaction([
      prisma.erpProjectUnit.deleteMany({ where: { towerId } }),
      prisma.erpProjectUnit.createMany({
        data: units.map((u) => ({ ...u, towerId })),
      }),
    ]);
    return this.getById(projectId, towerId);
  },

  async updateUnit(projectId: string, towerId: string, unitId: string, body: Record<string, unknown>) {
    await this.getById(projectId, towerId);
    const unit = await prisma.erpProjectUnit.findFirst({
      where: { id: unitId, towerId },
    });
    if (!unit) throw new Error('Unit not found');
    const data = mapUnitBody(body);
    requireUnit(data);
    return prisma.erpProjectUnit.update({
      where: { id: unitId },
      data: {
        unitNo: data.unitNo!,
        unitTypeCode: data.unitTypeCode,
        floorNo: data.floorNo!,
        superBuiltUp: data.superBuiltUp,
        carpetArea: data.carpetArea,
        areaUnitCode: data.areaUnitCode,
        statusCode: data.statusCode,
        facingCode: data.facingCode,
        categoryCode: data.categoryCode,
        builtUpArea: data.builtUpArea,
        balconyArea: data.balconyArea,
        terraceArea: data.terraceArea,
        plotArea: data.plotArea,
        parkingAllocation: data.parkingAllocation,
        plc: data.plc,
        baseRate: data.baseRate,
        totalValue: data.totalValue,
        remarks: data.remarks,
      },
    });
  },
};
