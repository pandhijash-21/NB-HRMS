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

    return res.json(ok(rows));
  },
};

