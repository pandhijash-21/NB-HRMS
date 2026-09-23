import type { Request } from 'express';
import { prisma } from '../../config/prisma';
import { decrypt } from '../../utils/crypto';
import { notificationsService } from '../notifications/notifications.service';
import { diffAndAudit, pushAudit } from './audit.helpers';

type PersonalCreateInput = {
  birthDate: Date;
  birthPlace?: string | null;
  homeTown?: string | null;
  gender: string;
  maritalStatus: string;
  nationality?: string;
  motherTongue?: string | null;
  bloodGroup?: string | null;
  castCategory?: string | null;
  subCaste?: string | null;
  nomineeName?: string | null;
  nomineeRelation?: string | null;
  aadhaarNo?: string | null;
  panNo?: string | null;
  aadhaarCardUrl?: string | null;
  panCardUrl?: string | null;
  otherDocumentUrl?: string | null;
  passportNo?: string | null;
  passportIssuePlace?: string | null;
  passportIssueDate?: Date | null;
  passportExpiryDate?: Date | null;
  updatedBy?: string | null;
};

type PersonalUpdateInput = Partial<PersonalCreateInput>;

/** Return plaintext; decrypt legacy AES values if still stored encrypted. */
function plainIdNumber(value: string | null | undefined): string | null {
  if (value == null || value === '') return null;
  if (/^[0-9a-f]+:[0-9a-f]+$/i.test(value)) {
    try {
      return decrypt(value);
    } catch {
      return value;
    }
  }
  return value;
}

export const personalService = {
  async get(employeeId: number) {
    const row = await prisma.employeePersonalInfo.findUnique({
      where: { employeeId },
    });
    if (!row) return null;

    return {
      ...row,
      aadhaarNo: plainIdNumber(row.aadhaarNo),
      panNo: plainIdNumber(row.panNo),
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
        aadhaarNo: input.aadhaarNo ?? null,
        panNo: input.panNo ?? null,
        aadhaarCardUrl: input.aadhaarCardUrl ?? null,
        panCardUrl: input.panCardUrl ?? null,
        otherDocumentUrl: input.otherDocumentUrl ?? null,
        passportNo: input.passportNo ?? null,
        passportIssuePlace: input.passportIssuePlace ?? null,
        passportIssueDate: input.passportIssueDate ?? null,
        passportExpiryDate: input.passportExpiryDate ?? null,
        updatedBy: input.updatedBy ?? req.user?.id ?? null,
      },
    });

    // First create: one audit line only (not every column on the form).
    pushAudit(req, {
      tableName: 'employee_personal_info',
      recordId: created.id,
      employeeId,
      fieldName: 'record',
      oldValue: null,
      newValue: 'created',
      changeReason: 'Personal info created',
    });

    void notificationsService
      .notifyProfileChange({
        employeeId,
        actorUserId: req.user?.id,
        summary: 'created personal information',
      })
      .catch(() => {});

    return {
      ...created,
      aadhaarNo: input.aadhaarNo ?? null,
      panNo: input.panNo ?? null,
    };
  },

  async update(employeeId: number, input: PersonalUpdateInput, req: Request) {
    const existing = await prisma.employeePersonalInfo.findUnique({ where: { employeeId } });

    // First-time save: create row instead of 404 (common for incomplete profiles).
    if (!existing) {
      if (!input.birthDate || !input.gender || !input.maritalStatus) {
        throw Object.assign(
          new Error('Date of birth, gender and marital status are required to create personal info'),
          { status: 400 },
        );
      }
      return this.create(
        employeeId,
        {
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
          aadhaarNo: input.aadhaarNo ?? null,
          panNo: input.panNo ?? null,
          aadhaarCardUrl: input.aadhaarCardUrl ?? null,
          panCardUrl: input.panCardUrl ?? null,
          otherDocumentUrl: input.otherDocumentUrl ?? null,
          passportNo: input.passportNo ?? null,
          passportIssuePlace: input.passportIssuePlace ?? null,
          passportIssueDate: input.passportIssueDate ?? null,
          passportExpiryDate: input.passportExpiryDate ?? null,
          updatedBy: input.updatedBy ?? req.user?.id ?? null,
        },
        req,
      );
    }

    const before = {
      ...existing,
      aadhaarNo: plainIdNumber(existing.aadhaarNo),
      panNo: plainIdNumber(existing.panNo),
    };

    const changedKeys = Object.keys(input).filter((k) => (input as any)[k] !== undefined);

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
        aadhaarNo: input.aadhaarNo !== undefined ? input.aadhaarNo : undefined,
        panNo: input.panNo !== undefined ? input.panNo : undefined,
        aadhaarCardUrl: input.aadhaarCardUrl ?? undefined,
        panCardUrl: input.panCardUrl ?? undefined,
        otherDocumentUrl: input.otherDocumentUrl ?? undefined,
        passportNo: input.passportNo ?? undefined,
        passportIssuePlace: input.passportIssuePlace ?? undefined,
        passportIssueDate: input.passportIssueDate ?? undefined,
        passportExpiryDate: input.passportExpiryDate ?? undefined,
        updatedBy: input.updatedBy ?? req.user?.id ?? undefined,
      },
    });

    diffAndAudit(req, {
      tableName: 'employee_personal_info',
      recordId: updated.id,
      employeeId,
      before,
      after: { ...before, ...input },
      changedKeys,
    });

    const changedOnly = changedKeys.filter((k) => k !== 'updatedBy');
    if (changedOnly.length) {
      void notificationsService
        .notifyProfileChange({
          employeeId,
          actorUserId: req.user?.id,
          summary:
            changedOnly.length === 1
              ? `updated ${changedOnly[0]}`
              : `updated ${changedOnly.length} personal fields`,
        })
        .catch(() => {});
    }

    return {
      ...updated,
      aadhaarNo: input.aadhaarNo !== undefined ? input.aadhaarNo : before.aadhaarNo,
      panNo: input.panNo !== undefined ? input.panNo : before.panNo,
    };
  },
};
