import {
  ApprovalAction,
  ApproverRole,
  Prisma,
  ReimbursementAmountMode,
  ReimbursementFieldKind,
  ReimbursementStatus,
  SalaryRecordStatus,
} from '@prisma/client';
import { prisma } from '../../config/prisma';
import { emitPushNotify } from '../collaboration/socket';
import { salaryService } from '../salary/salary.service';
import { findReimbursementEarningColumn } from '../salary/salary.types';

/** True when user role or employee designation is Admin (final authority). */
async function isAdminAuthority(userId: string): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      role: { select: { name: true } },
      employee: { select: { generalInfo: { select: { designation: true } } } },
    },
  });
  if (!user) return false;
  const role = String(user.role?.name ?? '').toUpperCase();
  if (['ADMIN', 'HR', 'HR_MANAGER', 'SUPERADMIN', 'SYSTEM_ADMIN'].includes(role)) {
    return true;
  }
  const designation = String(user.employee?.generalInfo?.designation ?? '')
    .trim()
    .toUpperCase();
  return designation === 'ADMIN';
}

function isPendingStep(s: { action: unknown; isSuperseded: boolean }) {
  return !s.isSuperseded && (s.action === null || typeof s.action === 'undefined');
}

async function nextClaimNo(): Promise<string> {
  const year = new Date().getFullYear();
  const prefix = `REIM-${year}-`;
  const latest = await prisma.reimbursementClaim.findFirst({
    where: { claimNo: { startsWith: prefix } },
    orderBy: { claimNo: 'desc' },
    select: { claimNo: true },
  });
  const seq = latest ? Number(latest.claimNo.slice(prefix.length)) + 1 : 1;
  return `${prefix}${String(seq).padStart(4, '0')}`;
}

const claimInclude = {
  employee: {
    include: {
      generalInfo: {
        select: {
          fullName: true,
          employeeCode: true,
          designation: true,
          department: true,
        },
      },
    },
  },
  type: { include: { fields: { orderBy: { sortOrder: 'asc' as const } } } },
  values: { include: { fieldDef: true } },
  approvalSteps: { orderBy: { stepNumber: 'asc' as const } },
};

const typeInclude = {
  fields: { orderBy: { sortOrder: 'asc' as const } },
  _count: { select: { claims: true } },
};

async function attachApproverNames<T extends { approverUserId: string | null }>(
  rows: T[],
): Promise<Array<T & { approverName: string | null }>> {
  const ids = [...new Set(rows.map((r) => r.approverUserId).filter(Boolean))] as string[];
  if (ids.length === 0) {
    return rows.map((r) => ({ ...r, approverName: null }));
  }
  const users = await prisma.user.findMany({
    where: { id: { in: ids } },
    select: {
      id: true,
      username: true,
      employee: { select: { generalInfo: { select: { fullName: true } } } },
    },
  });
  const nameById = new Map(
    users.map((u) => [
      u.id,
      u.employee?.generalInfo?.fullName?.trim() || u.username || u.id,
    ]),
  );
  return rows.map((r) => ({
    ...r,
    approverName: r.approverUserId ? nameById.get(r.approverUserId) ?? null : null,
  }));
}

