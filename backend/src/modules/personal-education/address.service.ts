import type { Request } from 'express';
import type { AddressType } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { diffAndAudit } from './audit.helpers';

type AddressInput = {
  addressType: AddressType;
  flatBlockNo?: string | null;
  buildingSociety?: string | null;
  area?: string | null;
  city?: string | null;
  state?: string | null;
  country?: string | null;
  zipPostalCode?: string | null;
  phoneNo?: string | null;
  mobileNo?: string | null;
  intercomNo?: string | null;
  personalEmail?: string | null;
  instituteEmail?: string | null;
  url?: string | null;
  updatedBy?: string | null;
};

type AddressPatch = Partial<Omit<AddressInput, 'addressType'>> & { updatedBy?: string | null };

type AddressWriteResult = {
  created: boolean;
  address: Awaited<ReturnType<typeof prisma.employeeAddress.create>>;
  personalEmailChanged: boolean;
  instituteEmailChanged: boolean;
  requiresEmailReverification: boolean;
};

function normEmail(v: string | null | undefined): string | null {
  const t = v?.trim().toLowerCase();
  return t ? t : null;
}

export const addressService = {
  getByType(employeeId: number, addressType: AddressType) {
    return prisma.employeeAddress.findUnique({
      where: { employeeId_addressType: { employeeId, addressType } },
    });
  },

  async upsert(employeeId: number, input: AddressInput, req: Request): Promise<AddressWriteResult> {
    const existing = await prisma.employeeAddress.findUnique({
      where: { employeeId_addressType: { employeeId, addressType: input.addressType } },
    });

    if (!existing) {
      const created = await prisma.employeeAddress.create({
        data: {
          employeeId,
          addressType: input.addressType,
          flatBlockNo: input.flatBlockNo ?? null,
          buildingSociety: input.buildingSociety ?? null,
          area: input.area ?? null,
          city: input.city ?? null,
          state: input.state ?? null,
          country: input.country ?? null,
          zipPostalCode: input.zipPostalCode ?? null,
          phoneNo: input.phoneNo ?? null,
          mobileNo: input.mobileNo ?? null,
          intercomNo: input.intercomNo ?? null,
          personalEmail: input.personalEmail ?? null,
          instituteEmail: input.instituteEmail ?? null,
          url: input.url ?? null,
          updatedBy: input.updatedBy ?? req.user?.id ?? null,
        },
      });

      diffAndAudit(req, {
        tableName: 'employee_addresses',
        recordId: created.id,
        employeeId,
        before: {},
        after: { ...input, addressType: input.addressType },
      });

      const hasEmail =
        !!normEmail(created.personalEmail) || !!normEmail(created.instituteEmail);
      return {
        created: true,
        address: created,
        personalEmailChanged: !!normEmail(created.personalEmail),
        instituteEmailChanged: !!normEmail(created.instituteEmail),
        requiresEmailReverification:
          input.addressType === 'LOCAL' && hasEmail,
      };
    }

    const personalChanged =
      input.addressType === 'LOCAL' &&
      input.personalEmail !== undefined &&
      normEmail(input.personalEmail) !== normEmail(existing.personalEmail);
    const instituteChanged =
      input.addressType === 'LOCAL' &&
      input.instituteEmail !== undefined &&
      normEmail(input.instituteEmail) !== normEmail(existing.instituteEmail);

    const updated = await prisma.employeeAddress.update({
      where: { employeeId_addressType: { employeeId, addressType: input.addressType } },
      data: {
        flatBlockNo: input.flatBlockNo ?? undefined,
        buildingSociety: input.buildingSociety ?? undefined,
        area: input.area ?? undefined,
        city: input.city ?? undefined,
        state: input.state ?? undefined,
        country: input.country ?? undefined,
        zipPostalCode: input.zipPostalCode ?? undefined,
        phoneNo: input.phoneNo ?? undefined,
        mobileNo: input.mobileNo ?? undefined,
        intercomNo: input.intercomNo ?? undefined,
        personalEmail: input.personalEmail ?? undefined,
        instituteEmail: input.instituteEmail ?? undefined,
        url: input.url ?? undefined,
        updatedBy: input.updatedBy ?? req.user?.id ?? undefined,
        ...(personalChanged ? { personalEmailVerifiedAt: null } : {}),
        ...(instituteChanged ? { instituteEmailVerifiedAt: null } : {}),
      },
    });

    diffAndAudit(req, {
      tableName: 'employee_addresses',
      recordId: updated.id,
      employeeId,
      before: existing,
      after: { ...existing, ...input },
    });

    return {
      created: false,
      address: updated,
      personalEmailChanged: personalChanged,
      instituteEmailChanged: instituteChanged,
      requiresEmailReverification: personalChanged || instituteChanged,
    };
  },

  async updateByType(
    employeeId: number,
    addressType: AddressType,
    patch: AddressPatch,
    req: Request,
  ): Promise<AddressWriteResult | null> {
    const existing = await prisma.employeeAddress.findUnique({
      where: { employeeId_addressType: { employeeId, addressType } },
    });

    // General-tab email edits (and similar) may run before any address row exists.
    // Create a minimal LOCAL/PERMANENT row instead of 404.
    if (!existing) {
      return this.upsert(
        employeeId,
        {
          addressType,
          flatBlockNo: patch.flatBlockNo ?? null,
          buildingSociety: patch.buildingSociety ?? null,
          area: patch.area ?? null,
          city: patch.city ?? null,
          state: patch.state ?? null,
          country: patch.country ?? 'India',
          zipPostalCode: patch.zipPostalCode ?? null,
          phoneNo: patch.phoneNo ?? null,
          mobileNo: patch.mobileNo ?? null,
          intercomNo: patch.intercomNo ?? null,
          personalEmail: patch.personalEmail ?? null,
          instituteEmail: patch.instituteEmail ?? null,
          url: patch.url ?? null,
          updatedBy: patch.updatedBy ?? null,
        },
        req,
      );
    }

    const personalChanged =
      addressType === 'LOCAL' &&
      patch.personalEmail !== undefined &&
      normEmail(patch.personalEmail) !== normEmail(existing.personalEmail);
    const instituteChanged =
      addressType === 'LOCAL' &&
      patch.instituteEmail !== undefined &&
      normEmail(patch.instituteEmail) !== normEmail(existing.instituteEmail);

    const updated = await prisma.employeeAddress.update({
      where: { employeeId_addressType: { employeeId, addressType } },
      data: {
        flatBlockNo: patch.flatBlockNo ?? undefined,
        buildingSociety: patch.buildingSociety ?? undefined,
        area: patch.area ?? undefined,
        city: patch.city ?? undefined,
        state: patch.state ?? undefined,
        country: patch.country ?? undefined,
        zipPostalCode: patch.zipPostalCode ?? undefined,
        phoneNo: patch.phoneNo ?? undefined,
        mobileNo: patch.mobileNo ?? undefined,
        intercomNo: patch.intercomNo ?? undefined,
        personalEmail: patch.personalEmail ?? undefined,
        instituteEmail: patch.instituteEmail ?? undefined,
        url: patch.url ?? undefined,
        updatedBy: patch.updatedBy ?? req.user?.id ?? undefined,
        ...(personalChanged ? { personalEmailVerifiedAt: null } : {}),
        ...(instituteChanged ? { instituteEmailVerifiedAt: null } : {}),
      },
    });

    diffAndAudit(req, {
      tableName: 'employee_addresses',
      recordId: updated.id,
      employeeId,
      before: existing,
      after: { ...existing, ...patch },
    });

    return {
      created: false,
      address: updated,
      personalEmailChanged: personalChanged,
      instituteEmailChanged: instituteChanged,
      requiresEmailReverification: personalChanged || instituteChanged,
    };
  },
};

