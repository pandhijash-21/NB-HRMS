import { prisma } from '../../config/prisma';

export type PositionSummary = {
  id: string;
  name: string;
  linkedRoleId: string;
  linkedRoleName: string;
};

/** Active position types (alias designations linked to a role). */
export async function listActivePositions(): Promise<PositionSummary[]> {
  const rows = await prisma.designation.findMany({
    where: { isAlias: true, isActive: true, linkedRoleId: { not: null } },
    include: { linkedRole: { select: { id: true, name: true } } },
    orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
  });

  return rows
    .filter((r) => r.linkedRoleId && r.linkedRole)
    .map((r) => ({
      id: r.id,
      name: r.name,
      linkedRoleId: r.linkedRoleId!,
      linkedRoleName: r.linkedRole!.name,
    }));
}

export async function loadPositionMapByRoleId(): Promise<Map<string, PositionSummary>> {
  const positions = await listActivePositions();
  return new Map(positions.map((p) => [p.linkedRoleId, p]));
}

export async function resolveRoleIdForPosition(positionDesignationId: string | null | undefined): Promise<string> {
  if (!positionDesignationId) {
    const employeeRole = await prisma.role.findUnique({ where: { name: 'EMPLOYEE' } });
    if (!employeeRole) throw new Error('EMPLOYEE role not found. Please seed the database.');
    return employeeRole.id;
  }

  const position = await prisma.designation.findUnique({ where: { id: positionDesignationId } });
  if (!position?.isAlias || !position.linkedRoleId) {
    throw new Error('Invalid position selected');
  }
  return position.linkedRoleId;
}
