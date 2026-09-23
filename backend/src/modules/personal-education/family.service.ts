import type { Request } from 'express';
import { prisma } from '../../config/prisma';
import { notificationsService } from '../notifications/notifications.service';
import { diffAndAudit, pushAudit } from './audit.helpers';

type FamilyCreateInput = {
  id?: string;
  relation: string;
  name: string;
  city?: string | null;
  mobileNo?: string | null;
  personalEmail?: string | null;
  dateOfBirth?: Date | null;
  isNominee?: boolean;
  isDependent?: boolean;
  isEmergencyContact?: boolean;
  isEmployed?: boolean;
  employerName?: string | null;
  updatedBy?: string | null;
};

type FamilyUpdateInput = Partial<FamilyCreateInput>;

function notifyFamilyChange(employeeId: number, actorUserId: string | undefined, summary: string) {
  void notificationsService
    .notifyProfileChange({ employeeId, actorUserId, summary })
    .catch(() => {});
}

export const familyService = {
  async list(employeeId: number) {
    return prisma.familyMember.findMany({
      where: { employeeId, isActive: true },
      orderBy: { createdAt: 'asc' },
    });
  },

  async hasEmergencyContact(employeeId: number): Promise<boolean> {
    const count = await prisma.familyMember.count({
      where: { employeeId, isActive: true, isEmergencyContact: true },
    });
    return count > 0;
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
        isNominee: input.isNominee ?? false,
        isDependent: input.isDependent ?? false,
        isEmergencyContact: input.isEmergencyContact ?? false,
        isEmployed: input.isEmployed ?? false,
        employerName: input.employerName ?? null,
        updatedBy: input.updatedBy ?? req.user?.id ?? null,
      },
    });

    pushAudit(req, {
      tableName: 'family_members',
      recordId: created.id,
      employeeId,
      fieldName: 'record',
      oldValue: null,
      newValue: created.isEmergencyContact
        ? `added ${created.name} (emergency)`
        : `added ${created.name}`,
    });

    notifyFamilyChange(
      employeeId,
      req.user?.id,
      `added family member ${created.name}${created.isEmergencyContact ? ' (emergency contact)' : ''}`,
    );

    return created;
  },

  async update(employeeId: number, memberId: string, input: FamilyUpdateInput, req: Request) {
    const existing = await prisma.familyMember.findFirst({
      where: { id: memberId, employeeId, isActive: true },
    });
    if (!existing) return null;

    const changedKeys = Object.keys(input).filter((k) => (input as any)[k] !== undefined);

    const updated = await prisma.familyMember.update({
      where: { id: memberId },
      data: {
        relation: input.relation ?? undefined,
        name: input.name ?? undefined,
        city: input.city ?? undefined,
        mobileNo: input.mobileNo ?? undefined,
        personalEmail: input.personalEmail ?? undefined,
        dateOfBirth: input.dateOfBirth ?? undefined,
        isNominee: input.isNominee ?? undefined,
        isDependent: input.isDependent ?? undefined,
        isEmergencyContact: input.isEmergencyContact ?? undefined,
        isEmployed: input.isEmployed ?? undefined,
        employerName: input.employerName ?? undefined,
        updatedBy: input.updatedBy ?? req.user?.id ?? undefined,
      },
    });

    diffAndAudit(req, {
      tableName: 'family_members',
      recordId: updated.id,
      employeeId,
      before: existing as unknown as Record<string, unknown>,
      after: { ...existing, ...input } as Record<string, unknown>,
      changedKeys,
    });

    notifyFamilyChange(employeeId, req.user?.id, `updated family member ${updated.name}`);

    return updated;
  },

  async softDelete(employeeId: number, memberId: string, req: Request) {
    const existing = await prisma.familyMember.findFirst({
      where: { id: memberId, employeeId, isActive: true },
    });
    if (!existing) return null;

    if (existing.isEmergencyContact) {
      const otherEmergency = await prisma.familyMember.count({
        where: {
          employeeId,
          isActive: true,
          isEmergencyContact: true,
          id: { not: memberId },
        },
      });
      if (otherEmergency === 0) {
        throw Object.assign(
          new Error('At least one emergency contact is required. Mark another contact as emergency before removing this one.'),
          { status: 400 },
        );
      }
    }

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

    notifyFamilyChange(employeeId, req.user?.id, `removed family member ${existing.name}`);

    return updated;
  },
};
