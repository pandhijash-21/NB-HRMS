import { prisma } from '../../config/prisma';

function toUtcDateOnly(d: Date | string) {
  const src = new Date(d);
  return new Date(Date.UTC(src.getUTCFullYear(), src.getUTCMonth(), src.getUTCDate()));
}

export type AssignmentSnapshot = {
  id: string;
  employeeId: number;
  effectiveFrom: string;
  effectiveTo: string | null;
  organization: string | null;
  subOrganization: string | null;
  department: string | null;
  designation: string;
  shift: string | null;
  appointmentType: string | null;
  reason: string | null;
  changedBy: string;
  createdAt: string;
};

export const assignmentService = {
  async list(employeeId: number): Promise<AssignmentSnapshot[]> {
    const rows = await prisma.employeeAssignment.findMany({
      where: { employeeId },
      orderBy: { effectiveFrom: 'asc' },
    });
    return rows.map((r) => ({
      id: r.id,
      employeeId: r.employeeId,
      effectiveFrom: r.effectiveFrom.toISOString().slice(0, 10),
      effectiveTo: r.effectiveTo ? r.effectiveTo.toISOString().slice(0, 10) : null,
      organization: r.organization ?? null,
      subOrganization: r.subOrganization ?? null,
      department: r.department ?? null,
      designation: r.designation,
      shift: r.shift ?? null,
      appointmentType: r.appointmentType ? String(r.appointmentType) : null,
      reason: r.reason ?? null,
      changedBy: r.changedBy,
      createdAt: r.createdAt.toISOString(),
    }));
  },

  async resolveForDate(employeeId: number, date: Date | string) {
    const d = toUtcDateOnly(date);
    return prisma.employeeAssignment.findFirst({
      where: {
        employeeId,
        effectiveFrom: { lte: d },
        OR: [{ effectiveTo: null }, { effectiveTo: { gte: d } }],
      },
      orderBy: { effectiveFrom: 'desc' },
    });
  },

  async backfillAll(changedBy: string) {
    const employees = await prisma.employee.findMany({
      select: {
        id: true,
        generalInfo: {
          select: {
            joiningDate: true,
            organization: true,
            subOrganization: true,
            department: true,
            designation: true,
            shift: true,
            appointmentType: true,
          },
        },
      },
    });

    let created = 0;
    let skipped = 0;

    for (const e of employees) {
      if (!e.generalInfo?.joiningDate || !e.generalInfo?.designation) {
        skipped += 1;
        continue;
      }
      const existing = await prisma.employeeAssignment.findFirst({
        where: { employeeId: e.id },
        select: { id: true },
      });
      if (existing) {
        skipped += 1;
        continue;
      }
      await prisma.employeeAssignment.create({
        data: {
          employeeId: e.id,
          effectiveFrom: toUtcDateOnly(e.generalInfo.joiningDate),
          effectiveTo: null,
          organization: e.generalInfo.organization ?? null,
          subOrganization: e.generalInfo.subOrganization ?? null,
          department: e.generalInfo.department ?? null,
          designation: e.generalInfo.designation,
          shift: e.generalInfo.shift ?? null,
          appointmentType: e.generalInfo.appointmentType ?? null,
          reason: 'Backfill from current general info',
          changedBy,
        },
      });
      created += 1;
    }

    return { created, skipped, total: employees.length };
  },
};

