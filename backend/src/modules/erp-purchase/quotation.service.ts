import { Prisma, ErpPurchaseQuotationStatus, ErpPurchaseRequestStatus } from '@prisma/client';
import { randomUUID } from 'crypto';
import { prisma } from '../../config/prisma';

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

const dec = (n: number) => new Prisma.Decimal(n);

const quoteInclude = {
  vendor: { select: { id: true, name: true, contractorTypeCode: true } },
  selectedBy: {
    select: {
      id: true,
      generalInfo: { select: { fullName: true, employeeCode: true } },
    },
  },
  lines: { orderBy: { sortOrder: 'asc' as const } },
  purchaseOrder: { select: { id: true, poNumber: true, status: true, totalAmount: true } },
  purchaseRequest: {
    select: {
      id: true,
      prNumber: true,
      status: true,
      projectId: true,
      project: { select: { id: true, name: true } },
    },
  },
} satisfies Prisma.ErpPurchaseQuotationInclude;

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

function serializeQuote(
  row: Prisma.ErpPurchaseQuotationGetPayload<{ include: typeof quoteInclude }>,
) {
  return {
    ...row,
    totalAmount: Number(row.totalAmount),
    selectedBy: mapEmployeeName(row.selectedBy),
    purchaseOrder: row.purchaseOrder
      ? {
          ...row.purchaseOrder,
          totalAmount:
            row.purchaseOrder.totalAmount != null
              ? Number(row.purchaseOrder.totalAmount)
              : null,
        }
      : null,
    lines: row.lines.map((l) => ({
      ...l,
      qty: Number(l.qty),
      rate: Number(l.rate),
      amount: Number(l.amount),
    })),
  };
}

function parseLines(raw: unknown) {
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new Error('At least one quotation line is required');
  }
  return raw.map((item, idx) => {
    const it = (item ?? {}) as Record<string, unknown>;
    const itemName = str(it.itemName);
    const qty = num(it.qty);
    const rate = num(it.rate) ?? 0;
    if (!itemName) throw new Error(`Line ${idx + 1}: item name is required`);
    if (qty == null || qty <= 0) throw new Error(`Line ${idx + 1}: qty must be > 0`);
    if (rate < 0) throw new Error(`Line ${idx + 1}: rate cannot be negative`);
    const amount = Math.round(qty * rate * 100) / 100;
    return {
      purchaseRequestLineId: str(it.purchaseRequestLineId),
      materialId: str(it.materialId),
      itemCode: str(it.itemCode),
      brand: str(it.brand),
      itemName,
      unitCode: str(it.unitCode),
      size: str(it.size),
      qty: dec(qty),
      rate: dec(rate),
      amount: dec(amount),
      sortOrder: idx,
    };
  });
}

async function nextQuotationNo(prNumber: string) {
  const prefix = `QT-${prNumber}-`;
  const existing = await prisma.erpPurchaseQuotation.count({
    where: { quotationNo: { startsWith: prefix } },
  });
  return `${prefix}${String(existing + 1).padStart(2, '0')}`;
}

