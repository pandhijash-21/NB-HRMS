import { prisma } from '../../config/prisma';
import { diffAndAudit } from './audit.helpers';
import type { Request } from 'express';

type BankInfoInput = {
  bankName?:       string | null;
  bankAccountNo?:  string | null;
  bankBranchCode?: string | null;
  ifscCode?:       string | null;
};

export const bankService = {
  get(employeeId: number) {
    return prisma.employeeBankInfo.findUnique({ where: { employeeId } });
  },

  async upsert(employeeId: number, input: BankInfoInput, updatedBy: string, req: Request) {
    const existing = await prisma.employeeBankInfo.findUnique({ where: { employeeId } });

    if (!existing) {
      return prisma.employeeBankInfo.create({
        data: {
          employeeId,
          bankName:       input.bankName       ?? null,
          bankAccountNo:  input.bankAccountNo  ?? null,
          bankBranchCode: input.bankBranchCode ?? null,
          ifscCode:       input.ifscCode       ?? null,
          updatedBy,
        },
      });
    }

    const updated = await prisma.employeeBankInfo.update({
      where: { employeeId },
      data: { ...input, updatedBy },
    });

    diffAndAudit(req, {
      tableName:  'employee_bank_info',
      recordId:   existing.id,
      employeeId,
      before:     existing as Record<string, unknown>,
      after:      updated  as Record<string, unknown>,
    });

    return updated;
  },
};
