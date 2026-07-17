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
  /** When omitted, only Cloudinary upload — no DB row yet (new qualification dialog). */
  qualId: z.string().min(1).optional(),
  sem: z.coerce.number().int().min(1).max(8),
});

const certificateMetaSchema = z.object({
  employeeId: z.coerce.number().int().positive(),
  qualId: z.string().min(1).optional(),
});

const employeeMetaSchema = z.object({
  employeeId: z.coerce.number().int().positive(),
});

const familyMemberMetaSchema = z.object({
  employeeId: z.coerce.number().int().positive(),
  memberId: z.string().min(1),
});

const experienceMetaSchema = z.object({
  employeeId: z.coerce.number().int().positive(),
  experienceId: z.string().min(1),
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
  // Existing uploads
  photo: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'employee/photo');
    const updated = await uploadService.setEmployeePhoto(meta.data.employeeId, url, req.user?.id);
    return res.json(ok({ url, photoUrl: url, employee: updated }));
  }],

  signature: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'employee/signature');
    const updated = await uploadService.setEmployeeSignature(meta.data.employeeId, url, req.user?.id);
    return res.json(ok({ url, signatureUrl: url, employee: updated }));
  }],

  aadhaarCard: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'employee/aadhaar-card');
    const updated = await uploadService.setAadhaarCard(meta.data.employeeId, url, req.user?.id);
    return res.json(ok({ url, employee: updated }));
  }],

  panCard: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'employee/pan-card');
    const updated = await uploadService.setPanCard(meta.data.employeeId, url, req.user?.id);
    return res.json(ok({ url, employee: updated }));
  }],

  otherDocument: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'employee/other-document');
    const updated = await uploadService.setOtherDocument(meta.data.employeeId, url, req.user?.id);
    return res.json(ok({ url, otherDocumentUrl: url, employee: updated }));
  }],

  /** Offer letter — Cloudinary only (no dedicated DB column in current schema). */
  offerLetter: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'employee/offer-letter');
    return res.json(ok({ url }));
  }],

  marksheet: [single('file'), async (req: Request, res: Response) => {
    const meta = marksheetMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, `academic/marksheet/sem${meta.data.sem}`);
    if (meta.data.qualId) {
      const updated = await uploadService.setSemMarksheet(meta.data.employeeId, meta.data.qualId, meta.data.sem, url, req.user?.id);
      return res.json(ok({ url, qualification: updated }));
    }
    return res.json(ok({ url }));
  }],

  certificate: [single('file'), async (req: Request, res: Response) => {
    const meta = certificateMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'academic/certificate');
    if (meta.data.qualId) {
      const updated = await uploadService.setCertificate(meta.data.employeeId, meta.data.qualId, url, req.user?.id);
      return res.json(ok({ url, qualification: updated }));
    }
    return res.json(ok({ url }));
  }],

  // NEW: Passport upload
  passport: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'employee/passport');
    const updated = await uploadService.setPassport(meta.data.employeeId, url, req.user?.id);
    return res.json(ok({ url, employee: updated }));
  }],

  // NEW: Family member Aadhaar upload
  aadhaarFamily: [single('file'), async (req: Request, res: Response) => {
    const meta = familyMemberMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, `family/aadhaar/${meta.data.memberId}`);
    const updated = await uploadService.setFamilyMemberAadhaar(meta.data.employeeId, meta.data.memberId, url, req.user?.id);
    return res.json(ok(updated ? { url, member: updated } : { url }));
  }],

  // Experience letter — optional experienceId (Experience tab sends id; Documents tab may omit)
  experienceLetter: [single('file'), async (req: Request, res: Response) => {
    const withExp = experienceMetaSchema.safeParse(req.body);
    const empOnly = employeeMetaSchema.safeParse(req.body);
    if (!withExp.success && !empOnly.success) {
      return res.status(400).json(fail(withExp.success ? empOnly.error.message : withExp.error.message));
    }
    if (!req.file) return res.status(400).json(fail('Missing file'));
    const employeeId = withExp.success ? withExp.data.employeeId : empOnly.data!.employeeId;
    assertUploadAccess(req, employeeId);
    const folder = withExp.success
      ? `experience/letter/${withExp.data.experienceId}`
      : `employee/experience-letter/${employeeId}`;
    const url = await uploadService.uploadToCloudinary(req.file, folder);
    return res.json(ok({ url }));
  }],

  // NEW: Last paycheck upload
  lastPaycheck: [single('file'), async (req: Request, res: Response) => {
    const meta = experienceMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, `experience/paycheck/${meta.data.experienceId}`);
    return res.json(ok({ url }));
  }],

  // NEW: Recommendation letter upload
  recommendation: [single('file'), async (req: Request, res: Response) => {
    const meta = experienceMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, `experience/recommendation/${meta.data.experienceId}`);
    return res.json(ok({ url }));
  }],

  cancelledCheque: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'bank/cancelled-cheque');
    const updated = await uploadService.setCancelledCheque(meta.data.employeeId, url, req.user?.id);
    return res.json(ok({ url, cancelledChequeUrl: url, bankInfo: updated }));
  }],

  passbook: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'bank/passbook');
    const updated = await uploadService.setPassbook(meta.data.employeeId, url, req.user?.id);
    return res.json(ok({ url, passbookUrl: url, bankInfo: updated }));
  }],

  /** Supporting document for leave applications (Cloudinary URL only). */
  leaveDocument: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(
      req.file,
      `leave/documents/${meta.data.employeeId}`,
    );
    return res.json(ok({ url }));
  }],
};
