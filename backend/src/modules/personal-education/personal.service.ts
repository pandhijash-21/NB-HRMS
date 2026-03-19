import type { Request } from 'express';
import type { BloodGroup, Gender, MaritalStatus } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { decrypt, encrypt } from '../../utils/crypto';
import { diffAndAudit, pushAudit } from './audit.helpers';

type PersonalCreateInput = {
  birthDate: Date;
  birthPlace?: string | null;
  homeTown?: string | null;
  gender: Gender;
  maritalStatus: MaritalStatus;
  nationality?: string;
  motherTongue?: string | null;
  bloodGroup?: BloodGroup | null;
  castCategory?: string | null;
  subCaste?: string | null;
  nomineeName?: string | null;
  nomineeRelation?: string | null;
  aadhaarNo?: string | null;
  panNo?: string | null;
  aadhaarCardUrl?: string | null;
  panCardUrl?: string | null;
  passportNo?: string | null;
  passportIssuePlace?: string | null;
  passportIssueDate?: Date | null;
  passportExpiryDate?: Date | null;
  updatedBy?: string | null;
};

type PersonalUpdateInput = Partial<PersonalCreateInput>;

export const personalService = {
  async get(employeeId: number) {
    const row = await prisma.employeePersonalInfo.findUnique({
      where: { employeeId },
    });
    if (!row) return null;

    // Decrypt for REST response (still only for authorized callers)
    return {
      ...row,
      aadhaarNo: row.aadhaarNo ? decrypt(row.aadhaarNo) : null,
      panNo: row.panNo ? decrypt(row.panNo) : null,
    };
  },

  async create(employeeId: number, input: PersonalCreateInput, req: Request) {
    const created = await prisma.employeePersonalInfo.create({
      data: {
        employeeId,
        birthDate: input.birthDate,
        birthPlace: input.birthPlace ?? null,
        homeTown: input.homeTown ?? null,
        gender: input.gender,
        maritalStatus: input.maritalStatus,
        nationality: input.nationality ?? 'INDIAN',
        motherTongue: input.motherTongue ?? null,
        bloodGroup: input.bloodGroup ?? null,
        castCategory: input.castCategory ?? null,
        subCaste: input.subCaste ?? null,
        nomineeName: input.nomineeName ?? null,
        nomineeRelation: input.nomineeRelation ?? null,
        aadhaarNo: input.aadhaarNo ? encrypt(input.aadhaarNo) : null,
        panNo: input.panNo ? encrypt(input.panNo) : null,
        aadhaarCardUrl: input.aadhaarCardUrl ?? null,
        panCardUrl: input.panCardUrl ?? null,
        passportNo: input.passportNo ?? null,
        passportIssuePlace: input.passportIssuePlace ?? null,
        passportIssueDate: input.passportIssueDate ?? null,
        passportExpiryDate: input.passportExpiryDate ?? null,
        updatedBy: input.updatedBy ?? req.user?.id ?? null,
      },
    });

    // Audit all fields on create as "newValue" only
    for (const [k, v] of Object.entries(input)) {
      if (v === undefined) continue;
      pushAudit(req, {
        tableName: 'employee_personal_info',
        recordId: created.id,
        employeeId,
        fieldName: k,
        oldValue: null,
        newValue: v == null ? null : String(v),
        sensitive: k === 'aadhaarNo' || k === 'panNo',
      });
    }

    return {
      ...created,
      aadhaarNo: input.aadhaarNo ?? null,
      panNo: input.panNo ?? null,
    };
  },

  async update(employeeId: number, input: PersonalUpdateInput, req: Request) {
    const existing = await prisma.employeePersonalInfo.findUnique({ where: { employeeId } });
    if (!existing) return null;

    const before = {
      ...existing,
      aadhaarNo: existing.aadhaarNo ? decrypt(existing.aadhaarNo) : null,
      panNo: existing.panNo ? decrypt(existing.panNo) : null,
    };

    const updated = await prisma.employeePersonalInfo.update({
      where: { employeeId },
      data: {
        birthDate: input.birthDate ?? undefined,
        birthPlace: input.birthPlace ?? undefined,
        homeTown: input.homeTown ?? undefined,
        gender: input.gender ?? undefined,
        maritalStatus: input.maritalStatus ?? undefined,
        nationality: input.nationality ?? undefined,
        motherTongue: input.motherTongue ?? undefined,
        bloodGroup: input.bloodGroup ?? undefined,
        castCategory: input.castCategory ?? undefined,
        subCaste: input.subCaste ?? undefined,
        nomineeName: input.nomineeName ?? undefined,
        nomineeRelation: input.nomineeRelation ?? undefined,
        aadhaarNo: input.aadhaarNo !== undefined ? (input.aadhaarNo ? encrypt(input.aadhaarNo) : null) : undefined,
        panNo: input.panNo !== undefined ? (input.panNo ? encrypt(input.panNo) : null) : undefined,
        aadhaarCardUrl: input.aadhaarCardUrl ?? undefined,
        panCardUrl: input.panCardUrl ?? undefined,
        passportNo: input.passportNo ?? undefined,
        passportIssuePlace: input.passportIssuePlace ?? undefined,
        passportIssueDate: input.passportIssueDate ?? undefined,
        passportExpiryDate: input.passportExpiryDate ?? undefined,
        updatedBy: input.updatedBy ?? req.user?.id ?? undefined,
      },
    });

    const after = {
      ...before,
      ...input,
    };

    diffAndAudit(req, {
      tableName: 'employee_personal_info',
      recordId: updated.id,
      employeeId,
      before,
      after,
      sensitiveFields: new Set(['aadhaarNo', 'panNo']),
    });

    return {
      ...updated,
      aadhaarNo: input.aadhaarNo !== undefined ? input.aadhaarNo : before.aadhaarNo,
      panNo: input.panNo !== undefined ? input.panNo : before.panNo,
    };
  },
};

