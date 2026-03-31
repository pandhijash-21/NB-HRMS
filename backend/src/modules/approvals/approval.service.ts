import { prisma } from '../../config/prisma';

type RequestStatusType = 'PENDING' | 'APPROVED' | 'REJECTED';

export const approvalService = {
  /** Employee submits a change request — data is NOT applied yet */
  async requestChange(
    employeeId: number,
    module: string,
    newData: Record<string, unknown>,
    _requestedBy: string
  ) {
    let oldData: Record<string, unknown> = {};
    if (module === 'PERSONAL') {
      const p = await prisma.employeePersonalInfo.findUnique({ where: { employeeId } });
      if (p) oldData = p as unknown as Record<string, unknown>;
    } else if (module === 'ADDRESS_LOCAL') {
      const a = await prisma.employeeAddress.findUnique({
        where: { employeeId_addressType: { employeeId, addressType: 'LOCAL' } },
      });
      if (a) oldData = a as unknown as Record<string, unknown>;
    } else if (module === 'ADDRESS_PERMANENT') {
      const a = await prisma.employeeAddress.findUnique({
        where: { employeeId_addressType: { employeeId, addressType: 'PERMANENT' } },
      });
      if (a) oldData = a as unknown as Record<string, unknown>;
    } else if (module === 'OTHER') {
      const o = await prisma.employeeOtherInfo.findUnique({ where: { employeeId } });
      if (o) oldData = o as unknown as Record<string, unknown>;
    }

    return prisma.changeRequest.create({
      data: { employeeId, module, oldData: oldData as any, newData: newData as any, status: 'PENDING' },
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

    console.log(`[APPROVE] Processing request ${requestId} for module ${req.module} (Employee ${employeeId})`);

    // Handle date field type conversions for Prisma
    const dataToUpdate: any = { ...newData };
    
    // List of date fields to parse safely for PERSONAL module
    if (req.module === 'PERSONAL') {
      const dateFields = ['birthDate', 'passportIssueDate', 'passportExpiryDate'];
      for (const f of dateFields) {
        if (dataToUpdate[f]) {
          const d = new Date(dataToUpdate[f]);
          if (!isNaN(d.getTime())) {
            dataToUpdate[f] = d;
          } else {
            delete dataToUpdate[f];
          }
        } else {
          delete dataToUpdate[f];
        }
      }
    }

    try {
      if (req.module === 'PERSONAL') {
        const allowed = [
          'birthDate', 'birthPlace', 'homeTown', 'gender', 'maritalStatus', 
          'nationality', 'motherTongue', 'bloodGroup', 'castCategory', 'subCaste',
          'nomineeName', 'nomineeRelation', 'passportNo', 'passportIssuePlace',
          'passportIssueDate', 'passportExpiryDate'
        ];
        const filtered = Object.keys(dataToUpdate)
          .filter(key => allowed.includes(key))
          .reduce((obj: any, key) => { obj[key] = dataToUpdate[key]; return obj; }, {});

        await prisma.employeePersonalInfo.update({ where: { employeeId }, data: filtered });
      } else if (req.module === 'ADDRESS_LOCAL' || req.module === 'ADDRESS_PERMANENT') {
        const type = req.module === 'ADDRESS_LOCAL' ? 'LOCAL' : 'PERMANENT';
        const allowed = [
          'flatBlockNo', 'buildingSociety', 'area', 'city', 'state', 'country',
          'zipPostalCode', 'phoneNo', 'mobileNo', 'intercomNo', 'personalEmail',
          'instituteEmail', 'url'
        ];
        const filtered = Object.keys(dataToUpdate)
          .filter(key => allowed.includes(key))
          .reduce((obj: any, key) => { obj[key] = dataToUpdate[key]; return obj; }, {});

        await prisma.employeeAddress.update({
          where: { employeeId_addressType: { employeeId, addressType: type } },
          data: filtered,
        });
      } else if (req.module === 'OTHER') {
        const allowed = ['skillSet', 'strength', 'weakness', 'hobbies', 'isHandicapped', 'heightInFeet', 'weightInKg'];
        const filtered = Object.keys(dataToUpdate)
          .filter(key => allowed.includes(key))
          .reduce((obj: any, key) => { obj[key] = dataToUpdate[key]; return obj; }, {});

        await prisma.employeeOtherInfo.update({ where: { employeeId }, data: filtered });
      }

      console.log(`[APPROVE] Successfully applied changes to ${req.module} for Employee ${employeeId}`);

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

  /** Check if there's a pending or recently rejected request for a given module */
  async getPending(employeeId: number, module: string) {
    return prisma.changeRequest.findFirst({
      where: { 
        employeeId, 
        module, 
        status: { in: ['PENDING', 'REJECTED'] as any } 
      },
      orderBy: { requestedAt: 'desc' },
    });
  },
};