/** Post approved amount onto the claim-date month (e.g. Aug claim → Aug salary). */
async function postAmountToClaimMonthSalary(params: {
  employeeId: number;
  amount: number;
  actorId: string;
  claimDate: Date;
}) {
  const salaryMonth = params.claimDate.getMonth() + 1;
  const salaryYear = params.claimDate.getFullYear();

  let record = await prisma.employeeSalaryRecord.findUnique({
    where: {
      employeeId_salaryMonth_salaryYear: {
        employeeId: params.employeeId,
        salaryMonth,
        salaryYear,
      },
    },
    include: { columnValues: true },
  });

  if (!record) {
    try {
      const created = await salaryService.createSalaryRecord(
        params.employeeId,
        salaryMonth,
        salaryYear,
        params.actorId,
      );
      record = await prisma.employeeSalaryRecord.findUnique({
        where: { id: created!.id },
        include: { columnValues: true },
      });
    } catch {
      // Salary structure may not be ready yet — still stamp claim month/year below.
      return { salaryRecordId: null as string | null, salaryMonth, salaryYear };
    }
  }

  if (!record) {
    return { salaryRecordId: null as string | null, salaryMonth, salaryYear };
  }

  // Already paid: keep claim linked to that month so recalculation / reopen can pick it up.
  if (record.status === SalaryRecordStatus.PAID) {
    return { salaryRecordId: record.id, salaryMonth, salaryYear, skippedPaid: true as const };
  }

  const overrides: Record<string, number> = {};
  for (const cv of record.columnValues) {
    if (cv.overrideValue != null) {
      overrides[cv.columnIdentifier] = Number(cv.overrideValue);
    }
  }

  const reimbursementCol = findReimbursementEarningColumn(
    record.columnValues.map((c) => ({
      columnIdentifier: c.columnIdentifier,
      category: String(c.category),
    })),
  );
  if (!reimbursementCol) {
    // Stamp month only — salary fold uses claimDate / salaryMonth on calculate.
    return { salaryRecordId: record.id, salaryMonth, salaryYear, missingCol: true as const };
  }
  const colId = reimbursementCol.columnIdentifier;
  const prev = overrides[colId] ?? 0;
  overrides[colId] = Number(prev) + Number(params.amount);

  await salaryService.updateSalaryRecord(record.id, overrides);

  return { salaryRecordId: record.id, salaryMonth, salaryYear };
}

/** Undo a posted reimbursement amount from an UNPAID salary record. */
async function reverseAmountFromClaimMonthSalary(params: {
  employeeId: number;
  amount: number;
  salaryRecordId?: string | null;
  salaryMonth?: number | null;
  salaryYear?: number | null;
  claimDate?: Date | null;
  actorId: string;
}) {
  void params.actorId;
  let record = params.salaryRecordId
    ? await prisma.employeeSalaryRecord.findUnique({
        where: { id: params.salaryRecordId },
        include: { columnValues: true },
      })
    : null;

  if (!record) {
    const month =
      params.salaryMonth ??
      (params.claimDate ? params.claimDate.getMonth() + 1 : null);
    const year =
      params.salaryYear ??
      (params.claimDate ? params.claimDate.getFullYear() : null);
    if (month == null || year == null) return;
    record = await prisma.employeeSalaryRecord.findUnique({
      where: {
        employeeId_salaryMonth_salaryYear: {
          employeeId: params.employeeId,
          salaryMonth: month,
          salaryYear: year,
        },
      },
      include: { columnValues: true },
    });
  }

  if (!record || record.status === SalaryRecordStatus.PAID) return;

  const overrides: Record<string, number> = {};
  for (const cv of record.columnValues) {
    if (cv.overrideValue != null) {
      overrides[cv.columnIdentifier] = Number(cv.overrideValue);
    }
  }

  const reimbursementCol = findReimbursementEarningColumn(
    record.columnValues.map((c) => ({
      columnIdentifier: c.columnIdentifier,
      category: String(c.category),
    })),
  );
  if (!reimbursementCol) return;

  const colId = reimbursementCol.columnIdentifier;
  const prev = overrides[colId] ?? 0;
  overrides[colId] = Math.max(0, Number(prev) - Number(params.amount));
  await salaryService.updateSalaryRecord(record.id, overrides);
}

async function notifyApprover(params: {
  approverUserId: string;
  claimNo: string;
  amount: number;
  employeeName: string;
  typeName: string;
}) {
  const title = 'Reimbursement approval';
  const body = `${params.employeeName} submitted ${params.typeName} (${params.claimNo}) · ₹${Number(params.amount).toFixed(2)}`;
  const path = '/reimbursements';
  try {
    await prisma.userNotification.create({
      data: {
        userId: params.approverUserId,
        title,
        body,
        kind: 'reimbursement',
        path,
      },
    });
  } catch {
    // non-fatal
  }
  emitPushNotify([params.approverUserId], {
    kind: 'reimbursement',
    title,
    body,
    path,
  });
}

