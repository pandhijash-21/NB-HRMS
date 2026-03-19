import type { Request, Response } from 'express';
import { z } from 'zod';
import { ok, fail } from '../../utils/response';
import { addressService } from './address.service';
import { parseAddressType } from './types';

const addressSchema = z.object({
  addressType: z.enum(['LOCAL', 'PERMANENT']).optional(),
  flatBlockNo: z.string().min(1).nullable().optional(),
  buildingSociety: z.string().min(1).nullable().optional(),
  area: z.string().min(1).nullable().optional(),
  city: z.string().min(1).nullable().optional(),
  state: z.string().min(1).nullable().optional(),
  country: z.string().min(1).nullable().optional(),
  zipPostalCode: z.string().min(1).nullable().optional(),
  phoneNo: z.string().min(1).nullable().optional(),
  mobileNo: z.string().min(1).nullable().optional(),
  intercomNo: z.string().min(1).nullable().optional(),
  personalEmail: z.string().email().nullable().optional(),
  instituteEmail: z.string().email().nullable().optional(),
  url: z.string().url().nullable().optional(),
  updatedBy: z.string().min(1).nullable().optional(),
});

export const addressController = {
  async getByType(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));

    if (req.user?.role === 'EMPLOYEE' && req.user.employeeId && req.user.employeeId !== employeeId) {
      return res.status(403).json(fail('Forbidden'));
    }

    let addressType;
    try {
      addressType = parseAddressType(String(req.params.type));
    } catch {
      return res.status(400).json(fail('Invalid address type'));
    }

    const data = await addressService.getByType(employeeId, addressType);
    if (!data) return res.status(404).json(fail('Address not found'));
    return res.json(ok(data));
  },

  async upsert(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    if (req.user?.role === 'EMPLOYEE' && req.user.employeeId && req.user.employeeId !== employeeId) {
      return res.status(403).json(fail('Forbidden'));
    }

    const body = addressSchema.extend({ addressType: z.enum(['LOCAL', 'PERMANENT']) }).safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.message));

    const result = await addressService.upsert(employeeId, body.data, req);
    return res.status(result.created ? 201 : 200).json(ok(result.address));
  },

  async updateByType(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    if (req.user?.role === 'EMPLOYEE' && req.user.employeeId && req.user.employeeId !== employeeId) {
      return res.status(403).json(fail('Forbidden'));
    }

    let addressType;
    try {
      addressType = parseAddressType(String(req.params.type));
    } catch {
      return res.status(400).json(fail('Invalid address type'));
    }

    const body = addressSchema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.message));

    const updated = await addressService.updateByType(employeeId, addressType, body.data, req);
    if (!updated) return res.status(404).json(fail('Address not found'));
    return res.json(ok(updated));
  },
};

