import { prisma } from '../../config/prisma';
import { redis, connectRedis } from '../../config/redis';
import type {
  BankApplicationItem,
  BankQueryItem,
  DisbursementDetails,
  FinalBankDetails,
  FinserveDocumentItem,
  TentativeDateEntry,
} from './crm.types';

/** Keys that used to live on CrmLead.customFields for Capital loan data. */
export const LOAN_CUSTOM_FIELD_KEYS = [
  'loanType',
  'loanStage',
  'applicationDetails',
  'bankApplications',
  'bankQueries',
  'documents',
  'finalBank',
  'disbursementDetails',
  'forwardedForProcessing',
  'portalToken',
  'portalLink',
  'clientPortalSubmitted',
  'clientPortalStatus',
  'clientPortalSubmittedAt',
  'clientPortalConfirmed',
  'portalOtp',
  'portalOtpRateLimit',
] as const;

export const loanApplicationInclude = {
  bankApplications: { orderBy: { sortOrder: 'asc' as const } },
  bankQueries: { orderBy: { raisedAt: 'desc' as const } },
  documents: { orderBy: { uploadedAt: 'desc' as const } },
  tentativeDates: { orderBy: { setAt: 'desc' as const } },
} as const;

export type LoanApplicationWithChildren = Awaited<
  ReturnType<typeof ensureLoanApplication>
>;

function parseDate(value: unknown): Date | null {
  if (!value) return null;
  const d = value instanceof Date ? value : new Date(String(value));
  return Number.isNaN(d.getTime()) ? null : d;
}

function toIso(value: Date | string | null | undefined): string | undefined {
  if (!value) return undefined;
  if (value instanceof Date) return value.toISOString();
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? undefined : d.toISOString();
}

export async function ensureLoanApplication(leadId: string) {
  const existing = await prisma.crmLoanApplication.findUnique({
    where: { leadId },
    include: loanApplicationInclude,
  });
  if (existing) return existing;

  return prisma.crmLoanApplication.create({
    data: { leadId },
    include: loanApplicationInclude,
  });
}

export async function findLoanByPortalToken(token: string) {
  if (!token) return null;
  return prisma.crmLoanApplication.findUnique({
    where: { portalToken: token },
    include: {
      ...loanApplicationInclude,
      lead: true,
    },
  });
}

