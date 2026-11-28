import { Prisma, ErpPurchaseQuotationStatus, ErpPurchaseRequestStatus } from '@prisma/client';
import { randomUUID } from 'crypto';
import { prisma } from '../../config/prisma';
import { DEFAULT_PO_TERMS, parseTerms } from './purchase.export';

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

function round2(n: number) {
  return Math.round(n * 100) / 100;
}

function normalizeGstMode(v: unknown): 'INCLUSIVE' | 'EXCLUSIVE' {
  const s = String(v ?? 'INCLUSIVE').trim().toUpperCase();
  return s === 'EXCLUSIVE' ? 'EXCLUSIVE' : 'INCLUSIVE';
}

function normalizeFreightMode(v: unknown): 'INCLUSIVE' | 'EXCLUSIVE' {
  const s = String(v ?? 'INCLUSIVE').trim().toUpperCase();
  return s === 'EXCLUSIVE' ? 'EXCLUSIVE' : 'INCLUSIVE';
}

function normalizeGstTaxType(v: unknown, vendorStateCode?: string | null): 'CGST_SGST' | 'IGST' | null {
  const s = str(v)?.toUpperCase() ?? null;
  if (s === 'CGST_SGST' || s === 'IGST') return s;
  if (s === 'CGST' || s === 'SGST') return 'CGST_SGST';
  const state = (vendorStateCode ?? '').trim().toUpperCase();
  if (!state) return null;
  return state === 'GUJARAT' ? 'CGST_SGST' : 'IGST';
}

/** Compute GST/freight amounts and final total from line subtotal + commercial fields. */
function computeCommercialTotals(input: {
  subtotal: number;
  gstMode: 'INCLUSIVE' | 'EXCLUSIVE';
  gstTaxType: 'CGST_SGST' | 'IGST' | null;
  cgstRate: number | null;
  sgstRate: number | null;
  igstRate: number | null;
  freightMode: 'INCLUSIVE' | 'EXCLUSIVE';
  freightAmount: number;
}) {
  const subtotal = round2(input.subtotal);
  let cgstAmount = 0;
  let sgstAmount = 0;
  let igstAmount = 0;
  if (input.gstMode === 'EXCLUSIVE') {
    if (input.gstTaxType === 'CGST_SGST') {
      cgstAmount = round2((subtotal * (input.cgstRate ?? 0)) / 100);
      sgstAmount = round2((subtotal * (input.sgstRate ?? 0)) / 100);
    } else if (input.gstTaxType === 'IGST') {
      igstAmount = round2((subtotal * (input.igstRate ?? 0)) / 100);
    }
  }
  const freightAdd =
    input.freightMode === 'EXCLUSIVE' ? round2(Math.max(0, input.freightAmount)) : 0;
  const freightAmount =
    input.freightMode === 'EXCLUSIVE' ? freightAdd : round2(Math.max(0, input.freightAmount));
  const finalAmount = round2(subtotal + cgstAmount + sgstAmount + igstAmount + freightAdd);
  return { cgstAmount, sgstAmount, igstAmount, freightAmount, finalAmount, totalAmount: subtotal };
}

function parseCommercial(body: Record<string, unknown>, subtotal: number) {
  const vendorStateCode = str(body.vendorStateCode);
  const gstMode = normalizeGstMode(body.gstMode);
  let gstTaxType = normalizeGstTaxType(body.gstTaxType, vendorStateCode);
  if (gstMode === 'EXCLUSIVE' && !gstTaxType) {
    gstTaxType = vendorStateCode && vendorStateCode.toUpperCase() !== 'GUJARAT' ? 'IGST' : 'CGST_SGST';
  }
  if (gstMode === 'INCLUSIVE') gstTaxType = null;

  const cgstRate = gstMode === 'EXCLUSIVE' && gstTaxType === 'CGST_SGST' ? num(body.cgstRate) ?? 0 : num(body.cgstRate);
  const sgstRate = gstMode === 'EXCLUSIVE' && gstTaxType === 'CGST_SGST' ? num(body.sgstRate) ?? 0 : num(body.sgstRate);
  const igstRate = gstMode === 'EXCLUSIVE' && gstTaxType === 'IGST' ? num(body.igstRate) ?? 0 : num(body.igstRate);
  const freightMode = normalizeFreightMode(body.freightMode);
  const freightAmountIn = num(body.freightAmount) ?? 0;
  if (freightMode === 'EXCLUSIVE' && freightAmountIn < 0) {
    throw new Error('Freight amount cannot be negative');
  }
  const deliveryDaysRaw = num(body.deliveryDays);
  const deliveryDays =
    deliveryDaysRaw == null ? null : Math.max(0, Math.floor(deliveryDaysRaw));
  const ratingRaw = num(body.rating);
  const rating =
    ratingRaw == null ? null : Math.min(5, Math.max(0, round2(ratingRaw)));

  const totals = computeCommercialTotals({
    subtotal,
    gstMode,
    gstTaxType,
    cgstRate,
    sgstRate,
    igstRate,
    freightMode,
    freightAmount: freightAmountIn,
  });

  return {
    gstMode,
    gstTaxType,
    vendorStateCode,
    cgstRate: cgstRate == null ? null : dec(cgstRate),
    sgstRate: sgstRate == null ? null : dec(sgstRate),
    igstRate: igstRate == null ? null : dec(igstRate),
    cgstAmount: dec(totals.cgstAmount),
    sgstAmount: dec(totals.sgstAmount),
    igstAmount: dec(totals.igstAmount),
    freightMode,
    freightAmount: dec(totals.freightAmount),
    paymentTerms: str(body.paymentTerms),
    deliveryDays,
    rating: rating == null ? null : dec(rating),
    totalAmount: dec(totals.totalAmount),
    finalAmount: dec(totals.finalAmount),
  };
}

