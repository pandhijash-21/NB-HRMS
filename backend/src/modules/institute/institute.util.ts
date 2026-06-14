import { prisma } from '../../config/prisma';
import type { Institute } from '@prisma/client';

/** Resolve institute from id and/or legacy subOrganization string (code or full name). */
export async function resolveInstituteRef(input: {
  instituteId?: string | null;
  subOrganization?: string | null;
}): Promise<{ instituteId: string | null; subOrganization: string | null; institute: Institute | null }> {
  if (input.instituteId) {
    const institute = await prisma.institute.findUnique({ where: { id: input.instituteId } });
    if (!institute) throw new Error('Institute not found');
    return { instituteId: institute.id, subOrganization: institute.code, institute };
  }

  const raw = input.subOrganization?.trim();
  if (!raw) {
    return { instituteId: null, subOrganization: null, institute: null };
  }

  const institute = await prisma.institute.findFirst({
    where: {
      OR: [
        { code: { equals: raw, mode: 'insensitive' } },
        { name: { equals: raw, mode: 'insensitive' } },
      ],
    },
  });

  if (institute) {
    return { instituteId: institute.id, subOrganization: institute.code, institute };
  }

  return { instituteId: null, subOrganization: raw, institute: null };
}

/** Prisma filters for employees / aliases belonging to an institute. */
export function instituteMemberFilters(institute: Institute) {
  const legacyValues = [institute.code, institute.name];

  return {
    employeeWhere: {
      status: { not: 'TERMINATED' as const },
      OR: [
        { generalInfo: { instituteId: institute.id } },
        { generalInfo: { subOrganization: { in: legacyValues, mode: 'insensitive' as const } } },
      ],
    },
    aliasWhere: {
      isActive: true,
      OR: [
        { instituteId: institute.id },
        { subOrganization: { in: legacyValues, mode: 'insensitive' as const } },
        { code: { endsWith: `-${institute.code}`, mode: 'insensitive' as const } },
      ],
    },
  };
}