export function loanToCustomFieldsPatch(
  loan: {
    loanType: string | null;
    loanStage: string | null;
    applicationDetails: unknown;
    forwardedToId: number | null;
    forwardedToName: string | null;
    forwardedAt: Date | null;
    forwardedBy: string | null;
    forwardedRemarks: string | null;
    finalBankName: string | null;
    finalBankRoi: string | null;
    finalBankApplicationId: string | null;
    finalBankId: string | null;
    loanAgreementNumber: string | null;
    finalizedAt: Date | null;
    finalizedBy: string | null;
    currentTentativeDate: Date | null;
    isDisbursed: boolean;
    disbursedAt: Date | null;
    disbursedAmount: string | null;
    disbursementRemarks: string | null;
    flowClosed: boolean;
    portalToken: string | null;
    portalLink: string | null;
    clientPortalStatus: string;
    clientPortalSubmittedAt: Date | null;
    clientPortalConfirmed: boolean;
    bankApplications?: Array<{
      id: string;
      bankName: string;
      appliedAt: Date | null;
      status: string;
      rejectionRemarks: string | null;
      roi: string | null;
      approvedAmount: string | null;
      tenureMonths: string | null;
      isFinalSelected: boolean;
    }>;
    bankQueries?: Array<{
      id: string;
      stage: string | null;
      query: string;
      required: string;
      status: string;
      raisedAt: Date;
      raisedBy: string | null;
      resolvedAt: Date | null;
      resolvedBy: string | null;
      resolutionNotes: string | null;
    }>;
    documents?: Array<{
      id: string;
      docTypeId: string;
      docName: string;
      fileUrl: string;
      fileName: string;
      fileSize: number | null;
      uploadedAt: Date;
      uploadedBy: string | null;
      status: string;
    }>;
    tentativeDates?: Array<{
      date: Date;
      setAt: Date;
      setBy: string | null;
      status: string;
      delayReason: string | null;
    }>;
  },
): Record<string, any> {
  const applicationDetails =
    loan.applicationDetails && typeof loan.applicationDetails === 'object' && !Array.isArray(loan.applicationDetails)
      ? { ...(loan.applicationDetails as Record<string, any>) }
      : {};

  const bankApplications: BankApplicationItem[] = (loan.bankApplications || []).map((b) => ({
    id: b.id,
    bankName: b.bankName,
    appliedAt: toIso(b.appliedAt),
    status: (b.status as BankApplicationItem['status']) || 'PENDING',
    rejectionRemarks: b.rejectionRemarks || undefined,
    roi: b.roi || undefined,
    approvedAmount: b.approvedAmount || undefined,
    tenureMonths: b.tenureMonths || undefined,
    isFinalSelected: !!b.isFinalSelected,
  }));

  const bankQueries: BankQueryItem[] = (loan.bankQueries || []).map((q) => ({
    id: q.id,
    stage: q.stage || undefined,
    query: q.query,
    required: q.required,
    status: (q.status as BankQueryItem['status']) || 'OPEN',
    raisedAt: toIso(q.raisedAt) || new Date().toISOString(),
    raisedBy: q.raisedBy || undefined,
    resolvedAt: toIso(q.resolvedAt),
    resolvedBy: q.resolvedBy || undefined,
    resolutionNotes: q.resolutionNotes || undefined,
  }));

  const documents: FinserveDocumentItem[] = (loan.documents || []).map((d) => ({
    id: d.id,
    docTypeId: d.docTypeId,
    docName: d.docName,
    fileUrl: d.fileUrl,
    fileName: d.fileName,
    fileSize: d.fileSize ?? undefined,
    uploadedAt: toIso(d.uploadedAt) || new Date().toISOString(),
    uploadedBy: d.uploadedBy || undefined,
    status: (d.status as FinserveDocumentItem['status']) || 'PENDING',
  }));

  const tentativeDates: TentativeDateEntry[] = (loan.tentativeDates || []).map((t) => ({
    date: t.date.toISOString().slice(0, 10),
    setAt: toIso(t.setAt) || new Date().toISOString(),
    setBy: t.setBy || undefined,
    status: (t.status as TentativeDateEntry['status']) || 'PENDING',
    delayReason: t.delayReason || undefined,
  }));

  const disbursementDetails: DisbursementDetails = {
    tentativeDates,
    currentTentativeDate: loan.currentTentativeDate
      ? loan.currentTentativeDate.toISOString().slice(0, 10)
      : undefined,
    isDisbursed: !!loan.isDisbursed,
    disbursedAt: toIso(loan.disbursedAt),
    disbursedAmount: loan.disbursedAmount || undefined,
    remarks: loan.disbursementRemarks || undefined,
    flowClosed: !!loan.flowClosed,
  };

  const patch: Record<string, any> = {
    applicationDetails,
    bankApplications,
    bankQueries,
    documents,
    disbursementDetails,
    clientPortalStatus: loan.clientPortalStatus || 'DRAFT',
    clientPortalSubmitted: loan.clientPortalStatus === 'SUBMITTED' || !!loan.clientPortalConfirmed,
    clientPortalConfirmed: !!loan.clientPortalConfirmed,
  };

  if (loan.loanType) patch.loanType = loan.loanType;
  if (loan.loanStage) patch.loanStage = loan.loanStage;
  if (loan.portalToken) patch.portalToken = loan.portalToken;
  if (loan.portalLink) patch.portalLink = loan.portalLink;
  if (loan.clientPortalSubmittedAt) {
    patch.clientPortalSubmittedAt = toIso(loan.clientPortalSubmittedAt);
  }

  if (loan.forwardedToId || loan.forwardedToName || loan.forwardedAt) {
    patch.forwardedForProcessing = {
      forwardedToId: loan.forwardedToId,
      forwardedToName: loan.forwardedToName,
      forwardedAt: toIso(loan.forwardedAt),
      forwardedBy: loan.forwardedBy,
      remarks: loan.forwardedRemarks,
    };
  }

  if (loan.finalBankName) {
    const finalBank: FinalBankDetails = {
      bankId: loan.finalBankId || undefined,
      bankName: loan.finalBankName,
      roi: loan.finalBankRoi || undefined,
      applicationId: loan.finalBankApplicationId || undefined,
      loanAgreementNumber: loan.loanAgreementNumber || undefined,
      finalizedAt: toIso(loan.finalizedAt),
      finalizedBy: loan.finalizedBy || undefined,
    };
    patch.finalBank = finalBank;
  }

  return patch;
}