function normalizeCode(input: string): string {
  return input
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '_')
    .replace(/^_|_$/g, '');
}

function normalizeFieldKey(input: string): string {
  return input
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '');
}

type ValueInput = {
  fieldKey: string;
  value?: string | number | null;
  proofUrl?: string | null;
};

function computeAmountFromType(params: {
  amountMode: ReimbursementAmountMode;
  ratePerUnit: Prisma.Decimal | number | null;
  fields: Array<{ key: string; fieldKind: ReimbursementFieldKind }>;
  values: ValueInput[];
  manualAmount?: number | null;
}): { amount: number; openingKm: number | null; closingKm: number | null } {
  const byKey = new Map(params.values.map((v) => [v.fieldKey, v]));
  let openingKm: number | null = null;
  let closingKm: number | null = null;

  for (const f of params.fields) {
    const raw = byKey.get(f.key);
    if (f.fieldKind === ReimbursementFieldKind.KM_OPENING && raw?.value != null && raw.value !== '') {
      openingKm = Number(raw.value);
    }
    if (f.fieldKind === ReimbursementFieldKind.KM_CLOSING && raw?.value != null && raw.value !== '') {
      closingKm = Number(raw.value);
    }
  }

  if (params.amountMode === ReimbursementAmountMode.KM_RATE) {
    if (openingKm == null || closingKm == null || !Number.isFinite(openingKm) || !Number.isFinite(closingKm)) {
      throw new Error('Opening km and closing km are required');
    }
    if (closingKm < openingKm) throw new Error('Closing km cannot be less than opening km');
    const rate = Number(params.ratePerUnit ?? 0);
    if (!Number.isFinite(rate) || rate <= 0) {
      throw new Error('Fuel rate per km is not configured. Ask Admin to set ₹/km on this type.');
    }
    const km = closingKm - openingKm;
    const amount = Math.round(km * rate * 100) / 100;
    if (amount <= 0) throw new Error('Calculated amount must be greater than 0');
    return { amount, openingKm, closingKm };
  }

  // MANUAL — prefer explicit amount, else AMOUNT field
  let amount = params.manualAmount != null ? Number(params.manualAmount) : NaN;
  if (!Number.isFinite(amount) || amount <= 0) {
    const amountField = params.fields.find((f) => f.fieldKind === ReimbursementFieldKind.AMOUNT);
    if (amountField) {
      const raw = byKey.get(amountField.key);
      amount = raw?.value != null && raw.value !== '' ? Number(raw.value) : NaN;
    }
  }
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error('Amount must be greater than 0');
  }
  return { amount, openingKm, closingKm };
}

