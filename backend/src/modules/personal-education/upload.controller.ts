import type { Request, Response } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { fail, ok } from '../../utils/response';
import { uploadService } from './upload.service';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
});

function single(field: string) {
  return upload.single(field);
}

const marksheetMetaSchema = z.object({
  employeeId: z.coerce.number().int().positive(),
  qualId: z.string().min(1),
  sem: z.coerce.number().int().min(1).max(8),
});

const certificateMetaSchema = z.object({
  employeeId: z.coerce.number().int().positive(),
  qualId: z.string().min(1),
});

const employeeMetaSchema = z.object({
  employeeId: z.coerce.number().int().positive(),
});

const PRIVILEGED_ROLES = ['ADMIN', 'HR', 'HOI'];

function assertUploadAccess(req: Request, targetEmployeeId: number) {
  const { roleName, employeeId: tokenEmployeeId } = req.user!;
  if (!PRIVILEGED_ROLES.includes(roleName) && tokenEmployeeId !== targetEmployeeId) {
    const err: any = new Error('You can only upload files for your own profile');
    err.status = 403;
    throw err;
  }
}

export const uploadController = {
  photo: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'employee/photo');
    const updated = await uploadService.setEmployeePhoto(meta.data.employeeId, url, req.user?.id);
    return res.json(ok(updated));
  }],

  signature: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'employee/signature');
    const updated = await uploadService.setEmployeeSignature(meta.data.employeeId, url, req.user?.id);
    return res.json(ok(updated));
  }],

  aadhaarCard: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'employee/aadhaar-card');
    const updated = await uploadService.setAadhaarCard(meta.data.employeeId, url, req.user?.id);
    return res.json(ok(updated));
  }],

  panCard: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'employee/pan-card');
    const updated = await uploadService.setPanCard(meta.data.employeeId, url, req.user?.id);
    return res.json(ok(updated));
  }],

  marksheet: [single('file'), async (req: Request, res: Response) => {
    const meta = marksheetMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, `academic/marksheet/sem${meta.data.sem}`);
    const updated = await uploadService.setSemMarksheet(meta.data.employeeId, meta.data.qualId, meta.data.sem, url, req.user?.id);
    return res.json(ok(updated));
  }],

  certificate: [single('file'), async (req: Request, res: Response) => {
    const meta = certificateMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'academic/certificate');
    const updated = await uploadService.setCertificate(meta.data.employeeId, meta.data.qualId, url, req.user?.id);
    return res.json(ok(updated));
  }],
};