/** Merge loan tables into lead.customFields shape (Flutter-compatible). */
export function hydrateLoanIntoCustomFields<T extends { customFields?: unknown; id?: string }>(
  lead: T,
  loan: Parameters<typeof loanToCustomFieldsPatch>[0] | null | undefined,
): T {
  if (!loan) return lead;
  const base =
    lead.customFields && typeof lead.customFields === 'object' && !Array.isArray(lead.customFields)
      ? { ...(lead.customFields as Record<string, any>) }
      : {};
  for (const key of LOAN_CUSTOM_FIELD_KEYS) {
    delete base[key];
  }
  return {
    ...lead,
    customFields: {
      ...base,
      ...loanToCustomFieldsPatch(loan),
    },
  };
}

export function stripLoanKeysFromCustomFields(custom: Record<string, any>): Record<string, any> {
  const out = { ...custom };
  for (const key of LOAN_CUSTOM_FIELD_KEYS) {
    delete out[key];
  }
  return out;
}

export async function hydrateLeadsWithLoanApplications<T extends { id: string; customFields?: unknown }>(
  leads: T[],
): Promise<T[]> {
  if (!leads.length) return leads;
  const ids = leads.map((l) => l.id);
  const loans = await prisma.crmLoanApplication.findMany({
    where: { leadId: { in: ids } },
    include: loanApplicationInclude,
  });
  const byLead = new Map(loans.map((l) => [l.leadId, l]));
  return leads.map((lead) => hydrateLoanIntoCustomFields(lead, byLead.get(lead.id)));
}

const leadIncludeBasic = {
  assignedTo: {
    include: { generalInfo: { select: { fullName: true } } },
  },
  telecaller: {
    include: { generalInfo: { select: { fullName: true } } },
  },
} as const;

export async function getHydratedLeadById(leadId: string) {
  const lead = await prisma.crmLead.findUnique({
    where: { id: leadId },
    include: leadIncludeBasic,
  });
  if (!lead) return null;
  const loan = await prisma.crmLoanApplication.findUnique({
    where: { leadId },
    include: loanApplicationInclude,
  });
  return hydrateLoanIntoCustomFields(lead, loan);
}

/** Replace bank applications for a loan (full list sync from pipeline DTO). */
export async function syncBankApplications(
  loanApplicationId: string,
  items: BankApplicationItem[],
) {
  await prisma.crmLoanBankApplication.deleteMany({ where: { loanApplicationId } });
  if (!items.length) return;
  await prisma.crmLoanBankApplication.createMany({
    data: items.map((b, idx) => {
      const row: {
        id?: string;
        loanApplicationId: string;
        bankName: string;
        appliedAt: Date | null;
        status: string;
        rejectionRemarks: string | null;
        roi: string | null;
        approvedAmount: string | null;
        tenureMonths: string | null;
        isFinalSelected: boolean;
        sortOrder: number;
      } = {
        loanApplicationId,
        bankName: b.bankName,
        appliedAt: parseDate(b.appliedAt),
        status: b.status || 'PENDING',
        rejectionRemarks: b.rejectionRemarks || null,
        roi: b.roi || null,
        approvedAmount: b.approvedAmount || null,
        tenureMonths: b.tenureMonths || null,
        isFinalSelected: !!b.isFinalSelected,
        sortOrder: idx,
      };
      // Keep stable client ids when they look like UUIDs / prior DB ids
      if (b.id && !b.id.startsWith('temp_') && !b.id.startsWith('bank_')) {
        row.id = b.id;
      }
      return row;
    }),
  });
}