export const quotationService = {
  async listByPurchaseRequest(purchaseRequestId: string) {
    const rows = await prisma.erpPurchaseQuotation.findMany({
      where: { purchaseRequestId },
      include: quoteInclude,
      orderBy: { createdAt: 'asc' },
    });
    return rows.map(serializeQuote);
  },

  async getById(id: string) {
    const row = await prisma.erpPurchaseQuotation.findUnique({
      where: { id },
      include: quoteInclude,
    });
    if (!row) throw new Error('Quotation not found');
    return serializeQuote(row);
  },

  async getComparisonSheet(purchaseRequestId: string) {
    const pr = await prisma.erpPurchaseRequest.findUnique({
      where: { id: purchaseRequestId },
      include: {
        project: { select: { id: true, name: true } },
        lines: { orderBy: { sortOrder: 'asc' } },
      },
    });
    if (!pr) throw new Error('Purchase request not found');
    const quotations = await this.listByPurchaseRequest(purchaseRequestId);
    return {
      purchaseRequest: {
        id: pr.id,
        prNumber: pr.prNumber,
        status: pr.status,
        projectId: pr.projectId,
        projectName: pr.project?.name,
        lines: pr.lines.map((l) => ({
          ...l,
          qty: Number(l.qty),
        })),
      },
      quotations,
    };
  },

  async create(
    purchaseRequestId: string,
    body: Record<string, unknown>,
    opts: { userId?: string },
  ) {
    const pr = await prisma.erpPurchaseRequest.findUnique({
      where: { id: purchaseRequestId },
      include: { lines: { orderBy: { sortOrder: 'asc' } } },
    });
    if (!pr) throw new Error('Purchase request not found');
    if (pr.status !== ErpPurchaseRequestStatus.APPROVED) {
      throw new Error('Quotations can only be added against an approved purchase request');
    }

    const vendorName = str(body.vendorName);
    if (!vendorName) throw new Error('Vendor / company name is required');

    // Prefer explicit lines; otherwise seed from PR lines with rate 0
    let linesData: ReturnType<typeof parseLines>;
    if (Array.isArray(body.lines) && body.lines.length > 0) {
      linesData = parseLines(body.lines);
    } else if (pr.lines.length === 0) {
      throw new Error('Purchase request has no lines to quote');
    } else {
      linesData = pr.lines.map((l, idx) => ({
        purchaseRequestLineId: l.id,
        materialId: l.materialId,
        itemCode: l.itemCode,
        brand: l.brand,
        itemName: l.itemName,
        unitCode: l.unitCode,
        size: l.size,
        qty: l.qty,
        rate: dec(0),
        amount: dec(0),
        sortOrder: idx,
      }));
    }

    const totalAmount = linesData.reduce((s, l) => s + Number(l.amount), 0);
    const quotationNo = str(body.quotationNo) || (await nextQuotationNo(pr.prNumber));

    const row = await prisma.erpPurchaseQuotation.create({
      data: {
        id: randomUUID(),
        purchaseRequestId,
        quotationNo,
        quotationDate: dateOnly(body.quotationDate) ?? new Date(),
        vendorId: str(body.vendorId),
        vendorName,
        address: str(body.address),
        gstNo: str(body.gstNo),
        panNo: str(body.panNo),
        remarks: str(body.remarks),
        status: ErpPurchaseQuotationStatus.DRAFT,
        totalAmount: dec(totalAmount),
        createdBy: opts.userId ?? null,
        lines: { create: linesData },
      },
      include: quoteInclude,
    });
    return serializeQuote(row);
  },

  async update(id: string, body: Record<string, unknown>) {
    const existing = await prisma.erpPurchaseQuotation.findUnique({ where: { id } });
    if (!existing) throw new Error('Quotation not found');
    if (
      existing.status === ErpPurchaseQuotationStatus.SELECTED ||
      existing.status === ErpPurchaseQuotationStatus.REJECTED
    ) {
      throw new Error('Cannot edit a selected or rejected quotation');
    }

    const linesData =
      Array.isArray(body.lines) && body.lines.length > 0 ? parseLines(body.lines) : null;
    const totalAmount = linesData
      ? linesData.reduce((s, l) => s + Number(l.amount), 0)
      : null;

    const row = await prisma.$transaction(async (tx) => {
      if (linesData) {
        await tx.erpPurchaseQuotationLine.deleteMany({ where: { quotationId: id } });
        await tx.erpPurchaseQuotationLine.createMany({
          data: linesData.map((l) => ({
            id: randomUUID(),
            quotationId: id,
            ...l,
          })),
        });
      }
      return tx.erpPurchaseQuotation.update({
        where: { id },
        data: {
          vendorId: body.vendorId !== undefined ? str(body.vendorId) : undefined,
          vendorName: body.vendorName !== undefined ? str(body.vendorName) ?? existing.vendorName : undefined,
          address: body.address !== undefined ? str(body.address) : undefined,
          gstNo: body.gstNo !== undefined ? str(body.gstNo) : undefined,
          panNo: body.panNo !== undefined ? str(body.panNo) : undefined,
          remarks: body.remarks !== undefined ? str(body.remarks) : undefined,
          quotationDate:
            body.quotationDate !== undefined
              ? dateOnly(body.quotationDate) ?? existing.quotationDate
              : undefined,
          ...(totalAmount != null ? { totalAmount: dec(totalAmount) } : {}),
        },
        include: quoteInclude,
      });
    });
    return serializeQuote(row);
  },

  async submit(id: string) {
    const existing = await prisma.erpPurchaseQuotation.findUnique({
      where: { id },
      include: { lines: true },
    });
    if (!existing) throw new Error('Quotation not found');
    if (existing.status !== ErpPurchaseQuotationStatus.DRAFT) {
      throw new Error('Only draft quotations can be submitted');
    }
    if (existing.lines.length === 0) throw new Error('Quotation has no lines');
    const missingRate = existing.lines.some((l) => Number(l.rate) <= 0);
    if (missingRate) throw new Error('All lines must have a rate > 0 before submit');

    const row = await prisma.erpPurchaseQuotation.update({
      where: { id },
      data: {
        status: ErpPurchaseQuotationStatus.SUBMITTED,
        submittedAt: new Date(),
      },
      include: quoteInclude,
    });
    return serializeQuote(row);
  },

  async remove(id: string) {
    const existing = await prisma.erpPurchaseQuotation.findUnique({ where: { id } });
    if (!existing) throw new Error('Quotation not found');
    if (existing.status === ErpPurchaseQuotationStatus.SELECTED) {
      throw new Error('Cannot delete the selected quotation');
    }
    await prisma.erpPurchaseQuotation.delete({ where: { id } });
    return { ok: true };
  },

  /**
   * CS approval: select winning quotation → create final OPEN PO with rates.
   * Actor must match settings.csApproverEmployeeId.
   */
  async selectAndCreatePo(quotationId: string, actorEmployeeId?: number) {
    const settings = await prisma.erpPurchaseSettings.findUnique({ where: { key: 'DEFAULT' } });
    if (!settings?.csApproverEmployeeId) {
      throw new Error('Comparison Sheet approver is not configured in Purchase settings');
    }
    if (!actorEmployeeId || actorEmployeeId !== settings.csApproverEmployeeId) {
      throw new Error('Only the configured CS approver can select a quotation');
    }

    const quote = await prisma.erpPurchaseQuotation.findUnique({
      where: { id: quotationId },
      include: {
        lines: { orderBy: { sortOrder: 'asc' } },
        purchaseRequest: true,
        purchaseOrder: true,
      },
    });
    if (!quote) throw new Error('Quotation not found');
    if (quote.purchaseOrder) throw new Error('A purchase order already exists for this quotation');
    if (quote.purchaseRequest.status !== ErpPurchaseRequestStatus.APPROVED) {
      throw new Error('Purchase request is not approved');
    }
    if (
      quote.status !== ErpPurchaseQuotationStatus.DRAFT &&
      quote.status !== ErpPurchaseQuotationStatus.SUBMITTED
    ) {
      throw new Error('Only draft or submitted quotations can be selected');
    }
    if (quote.lines.length === 0) throw new Error('Quotation has no lines');

    const alreadySelected = await prisma.erpPurchaseQuotation.findFirst({
      where: {
        purchaseRequestId: quote.purchaseRequestId,
        status: ErpPurchaseQuotationStatus.SELECTED,
      },
    });
    if (alreadySelected) {
      throw new Error('A quotation is already selected for this purchase request');
    }

    const poNumber = `PO-${quote.purchaseRequest.prNumber}-${Date.now().toString().slice(-4)}`;
    const totalAmount = Number(quote.totalAmount);

    const result = await prisma.$transaction(async (tx) => {
      await tx.erpPurchaseQuotation.update({
        where: { id: quotationId },
        data: {
          status: ErpPurchaseQuotationStatus.SELECTED,
          selectedAt: new Date(),
          selectedByEmployeeId: actorEmployeeId,
        },
      });
      await tx.erpPurchaseQuotation.updateMany({
        where: {
          purchaseRequestId: quote.purchaseRequestId,
          id: { not: quotationId },
          status: {
            in: [ErpPurchaseQuotationStatus.DRAFT, ErpPurchaseQuotationStatus.SUBMITTED],
          },
        },
        data: { status: ErpPurchaseQuotationStatus.REJECTED },
      });

      const po = await tx.erpPurchaseOrder.create({
        data: {
          id: randomUUID(),
          poNumber,
          vendorName: quote.vendorName,
          vendorId: quote.vendorId,
          projectId: quote.purchaseRequest.projectId,
          purchaseRequestId: quote.purchaseRequestId,
          quotationId: quote.id,
          orderDate: new Date(),
          status: 'OPEN',
          totalAmount: dec(totalAmount),
          remarks: `Created from quotation ${quote.quotationNo} (CS approved)`,
          createdBy: null,
          items: {
            create: quote.lines.map((l, idx) => ({
              id: randomUUID(),
              materialId: l.materialId,
              itemName: l.itemName,
              brand: l.brand,
              unitCode: l.unitCode,
              size: l.size,
              orderedQty: l.qty,
              rate: l.rate,
              amount: l.amount,
              sortOrder: idx,
            })),
          },
        },
        include: {
          items: { orderBy: { sortOrder: 'asc' } },
          vendor: { select: { id: true, name: true } },
        },
      });
      return po;
    });

    const selected = await this.getById(quotationId);
    return {
      quotation: selected,
      purchaseOrder: {
        ...result,
        totalAmount: result.totalAmount != null ? Number(result.totalAmount) : null,
        items: result.items.map((i) => ({
          ...i,
          orderedQty: Number(i.orderedQty),
          rate: i.rate != null ? Number(i.rate) : null,
          amount: i.amount != null ? Number(i.amount) : null,
        })),
      },
    };
  },
};
