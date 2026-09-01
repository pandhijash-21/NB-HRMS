import { prisma } from '../../config/prisma';

export type CollabProfile = {
  userId: string;
  employeeId: number | null;
  name: string;
  photoUrl: string | null;
  email: string | null;
  role: string;
  username: string | null;
  department: string | null;
};

function mapUser(u: {
  id: string;
  username: string | null;
  employeeId: number | null;
  role: { name: string };
  employee: {
    id: number;
    photoUrl: string | null;
    generalInfo: { fullName: string; department: string | null } | null;
    addresses: { personalEmail: string | null; instituteEmail: string | null }[];
  } | null;
}): CollabProfile {
  const local = u.employee?.addresses?.[0];
  const name =
    u.employee?.generalInfo?.fullName?.trim() ||
    u.username?.trim() ||
    `User ${u.employeeId ?? u.id.slice(0, 6)}`;
  const email = local?.instituteEmail?.trim() || local?.personalEmail?.trim() || null;
  return {
    userId: u.id,
    employeeId: u.employeeId ?? u.employee?.id ?? null,
    name,
    photoUrl: u.employee?.photoUrl ?? null,
    email,
    role: u.role.name,
    username: u.username,
    department: u.employee?.generalInfo?.department?.trim() || null,
  };
}

const userInclude = {
  role: { select: { name: true } },
  employee: {
    select: {
      id: true,
      photoUrl: true,
      generalInfo: { select: { fullName: true, department: true } },
      addresses: {
        where: { addressType: 'LOCAL' as const },
        take: 1,
        select: { personalEmail: true, instituteEmail: true },
      },
    },
  },
};

export async function getProfile(userId: string): Promise<CollabProfile | null> {
  const u = await prisma.user.findUnique({ where: { id: userId }, include: userInclude });
  return u ? mapUser(u) : null;
}

export async function getProfiles(userIds: string[]): Promise<Map<string, CollabProfile>> {
  const unique = [...new Set(userIds.filter(Boolean))];
  if (unique.length === 0) return new Map();
  const rows = await prisma.user.findMany({
    where: { id: { in: unique } },
    include: userInclude,
  });
  return new Map(rows.map((row) => [row.id, mapUser(row)]));
}

export async function searchDirectory(q: string, viewerUserId: string, limit = 20, skip = 0) {
  const term = q.trim();
  const rows = await prisma.user.findMany({
    where: {
      isActive: true,
      id: { not: viewerUserId },
      ...(term
        ? {
            OR: [
              { username: { contains: term, mode: 'insensitive' } },
              { employee: { generalInfo: { fullName: { contains: term, mode: 'insensitive' } } } },
              { employee: { generalInfo: { department: { contains: term, mode: 'insensitive' } } } },
              { employee: { addresses: { some: { personalEmail: { contains: term, mode: 'insensitive' } } } } },
              { employee: { addresses: { some: { instituteEmail: { contains: term, mode: 'insensitive' } } } } },
            ],
          }
        : {}),
    },
    skip: Math.max(0, skip),
    take: Math.min(Math.max(limit, 1), 200),
    orderBy: { employee: { generalInfo: { fullName: 'asc' } } },
    include: userInclude,
  });
  const people = rows.map(mapUser);
  if (skip > 0) return people;

  const me = await getProfile(viewerUserId);
  if (!me) return people;
  const t = term.toLowerCase();
  const hay = `${me.name} ${me.email ?? ''} ${me.username ?? ''}`.toLowerCase();
  const selfQuery =
    !t ||
    hay.includes(t) ||
    ['you', 'yourself', 'self', 'me', 'note to self'].some((k) => k.startsWith(t));
  if (!selfQuery) return people;
  return [me, ...people];
}