export async function syncTentativeDates(
  loanApplicationId: string,
  items: TentativeDateEntry[],
) {
  await prisma.crmLoanTentativeDate.deleteMany({ where: { loanApplicationId } });
  if (!items.length) return;
  const rows = items
    .map((t) => {
      const date = parseDate(t.date);
      if (!date) return null;
      return {
        loanApplicationId,
        date,
        setAt: parseDate(t.setAt) || new Date(),
        setBy: t.setBy || null,
        status: t.status || 'PENDING',
        delayReason: t.delayReason || null,
      };
    })
    .filter(Boolean) as Array<{
    loanApplicationId: string;
    date: Date;
    setAt: Date;
    setBy: string | null;
    status: string;
    delayReason: string | null;
  }>;
  if (rows.length) {
    await prisma.crmLoanTentativeDate.createMany({ data: rows });
  }
}

// ---------------------------------------------------------------------------
// Portal OTP in Redis
// ---------------------------------------------------------------------------

type PortalOtpRateLimit = {
  attempts: number;
  firstAttemptAt: number;
  lastSentAt: number;
  lockoutUntil: number;
};

type PortalOtpPayload = {
  code: string;
  expiresAt: number;
  mobile: string;
};

function otpKey(token: string) {
  return `finserve_portal_otp:${token}`;
}
function otpRateKey(token: string) {
  return `finserve_portal_otp_rl:${token}`;
}

export async function getPortalOtpRateLimit(token: string): Promise<PortalOtpRateLimit> {
  await connectRedis();
  const raw = await redis.get(otpRateKey(token));
  if (!raw) return { attempts: 0, firstAttemptAt: 0, lastSentAt: 0, lockoutUntil: 0 };
  try {
    return JSON.parse(raw) as PortalOtpRateLimit;
  } catch {
    return { attempts: 0, firstAttemptAt: 0, lastSentAt: 0, lockoutUntil: 0 };
  }
}

export async function setPortalOtpRateLimit(token: string, rate: PortalOtpRateLimit) {
  await connectRedis();
  await redis.setEx(otpRateKey(token), 60 * 60 * 2, JSON.stringify(rate));
}

export async function setPortalOtp(token: string, payload: PortalOtpPayload) {
  await connectRedis();
  await redis.setEx(otpKey(token), 10 * 60, JSON.stringify(payload));
}

export async function getPortalOtp(token: string): Promise<PortalOtpPayload | null> {
  await connectRedis();
  const raw = await redis.get(otpKey(token));
  if (!raw) return null;
  try {
    return JSON.parse(raw) as PortalOtpPayload;
  } catch {
    return null;
  }
}

export async function clearPortalOtp(token: string) {
  await connectRedis();
  await redis.del(otpKey(token));
}

/**
 * One-time: copy loan keys from lead.customFields into CrmLoan* tables, then strip keys.
 * Safe when Capital has no data yet.
 */
