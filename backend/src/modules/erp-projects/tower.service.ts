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
  units: { orderBy: [{ floorNo: 'asc' as const }, { sortOrder: 'asc' as const }] },
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
  const frc = dec(body.frc);
  const developmentCharge = dec(body.developmentCharge ?? body.amcGebCharge);
  const plc = dec(body.plc);
  const isDuplex = bool(body.isDuplex, false);

  // Total Unit Value = (Super built up x Base Rate) + (Super built up x FRC) + (Super built up x Dev Charge) + (Super built up x PLC)
  let totalUnitValue: Prisma.Decimal | null = dec(body.totalUnitValue);
  if (totalUnitValue == null && superBuiltUp != null && baseRate != null) {
    const sArea = Number(superBuiltUp);
    const bRate = Number(baseRate);
    const fVal = frc != null ? Number(frc) : 0;
    const dVal = developmentCharge != null ? Number(developmentCharge) : 0;
    const pVal = plc != null ? Number(plc) : 0;

    const bsv = sArea * bRate;
    const dCharge = sArea * dVal;
    const fCharge = sArea * fVal;
    const pCharge = sArea * pVal;
    const unitVal = bsv + fCharge + dCharge + pCharge;
    totalUnitValue = new Prisma.Decimal(Math.round(unitVal * 100) / 100);
  }

  // Taxes
  let taxes = body.taxes as Array<{ name: string; ratePercent: number; amount: number }> | null | undefined;
  if (!Array.isArray(taxes) && totalUnitValue != null) {
    const baseVal = Number(totalUnitValue);
    taxes = [
      { name: 'GST', ratePercent: 5.0, amount: Math.round(baseVal * 0.05 * 100) / 100 },
      { name: 'Stamp Duty', ratePercent: 4.9, amount: Math.round(baseVal * 0.049 * 100) / 100 },
      { name: 'Registration', ratePercent: 1.0, amount: Math.round(baseVal * 0.01 * 100) / 100 },
    ];
  }

  // Maintenance
  const maintenance = Array.isArray(body.maintenance) ? body.maintenance : undefined;

  // Other Charges
  const otherCharges = Array.isArray(body.otherCharges) ? body.otherCharges : undefined;

  // Payment Terms
  const paymentTerms = Array.isArray(body.paymentTerms) ? body.paymentTerms : undefined;

  let totalTaxAmt = 0;
  if (Array.isArray(taxes)) {
    for (const t of taxes) totalTaxAmt += Number(t.amount || 0);
  }

  let totalMaintAmt = 0;
  if (Array.isArray(maintenance)) {
    for (const m of maintenance as Array<{ amount?: number }>) totalMaintAmt += Number(m.amount || 0);
  }

  let totalOtherAmt = 0;
  if (Array.isArray(otherCharges)) {
    for (const o of otherCharges as Array<{ amount?: number }>) totalOtherAmt += Number(o.amount || 0);
  }

  const unitValNum = totalUnitValue != null ? Number(totalUnitValue) : (body.totalValue != null ? Number(dec(body.totalValue)) : 0);
  const grandTotalNum = unitValNum + totalTaxAmt + totalMaintAmt + totalOtherAmt;
  const grandTotal = new Prisma.Decimal(Math.round(grandTotalNum * 100) / 100);
  const totalValue = dec(body.totalValue) ?? (grandTotalNum > 0 ? grandTotal : totalUnitValue);

  return {
    unitNo: str(body.unitNo),
    unitTypeCode: str(body.unitTypeCode),
    floorNo: int(body.floorNo),
    isDuplex,
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
    plc,
    frc,
    developmentCharge,
    baseRate,
    totalUnitValue,
    taxes: (taxes ?? null) as unknown as Prisma.InputJsonValue,
    maintenance: (maintenance ?? null) as unknown as Prisma.InputJsonValue,
    otherCharges: (otherCharges ?? null) as unknown as Prisma.InputJsonValue,
    paymentTerms: (paymentTerms ?? null) as unknown as Prisma.InputJsonValue,
    grandTotal,
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

  async createUnit(projectId: string, towerId: string, body: Record<string, unknown>) {
    await this.getById(projectId, towerId);
    const data = mapUnitBody(body);
    if (!data.unitNo) throw new Error('Unit No is required');
    if (data.floorNo == null) throw new Error('Floor No is required');

    return prisma.erpProjectUnit.create({
      data: {
        towerId,
        unitNo: data.unitNo,
        unitTypeCode: data.unitTypeCode,
        floorNo: data.floorNo,
        isDuplex: data.isDuplex,
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
        frc: data.frc,
        developmentCharge: data.developmentCharge,
        baseRate: data.baseRate,
        totalValue: data.totalValue,
        remarks: data.remarks,
      },
    });
  },

  async deleteUnit(projectId: string, towerId: string, unitId: string) {
    await this.getById(projectId, towerId);
    const unit = await prisma.erpProjectUnit.findFirst({
      where: { id: unitId, towerId },
    });
    if (!unit) throw new Error('Unit not found');
    await prisma.erpProjectUnit.delete({ where: { id: unitId } });
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

    // If marked as duplex, link and auto-occupy the matching unit on floorNo + 1
    // Keep all floors intact: name upper unit as `${unitNo}-2`, set isDuplex = true, statusCode = 'OCCUPIED'
    if (data.isDuplex && data.floorNo != null) {
      const nextFloor = data.floorNo + 1;
      const allUnits = await prisma.erpProjectUnit.findMany({
        where: { towerId },
        orderBy: [{ floorNo: 'asc' }, { sortOrder: 'asc' }, { unitNo: 'asc' }],
      });
      const sameFloorUnits = allUnits.filter((u) => u.floorNo === data.floorNo);
      const nextFloorUnits = allUnits.filter((u) => u.floorNo === nextFloor);
      const unitIndex = sameFloorUnits.findIndex((u) => u.id === unitId);

      let targetUpper: typeof allUnits[0] | null = null;
      // 1. Check if already named ${data.unitNo}-2 or ${unit.unitNo}-2
      targetUpper = nextFloorUnits.find(
        (x) => x.unitNo === `${data.unitNo}-2` || x.unitNo === `${unit.unitNo}-2`
      ) ?? null;
      // 2. Check suffix match (e.g. 01, 02)
      if (!targetUpper) {
        const suffixMatch = data.unitNo ? data.unitNo.match(/(\d+)$/) : null;
        if (suffixMatch && nextFloorUnits.length) {
          targetUpper = nextFloorUnits.find((x) => x.unitNo.endsWith(suffixMatch[1])) ?? null;
        }
      }
      // 3. Match by index on floor
      if (!targetUpper && unitIndex >= 0 && unitIndex < nextFloorUnits.length) {
        targetUpper = nextFloorUnits[unitIndex];
      }

      if (targetUpper && targetUpper.id !== unitId) {
        await prisma.erpProjectUnit.update({
          where: { id: targetUpper.id },
          data: {
            unitNo: `${data.unitNo}-2`,
            isDuplex: true,
            statusCode: 'OCCUPIED',
            unitTypeCode: data.unitTypeCode ?? targetUpper.unitTypeCode,
            areaUnitCode: data.areaUnitCode ?? targetUpper.areaUnitCode,
            remarks: `Duplex upper level of ${data.unitNo}`,
          },
        });
      }
    } else if (!data.isDuplex && unit.isDuplex && unit.floorNo != null) {
      // Duplex was turned off: revert upper unit name and status back to normal
      const nextFloor = unit.floorNo + 1;
      const targetNo = `${unit.unitNo}-2`;
      const pairedUpper = await prisma.erpProjectUnit.findFirst({
        where: { towerId, floorNo: nextFloor, unitNo: targetNo },
      });
      if (pairedUpper) {
        const existingTower = await prisma.erpProjectTower.findUnique({ where: { id: towerId } });
        const prefix = existingTower ? towerPrefix(existingTower.name) : 'T';
        const allUpper = await prisma.erpProjectUnit.findMany({
          where: { towerId, floorNo: nextFloor },
          orderBy: [{ sortOrder: 'asc' }, { unitNo: 'asc' }],
        });
        const idx = allUpper.findIndex((x) => x.id === pairedUpper.id);
        const restoredNo = buildUnitNo(prefix, nextFloor, (idx >= 0 ? idx : 0) + 1);
        await prisma.erpProjectUnit.update({
          where: { id: pairedUpper.id },
          data: {
            unitNo: restoredNo,
            isDuplex: false,
            statusCode: 'AVAILABLE',
            remarks: null,
          },
        });
      }
    }

    return prisma.erpProjectUnit.update({
      where: { id: unitId },
      data: {
        unitNo: data.unitNo!,
        unitTypeCode: data.unitTypeCode,
        floorNo: data.floorNo!,
        isDuplex: data.isDuplex,
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
        frc: data.frc,
        developmentCharge: data.developmentCharge,
        baseRate: data.baseRate,
        totalUnitValue: data.totalUnitValue,
        totalValue: data.totalValue,
        grandTotal: data.grandTotal ?? data.totalValue,
        taxes: data.taxes,
        maintenance: data.maintenance,
        otherCharges: data.otherCharges,
        paymentTerms: data.paymentTerms,
        remarks: data.remarks,
      },
    });
  },

  async batchApplyUnits(
    projectId: string,
    towerId: string,
    payload: {
      scope?: string;
      currentFloor?: number;
      floors?: number[];
      sourceUnitId?: string;
      targetUnitIds?: string[];
      targetFloorNos?: number[];
      allUnits?: boolean;
      data?: Record<string, unknown>;
      unitData?: Record<string, unknown>;
      absorbUpperFloors?: boolean;
    },
  ) {
    const tower = await this.getById(projectId, towerId);
    const rawData = (payload.unitData ?? payload.data ?? {}) as Record<string, unknown>;
    const data = mapUnitBody(rawData);

    const allTowerUnits = await prisma.erpProjectUnit.findMany({
      where: { towerId },
      orderBy: [{ floorNo: 'asc' }, { sortOrder: 'asc' }, { unitNo: 'asc' }],
    });

    const prefix = tower ? towerPrefix(tower.name) : 'T';

    // If batch applying duplex mode
    if (data.isDuplex) {
      // Determine base floors and upper floors
      const allFloorNos = Array.from(new Set(allTowerUnits.map((u) => u.floorNo))).sort((a, b) => a - b);
      
      let baseFloors: number[] = [];
      if (payload.scope === 'ALL_TOWER' || payload.allUnits) {
        // In full tower duplex, alternate floors: 1 is base (2 is upper), 3 is base (4 is upper), etc.
        for (let i = 0; i < allFloorNos.length; i += 2) {
          baseFloors.push(allFloorNos[i]);
        }
      } else if (payload.scope === 'SAME_FLOOR' && payload.currentFloor != null) {
        baseFloors = [Number(payload.currentFloor)];
      } else if (payload.scope === 'FLOOR_RANGE' && Array.isArray(payload.floors) && payload.floors.length > 0) {
        const sortedSelected = [...payload.floors].map(Number).sort((a, b) => a - b);
        const handledUpper = new Set<number>();
        for (const fl of sortedSelected) {
          if (!handledUpper.has(fl)) {
            baseFloors.push(fl);
            handledUpper.add(fl + 1);
          }
        }
      } else {
        baseFloors = [Number(payload.currentFloor ?? allFloorNos[0] ?? 1)];
      }

      await prisma.$transaction(async (tx) => {
        for (const baseFl of baseFloors) {
          const upperFl = baseFl + 1;
          const baseUnits = allTowerUnits.filter((u) => u.floorNo === baseFl);
          const upperUnits = allTowerUnits.filter((u) => u.floorNo === upperFl);

          // Update lower floor units with configuration and mark as base duplex
          for (let i = 0; i < baseUnits.length; i++) {
            const bUnit = baseUnits[i];
            // Ensure base unitNo doesn't have -2 suffix
            const cleanBaseNo = bUnit.unitNo.replace(/-2$/, '');
            const sArea = Number(data.superBuiltUp ?? bUnit.superBuiltUp ?? 0);
            const bRate = Number(data.baseRate ?? bUnit.baseRate ?? 0);
            const fVal = Number(data.frc ?? bUnit.frc ?? 0);
            const dVal = Number(data.developmentCharge ?? bUnit.developmentCharge ?? 0);
            const pVal = Number(data.plc ?? bUnit.plc ?? 0);
            let bTotalUnitVal = data.totalUnitValue ?? bUnit.totalUnitValue;
            if (sArea > 0 && bRate > 0) {
              const calc = (sArea * bRate) + (sArea * fVal) + (sArea * dVal) + (sArea * pVal);
              bTotalUnitVal = new Prisma.Decimal(Math.round(calc * 100) / 100);
            }

            await tx.erpProjectUnit.update({
              where: { id: bUnit.id },
              data: {
                unitNo: cleanBaseNo,
                unitTypeCode: data.unitTypeCode ?? bUnit.unitTypeCode,
                isDuplex: true,
                superBuiltUp: data.superBuiltUp ?? bUnit.superBuiltUp,
                carpetArea: data.carpetArea ?? bUnit.carpetArea,
                areaUnitCode: data.areaUnitCode ?? bUnit.areaUnitCode,
                statusCode: data.statusCode ?? bUnit.statusCode ?? 'AVAILABLE',
                facingCode: data.facingCode ?? bUnit.facingCode,
                categoryCode: data.categoryCode ?? bUnit.categoryCode,
                builtUpArea: data.builtUpArea ?? bUnit.builtUpArea,
                balconyArea: data.balconyArea ?? bUnit.balconyArea,
                terraceArea: data.terraceArea ?? bUnit.terraceArea,
                plotArea: data.plotArea ?? bUnit.plotArea,
                parkingAllocation: data.parkingAllocation ?? bUnit.parkingAllocation,
                plc: data.plc ?? bUnit.plc,
                frc: data.frc ?? bUnit.frc,
                developmentCharge: data.developmentCharge ?? bUnit.developmentCharge,
                baseRate: data.baseRate ?? bUnit.baseRate,
                totalUnitValue: bTotalUnitVal,
                taxes: (data.taxes ?? bUnit.taxes) as Prisma.InputJsonValue,
                maintenance: (data.maintenance ?? bUnit.maintenance) as Prisma.InputJsonValue,
                otherCharges: (data.otherCharges ?? bUnit.otherCharges) as Prisma.InputJsonValue,
                paymentTerms: (data.paymentTerms ?? bUnit.paymentTerms) as Prisma.InputJsonValue,
                grandTotal: data.grandTotal ?? bUnit.grandTotal,
                totalValue: data.totalValue ?? bUnit.totalValue,
                remarks: `Duplex (Floor ${baseFl} + Floor ${upperFl})`,
              },
            });

            // Match upper unit by index or suffix
            let uUnit: typeof upperUnits[0] | null = null;
            if (i < upperUnits.length) {
              uUnit = upperUnits[i];
            } else {
              const suffixMatch = cleanBaseNo.match(/(\d+)$/);
              if (suffixMatch) {
                uUnit = upperUnits.find((x) => x.unitNo.endsWith(suffixMatch[1])) ?? null;
              }
            }

            if (uUnit) {
              // Name upper unit as `${cleanBaseNo}-2`, mark as isDuplex = true, auto-occupied
              await tx.erpProjectUnit.update({
                where: { id: uUnit.id },
                data: {
                  unitNo: `${cleanBaseNo}-2`,
                  isDuplex: true,
                  statusCode: 'OCCUPIED',
                  unitTypeCode: data.unitTypeCode ?? uUnit.unitTypeCode,
                  areaUnitCode: data.areaUnitCode ?? uUnit.areaUnitCode,
                  superBuiltUp: data.superBuiltUp ?? uUnit.superBuiltUp,
                  carpetArea: data.carpetArea ?? uUnit.carpetArea,
                  remarks: `Duplex upper level of ${cleanBaseNo}`,
                },
              });
            }
          }
        }
      });

      return this.getById(projectId, towerId);
    }

    // Normal (non-duplex) batch apply:
    let targetUnits = allTowerUnits;
    if (payload.targetUnitIds && payload.targetUnitIds.length > 0) {
      const set = new Set(payload.targetUnitIds);
      targetUnits = allTowerUnits.filter((u) => set.has(u.id));
    } else if (payload.scope === 'SAME_FLOOR' && payload.currentFloor != null) {
      targetUnits = allTowerUnits.filter((u) => u.floorNo === Number(payload.currentFloor));
    } else if (payload.scope === 'FLOOR_RANGE' && Array.isArray(payload.floors) && payload.floors.length > 0) {
      const floorSet = new Set(payload.floors.map(Number));
      targetUnits = allTowerUnits.filter((u) => floorSet.has(u.floorNo));
    } else if (payload.targetFloorNos && payload.targetFloorNos.length > 0) {
      const floorSet = new Set(payload.targetFloorNos.map(Number));
      targetUnits = allTowerUnits.filter((u) => floorSet.has(u.floorNo));
    } else if (payload.scope === 'ALL_TOWER' || payload.allUnits) {
      targetUnits = allTowerUnits;
    } else if (!payload.allUnits && payload.sourceUnitId) {
      const source = allTowerUnits.find((u) => u.id === payload.sourceUnitId);
      if (source) {
        targetUnits = allTowerUnits.filter((u) => u.floorNo === source.floorNo && u.id !== source.id);
      }
    }

    await prisma.$transaction(async (tx) => {
      for (const u of targetUnits) {
        // If this unit had -2 suffix because it was duplex upper, restore standard unitNo
        let unitNo = u.unitNo;
        if (u.unitNo.endsWith('-2')) {
          const sameFloor = allTowerUnits.filter((x) => x.floorNo === u.floorNo);
          const idx = sameFloor.findIndex((x) => x.id === u.id);
          unitNo = buildUnitNo(prefix, u.floorNo, (idx >= 0 ? idx : 0) + 1);
        }

        const sArea = Number(data.superBuiltUp ?? u.superBuiltUp ?? 0);
        const bRate = Number(data.baseRate ?? u.baseRate ?? 0);
        const fVal = Number(data.frc ?? u.frc ?? 0);
        const dVal = Number(data.developmentCharge ?? u.developmentCharge ?? 0);
        const pVal = Number(data.plc ?? u.plc ?? 0);
        let uTotalUnitVal = data.totalUnitValue ?? u.totalUnitValue;
        if (sArea > 0 && bRate > 0) {
          const calc = (sArea * bRate) + (sArea * fVal) + (sArea * dVal) + (sArea * pVal);
          uTotalUnitVal = new Prisma.Decimal(Math.round(calc * 100) / 100);
        }

        await tx.erpProjectUnit.update({
          where: { id: u.id },
          data: {
            unitNo,
            unitTypeCode: data.unitTypeCode ?? u.unitTypeCode,
            isDuplex: false,
            superBuiltUp: data.superBuiltUp ?? u.superBuiltUp,
            carpetArea: data.carpetArea ?? u.carpetArea,
            areaUnitCode: data.areaUnitCode ?? u.areaUnitCode,
            statusCode: data.statusCode ?? u.statusCode,
            facingCode: data.facingCode ?? u.facingCode,
            categoryCode: data.categoryCode ?? u.categoryCode,
            builtUpArea: data.builtUpArea ?? u.builtUpArea,
            balconyArea: data.balconyArea ?? u.balconyArea,
            terraceArea: data.terraceArea ?? u.terraceArea,
            plotArea: data.plotArea ?? u.plotArea,
            parkingAllocation: data.parkingAllocation ?? u.parkingAllocation,
            plc: data.plc ?? u.plc,
            frc: data.frc ?? u.frc,
            developmentCharge: data.developmentCharge ?? u.developmentCharge,
            baseRate: data.baseRate ?? u.baseRate,
            totalUnitValue: uTotalUnitVal,
            taxes: (data.taxes ?? u.taxes) as Prisma.InputJsonValue,
            maintenance: (data.maintenance ?? u.maintenance) as Prisma.InputJsonValue,
            otherCharges: (data.otherCharges ?? u.otherCharges) as Prisma.InputJsonValue,
            paymentTerms: (data.paymentTerms ?? u.paymentTerms) as Prisma.InputJsonValue,
            grandTotal: data.grandTotal ?? u.grandTotal,
            totalValue: data.totalValue ?? u.totalValue,
            remarks: data.remarks ?? u.remarks,
          },
        });
      }
    });

    return this.getById(projectId, towerId);
  },
};
