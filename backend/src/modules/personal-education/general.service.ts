import { prisma } from '../../config/prisma';
import { diffAndAudit } from './audit.helpers';
import type { Request } from 'express';

type GeneralInfoInput = {
  fullName?: string;
  originalJoiningDate?: Date;
  joiningDate?: Date;
  incrementMonth?: string | null;
  organization?: string;
  subOrganization?: string | null;
  department?: string;
  functionalDepartment?: string | null;
  firstReportingId?: number | null;
  secondReportingId?: number | null;
  thirdReportingId?: number | null;
  firstApproverUserId?: string | null;
  secondApproverUserId?: string | null;
  thirdApproverUserId?: string | null;
  employeeCategory?: string;
  designation?: string;
  shift?: string | null;
  appointmentType?: string | null;
  employeeCode?: string | null;
  punchId?: string | null;
  instituteId?: string | null;
};

export const generalService = {
  get(employeeId: number) {
    return prisma.employeeGeneralInfo.findUnique({ where: { employeeId } });
  },

  async create(employeeId: number, input: GeneralInfoInput, createdBy: string) {
    return prisma.employeeGeneralInfo.create({
      data: {
        employeeId,
        fullName:             input.fullName!,
        originalJoiningDate:  input.originalJoiningDate!,
        joiningDate:          input.joiningDate!,
        incrementMonth:       input.incrementMonth ?? null,
        organization:         input.organization!,
        subOrganization:      input.subOrganization ?? null,
        department:           input.department!,
        functionalDepartment: input.functionalDepartment ?? null,
        firstReportingId:      input.firstReportingId      ?? null,
        secondReportingId:     input.secondReportingId     ?? null,
        thirdReportingId:      input.thirdReportingId      ?? null,
        firstApproverUserId:   input.firstApproverUserId   ?? null,
        secondApproverUserId:  input.secondApproverUserId  ?? null,
        thirdApproverUserId:   input.thirdApproverUserId   ?? null,
        employeeCategory:     input.employeeCategory!,
        designation:          input.designation!,
        shift:                input.shift ?? null,
        appointmentType:      input.appointmentType ?? null,
        employeeCode:         input.employeeCode ?? null,
        punchId:              input.punchId ?? null,
        instituteId:          input.instituteId ?? null,
        updatedBy:            createdBy,
      },
    });
  },

  async update(employeeId: number, input: GeneralInfoInput, updatedBy: string, req: Request) {
    const existing = await prisma.employeeGeneralInfo.findUnique({ where: { employeeId } });
    if (!existing) throw { status: 404, message: 'General info not found' };

    // Normalize empty punchId to null for unique constraint
    const data = {
      ...input,
      punchId:
        input.punchId !== undefined
          ? input.punchId && String(input.punchId).trim()
            ? String(input.punchId).trim()
            : null
          : undefined,
      updatedBy,
    };

    const updated = await prisma.employeeGeneralInfo.update({
      where: { employeeId },
      data,
    });

    diffAndAudit(req, {
      tableName:  'employee_general_info',
      recordId:   existing.id,
      employeeId,
      before:     existing as Record<string, unknown>,
      after:      updated  as Record<string, unknown>,
    });

    return updated;
  },
};