export async function migrateLoanDataFromCustomFields(options?: { limit?: number }) {
  const limit = options?.limit ?? 5000;
  const leads = await prisma.crmLead.findMany({
    where: { scope: 'NB_FINSERVE', isDeleted: false },
    take: limit,
    select: { id: true, customFields: true },
  });

  let migrated = 0;
  for (const lead of leads) {
    const custom =
      lead.customFields && typeof lead.customFields === 'object' && !Array.isArray(lead.customFields)
        ? { ...(lead.customFields as Record<string, any>) }
        : {};

    const hasLoanData = LOAN_CUSTOM_FIELD_KEYS.some((k) => custom[k] != null);
    if (!hasLoanData) continue;

    const loan = await ensureLoanApplication(lead.id);
    const appDetails = {
      ...((loan.applicationDetails as Record<string, any>) || {}),
      ...(custom.applicationDetails && typeof custom.applicationDetails === 'object'
        ? custom.applicationDetails
        : {}),
    };

    const finalBank = custom.finalBank || {};
    const disb = custom.disbursementDetails || {};
    const forwarded = custom.forwardedForProcessing || {};

    await prisma.crmLoanApplication.update({
      where: { id: loan.id },
      data: {
        loanType: custom.loanType || custom.Loan_Type || loan.loanType,
        loanStage: custom.loanStage || loan.loanStage,
        applicationDetails: appDetails,
        forwardedToId: forwarded.forwardedToId != null ? Number(forwarded.forwardedToId) : loan.forwardedToId,
        forwardedToName: forwarded.forwardedToName || loan.forwardedToName,
        forwardedAt: parseDate(forwarded.forwardedAt) || loan.forwardedAt,
        forwardedBy: forwarded.forwardedBy || loan.forwardedBy,
        forwardedRemarks: forwarded.remarks || loan.forwardedRemarks,
        finalBankName: finalBank.bankName || loan.finalBankName,
        finalBankRoi: finalBank.roi || loan.finalBankRoi,
        finalBankApplicationId: finalBank.applicationId || loan.finalBankApplicationId,
        finalBankId: finalBank.bankId || loan.finalBankId,
        loanAgreementNumber: finalBank.loanAgreementNumber || loan.loanAgreementNumber,
        finalizedAt: parseDate(finalBank.finalizedAt) || loan.finalizedAt,
        finalizedBy: finalBank.finalizedBy || loan.finalizedBy,
        currentTentativeDate: parseDate(disb.currentTentativeDate) || loan.currentTentativeDate,
        isDisbursed: disb.isDisbursed != null ? !!disb.isDisbursed : loan.isDisbursed,
        disbursedAt: parseDate(disb.disbursedAt) || loan.disbursedAt,
        disbursedAmount: disb.disbursedAmount || loan.disbursedAmount,
        disbursementRemarks: disb.remarks || loan.disbursementRemarks,
        flowClosed: disb.flowClosed != null ? !!disb.flowClosed : loan.flowClosed,
        portalToken: custom.portalToken || loan.portalToken,
        portalLink: custom.portalLink || loan.portalLink,
        clientPortalStatus: custom.clientPortalStatus || (custom.clientPortalSubmitted ? 'SUBMITTED' : loan.clientPortalStatus),
        clientPortalSubmittedAt:
          parseDate(custom.clientPortalSubmittedAt) || loan.clientPortalSubmittedAt,
        clientPortalConfirmed:
          custom.clientPortalConfirmed != null ? !!custom.clientPortalConfirmed : loan.clientPortalConfirmed,
      },
    });

    if (Array.isArray(custom.bankApplications) && custom.bankApplications.length) {
      await syncBankApplications(loan.id, custom.bankApplications);
    }

    if (Array.isArray(custom.bankQueries) && custom.bankQueries.length) {
      const existing = await prisma.crmLoanBankQuery.count({ where: { loanApplicationId: loan.id } });
      if (existing === 0) {
        await prisma.crmLoanBankQuery.createMany({
          data: custom.bankQueries.map((q: BankQueryItem) => ({
            id: q.id,
            loanApplicationId: loan.id,
            stage: q.stage || 'General',
            query: q.query,
            required: q.required,
            status: q.status || 'OPEN',
            raisedAt: parseDate(q.raisedAt) || new Date(),
            raisedBy: q.raisedBy || null,
            resolvedAt: parseDate(q.resolvedAt),
            resolvedBy: q.resolvedBy || null,
            resolutionNotes: q.resolutionNotes || null,
          })),
          skipDuplicates: true,
        });
      }
    }

    if (Array.isArray(custom.documents) && custom.documents.length) {
      const existing = await prisma.crmLoanDocument.count({ where: { loanApplicationId: loan.id } });
      if (existing === 0) {
        await prisma.crmLoanDocument.createMany({
          data: custom.documents.map((d: FinserveDocumentItem) => ({
            id: d.id,
            loanApplicationId: loan.id,
            docTypeId: d.docTypeId,
            docName: d.docName,
            fileUrl: d.fileUrl,
            fileName: d.fileName,
            fileSize: d.fileSize ?? null,
            uploadedAt: parseDate(d.uploadedAt) || new Date(),
            uploadedBy: d.uploadedBy || null,
            status: d.status || 'PENDING',
            source: String(d.uploadedBy || '').toUpperCase() === 'CLIENT' ? 'portal' : 'agent',
          })),
          skipDuplicates: true,
        });
      }
    }

    if (Array.isArray(disb.tentativeDates) && disb.tentativeDates.length) {
      await syncTentativeDates(loan.id, disb.tentativeDates);
    }

    await prisma.crmLead.update({
      where: { id: lead.id },
      data: { customFields: stripLoanKeysFromCustomFields(custom) },
    });
    migrated += 1;
  }

  return { scanned: leads.length, migrated };
}
