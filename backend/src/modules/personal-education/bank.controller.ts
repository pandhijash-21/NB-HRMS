import type { Request, Response } from 'express';
import { z } from 'zod';
import { ok, fail } from '../../utils/response';
import { bankService } from './bank.service';
import { assertMayDirectWriteProfile } from './profileWriteGuard';

const BankInfoSchema = z.object({
  bankName:       z.string().optional().nullable(),
  bankAccountNo:  z.string().optional().nullable(),
  bankBranchCode: z.string().optional().nullable(),
  ifscCode:       z.string().optional().nullable(),
});

function assertSelfAccess(req: Request, employeeId: number) {
  const role = req.user?.roleName ?? req.user?.role;
  if (role === 'EMPLOYEE' && req.user?.employeeId !== employeeId) {
    throw { status: 403, message: 'Forbidden' };
  }
}

export const bankController = {
  async get(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    try {
      assertSelfAccess(req, employeeId);
      const data = await bankService.get(employeeId);
      return res.json(ok(data));
    } catch (err: any) {
      return res.status(err.status ?? 500).json(fail(err.message ?? 'Internal server error'));
    }
  },

  async upsert(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));

    const body = BankInfoSchema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));

    try {
      assertSelfAccess(req, employeeId);
      await assertMayDirectWriteProfile(req, employeeId, 'BANK');
      const updated = await bankService.upsert(employeeId, body.data, req.user!.id, req);
      return res.json(ok(updated));
    } catch (err: any) {
      return res.status(err.status ?? 500).json(fail(err.message ?? 'Internal server error'));
    }
  },
};
