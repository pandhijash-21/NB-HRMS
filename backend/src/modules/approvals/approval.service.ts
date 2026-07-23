import { prisma } from '../../config/prisma';

type RequestStatusType = 'PENDING' | 'APPROVED' | 'REJECTED';

const PERSONAL_ALLOWED = [
  'birthDate',
  'birthPlace',
  'homeTown',
  'gender',
  'maritalStatus',
  'nationality',
  'motherTongue',
  'bloodGroup',
  'castCategory',
  'subCaste',
  'nomineeName',
  'nomineeRelation',
  'aadhaarNo',
  'panNo',
  'aadhaarCardUrl',
  'panCardUrl',
  'otherDocumentUrl',
  'passportNo',
  'passportIssuePlace',
  'passportIssueDate',
  'passportExpiryDate',
] as const;

const ADDRESS_ALLOWED = [
  'flatBlockNo',
  'buildingSociety',
  'area',
  'city',
  'state',
  'country',
  'zipPostalCode',
  'phoneNo',
  'mobileNo',
  'intercomNo',
  'personalEmail',
  'instituteEmail',
  'url',
] as const;

const OTHER_ALLOWED = [
  'skillSet',
  'strength',
  'weakness',
  'hobbies',
  'isHandicapped',
  'handicapDetails',
  'heightInFeet',
  'weightInKg',
  'passportUrl',
] as const;

const BANK_ALLOWED = [
  'bankName',
  'bankAccountNo',
  'bankBranchCode',
  'ifscCode',
  'cancelledChequeUrl',
  'passbookUrl',
] as const;

function pickAllowed(data: Record<string, unknown>, allowed: readonly string[]) {
  return Object.keys(data)
    .filter((key) => allowed.includes(key))
    .reduce((obj: Record<string, unknown>, key) => {
      obj[key] = data[key];
      return obj;
    }, {});
}

function stripMeta(row: Record<string, unknown> | null | undefined) {
  if (!row) return {};
  const out = { ...row };
  delete out.id;
  delete out.employeeId;
  delete out.updatedAt;
  delete out.updatedBy;
  delete out.createdAt;
  delete out.employee;
  return out;
}

function summarizeChanges(
  oldData: Record<string, unknown>,
  newData: Record<string, unknown>,
): string[] {
  const keys = new Set([...Object.keys(oldData), ...Object.keys(newData)]);
  const skip = new Set(['id', 'employeeId', 'updatedAt', 'updatedBy', 'createdAt', 'employee']);
  const changed: string[] = [];
  for (const key of keys) {
    if (skip.has(key)) continue;
    const a = oldData[key];
    const b = newData[key];
    const aStr = a == null ? '' : String(a);
    const bStr = b == null ? '' : String(b);
    if (aStr !== bStr) changed.push(key);
  }
  return changed;
}

async function applyAddress(employeeId: number, addressType: 'LOCAL' | 'PERMANENT', raw: Record<string, unknown>) {
  const filtered = pickAllowed(raw, ADDRESS_ALLOWED);
  if (Object.keys(filtered).length === 0) return;
  await prisma.employeeAddress.upsert({
    where: { employeeId_addressType: { employeeId, addressType } },
    update: filtered as any,
    create: {
      employeeId,
      addressType,
      ...(filtered as any),
    },
  });
}