export const reimbursementsService = {
  // ── Types / fields (admin config) ──────────────────────────────────────────

  async listTypes(opts?: { activeOnly?: boolean }) {
    const rows = await prisma.reimbursementType.findMany({
      where: opts?.activeOnly ? { isActive: true } : undefined,
      include: typeInclude,
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
    return attachApproverNames(rows);
  },

  async getType(id: string) {
    const row = await prisma.reimbursementType.findUnique({
      where: { id },
      include: typeInclude,
    });
    if (!row) throw new Error('Reimbursement type not found');
    const [enriched] = await attachApproverNames([row]);
    return enriched;
  },

  async createType(input: {
    code: string;
    name: string;
    description?: string | null;
    amountMode?: ReimbursementAmountMode;
    ratePerUnit?: number | null;
    approverUserId?: string | null;
    sortOrder?: number;
    fields?: Array<{
      key?: string;
      label: string;
      fieldKind: ReimbursementFieldKind;
      requiresProof?: boolean;
      isRequired?: boolean;
      sortOrder?: number;
    }>;
  }) {
    const code = normalizeCode(input.code || input.name);
    if (!code) throw new Error('Code is required');
    const name = input.name.trim();
    if (!name) throw new Error('Name is required');

    const existing = await prisma.reimbursementType.findUnique({ where: { code } });
    if (existing) throw new Error(`Type code "${code}" already exists`);

    const amountMode = input.amountMode ?? ReimbursementAmountMode.KM_RATE;
    const rate =
      amountMode === ReimbursementAmountMode.KM_RATE
        ? input.ratePerUnit != null
          ? input.ratePerUnit
          : 10
        : input.ratePerUnit ?? null;

    const approverUserId = input.approverUserId?.trim() || null;
    if (!approverUserId) {
      throw new Error('Select who approves this reimbursement type');
    }
    const approver = await prisma.user.findUnique({
      where: { id: approverUserId },
      select: { id: true, isActive: true },
    });
    if (!approver || !approver.isActive) {
      throw new Error('Approver user not found or inactive');
    }

    return prisma.reimbursementType.create({
      data: {
        code,
        name,
        description: input.description?.trim() || null,
        amountMode,
        ratePerUnit: rate,
        approverUserId,
        sortOrder: input.sortOrder ?? 0,
        fields: input.fields?.length
          ? {
              create: input.fields.map((f, i) => ({
                key: normalizeFieldKey(f.key || f.label) || `field_${i + 1}`,
                label: f.label.trim(),
                fieldKind: f.fieldKind,
                requiresProof: f.requiresProof ?? false,
                isRequired: f.isRequired ?? true,
                sortOrder: f.sortOrder ?? i + 1,
              })),
            }
          : undefined,
      },
      include: typeInclude,
    }).then(async (row) => {
      const [enriched] = await attachApproverNames([row]);
      return enriched;
    });
  },

  async updateType(
    id: string,
    input: {
      name?: string;
      description?: string | null;
      amountMode?: ReimbursementAmountMode;
      ratePerUnit?: number | null;
      approverUserId?: string | null;
      isActive?: boolean;
      sortOrder?: number;
    },
  ) {
    await this.getType(id);

    let approverUserId: string | null | undefined = undefined;
    if (input.approverUserId !== undefined) {
      const uid = input.approverUserId?.trim() || null;
      if (!uid) throw new Error('Select who approves this reimbursement type');
      const approver = await prisma.user.findUnique({
        where: { id: uid },
        select: { id: true, isActive: true },
      });
      if (!approver || !approver.isActive) {
        throw new Error('Approver user not found or inactive');
      }
      approverUserId = uid;
    }

    return prisma.reimbursementType.update({
      where: { id },
      data: {
        ...(input.name !== undefined ? { name: input.name.trim() } : {}),
        ...(input.description !== undefined
          ? { description: input.description?.trim() || null }
          : {}),
        ...(input.amountMode !== undefined ? { amountMode: input.amountMode } : {}),
        ...(input.ratePerUnit !== undefined ? { ratePerUnit: input.ratePerUnit } : {}),
        ...(approverUserId !== undefined ? { approverUserId } : {}),
        ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
        ...(input.sortOrder !== undefined ? { sortOrder: input.sortOrder } : {}),
      },
      include: typeInclude,
    }).then(async (row) => {
      const [enriched] = await attachApproverNames([row]);
      return enriched;
    });
  },

  async deleteType(id: string) {
    const t = await this.getType(id);
    if (t._count.claims > 0) {
      // Soft-deactivate instead of hard delete when claims exist
      return prisma.reimbursementType.update({
        where: { id },
        data: { isActive: false },
        include: typeInclude,
      });
    }
    await prisma.reimbursementType.delete({ where: { id } });
    return { deleted: true };
  },

  async addField(
    typeId: string,
    input: {
      key?: string;
      label: string;
      fieldKind: ReimbursementFieldKind;
      requiresProof?: boolean;
      isRequired?: boolean;
      sortOrder?: number;
    },
  ) {
    await this.getType(typeId);
    const label = input.label.trim();
    if (!label) throw new Error('Field label is required');
    const key = normalizeFieldKey(input.key || label);
    if (!key) throw new Error('Field key is required');

    const maxSort = await prisma.reimbursementFieldDef.aggregate({
      where: { typeId },
      _max: { sortOrder: true },
    });

    return prisma.reimbursementFieldDef.create({
      data: {
        typeId,
        key,
        label,
        fieldKind: input.fieldKind,
        requiresProof: input.requiresProof ?? false,
        isRequired: input.isRequired ?? true,
        sortOrder: input.sortOrder ?? (maxSort._max.sortOrder ?? 0) + 1,
      },
    });
  },

  async updateField(
    fieldId: string,
    input: {
      label?: string;
      fieldKind?: ReimbursementFieldKind;
      requiresProof?: boolean;
      isRequired?: boolean;
      sortOrder?: number;
    },
  ) {
    const existing = await prisma.reimbursementFieldDef.findUnique({ where: { id: fieldId } });
    if (!existing) throw new Error('Field not found');
    return prisma.reimbursementFieldDef.update({
      where: { id: fieldId },
      data: {
        ...(input.label !== undefined ? { label: input.label.trim() } : {}),
        ...(input.fieldKind !== undefined ? { fieldKind: input.fieldKind } : {}),
        ...(input.requiresProof !== undefined ? { requiresProof: input.requiresProof } : {}),
        ...(input.isRequired !== undefined ? { isRequired: input.isRequired } : {}),
        ...(input.sortOrder !== undefined ? { sortOrder: input.sortOrder } : {}),
      },
    });
  },

  async deleteField(fieldId: string) {
    const existing = await prisma.reimbursementFieldDef.findUnique({ where: { id: fieldId } });
    if (!existing) throw new Error('Field not found');
    await prisma.reimbursementFieldDef.delete({ where: { id: fieldId } });
    return { deleted: true };
  },

  /** Replace all fields for a type (used by admin builder save). */
  async replaceFields(
    typeId: string,
    fields: Array<{
      id?: string;
      key?: string;
      label: string;
      fieldKind: ReimbursementFieldKind;
      requiresProof?: boolean;
      isRequired?: boolean;
      sortOrder?: number;
    }>,
  ) {
    await this.getType(typeId);
    return prisma.$transaction(async (tx) => {
      await tx.reimbursementFieldDef.deleteMany({ where: { typeId } });
      if (fields.length) {
        await tx.reimbursementFieldDef.createMany({
          data: fields.map((f, i) => ({
            typeId,
            key: normalizeFieldKey(f.key || f.label) || `field_${i + 1}`,
            label: f.label.trim(),
            fieldKind: f.fieldKind,
            requiresProof: f.requiresProof ?? false,
            isRequired: f.isRequired ?? true,
            sortOrder: f.sortOrder ?? i + 1,
          })),
        });
      }
      return tx.reimbursementType.findUnique({
        where: { id: typeId },
        include: typeInclude,
      });
    });
  },

  // ── Apply / list / approve ─────────────────────────────────────────────────

  async apply(params: {
    employeeId: number;
    appliedBy: string;
    typeId: string;
    claimDate?: string | Date | null;
    title?: string | null;
    description?: string | null;
    values: ValueInput[];
    /** Manual amount when amountMode = MANUAL */
    amount?: number | null;
    /** When set by Admin/HR — claim is for this employee and auto-approved */
    onBehalf?: boolean;
  }) {
    const type = await prisma.reimbursementType.findUnique({
      where: { id: params.typeId },
      include: { fields: { orderBy: { sortOrder: 'asc' } } },
    });
    if (!type || !type.isActive) throw new Error('Reimbursement type not found or inactive');

    const values = params.values ?? [];
    const byKey = new Map(values.map((v) => [v.fieldKey, v]));

    for (const f of type.fields) {
      const v = byKey.get(f.key);
      const empty =
        v == null ||
        (v.value == null || v.value === '') &&
          f.fieldKind !== ReimbursementFieldKind.FILE;
      if (f.isRequired && f.fieldKind !== ReimbursementFieldKind.FILE && empty) {
        throw new Error(`${f.label} is required`);
      }
      if (f.requiresProof) {
        const proof = v?.proofUrl?.trim();
        if (!proof) throw new Error(`Proof is required for ${f.label}`);
      }
    }

    const { amount, openingKm, closingKm } = computeAmountFromType({
      amountMode: type.amountMode,
      ratePerUnit: type.ratePerUnit,
      fields: type.fields,
      values,
      manualAmount: params.amount,
    });

    const claimDate = params.claimDate
      ? new Date(params.claimDate)
      : new Date();
    if (Number.isNaN(claimDate.getTime())) throw new Error('Invalid claim date');

    const title =
      (params.title?.trim() || type.name).trim() ||
      type.name;
    const description =
      params.description?.trim() ||
      `${type.name} claim` +
        (openingKm != null && closingKm != null
          ? ` (${openingKm} → ${closingKm} km)`
          : '');

    const claimNo = await nextClaimNo();
    const onBehalf = Boolean(params.onBehalf);

    if (!onBehalf && !type.approverUserId) {
      throw new Error(
        'This reimbursement type has no approver configured. Ask Admin to set who approves it.',
      );
    }

    const claim = await prisma.$transaction(async (tx) => {
      const created = await tx.reimbursementClaim.create({
        data: {
          claimNo,
          employeeId: params.employeeId,
          typeId: type.id,
          title,
          description,
          amount,
          claimDate,
          openingKm,
          closingKm,
          openingKmPhotoUrl:
            values.find((v) => {
              const f = type.fields.find((x) => x.key === v.fieldKey);
              return f?.fieldKind === ReimbursementFieldKind.KM_OPENING;
            })?.proofUrl?.trim() || null,
          closingKmPhotoUrl:
            values.find((v) => {
              const f = type.fields.find((x) => x.key === v.fieldKey);
              return f?.fieldKind === ReimbursementFieldKind.KM_CLOSING;
            })?.proofUrl?.trim() || null,
          status: onBehalf ? ReimbursementStatus.APPROVED : ReimbursementStatus.PENDING,
          appliedBy: params.appliedBy,
          onBehalfBy: onBehalf ? params.appliedBy : null,
          approvalSteps: onBehalf
            ? undefined
            : {
                create: [
                  {
                    stepNumber: 1,
                    approverRole: ApproverRole.REGISTRAR,
                    approverUserId: type.approverUserId,
                  },
                ],
              },
          values: {
            create: type.fields
              .map((f) => {
                const v = byKey.get(f.key);
                if (!v) return null;
                const num =
                  v.value != null && v.value !== '' && !Number.isNaN(Number(v.value))
                    ? Number(v.value)
                    : null;
                const text =
                  f.fieldKind === ReimbursementFieldKind.TEXT ||
                  f.fieldKind === ReimbursementFieldKind.DATE ||
                  f.fieldKind === ReimbursementFieldKind.FILE
                    ? v.value != null
                      ? String(v.value)
                      : null
                    : v.value != null
                      ? String(v.value)
                      : null;
                return {
                  fieldDefId: f.id,
                  valueText: text,
                  valueNumber: (
                    [
                      ReimbursementFieldKind.NUMBER,
                      ReimbursementFieldKind.KM_OPENING,
                      ReimbursementFieldKind.KM_CLOSING,
                      ReimbursementFieldKind.AMOUNT,
                    ] as ReimbursementFieldKind[]
                  ).includes(f.fieldKind)
                    ? num
                    : null,
                  proofUrl: v.proofUrl?.trim() || null,
                };
              })
              .filter((x): x is NonNullable<typeof x> => x != null),
          },
        },
        include: claimInclude,
      });
      return created;
    });

    if (onBehalf) {
      try {
        const posted = await postAmountToClaimMonthSalary({
          employeeId: params.employeeId,
          amount,
          actorId: params.appliedBy,
          claimDate,
        });
        return prisma.reimbursementClaim.update({
          where: { id: claim.id },
          data: {
            salaryMonth: posted.salaryMonth,
            salaryYear: posted.salaryYear,
            salaryRecordId: posted.salaryRecordId,
          },
          include: claimInclude,
        });
      } catch (e: any) {
        // Still stamp claim month so August salary calc can pick it up later.
        await prisma.reimbursementClaim.update({
          where: { id: claim.id },
          data: {
            salaryMonth: claimDate.getMonth() + 1,
            salaryYear: claimDate.getFullYear(),
          },
        });
        throw new Error(
          `Claim auto-approved for ${claimDate.getMonth() + 1}/${claimDate.getFullYear()}, but salary post failed: ${e?.message ?? 'unknown error'}`,
        );
      }
    }

    if (!onBehalf && type.approverUserId) {
      const empName =
        claim.employee?.generalInfo?.fullName ?? `Employee #${params.employeeId}`;
      void notifyApprover({
        approverUserId: type.approverUserId,
        claimNo,
        amount,
        employeeName: empName,
        typeName: type.name,
      });
    }

    return claim;
  },

  async listMine(employeeId: number) {
    return prisma.reimbursementClaim.findMany({
      where: { employeeId },
      include: claimInclude,
      orderBy: { appliedAt: 'desc' },
    });
  },

  async listAll(opts?: { status?: ReimbursementStatus }) {
    return prisma.reimbursementClaim.findMany({
      where: opts?.status ? { status: opts.status } : undefined,
      include: claimInclude,
      orderBy: { appliedAt: 'desc' },
    });
  },

  async getById(id: string) {
    return prisma.reimbursementClaim.findUnique({
      where: { id },
      include: claimInclude,
    });
  },

  async getPendingForApprover(
    approverUserId: string,
    opts?: { privilegedAdmin?: boolean },
  ) {
    // Assigned approver always sees their queue; Admin/HR also see all pending.
    if (opts?.privilegedAdmin) {
      return prisma.reimbursementClaim.findMany({
        where: { status: ReimbursementStatus.PENDING },
        include: claimInclude,
        orderBy: { appliedAt: 'asc' },
      });
    }

    return prisma.reimbursementClaim.findMany({
      where: {
        status: ReimbursementStatus.PENDING,
        approvalSteps: {
          some: {
            approverUserId,
            isSuperseded: false,
            action: null,
          },
        },
      },
      include: claimInclude,
      orderBy: { appliedAt: 'asc' },
    });
  },

  async approveOrReject(params: {
    claimId: string;
    approverUserId: string;
    action: 'APPROVE' | 'REJECT';
    remarks?: string;
    allowAdminOverride?: boolean;
  }) {
    const { claimId, approverUserId, action, remarks, allowAdminOverride } = params;

    const result = await prisma.$transaction(async (tx) => {
      const claim = await tx.reimbursementClaim.findUnique({
        where: { id: claimId },
        include: { approvalSteps: true },
      });
      if (!claim) throw new Error('Claim not found');
      if (claim.status !== ReimbursementStatus.PENDING) {
        throw new Error('Claim is not pending');
      }
      if (claim.salaryRecordId) {
        throw new Error('Claim already posted to salary');
      }

      const steps = claim.approvalSteps;
      const pendingSteps = steps.filter((s) => isPendingStep(s));
      const myStep = pendingSteps.find((s) => s.approverUserId === approverUserId)
        ?? pendingSteps[0];

      const isAssigned =
        myStep != null &&
        (myStep.approverUserId == null || myStep.approverUserId === approverUserId);
      if (!allowAdminOverride && !isAssigned) {
        throw new Error('You are not the assigned approver for this claim');
      }
      if (!allowAdminOverride && myStep?.approverUserId && myStep.approverUserId !== approverUserId) {
        throw new Error('You are not the assigned approver for this claim');
      }

      if (myStep) {
        await tx.reimbursementApprovalStep.update({
          where: { id: myStep.id },
          data: {
            action:
              action === 'REJECT' ? ApprovalAction.REJECTED : ApprovalAction.APPROVED,
            remarks: remarks ?? null,
            actionAt: new Date(),
            approverUserId,
          },
        });
        await tx.reimbursementApprovalStep.updateMany({
          where: { claimId, id: { not: myStep.id }, action: null, isSuperseded: false },
          data: { isSuperseded: true },
        });
      } else if (!allowAdminOverride) {
        throw new Error('No pending approval step found');
      }

      if (action === 'REJECT') {
        await tx.reimbursementClaim.update({
          where: { id: claimId },
          data: { status: ReimbursementStatus.REJECTED },
        });
        return { status: 'REJECTED' as const, finalized: false };
      }

      await tx.reimbursementClaim.update({
        where: { id: claimId },
        data: { status: ReimbursementStatus.APPROVED },
      });

      return {
        status: 'APPROVED' as const,
        finalized: true,
        employeeId: claim.employeeId,
        amount: Number(claim.amount),
        claimDate: claim.claimDate,
      };
    });

    if (result.finalized && result.status === 'APPROVED') {
      const claimDate = result.claimDate ?? new Date();
      try {
        const posted = await postAmountToClaimMonthSalary({
          employeeId: result.employeeId!,
          amount: result.amount!,
          actorId: approverUserId,
          claimDate,
        });
        await prisma.reimbursementClaim.update({
          where: { id: claimId },
          data: {
            salaryMonth: posted.salaryMonth,
            salaryYear: posted.salaryYear,
            salaryRecordId: posted.salaryRecordId,
          },
        });
      } catch (e: any) {
        await prisma.reimbursementClaim.update({
          where: { id: claimId },
          data: {
            salaryMonth: claimDate.getMonth() + 1,
            salaryYear: claimDate.getFullYear(),
          },
        });
        throw new Error(
          `Claim approved for ${claimDate.getMonth() + 1}/${claimDate.getFullYear()}, but salary post failed: ${e?.message ?? 'unknown error'}`,
        );
      }
    }

    return this.getById(claimId);
  },

  async cancel(claimId: string, employeeId: number) {
    const claim = await prisma.reimbursementClaim.findUnique({ where: { id: claimId } });
    if (!claim) throw new Error('Claim not found');
    if (claim.employeeId !== employeeId) throw new Error('Not your claim');
    if (claim.status !== ReimbursementStatus.PENDING) {
      throw new Error('Only pending claims can be cancelled');
    }
    await prisma.reimbursementApprovalStep.updateMany({
      where: { claimId, action: null, isSuperseded: false },
      data: { isSuperseded: true },
    });
    return prisma.reimbursementClaim.update({
      where: { id: claimId },
      data: { status: ReimbursementStatus.CANCELLED },
      include: claimInclude,
    });
  },

  /** Admin/HR hard-delete. Reverses unpaid salary posting when present. */
  async adminDelete(claimId: string, actorId: string) {
    const claim = await prisma.reimbursementClaim.findUnique({ where: { id: claimId } });
    if (!claim) throw new Error('Claim not found');

    if (
      claim.status === ReimbursementStatus.APPROVED &&
      (claim.salaryRecordId || (claim.salaryMonth != null && claim.salaryYear != null))
    ) {
      await reverseAmountFromClaimMonthSalary({
        employeeId: claim.employeeId,
        amount: Number(claim.amount),
        salaryRecordId: claim.salaryRecordId,
        salaryMonth: claim.salaryMonth,
        salaryYear: claim.salaryYear,
        claimDate: claim.claimDate,
        actorId,
      });
    }

    await prisma.reimbursementClaim.delete({ where: { id: claimId } });
    return { deleted: true, claimNo: claim.claimNo };
  },
};
