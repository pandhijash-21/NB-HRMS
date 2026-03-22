import { prisma } from '../../config/prisma';
import { diffAndAudit } from './audit.helpers';
import type { Request } from 'express';

type OtherInfoInput = {
  skillSet?:       string | null;
  hobbies?:        string | null;
  strength?:       string | null;
  weakness?:       string | null;
  isHandicapped?:  boolean;
  handicapDetails?:string | null;
  heightInFeet?:   number | null;
  weightInKg?:     number | null;
};

export const otherService = {
  get(employeeId: number) {
    return prisma.employeeOtherInfo.findUnique({ where: { employeeId } });
  },

  async create(employeeId: number, input: OtherInfoInput, createdBy: string) {
    return prisma.employeeOtherInfo.create({
      data: {
        employeeId,
        skillSet:        input.skillSet        ?? null,
        hobbies:         input.hobbies         ?? null,
        strength:        input.strength        ?? null,
        weakness:        input.weakness        ?? null,
        isHandicapped:   input.isHandicapped   ?? false,
        handicapDetails: input.handicapDetails ?? null,
        heightInFeet:    input.heightInFeet    ?? null,
        weightInKg:      input.weightInKg      ?? null,
        updatedBy:       createdBy,
      },
    });
  },

  async update(employeeId: number, input: OtherInfoInput, updatedBy: string, req: Request) {
    const existing = await prisma.employeeOtherInfo.findUnique({ where: { employeeId } });
    if (!existing) throw { status: 404, message: 'Other info not found' };

    const updated = await prisma.employeeOtherInfo.update({
      where: { employeeId },
      data: { ...input, updatedBy },
    });

    diffAndAudit(req, {
      tableName:  'employee_other_info',
      recordId:   existing.id,
      employeeId,
      before:     existing as Record<string, unknown>,
      after:      updated  as Record<string, unknown>,
    });

    return updated;
  },
};