export const approvalService = {
  /** Build a short human summary of which fields changed. */
  describeChanges(oldData: unknown, newData: unknown): string[] {
    return summarizeChanges(
      (oldData as Record<string, unknown>) || {},
      (newData as Record<string, unknown>) || {},
    );
  },

  /** Employee submits a change request — data is NOT applied yet */
  async requestChange(
    employeeId: number,
    module: string,
    newData: Record<string, unknown>,
    _requestedBy: string,
  ) {
    let oldData: Record<string, unknown> = {};

    if (module === 'PERSONAL') {
      const [p, e] = await Promise.all([
        prisma.employeePersonalInfo.findUnique({ where: { employeeId } }),
        prisma.employee.findUnique({
          where: { id: employeeId },
          select: { photoUrl: true, signatureUrl: true },
        }),
      ]);
      oldData = {
        ...stripMeta(p as unknown as Record<string, unknown>),
        ...(e ?? {}),
      };
    } else if (module === 'ADDRESS_LOCAL') {
      const a = await prisma.employeeAddress.findUnique({
        where: { employeeId_addressType: { employeeId, addressType: 'LOCAL' } },
      });
      oldData = stripMeta(a as unknown as Record<string, unknown>);
    } else if (module === 'ADDRESS_PERMANENT') {
      const a = await prisma.employeeAddress.findUnique({
        where: { employeeId_addressType: { employeeId, addressType: 'PERMANENT' } },
      });
      oldData = stripMeta(a as unknown as Record<string, unknown>);
    } else if (module === 'ADDRESS') {
      // Legacy Flutter payload: { local, permanent }
      const [local, permanent] = await Promise.all([
        prisma.employeeAddress.findUnique({
          where: { employeeId_addressType: { employeeId, addressType: 'LOCAL' } },
        }),
        prisma.employeeAddress.findUnique({
          where: { employeeId_addressType: { employeeId, addressType: 'PERMANENT' } },
        }),
      ]);
      oldData = {
        local: stripMeta(local as unknown as Record<string, unknown>),
        permanent: stripMeta(permanent as unknown as Record<string, unknown>),
      };
    } else if (module === 'OTHER') {
      const o = await prisma.employeeOtherInfo.findUnique({ where: { employeeId } });
      oldData = stripMeta(o as unknown as Record<string, unknown>);
    } else if (module === 'BANK') {
      const b = await prisma.employeeBankInfo.findUnique({ where: { employeeId } });
      oldData = stripMeta(b as unknown as Record<string, unknown>);
    }

    // Replace any prior pending request for the same module
    await prisma.changeRequest.updateMany({
      where: { employeeId, module, status: 'PENDING' },
      data: { status: 'REJECTED', reviewedBy: 'system:superseded', reviewedAt: new Date() },
    });

    return prisma.changeRequest.create({
      data: {
        employeeId,
        module,
        oldData: oldData as any,
        newData: newData as any,
        status: 'PENDING',
      },
    });
  },

  /** LIST — for Admin review panel */
  async list(params: { status?: RequestStatusType; employeeId?: number }) {
    const where: any = {};
    if (params.status) where.status = params.status as any;
    if (params.employeeId) where.employeeId = params.employeeId;

    return prisma.changeRequest.findMany({
      where,
      include: {
        employee: {
          select: {
            id: true,
            generalInfo: { select: { fullName: true, employeeCode: true, designation: true } },
          },
        },
      },
      orderBy: { requestedAt: 'desc' },
    });
  },

  /** Admin APPROVES — writes newData into the actual table */
  async approve(requestId: string, reviewerId: string) {
    const req = await prisma.changeRequest.findUnique({ where: { id: requestId } });
    if (!req || req.status !== 'PENDING') return null;

    const newData = (req.newData as any) || {};
    const employeeId = req.employeeId as number;

    const dataToUpdate: any = { ...newData };

    if (req.module === 'PERSONAL') {
      const dateFields = ['birthDate', 'passportIssueDate', 'passportExpiryDate'];
      for (const f of dateFields) {
        if (dataToUpdate[f]) {
          const d = new Date(dataToUpdate[f]);
          if (!isNaN(d.getTime())) dataToUpdate[f] = d;
          else delete dataToUpdate[f];
        } else {
          delete dataToUpdate[f];
        }
      }
    }

    try {
      if (req.module === 'PERSONAL') {
        const filtered = pickAllowed(dataToUpdate, PERSONAL_ALLOWED);
        await prisma.employeePersonalInfo.upsert({
          where: { employeeId },
          update: filtered as any,
          create: {
            employeeId,
            birthDate: (filtered.birthDate as Date) ?? new Date('1970-01-01'),
            gender: (filtered.gender as any) ?? 'MALE',
            maritalStatus: (filtered.maritalStatus as any) ?? 'SINGLE',
            ...(filtered as any),
          },
        });

        const mediaUpdate: { photoUrl?: string | null; signatureUrl?: string | null } = {};
        if (Object.prototype.hasOwnProperty.call(dataToUpdate, 'photoUrl')) {
          mediaUpdate.photoUrl = dataToUpdate.photoUrl ?? null;
        }
        if (Object.prototype.hasOwnProperty.call(dataToUpdate, 'signatureUrl')) {
          mediaUpdate.signatureUrl = dataToUpdate.signatureUrl ?? null;
        }
        if (Object.keys(mediaUpdate).length > 0) {
          await prisma.employee.update({ where: { id: employeeId }, data: mediaUpdate });
        }

        if (Object.prototype.hasOwnProperty.call(dataToUpdate, 'passportUrl')) {
          await prisma.employeeOtherInfo.upsert({
            where: { employeeId },
            update: { passportUrl: dataToUpdate.passportUrl ?? null },
            create: { employeeId, passportUrl: dataToUpdate.passportUrl ?? null },
          });
        }
      } else if (req.module === 'ADDRESS_LOCAL') {
        await applyAddress(employeeId, 'LOCAL', dataToUpdate);
      } else if (req.module === 'ADDRESS_PERMANENT') {
        await applyAddress(employeeId, 'PERMANENT', dataToUpdate);
      } else if (req.module === 'ADDRESS') {
        // Legacy nested payload from Flutter
        if (dataToUpdate.local && typeof dataToUpdate.local === 'object') {
          await applyAddress(employeeId, 'LOCAL', dataToUpdate.local);
        }
        if (dataToUpdate.permanent && typeof dataToUpdate.permanent === 'object') {
          await applyAddress(employeeId, 'PERMANENT', dataToUpdate.permanent);
        }
      } else if (req.module === 'OTHER') {
        const filtered = pickAllowed(dataToUpdate, OTHER_ALLOWED);
        await prisma.employeeOtherInfo.upsert({
          where: { employeeId },
          update: filtered as any,
          create: { employeeId, ...(filtered as any) },
        });
      } else if (req.module === 'BANK') {
        const filtered = pickAllowed(dataToUpdate, BANK_ALLOWED);
        await prisma.employeeBankInfo.upsert({
          where: { employeeId },
          update: filtered as any,
          create: { employeeId, ...(filtered as any) },
        });
      } else {
        throw new Error(`Unsupported change-request module: ${req.module}`);
      }

      return prisma.changeRequest.update({
        where: { id: requestId },
        data: { status: 'APPROVED', reviewedBy: reviewerId, reviewedAt: new Date() },
      });
    } catch (error) {
      console.error(`[APPROVE] Failed to apply changes for request ${requestId}:`, error);
      throw error;
    }
  },

  /** Admin REJECTS — data stays unchanged */
  async reject(requestId: string, reviewerId: string) {
    const req = await prisma.changeRequest.findUnique({ where: { id: requestId } });
    if (!req || req.status !== 'PENDING') return null;

    return prisma.changeRequest.update({
      where: { id: requestId },
      data: { status: 'REJECTED', reviewedBy: reviewerId, reviewedAt: new Date() },
    });
  },

  /** Active pending request for a module (rejected ones are not treated as blocking). */
  async getPending(employeeId: number, module: string) {
    return prisma.changeRequest.findFirst({
      where: {
        employeeId,
        module,
        status: 'PENDING',
      },
      orderBy: { requestedAt: 'desc' },
    });
  },
};
