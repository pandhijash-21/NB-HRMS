import { prisma } from '../../config/prisma';
import { resolveInstituteRef } from '../institute/institute.util';
import { assignmentService } from './assignment.service';

function toUtcDateOnly(d: Date | string) {
  const src = new Date(d);
  return new Date(Date.UTC(src.getUTCFullYear(), src.getUTCMonth(), src.getUTCDate()));
}

function ymd(d: Date) {
  return d.toISOString().slice(0, 10);
}

function addDays(d: Date, days: number) {
  const out = new Date(d);
  out.setUTCDate(out.getUTCDate() + days);
  return out;
}

async function requireCurrentAssignment(employeeId: number) {
  const current = await prisma.employeeAssignment.findFirst({
    where: { employeeId, effectiveTo: null },
    orderBy: { effectiveFrom: 'desc' },
  });
  if (current) return current;

  // If none exists, try backfill just for this employee from generalInfo.
  const gi = await prisma.employeeGeneralInfo.findUnique({ where: { employeeId } });
  if (!gi) throw new Error('Employee general info not found');

  return prisma.employeeAssignment.create({
    data: {
      employeeId,
      effectiveFrom: toUtcDateOnly(gi.joiningDate),
      effectiveTo: null,
      organization: gi.organization ?? null,
      subOrganization: gi.subOrganization ?? null,
      department: gi.department ?? null,
      designation: gi.designation,
      shift: gi.shift ?? null,
      appointmentType: gi.appointmentType ?? null,
      reason: 'Auto-backfill on change',
      changedBy: 'system',
    },
  });
}

async function validateNoOverlap(employeeId: number, effectiveFrom: Date, excludeAssignmentId?: string) {
  const conflict = await prisma.employeeAssignment.findFirst({
    where: {
      employeeId,
      ...(excludeAssignmentId ? { id: { not: excludeAssignmentId } } : {}),
      effectiveFrom: { lte: effectiveFrom },
      OR: [{ effectiveTo: null }, { effectiveTo: { gte: effectiveFrom } }],
    },
    select: { id: true, effectiveFrom: true, effectiveTo: true },
  });
  if (conflict) {
    throw new Error(
      `Effective date overlaps existing assignment (${ymd(conflict.effectiveFrom)} to ${conflict.effectiveTo ? ymd(conflict.effectiveTo) : 'present'})`
    );
  }
}

export const employmentChangeService = {
  async instituteTransfer(params: {
    employeeId: number;
    newSubOrganization?: string | null;
    instituteId?: string | null;
    effectiveFrom: Date | string;
    reason?: string | null;
    changedBy: string;
  }) {
    const effectiveFrom = toUtcDateOnly(params.effectiveFrom);
    const instituteRef = await resolveInstituteRef({
      instituteId: params.instituteId,
      subOrganization: params.newSubOrganization,
    });

    return prisma.$transaction(async (tx) => {
      // Ensure we have some baseline assignment history
      const current = await tx.employeeAssignment.findFirst({
        where: { employeeId: params.employeeId, effectiveTo: null },
        orderBy: { effectiveFrom: 'desc' },
      });
      const base = current ?? (await requireCurrentAssignment(params.employeeId));

      // Allow splitting the current/base assignment; prevent overlap with any OTHER range.
      await validateNoOverlap(params.employeeId, effectiveFrom, base.id);

      // Close current assignment the day before
      if (!base.effectiveTo) {
        const closeTo = addDays(effectiveFrom, -1);
        if (closeTo < base.effectiveFrom) {
          throw new Error('Effective date cannot be before current assignment start');
        }
        await tx.employeeAssignment.update({
          where: { id: base.id },
          data: { effectiveTo: closeTo },
        });
      }

      const next = await tx.employeeAssignment.create({
        data: {
          employeeId: params.employeeId,
          effectiveFrom,
          effectiveTo: null,
          organization: base.organization ?? null,
          instituteId: instituteRef.instituteId,
          subOrganization: instituteRef.subOrganization,
          department: base.department ?? null,
          designation: base.designation,
          shift: base.shift ?? null,
          appointmentType: base.appointmentType ?? null,
          reason: params.reason ?? 'Institute transfer',
          changedBy: params.changedBy,
        },
      });

      // Update current snapshot if effective now/past
      const today = toUtcDateOnly(new Date());
      if (effectiveFrom <= today) {
        await tx.employeeGeneralInfo.update({
          where: { employeeId: params.employeeId },
          data: {
            instituteId: instituteRef.instituteId,
            subOrganization: instituteRef.subOrganization,
          },
        });
      }

      return {
        createdAssignmentId: next.id,
        employeeId: params.employeeId,
      };
    });
  },

  async designationUpgrade(params: { employeeId: number; newDesignation: string; effectiveFrom: Date | string; reason?: string | null; changedBy: string }) {
    const effectiveFrom = toUtcDateOnly(params.effectiveFrom);

    return prisma.$transaction(async (tx) => {
      const current = await tx.employeeAssignment.findFirst({
        where: { employeeId: params.employeeId, effectiveTo: null },
        orderBy: { effectiveFrom: 'desc' },
      });
      const base = current ?? (await requireCurrentAssignment(params.employeeId));

      // Allow splitting the current/base assignment; prevent overlap with any OTHER range.
      await validateNoOverlap(params.employeeId, effectiveFrom, base.id);

      if (!base.effectiveTo) {
        const closeTo = addDays(effectiveFrom, -1);
        if (closeTo < base.effectiveFrom) {
          throw new Error('Effective date cannot be before current assignment start');
        }
        await tx.employeeAssignment.update({
          where: { id: base.id },
          data: { effectiveTo: closeTo },
        });
      }

      const designationRef = await tx.designation.findFirst({
        where: { name: params.newDesignation, isAlias: false },
      });

      const next = await tx.employeeAssignment.create({
        data: {
          employeeId: params.employeeId,
          effectiveFrom,
          effectiveTo: null,
          organization: base.organization ?? null,
          subOrganization: base.subOrganization ?? null,
          department: base.department ?? null,
          designation: params.newDesignation,
          designationId: designationRef?.id ?? null,
          shift: base.shift ?? null,
          appointmentType: base.appointmentType ?? null,
          reason: params.reason ?? 'Designation upgrade',
          changedBy: params.changedBy,
        },
      });

      const today = toUtcDateOnly(new Date());
      if (effectiveFrom <= today) {
        await tx.employeeGeneralInfo.update({
          where: { employeeId: params.employeeId },
          data: {
            designation: params.newDesignation,
            designationId: designationRef?.id ?? null,
          },
        });
      }

      return {
        createdAssignmentId: next.id,
        employeeId: params.employeeId,
      };
    });
  },

  async resolveAssignmentIdForLeave(params: { employeeId: number; fromDate: Date }) {
    const row = await assignmentService.resolveForDate(params.employeeId, params.fromDate);
    return row?.id ?? null;
  },
};

