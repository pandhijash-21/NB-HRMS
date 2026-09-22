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
  return new Prisma.Decimal(num(v) ?? 0);
}

function parseDate(v: unknown, fallback = new Date()): Date {
  if (v == null || v === '') return fallback;
  const d = new Date(String(v));
  return Number.isNaN(d.getTime()) ? fallback : d;
}

/** Accepted qty already received against a PO line (FAIL inwards contribute 0). */
async function acceptedByPoItem(poItemIds: string[]): Promise<Map<string, number>> {
  const map = new Map<string, number>();
  if (poItemIds.length === 0) return map;
  const rows = await prisma.erpStoreInwardLine.groupBy({
    by: ['purchaseOrderItemId'],
    where: { purchaseOrderItemId: { in: poItemIds } },
    _sum: { quantityAccepted: true },
  });
  for (const r of rows) {
    map.set(r.purchaseOrderItemId, Number(r._sum.quantityAccepted ?? 0));
  }
  return map;
}

async function refreshPoStatus(poId: string) {
  const items = await prisma.erpPurchaseOrderItem.findMany({
    where: { purchaseOrderId: poId },
    select: { id: true, orderedQty: true },
  });
  const accepted = await acceptedByPoItem(items.map((i) => i.id));
  let anyAccepted = false;
  let allComplete = items.length > 0;
  for (const item of items) {
    const got = accepted.get(item.id) ?? 0;
    const ordered = Number(item.orderedQty);
    if (got > 0) anyAccepted = true;
    if (got + 1e-9 < ordered) allComplete = false;
  }
  const status = allComplete
    ? 'RECEIVED'
    : anyAccepted
      ? 'PARTIALLY_RECEIVED'
      : 'OPEN';
  await prisma.erpPurchaseOrder.update({
    where: { id: poId },
    data: { status },
  });
}

function mapPoWithRemaining(
  po: {
    id: string;
    poNumber: string;
    vendorName: string;
    vendorId: string | null;
    projectId: string | null;
    orderDate: Date;
    status: string;
    remarks: string | null;
    createdAt: Date;
    updatedAt: Date;
    vendor?: {
      id: string;
      name: string;
      contactPerson?: string | null;
      phone?: string | null;
      mobileNo?: string | null;
      email?: string | null;
      contractorTypeCode?: string | null;
    } | null;
    items: Array<{
      id: string;
      materialId: string | null;
      itemName: string;
      brand: string | null;
      unitCode: string | null;
      size: string | null;
      orderedQty: Prisma.Decimal;
      sortOrder: number;
      material?: { id: string; name: string; qtyOnHand: Prisma.Decimal } | null;
    }>;
  },
  acceptedMap: Map<string, number>,
) {
  const items = po.items.map((it) => {
    const ordered = Number(it.orderedQty);
    const receivedAccepted = acceptedMap.get(it.id) ?? 0;
    const remainingQty = Math.max(0, ordered - receivedAccepted);
    return {
      id: it.id,
      materialId: it.materialId,
      itemName: it.itemName,
      brand: it.brand,
      unitCode: it.unitCode,
      size: it.size,
      orderedQty: ordered,
      receivedQty: receivedAccepted,
      remainingQty,
      sortOrder: it.sortOrder,
      material: it.material
        ? { id: it.material.id, name: it.material.name, qtyOnHand: Number(it.material.qtyOnHand) }
        : null,
    };
  });
  return {
    id: po.id,
    poNumber: po.poNumber,
    vendorName: po.vendorName,
    vendorId: po.vendorId,
    vendor: po.vendor ?? null,
    projectId: po.projectId,
    orderDate: po.orderDate,
    status: po.status,
    remarks: po.remarks,
    createdAt: po.createdAt,
    updatedAt: po.updatedAt,
    items,
    totalOrdered: items.reduce((s, i) => s + i.orderedQty, 0),
    totalRemaining: items.reduce((s, i) => s + i.remainingQty, 0),
  };
}

