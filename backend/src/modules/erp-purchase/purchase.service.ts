import { Prisma, ErpPurchaseRequestStatus } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { randomUUID } from 'crypto';
import {
  DEFAULT_PO_TERMS,
  parseTerms,
  buildComparisonSheetXlsx,
  buildPurchaseOrderXlsx,
} from './purchase.export';
import { quotationService } from './quotation.service';
import { emitErpUpdate } from '../collaboration/socket';

const str = (v: unknown) => {
  if (v == null) return null;
  const s = String(v).trim();
  return s.length ? s : null;
};

const num = (v: unknown) => {
  if (v == null || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

const dateOnly = (v: unknown) => {
  if (v == null || v === '') return null;
  const d = new Date(String(v));
  return Number.isNaN(d.getTime()) ? null : d;
};

const SETTINGS_KEY = 'DEFAULT';

const prInclude = {
  project: { select: { id: true, name: true, projectNo: true } },
  activity: { select: { id: true, name: true } },
  vendor: { select: { id: true, name: true, contractorTypeCode: true } },
  store: {
    select: {
      id: true,
      name: true,
      location: true,
      propertyId: true,
      property: { select: { id: true, name: true } },
    },
  },
  requestedBy: {
    select: {
      id: true,
      generalInfo: { select: { fullName: true, employeeCode: true } },
    },
  },
  approver: {
    select: {
      id: true,
      generalInfo: { select: { fullName: true, employeeCode: true } },
    },
  },
  lines: { orderBy: { sortOrder: 'asc' as const } },
} satisfies Prisma.ErpPurchaseRequestInclude;

function mapEmployeeName(e: {
  id: number;
  generalInfo: { fullName: string; employeeCode: string | null } | null;
} | null) {
  if (!e) return null;
  return {
    id: e.id,
    employeeCode: e.generalInfo?.employeeCode,
    name: e.generalInfo?.fullName ?? e.generalInfo?.employeeCode ?? String(e.id),
  };
}

function serializePr(
  row: Prisma.ErpPurchaseRequestGetPayload<{ include: typeof prInclude }>,
) {
  return {
    ...row,
    requestedBy: mapEmployeeName(row.requestedBy),
    approver: mapEmployeeName(row.approver),
    lines: row.lines.map((l) => ({
      ...l,
      qty: Number(l.qty),
    })),
  };
}

export const purchaseService = {
  async getSettings() {
    const settingsInclude = {
      defaultApprover: {
        select: {
          id: true,
          generalInfo: { select: { fullName: true, employeeCode: true } },
        },
      },
      csApprover: {
        select: {
          id: true,
          generalInfo: { select: { fullName: true, employeeCode: true } },
        },
      },
    } as const;
    let row = await prisma.erpPurchaseSettings.findUnique({
      where: { key: SETTINGS_KEY },
      include: settingsInclude,
    });
    if (!row) {
      row = await prisma.erpPurchaseSettings.create({
        data: { id: randomUUID(), key: SETTINGS_KEY },
        include: settingsInclude,
      });
    }
    return {
      id: row.id,
      key: row.key,
      defaultApproverEmployeeId: row.defaultApproverEmployeeId,
      defaultApprover: mapEmployeeName(row.defaultApprover),
      csApproverEmployeeId: row.csApproverEmployeeId,
      csApprover: mapEmployeeName(row.csApprover),
      defaultPoTerms: parseTerms(row.defaultPoTerms),
    };
  },

  async updateSettings(body: Record<string, unknown>) {
    const data: Prisma.ErpPurchaseSettingsUpdateInput = {};
    if ('defaultApproverEmployeeId' in body) {
      const approverId = num(body.defaultApproverEmployeeId);
      if (approverId != null) {
        await prisma.employee.findUniqueOrThrow({ where: { id: approverId } });
      }
      data.defaultApprover =
        approverId == null ? { disconnect: true } : { connect: { id: approverId } };
    }
    if ('csApproverEmployeeId' in body) {
      const csId = num(body.csApproverEmployeeId);
      if (csId != null) {
        await prisma.employee.findUniqueOrThrow({ where: { id: csId } });
      }
      data.csApprover = csId == null ? { disconnect: true } : { connect: { id: csId } };
    }
    if ('defaultPoTerms' in body) {
      const terms = parseTerms(body.defaultPoTerms);
      data.defaultPoTerms = terms.length ? terms : DEFAULT_PO_TERMS;
    }
    await this.getSettings();
    const row = await prisma.erpPurchaseSettings.update({
      where: { key: SETTINGS_KEY },
      data,
      include: {
        defaultApprover: {
          select: {
            id: true,
            generalInfo: { select: { fullName: true, employeeCode: true } },
          },
        },
        csApprover: {
          select: {
            id: true,
            generalInfo: { select: { fullName: true, employeeCode: true } },
          },
        },
      },
    });
    return {
      id: row.id,
      key: row.key,
      defaultApproverEmployeeId: row.defaultApproverEmployeeId,
      defaultApprover: mapEmployeeName(row.defaultApprover),
      csApproverEmployeeId: row.csApproverEmployeeId,
      csApprover: mapEmployeeName(row.csApprover),
      defaultPoTerms: parseTerms(row.defaultPoTerms),
    };
  },

  async getPurchaseOrder(id: string) {
    const po = await prisma.erpPurchaseOrder.findUnique({
      where: { id },
      include: {
        items: { orderBy: { sortOrder: 'asc' } },
        vendor: {
          select: {
            id: true,
            name: true,
            contactPerson: true,
            phone: true,
            mobileNo: true,
            locations: {
              orderBy: { sortOrder: 'asc' },
              take: 1,
              select: {
                address1: true,
                address2: true,
                cityCode: true,
                stateCode: true,
                postCode: true,
                gstNo: true,
              },
            },
          },
        },
        quotation: true,
        purchaseRequest: {
          select: {
            id: true,
            prNumber: true,
            prDate: true,
            project: { select: { id: true, name: true } },
          },
        },
      },
    });
    if (!po) throw new Error('Purchase order not found');
    const loc = po.vendor?.locations?.[0];
    const vendorAddress = loc
      ? [loc.address1, loc.address2, loc.cityCode, loc.stateCode, loc.postCode]
          .filter(Boolean)
          .join(', ')
      : null;
    return {
      ...po,
      totalAmount: po.totalAmount != null ? Number(po.totalAmount) : null,
      cgstRate: po.cgstRate != null ? Number(po.cgstRate) : 9,
      sgstRate: po.sgstRate != null ? Number(po.sgstRate) : 9,
      termsAndConditions: parseTerms(po.termsAndConditions),
      vendor: po.vendor
        ? {
            id: po.vendor.id,
            name: po.vendor.name,
            contactPerson: po.vendor.contactPerson,
            phone: po.vendor.phone,
            mobileNo: po.vendor.mobileNo,
            address: vendorAddress,
            gstNo: loc?.gstNo ?? null,
          }
        : null,
      project: po.purchaseRequest?.project
        ? { id: po.purchaseRequest.project.id, name: po.purchaseRequest.project.name }
        : null,
      items: po.items.map((i) => ({
        ...i,
        orderedQty: Number(i.orderedQty),
        rate: i.rate != null ? Number(i.rate) : null,
        amount: i.amount != null ? Number(i.amount) : null,
      })),
    };
  },

  async updatePurchaseOrder(id: string, body: Record<string, unknown>) {
    const existing = await prisma.erpPurchaseOrder.findUnique({ where: { id } });
    if (!existing) throw new Error('Purchase order not found');

    const data: Prisma.ErpPurchaseOrderUpdateInput = {};
    if ('termsAndConditions' in body) {
      data.termsAndConditions = parseTerms(body.termsAndConditions);
    }
    if ('cgstRate' in body) {
      const r = num(body.cgstRate);
      if (r == null || r < 0) throw new Error('Invalid CGST rate');
      data.cgstRate = r;
    }
    if ('sgstRate' in body) {
      const r = num(body.sgstRate);
      if (r == null || r < 0) throw new Error('Invalid SGST rate');
      data.sgstRate = r;
    }
    if ('remarks' in body) data.remarks = str(body.remarks);

    await prisma.erpPurchaseOrder.update({ where: { id }, data });
    return this.getPurchaseOrder(id);
  },

  async exportComparisonSheet(purchaseRequestId: string) {
    const sheet = await quotationService.getComparisonSheet(purchaseRequestId);
    return buildComparisonSheetXlsx({
      purchaseRequest: {
        prNumber: sheet.purchaseRequest.prNumber,
        status: sheet.purchaseRequest.status,
        projectName: sheet.purchaseRequest.projectName,
        lines: sheet.purchaseRequest.lines,
      },
      quotations: sheet.quotations.map((q) => ({
        quotationNo: q.quotationNo,
        vendorName: q.vendorName,
        status: q.status,
        totalAmount: Number(q.totalAmount),
        gstNo: q.gstNo,
        lines: q.lines.map((l) => ({
          purchaseRequestLineId: l.purchaseRequestLineId,
          itemName: l.itemName,
          materialId: l.materialId,
          qty: Number(l.qty),
          rate: Number(l.rate),
          amount: Number(l.amount),
          unitCode: l.unitCode,
        })),
      })),
    });
  },

  async exportPurchaseOrderXlsx(id: string) {
    const po = await this.getPurchaseOrder(id);
    const org = await prisma.organization.findFirst({
      where: { isActive: true, deletedAt: null },
      orderBy: { sortOrder: 'asc' },
    });
    return buildPurchaseOrderXlsx({
      po: {
        poNumber: po.poNumber,
        orderDate: po.orderDate,
        vendorName: po.vendorName,
        totalAmount: po.totalAmount,
        remarks: po.remarks,
        cgstRate: po.cgstRate,
        sgstRate: po.sgstRate,
        termsAndConditions: po.termsAndConditions,
      },
      quotation: po.quotation
        ? {
            quotationNo: po.quotation.quotationNo,
            quotationDate: po.quotation.quotationDate,
            address: po.quotation.address,
            gstNo: po.quotation.gstNo,
            vendorName: po.quotation.vendorName,
          }
        : null,
      vendor: po.vendor,
      project: po.project,
      purchaseRequest: po.purchaseRequest
        ? { prNumber: po.purchaseRequest.prNumber, prDate: po.purchaseRequest.prDate }
        : null,
      organization: org
        ? {
            name: org.name,
            address1: org.address1,
            address2: org.address2,
            city: org.city,
            state: org.state,
            pinCode: org.pinCode,
            gstNo: org.gstNo,
          }
        : null,
      items: po.items,
    });
  },

  async list(params: {
    status?: string;
    approverEmployeeId?: number;
    requestedByEmployeeId?: number;
  }) {
    const where: Prisma.ErpPurchaseRequestWhereInput = {};
    if (params.status) {
      where.status = params.status as ErpPurchaseRequestStatus;
    }
    if (params.approverEmployeeId != null) {
      where.approverEmployeeId = params.approverEmployeeId;
    }
    if (params.requestedByEmployeeId != null) {
      where.requestedByEmployeeId = params.requestedByEmployeeId;
    }
    const rows = await prisma.erpPurchaseRequest.findMany({
      where,
      orderBy: [{ prDate: 'desc' }, { createdAt: 'desc' }],
      include: prInclude,
    });
    return rows.map(serializePr);
  },

  async getById(id: string) {
    const row = await prisma.erpPurchaseRequest.findUniqueOrThrow({
      where: { id },
      include: prInclude,
    });
    return serializePr(row);
  },

  async create(
    body: Record<string, unknown>,
    ctx: { userId?: string; employeeId?: number },
  ) {
    const prNumber = str(body.prNumber);
    if (!prNumber) throw new Error('PR No. is required');
    const prDate = dateOnly(body.prDate) ?? new Date();
    const linesRaw = Array.isArray(body.lines) ? body.lines : [];
    if (!linesRaw.length) throw new Error('At least one material line is required');

    const existing = await prisma.erpPurchaseRequest.findUnique({ where: { prNumber } });
    if (existing) throw new Error(`PR No. ${prNumber} already exists`);

    const submit = body.submit === true || body.status === 'PENDING';
    let approverEmployeeId: number | null = num(body.approverEmployeeId);
    let status: ErpPurchaseRequestStatus = 'DRAFT';

    if (submit) {
      const settings = await this.getSettings();
      approverEmployeeId = settings.defaultApproverEmployeeId;
      if (approverEmployeeId == null) {
        throw new Error('Set a default Purchase Request approver in Purchase settings before submitting');
      }
      status = 'PENDING';
    }

    const linesData = linesRaw.map((raw, i) => {
      const line = (raw ?? {}) as Record<string, unknown>;
      const itemName = str(line.itemName) ?? str(line.name);
      if (!itemName) throw new Error(`Line ${i + 1}: item name is required`);
      const qty = Number(line.qty ?? line.quantity ?? 0);
      if (!(qty > 0)) throw new Error(`Line ${i + 1}: quantity must be positive`);
      return {
        materialId: str(line.materialId) ?? str(line.inventoryItemId),
        itemCode: str(line.itemCode),
        categoryCode: str(line.categoryCode),
        brandCode: str(line.brandCode),
        brand: str(line.brand),
        itemName,
        unitCode: str(line.unitCode),
        sizeCode: str(line.sizeCode),
        size: str(line.size),
        qty,
        remark: str(line.remark),
        sortOrder: i,
      };
    });

    const row = await prisma.erpPurchaseRequest.create({
      data: {
        id: randomUUID(),
        prNumber,
        prDate,
        prTypeCode: str(body.prTypeCode),
        projectId: str(body.projectId),
        activityId: str(body.activityId),
        vendorId: str(body.vendorId),
        requestedByEmployeeId: num(body.requestedByEmployeeId) ?? ctx.employeeId ?? null,
        requestedByUserId: str(body.requestedByUserId) ?? ctx.userId ?? null,
        requiredByDate: dateOnly(body.requiredByDate),
        priorityCode: str(body.priorityCode),
        storeId: str(body.storeId),
        propertyId: str(body.propertyId),
        status,
        approverEmployeeId,
        remarks: str(body.remarks),
        createdBy: ctx.userId ?? null,
        lines: { create: linesData },
      },
      include: prInclude,
    });
    emitErpUpdate({ module: 'purchase', id: row.id, action: 'created' });
    return serializePr(row);
  },

  async update(id: string, body: Record<string, unknown>) {
    const existing = await prisma.erpPurchaseRequest.findUniqueOrThrow({ where: { id } });
    if (existing.status === 'APPROVED' || existing.status === 'REJECTED') {
      throw new Error('Approved/rejected purchase requests cannot be edited');
    }
    if (existing.status === 'PENDING' && body.lines != null) {
      throw new Error('Pending purchase requests cannot change lines; withdraw first');
    }

    const data: Prisma.ErpPurchaseRequestUpdateInput = {};
    if (body.prNumber !== undefined) {
      const prNumber = str(body.prNumber);
      if (!prNumber) throw new Error('PR No. is required');
      data.prNumber = prNumber;
    }
    if (body.prDate !== undefined) {
      const d = dateOnly(body.prDate);
      if (!d) throw new Error('Invalid PR date');
      data.prDate = d;
    }
    if (body.prTypeCode !== undefined) data.prTypeCode = str(body.prTypeCode);
    if (body.projectId !== undefined) {
      data.project = str(body.projectId) ? { connect: { id: str(body.projectId)! } } : { disconnect: true };
    }
    if (body.activityId !== undefined) {
      data.activity = str(body.activityId) ? { connect: { id: str(body.activityId)! } } : { disconnect: true };
    }
    if (body.vendorId !== undefined) {
      data.vendor = str(body.vendorId) ? { connect: { id: str(body.vendorId)! } } : { disconnect: true };
    }
    if (body.storeId !== undefined) {
      data.store = str(body.storeId) ? { connect: { id: str(body.storeId)! } } : { disconnect: true };
    }
    if (body.propertyId !== undefined) data.propertyId = str(body.propertyId);
    if (body.requiredByDate !== undefined) data.requiredByDate = dateOnly(body.requiredByDate);
    if (body.priorityCode !== undefined) data.priorityCode = str(body.priorityCode);
    if (body.remarks !== undefined) data.remarks = str(body.remarks);

    if (Array.isArray(body.lines) && existing.status === 'DRAFT') {
      const linesRaw = body.lines as unknown[];
      await prisma.$transaction(async (tx) => {
        await tx.erpPurchaseRequestLine.deleteMany({ where: { purchaseRequestId: id } });
        for (let i = 0; i < linesRaw.length; i++) {
          const line = (linesRaw[i] ?? {}) as Record<string, unknown>;
          const itemName = str(line.itemName) ?? str(line.name);
          if (!itemName) throw new Error(`Line ${i + 1}: item name is required`);
          const qty = Number(line.qty ?? line.quantity ?? 0);
          if (!(qty > 0)) throw new Error(`Line ${i + 1}: quantity must be positive`);
          await tx.erpPurchaseRequestLine.create({
            data: {
              purchaseRequestId: id,
              materialId: str(line.materialId) ?? str(line.inventoryItemId),
              itemCode: str(line.itemCode),
              categoryCode: str(line.categoryCode),
              brandCode: str(line.brandCode),
              brand: str(line.brand),
              itemName,
              unitCode: str(line.unitCode),
              sizeCode: str(line.sizeCode),
              size: str(line.size),
              qty,
              remark: str(line.remark),
              sortOrder: i,
            },
          });
        }
      });
    }

    const row = await prisma.erpPurchaseRequest.update({
      where: { id },
      data,
      include: prInclude,
    });
    return serializePr(row);
  },

  async submit(id: string) {
    const existing = await prisma.erpPurchaseRequest.findUniqueOrThrow({
      where: { id },
      include: { lines: true },
    });
    if (existing.status !== 'DRAFT' && existing.status !== 'REJECTED') {
      throw new Error('Only draft or rejected PRs can be submitted');
    }
    if (!existing.lines.length) throw new Error('Add at least one material line before submit');
    const settings = await this.getSettings();
    if (settings.defaultApproverEmployeeId == null) {
      throw new Error('Set a default Purchase Request approver in Purchase settings before submitting');
    }
    const row = await prisma.erpPurchaseRequest.update({
      where: { id },
      data: {
        status: 'PENDING',
        approverEmployeeId: settings.defaultApproverEmployeeId,
        rejectionReason: null,
        approvedAt: null,
      },
      include: prInclude,
    });
    emitErpUpdate({ module: 'purchase', id: row.id, action: 'submitted' });
    return serializePr(row);
  },

  async approve(id: string, actorEmployeeId?: number) {
    const existing = await prisma.erpPurchaseRequest.findUniqueOrThrow({ where: { id } });
    if (existing.status !== 'PENDING') throw new Error('Only pending PRs can be approved');
    if (
      existing.approverEmployeeId != null &&
      actorEmployeeId != null &&
      existing.approverEmployeeId !== actorEmployeeId
    ) {
      throw new Error('Only the assigned approver can approve this purchase request');
    }
    const row = await prisma.erpPurchaseRequest.update({
      where: { id },
      data: {
        status: 'APPROVED',
        approvedAt: new Date(),
        rejectionReason: null,
      },
      include: prInclude,
    });
    emitErpUpdate({ module: 'purchase', id: row.id, action: 'approved' });
    return serializePr(row);
  },

  async reject(id: string, reason?: string | null, actorEmployeeId?: number) {
    const existing = await prisma.erpPurchaseRequest.findUniqueOrThrow({ where: { id } });
    if (existing.status !== 'PENDING') throw new Error('Only pending PRs can be rejected');
    if (
      existing.approverEmployeeId != null &&
      actorEmployeeId != null &&
      existing.approverEmployeeId !== actorEmployeeId
    ) {
      throw new Error('Only the assigned approver can reject this purchase request');
    }
    const row = await prisma.erpPurchaseRequest.update({
      where: { id },
      data: {
        status: 'REJECTED',
        rejectionReason: str(reason) ?? 'Rejected',
        approvedAt: null,
      },
      include: prInclude,
    });
    emitErpUpdate({ module: 'purchase', id: row.id, action: 'rejected' });
    return serializePr(row);
  },

  async remove(id: string) {
    const existing = await prisma.erpPurchaseRequest.findUniqueOrThrow({ where: { id } });
    if (existing.status === 'APPROVED' || existing.status === 'PENDING') {
      throw new Error('Cannot delete pending or approved purchase requests');
    }
    await prisma.erpPurchaseRequest.delete({ where: { id } });
    emitErpUpdate({ module: 'purchase', id, action: 'deleted' });
    return { id, deleted: true };
  },
};
