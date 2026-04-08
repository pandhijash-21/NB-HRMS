import type { Request } from 'express';
import type { FamilyRelation } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { decrypt, encrypt } from '../../utils/crypto';
import { diffAndAudit, pushAudit } from './audit.helpers';

type FamilyCreateInput = {
  id?: string;
  relation: FamilyRelation;
  name: string;
  city?: string | null;
  mobileNo?: string | null;
  personalEmail?: string | null;
  dateOfBirth?: Date | null;
  aadhaarNo?: string | null;
  aadhaarUrl?: string | null;
  isNominee?: boolean;
  updatedBy?: string | null;
};

type FamilyUpdateInput = Partial<FamilyCreateInput>;

export const familyService = {
  async list(employeeId: number) {
    const rows = await prisma.familyMember.findMany({
      where: { employeeId, isActive: true },
      orderBy: { createdAt: 'asc' },
    });

    return rows.map((r) => ({
      ...r,
      aadhaarNo: r.aadhaarNo ? decrypt(r.aadhaarNo) : null,
      aadhaarUrl: r.aadhaarUrl ?? null,
    }));
  },

  async create(employeeId: number, input: FamilyCreateInput, req: Request) {
    const created = await prisma.familyMember.create({
      data: {
        ...(input.id ? { id: input.id } : {}),
        employeeId,
        relation: input.relation,
        name: input.name,
        city: input.city ?? null,
        mobileNo: input.mobileNo ?? null,
        personalEmail: input.personalEmail ?? null,
        dateOfBirth: input.dateOfBirth ?? null,
        aadhaarNo: input.aadhaarNo ? encrypt(input.aadhaarNo) : null,
        aadhaarUrl: input.aadhaarUrl ?? null,
        isNominee: input.isNominee ?? false,
        updatedBy: input.updatedBy ?? req.user?.id ?? null,
      },
    });

    for (const [k, v] of Object.entries(input)) {
      if (v === undefined) continue;
      pushAudit(req, {
        tableName: 'family_members',
        recordId: created.id,
        employeeId,
        fieldName: k,
        oldValue: null,
        newValue: v == null ? null : String(v),
        sensitive: k === 'aadhaarNo',
      });
    }

    return { ...created, aadhaarNo: input.aadhaarNo ?? null, aadhaarUrl: input.aadhaarUrl ?? null };
  },

  async update(employeeId: number, memberId: string, input: FamilyUpdateInput, req: Request) {
    const existing = await prisma.familyMember.findFirst({
      where: { id: memberId, employeeId, isActive: true },
    });
    if (!existing) return null;

    const before = {
      ...existing,
      aadhaarNo: existing.aadhaarNo ? decrypt(existing.aadhaarNo) : null,
    };

    const updated = await prisma.familyMember.update({
      where: { id: memberId },
      data: {
        relation: input.relation ?? undefined,
        name: input.name ?? undefined,
        city: input.city ?? undefined,
        mobileNo: input.mobileNo ?? undefined,
        personalEmail: input.personalEmail ?? undefined,
        dateOfBirth: input.dateOfBirth ?? undefined,
        aadhaarNo: input.aadhaarNo !== undefined ? (input.aadhaarNo ? encrypt(input.aadhaarNo) : null) : undefined,
        aadhaarUrl: input.aadhaarUrl !== undefined ? input.aadhaarUrl : undefined,
        isNominee: input.isNominee ?? undefined,
        updatedBy: input.updatedBy ?? req.user?.id ?? undefined,
      },
    });

    diffAndAudit(req, {
      tableName: 'family_members',
      recordId: updated.id,
      employeeId,
      before,
      after: { ...before, ...input },
      sensitiveFields: new Set(['aadhaarNo']),
    });

    return {
      ...updated,
      aadhaarNo: input.aadhaarNo !== undefined ? input.aadhaarNo : before.aadhaarNo,
    };
  },

  async softDelete(employeeId: number, memberId: string, req: Request) {
    const existing = await prisma.familyMember.findFirst({
      where: { id: memberId, employeeId, isActive: true },
    });
    if (!existing) return null;

    const updated = await prisma.familyMember.update({
      where: { id: memberId },
      data: { isActive: false, updatedBy: req.user?.id ?? undefined },
    });

    diffAndAudit(req, {
      tableName: 'family_members',
      recordId: updated.id,
      employeeId,
      before: existing,
      after: { ...existing, isActive: false },
    });

    return updated;
  },
};