export const storeInwardService = {
  // ── Store masters (config) ───────────────────────────────────────────────
  async listStores(includeInactive = false) {
    return prisma.erpStoreMaster.findMany({
      where: includeInactive ? undefined : { isActive: true },
      orderBy: { name: 'asc' },
    });
  },

  async createStore(body: Record<string, unknown>) {
    const name = str(body.name);
    const location = str(body.location);
    if (!name) throw new Error('Store name is required');
    if (!location) throw new Error('Store location is required');
    return prisma.erpStoreMaster.create({
      data: { name, location, isActive: body.isActive !== false },
    });
  },

  async updateStore(id: string, body: Record<string, unknown>) {
    const data: Prisma.ErpStoreMasterUpdateInput = {};
    if (body.name !== undefined) {
      const name = str(body.name);
      if (!name) throw new Error('Store name is required');
      data.name = name;
    }
    if (body.location !== undefined) {
      const location = str(body.location);
      if (!location) throw new Error('Store location is required');
      data.location = location;
    }
    if (body.isActive !== undefined) data.isActive = Boolean(body.isActive);
    return prisma.erpStoreMaster.update({ where: { id }, data });
  },

  async removeStore(id: string) {
    const used = await prisma.erpStoreInward.count({ where: { storeId: id } });
    if (used > 0) {
      return prisma.erpStoreMaster.update({
        where: { id },
        data: { isActive: false },
      });
    }
    return prisma.erpStoreMaster.delete({ where: { id } });
  },

  // ── Purchase orders (stub for Purchase menu) ─────────────────────────────
  async listPurchaseOrders(params?: { status?: string; openOnly?: boolean }) {
    const where: Prisma.ErpPurchaseOrderWhereInput = {};
    if (params?.openOnly) {
      where.status = { in: ['OPEN', 'PARTIALLY_RECEIVED', 'DRAFT'] };
    } else if (params?.status) {
      where.status = params.status as never;
    }
    const rows = await prisma.erpPurchaseOrder.findMany({
      where,
      include: {
        vendor: {
          select: {
            id: true,
            name: true,
            contactPerson: true,
            phone: true,
            mobileNo: true,
            email: true,
            contractorTypeCode: true,
          },
        },
        items: {
          orderBy: { sortOrder: 'asc' },
          include: { material: { select: { id: true, name: true, qtyOnHand: true } } },
        },
      },
      orderBy: { orderDate: 'desc' },
    });
    const allItemIds = rows.flatMap((r) => r.items.map((i) => i.id));
    const accepted = await acceptedByPoItem(allItemIds);
    return rows.map((r) => mapPoWithRemaining(r, accepted));
  },

  async getPurchaseOrder(id: string) {
    const po = await prisma.erpPurchaseOrder.findUnique({
      where: { id },
      include: {
        vendor: {
          select: {
            id: true,
            name: true,
            contactPerson: true,
            phone: true,
            mobileNo: true,
            email: true,
            contractorTypeCode: true,
          },
        },
        items: {
          orderBy: { sortOrder: 'asc' },
          include: { material: { select: { id: true, name: true, qtyOnHand: true } } },
        },
      },
    });
    if (!po) throw new Error('Purchase order not found');
    const accepted = await acceptedByPoItem(po.items.map((i) => i.id));
    return mapPoWithRemaining(po, accepted);
  },

  /** Stub create — full Purchase UI later. Used to seed / API create POs. */
  async createPurchaseOrder(body: Record<string, unknown>, userId?: string) {
    const poNumber =
      str(body.poNumber) ||
      `PO-${new Date().toISOString().slice(0, 10).replace(/-/g, '')}-${Date.now().toString().slice(-4)}`;
    const vendorName = str(body.vendorName);
    if (!vendorName) throw new Error('Vendor name is required');
    const itemsIn = Array.isArray(body.items) ? body.items : [];
    if (itemsIn.length === 0) throw new Error('At least one PO item is required');

    const itemsData = itemsIn.map((raw, idx) => {
      const it = (raw ?? {}) as Record<string, unknown>;
      const itemName = str(it.itemName) || str(it.name);
      const orderedQty = num(it.orderedQty) ?? num(it.quantity);
      if (!itemName) throw new Error(`Item ${idx + 1}: name is required`);
      if (orderedQty == null || orderedQty <= 0) {
        throw new Error(`Item ${idx + 1}: ordered quantity must be > 0`);
      }
      return {
        materialId: str(it.materialId),
        itemName,
        brand: str(it.brand),
        unitCode: str(it.unitCode),
        size: str(it.size),
        orderedQty: dec(orderedQty),
        sortOrder: idx,
      };
    });

    return prisma.erpPurchaseOrder.create({
      data: {
        poNumber,
        vendorName,
        vendorId: str(body.vendorId),
        projectId: str(body.projectId),
        orderDate: parseDate(body.orderDate),
        status: 'OPEN',
        remarks: str(body.remarks),
        createdBy: userId ?? null,
        items: { create: itemsData },
      },
      include: {
        vendor: {
          select: {
            id: true,
            name: true,
            contactPerson: true,
            phone: true,
            mobileNo: true,
            email: true,
            contractorTypeCode: true,
          },
        },
        items: { orderBy: { sortOrder: 'asc' } },
      },
    });
  },

  // ── Goods inward ─────────────────────────────────────────────────────────
  async listInwards(params?: { purchaseOrderId?: string; storeId?: string }) {
    return prisma.erpStoreInward.findMany({
      where: {
        ...(params?.purchaseOrderId ? { purchaseOrderId: params.purchaseOrderId } : {}),
        ...(params?.storeId ? { storeId: params.storeId } : {}),
      },
      include: {
        store: true,
        purchaseOrder: { select: { id: true, poNumber: true, vendorName: true } },
        lines: { orderBy: { sortOrder: 'asc' } },
      },
      orderBy: { inwardDate: 'desc' },
    });
  },

  async getInward(id: string) {
    const row = await prisma.erpStoreInward.findUnique({
      where: { id },
      include: {
        store: true,
        purchaseOrder: {
          include: {
            items: true,
            vendor: {
          select: {
            id: true,
            name: true,
            contactPerson: true,
            phone: true,
            mobileNo: true,
            email: true,
            contractorTypeCode: true,
          },
        },
          },
        },
        lines: { orderBy: { sortOrder: 'asc' } },
      },
    });
    if (!row) throw new Error('Store inward not found');
    return row;
  },

  async createInward(body: Record<string, unknown>, userId?: string) {
    const purchaseOrderId = str(body.purchaseOrderId);
    const storeId = str(body.storeId);
    const qcStatus = str(body.qcStatus)?.toUpperCase();
    if (!purchaseOrderId) throw new Error('Purchase order is required');
    if (!storeId) throw new Error('Store is required');
    if (!qcStatus || !['PASSED', 'PARTIAL_PASS', 'FAIL'].includes(qcStatus)) {
      throw new Error('QC status is required (PASSED, PARTIAL_PASS, or FAIL)');
    }

    const store = await prisma.erpStoreMaster.findFirst({
      where: { id: storeId, isActive: true },
    });
    if (!store) throw new Error('Store not found or inactive');

    const po = await this.getPurchaseOrder(purchaseOrderId);
    if (po.status === 'CANCELLED' || po.status === 'RECEIVED') {
      throw new Error(`Cannot receive against PO in status ${po.status}`);
    }

    const linesIn = Array.isArray(body.lines) ? body.lines : [];
    if (linesIn.length === 0) throw new Error('At least one item line is required');

    const headerRejected = num(body.quantityRejected) ?? 0;
    const returnDateRaw = body.returnDate;
    let returnDate: Date | null = null;
    if (qcStatus === 'PARTIAL_PASS' || qcStatus === 'FAIL') {
      if (!returnDateRaw) throw new Error('Return date is required for partial pass / fail');
      returnDate = parseDate(returnDateRaw);
    }
    if (qcStatus === 'PARTIAL_PASS' && headerRejected <= 0) {
      // Allow per-line rejection instead of header; validate later
    }

    const remainingByItem = new Map(po.items.map((i) => [i.id, i.remainingQty]));
    const poItemById = new Map(po.items.map((i) => [i.id, i]));

    type PreparedLine = {
      purchaseOrderItemId: string;
      materialId: string | null;
      itemName: string;
      brand: string | null;
      unitCode: string | null;
      size: string | null;
      quantityReceived: number;
      quantityAccepted: number;
      quantityRejected: number;
      sortOrder: number;
    };

    const prepared: PreparedLine[] = [];
    let lineRejectSum = 0;

    for (let idx = 0; idx < linesIn.length; idx++) {
      const raw = (linesIn[idx] ?? {}) as Record<string, unknown>;
      const poItemId = str(raw.purchaseOrderItemId) || str(raw.poItemId);
      if (!poItemId) throw new Error(`Line ${idx + 1}: PO item is required`);
      const poItem = poItemById.get(poItemId);
      if (!poItem) throw new Error(`Line ${idx + 1}: item not on this PO`);

      const qtyReceived = num(raw.quantityReceived) ?? num(raw.quantity) ?? 0;
      if (qtyReceived <= 0) throw new Error(`Line ${idx + 1}: quantity must be > 0`);

      const remaining = remainingByItem.get(poItemId) ?? 0;
      if (qtyReceived > remaining + 1e-9) {
        throw new Error(
          `Line ${idx + 1}: qty ${qtyReceived} exceeds remaining ${remaining} for "${poItem.itemName}" on this PO`,
        );
      }

      let qtyRejected = 0;
      let qtyAccepted = qtyReceived;
      if (qcStatus === 'FAIL') {
        qtyRejected = qtyReceived;
        qtyAccepted = 0;
      } else if (qcStatus === 'PARTIAL_PASS') {
        qtyRejected = num(raw.quantityRejected) ?? 0;
        if (qtyRejected < 0) throw new Error(`Line ${idx + 1}: rejected qty invalid`);
        if (qtyRejected > qtyReceived) {
          throw new Error(`Line ${idx + 1}: rejected qty cannot exceed received qty`);
        }
        qtyAccepted = qtyReceived - qtyRejected;
        lineRejectSum += qtyRejected;
      }

      // Consume remaining for multi-line same item validation within this request
      remainingByItem.set(poItemId, remaining - qtyReceived);

      prepared.push({
        purchaseOrderItemId: poItemId,
        materialId: poItem.materialId,
        itemName: poItem.itemName,
        brand: poItem.brand,
        unitCode: poItem.unitCode,
        size: poItem.size,
        quantityReceived: qtyReceived,
        quantityAccepted: qtyAccepted,
        quantityRejected: qtyRejected,
        sortOrder: idx,
      });
    }

    if (qcStatus === 'PARTIAL_PASS') {
      const totalRejected = headerRejected > 0 ? headerRejected : lineRejectSum;
      if (totalRejected <= 0) {
        throw new Error('Partial pass requires quantity rejected > 0');
      }
      // If header rejected provided but lines have 0, distribute onto first line
      if (headerRejected > 0 && lineRejectSum <= 0) {
        const first = prepared[0]!;
        if (headerRejected > first.quantityReceived) {
          throw new Error('Quantity rejected cannot exceed received quantity');
        }
        first.quantityRejected = headerRejected;
        first.quantityAccepted = first.quantityReceived - headerRejected;
      }
    }

    const inward = await prisma.$transaction(async (tx) => {
      const header = await tx.erpStoreInward.create({
        data: {
          purchaseOrderId,
          storeId,
          inwardDate: parseDate(body.inwardDate ?? body.date),
          truckNumber: str(body.truckNumber),
          challanNumber: str(body.challanNumber),
          challanImageUrl: str(body.challanImageUrl),
          qcStatus: qcStatus as never,
          quantityRejected:
            qcStatus === 'PARTIAL_PASS'
              ? dec(headerRejected > 0 ? headerRejected : lineRejectSum)
              : qcStatus === 'FAIL'
                ? dec(prepared.reduce((s, l) => s + l.quantityReceived, 0))
                : null,
          returnDate,
          remarks: str(body.remarks),
          createdBy: userId ?? null,
          lines: {
            create: prepared.map((l) => ({
              purchaseOrderItemId: l.purchaseOrderItemId,
              materialId: l.materialId,
              itemName: l.itemName,
              brand: l.brand,
              unitCode: l.unitCode,
              size: l.size,
              quantityReceived: dec(l.quantityReceived),
              quantityAccepted: dec(l.quantityAccepted),
              quantityRejected: dec(l.quantityRejected),
              sortOrder: l.sortOrder,
            })),
          },
        },
        include: {
          store: true,
          purchaseOrder: { select: { id: true, poNumber: true, vendorName: true } },
          lines: { orderBy: { sortOrder: 'asc' } },
        },
      });

      // Add accepted qty to stock (material or machine)
      const resourceType =
        String(body.resourceType ?? 'MATERIAL').toUpperCase() === 'MACHINE'
          ? 'MACHINE'
          : 'MATERIAL';

      for (const line of prepared) {
        if (line.quantityAccepted <= 0) continue;

        if (resourceType === 'MACHINE') {
          let machineId: string | null = null;
          const existing = await tx.erpMachine.findFirst({
            where: { name: line.itemName, isActive: true },
          });
          if (existing) {
            machineId = existing.id;
          } else {
            const created = await tx.erpMachine.create({
              data: {
                name: line.itemName,
                brand: line.brand,
                unitCode: line.unitCode,
                size: line.size,
                qtyOnHand: dec(0),
              },
            });
            machineId = created.id;
          }

          await tx.erpMachine.update({
            where: { id: machineId },
            data: { qtyOnHand: { increment: dec(line.quantityAccepted) } },
          });
          await tx.erpMachineStockLog.create({
            data: {
              machineId,
              logType: 'PURCHASE',
              quantity: dec(line.quantityAccepted),
              remarks: `PO ${po.poNumber} / Challan ${str(body.challanNumber) ?? '—'} / QC ${qcStatus}`,
              createdBy: userId ?? null,
            },
          });
          continue;
        }

        let materialId = line.materialId;
        if (!materialId) {
          const existing = await tx.erpMaterial.findFirst({
            where: { name: line.itemName, isActive: true },
          });
          if (existing) {
            materialId = existing.id;
          } else {
            const created = await tx.erpMaterial.create({
              data: {
                name: line.itemName,
                brand: line.brand,
                unitCode: line.unitCode,
                size: line.size,
                qtyOnHand: dec(0),
              },
            });
            materialId = created.id;
            await tx.erpPurchaseOrderItem.update({
              where: { id: line.purchaseOrderItemId },
              data: { materialId },
            });
          }
        }

        await tx.erpMaterial.update({
          where: { id: materialId },
          data: { qtyOnHand: { increment: dec(line.quantityAccepted) } },
        });
        await tx.erpMaterialStockLog.create({
          data: {
            materialId,
            logType: 'PURCHASE',
            quantity: dec(line.quantityAccepted),
            remarks: `PO ${po.poNumber} / Challan ${str(body.challanNumber) ?? '—'} / QC ${qcStatus}`,
            createdBy: userId ?? null,
          },
        });
        await tx.erpStoreInwardLine.updateMany({
          where: {
            inwardId: header.id,
            purchaseOrderItemId: line.purchaseOrderItemId,
            sortOrder: line.sortOrder,
          },
          data: { materialId },
        });
      }

      return header;
    });

    await refreshPoStatus(purchaseOrderId);
    return inward;
  },
};
