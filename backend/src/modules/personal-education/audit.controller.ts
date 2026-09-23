import type { Request, Response } from 'express';
import { ok, fail } from '../../utils/response';
import { prisma } from '../../config/prisma';

export const auditController = {
  async list(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));

    const rows = await prisma.auditLog.findMany({
      where: { employeeId },
      orderBy: { changedAt: 'desc' },
      take: 500,
    });

    const changerIds = [...new Set(rows.map((r) => r.changedBy).filter(Boolean))];
    const users = changerIds.length
      ? await prisma.user.findMany({
          where: { id: { in: changerIds } },
          select: {
            id: true,
            username: true,
            employee: { select: { generalInfo: { select: { fullName: true } } } },
          },
        })
      : [];
    const nameById = new Map(
      users.map((u) => [
        u.id,
        u.employee?.generalInfo?.fullName?.trim() || u.username || u.id,
      ]),
    );

    return res.json(
      ok(
        rows.map((r) => ({
          ...r,
          changedByName: nameById.get(r.changedBy) ?? r.changedBy,
        })),
      ),
    );
  },
};