function serializeQuote(
  row: Prisma.ErpPurchaseQuotationGetPayload<{ include: typeof quoteInclude }>,
) {
  return {
    ...row,
    totalAmount: Number(row.totalAmount),
    finalAmount: Number(row.finalAmount),
    cgstRate: row.cgstRate != null ? Number(row.cgstRate) : null,
    sgstRate: row.sgstRate != null ? Number(row.sgstRate) : null,
    igstRate: row.igstRate != null ? Number(row.igstRate) : null,
    cgstAmount: Number(row.cgstAmount),
    sgstAmount: Number(row.sgstAmount),
    igstAmount: Number(row.igstAmount),
    freightAmount: Number(row.freightAmount),
    rating: row.rating != null ? Number(row.rating) : null,
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

    const subtotal = linesData.reduce((s, l) => s + Number(l.amount), 0);
    const commercial = parseCommercial(body, subtotal);
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
        vendorEmail: str(body.vendorEmail),
        submittedViaPortal: body.submittedViaPortal === true,
        status: ErpPurchaseQuotationStatus.DRAFT,
        ...commercial,
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
    const subtotal = linesData
      ? linesData.reduce((s, l) => s + Number(l.amount), 0)
      : Number(existing.totalAmount);

    const commercialBody: Record<string, unknown> = {
      gstMode: body.gstMode !== undefined ? body.gstMode : existing.gstMode,
      gstTaxType: body.gstTaxType !== undefined ? body.gstTaxType : existing.gstTaxType,
      vendorStateCode:
        body.vendorStateCode !== undefined ? body.vendorStateCode : existing.vendorStateCode,
      cgstRate: body.cgstRate !== undefined ? body.cgstRate : existing.cgstRate,
      sgstRate: body.sgstRate !== undefined ? body.sgstRate : existing.sgstRate,
      igstRate: body.igstRate !== undefined ? body.igstRate : existing.igstRate,
      freightMode: body.freightMode !== undefined ? body.freightMode : existing.freightMode,
      freightAmount:
        body.freightAmount !== undefined ? body.freightAmount : existing.freightAmount,
      paymentTerms: body.paymentTerms !== undefined ? body.paymentTerms : existing.paymentTerms,
      deliveryDays: body.deliveryDays !== undefined ? body.deliveryDays : existing.deliveryDays,
      rating: body.rating !== undefined ? body.rating : existing.rating,
    };
    const commercial = parseCommercial(commercialBody, subtotal);

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
          ...commercial,
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
    const totalAmount = Number(quote.finalAmount || quote.totalAmount);
    const terms = parseTerms(
      Array.isArray(settings.defaultPoTerms) && settings.defaultPoTerms.length > 0
        ? settings.defaultPoTerms
        : DEFAULT_PO_TERMS,
    );
    // Carry quotation GST into PO (IGST mapped to cgst when CGST/SGST not used)
    const quoteGstExclusive = quote.gstMode === 'EXCLUSIVE';
    const poCgst =
      quoteGstExclusive && quote.gstTaxType === 'CGST_SGST'
        ? Number(quote.cgstRate ?? 0)
        : quoteGstExclusive && quote.gstTaxType === 'IGST'
          ? Number(quote.igstRate ?? 0)
          : 0;
    const poSgst =
      quoteGstExclusive && quote.gstTaxType === 'CGST_SGST' ? Number(quote.sgstRate ?? 0) : 0;

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
          termsAndConditions: terms,
          cgstRate: poCgst,
          sgstRate: poSgst,
          remarks: [
            `Created from quotation ${quote.quotationNo} (CS approved)`,
            quote.paymentTerms ? `Payment: ${quote.paymentTerms}` : null,
            quote.deliveryDays != null ? `Delivery: ${quote.deliveryDays} day(s)` : null,
            quote.freightMode === 'EXCLUSIVE' && Number(quote.freightAmount) > 0
              ? `Freight (extra): ${Number(quote.freightAmount)}`
              : null,
          ]
            .filter(Boolean)
            .join(' · '),
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
