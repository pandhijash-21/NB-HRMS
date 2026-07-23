import type { Request, Response } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { fail, ok } from '../../utils/response';
import { uploadService } from './upload.service';
import { mayPersistEmployeeUpload } from './profileWriteGuard';
import { prisma } from '../../config/prisma';

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

const PRIVILEGED_ROLES = ['ADMIN', 'HR', 'HOI', 'HR_MANAGER', 'SUPER_ADMIN', 'REGISTRAR', 'VC'];

function assertUploadAccess(req: Request, targetEmployeeId: number) {
  const roleName = String(req.user?.roleName ?? req.user?.role ?? '').toUpperCase();
  const tokenEmployeeId = req.user?.employeeId != null ? Number(req.user.employeeId) : null;
  if (!PRIVILEGED_ROLES.includes(roleName) && tokenEmployeeId !== targetEmployeeId) {
    const err: any = new Error('You can only upload files for your own profile');
    err.status = 403;
    throw err;
  }
}

async function respondIdentityUpload(params: {
  req: Request;
  res: Response;
  employeeId: number;
  folder: string;
  existingUrl: string | null | undefined;
  persist: (url: string) => Promise<unknown>;
  fieldKey: string;
}) {
  const { req, res, employeeId, folder, existingUrl, persist, fieldKey } = params;
  if (!req.file) return res.status(400).json(fail('Missing file'));
  assertUploadAccess(req, employeeId);
  const url = await uploadService.uploadToCloudinary(req.file, folder);
  const persistNow = await mayPersistEmployeeUpload(req, employeeId, Boolean(existingUrl));
  if (persistNow) {
    const updated = await persist(url);
    return res.json(ok({ url, [fieldKey]: url, persisted: true, employee: updated }));
  }
  return res.json(
    ok({
      url,
      [fieldKey]: url,
      persisted: false,
      pendingApproval: true,
      message:
        'File uploaded. Submit a profile change request so Admin/HR can verify before it is saved permanently.',
    }),
  );
}

export const uploadController = {
  photo: [single('file'), async (req: Request, res: Response) => {
    try {
      const meta = employeeMetaSchema.safeParse(req.body);
      if (!meta.success) return res.status(400).json(fail(meta.error.message));
      const emp = await prisma.employee.findUnique({
        where: { id: meta.data.employeeId },
        select: { photoUrl: true },
      });
      return await respondIdentityUpload({
        req,
        res,
        employeeId: meta.data.employeeId,
        folder: 'employee/photo',
        existingUrl: emp?.photoUrl,
        fieldKey: 'photoUrl',
        persist: (url) => uploadService.setEmployeePhoto(meta.data.employeeId, url, req.user?.id),
      });
    } catch (err: any) {
      return res.status(err.status ?? 500).json(fail(err.message ?? 'Upload failed'));
    }
  }],

  signature: [single('file'), async (req: Request, res: Response) => {
    try {
      const meta = employeeMetaSchema.safeParse(req.body);
      if (!meta.success) return res.status(400).json(fail(meta.error.message));
      const emp = await prisma.employee.findUnique({
        where: { id: meta.data.employeeId },
        select: { signatureUrl: true },
      });
      return await respondIdentityUpload({
        req,
        res,
        employeeId: meta.data.employeeId,
        folder: 'employee/signature',
        existingUrl: emp?.signatureUrl,
        fieldKey: 'signatureUrl',
        persist: (url) => uploadService.setEmployeeSignature(meta.data.employeeId, url, req.user?.id),
      });
    } catch (err: any) {
      return res.status(err.status ?? 500).json(fail(err.message ?? 'Upload failed'));
    }
  }],

  aadhaarCard: [single('file'), async (req: Request, res: Response) => {
    try {
      const meta = employeeMetaSchema.safeParse(req.body);
      if (!meta.success) return res.status(400).json(fail(meta.error.message));
      const personal = await prisma.employeePersonalInfo.findUnique({
        where: { employeeId: meta.data.employeeId },
        select: { aadhaarCardUrl: true },
      });
      return await respondIdentityUpload({
        req,
        res,
        employeeId: meta.data.employeeId,
        folder: 'employee/aadhaar-card',
        existingUrl: personal?.aadhaarCardUrl,
        fieldKey: 'aadhaarCardUrl',
        persist: (url) => uploadService.setAadhaarCard(meta.data.employeeId, url, req.user?.id),
      });
    } catch (err: any) {
      return res.status(err.status ?? 500).json(fail(err.message ?? 'Upload failed'));
    }
  }],

  panCard: [single('file'), async (req: Request, res: Response) => {
    try {
      const meta = employeeMetaSchema.safeParse(req.body);
      if (!meta.success) return res.status(400).json(fail(meta.error.message));
      const personal = await prisma.employeePersonalInfo.findUnique({
        where: { employeeId: meta.data.employeeId },
        select: { panCardUrl: true },
      });
      return await respondIdentityUpload({
        req,
        res,
        employeeId: meta.data.employeeId,
        folder: 'employee/pan-card',
        existingUrl: personal?.panCardUrl,
        fieldKey: 'panCardUrl',
        persist: (url) => uploadService.setPanCard(meta.data.employeeId, url, req.user?.id),
      });
    } catch (err: any) {
      return res.status(err.status ?? 500).json(fail(err.message ?? 'Upload failed'));
    }
  }],

  otherDocument: [single('file'), async (req: Request, res: Response) => {
    try {
      const meta = employeeMetaSchema.safeParse(req.body);
      if (!meta.success) return res.status(400).json(fail(meta.error.message));
      const personal = await prisma.employeePersonalInfo.findUnique({
        where: { employeeId: meta.data.employeeId },
        select: { otherDocumentUrl: true },
      });
      return await respondIdentityUpload({
        req,
        res,
        employeeId: meta.data.employeeId,
        folder: 'employee/other-document',
        existingUrl: personal?.otherDocumentUrl,
        fieldKey: 'otherDocumentUrl',
        persist: (url) => uploadService.setOtherDocument(meta.data.employeeId, url, req.user?.id),
      });
    } catch (err: any) {
      return res.status(err.status ?? 500).json(fail(err.message ?? 'Upload failed'));
    }
  }],

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
      await uploadService.setSemMarksheet(
        meta.data.employeeId,
        meta.data.qualId,
        meta.data.sem,
        url,
        req.user?.id,
      );
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
      await uploadService.setCertificate(meta.data.employeeId, meta.data.qualId, url, req.user?.id);
    }
    return res.json(ok({ url }));
  }],

  passport: [single('file'), async (req: Request, res: Response) => {
    try {
      const meta = employeeMetaSchema.safeParse(req.body);
      if (!meta.success) return res.status(400).json(fail(meta.error.message));
      const other = await prisma.employeeOtherInfo.findUnique({
        where: { employeeId: meta.data.employeeId },
        select: { passportUrl: true },
      });
      return await respondIdentityUpload({
        req,
        res,
        employeeId: meta.data.employeeId,
        folder: 'employee/passport',
        existingUrl: other?.passportUrl,
        fieldKey: 'passportUrl',
        persist: (url) => uploadService.setPassport(meta.data.employeeId, url, req.user?.id),
      });
    } catch (err: any) {
      return res.status(err.status ?? 500).json(fail(err.message ?? 'Upload failed'));
    }
  }],

  aadhaarFamily: [single('file'), async (req: Request, res: Response) => {
    const meta = familyMemberMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, 'family/aadhaar');
    const updated = await uploadService.setFamilyMemberAadhaar(
      meta.data.employeeId,
      meta.data.memberId,
      url,
      req.user?.id,
    );
    return res.json(ok({ url, member: updated }));
  }],

  experienceLetter: [single('file'), async (req: Request, res: Response) => {
    const meta = experienceMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, `experience/letter/${meta.data.experienceId}`);
    return res.json(ok({ url }));
  }],

  lastPaycheck: [single('file'), async (req: Request, res: Response) => {
    const meta = experienceMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, `experience/paycheck/${meta.data.experienceId}`);
    return res.json(ok({ url }));
  }],

  recommendation: [single('file'), async (req: Request, res: Response) => {
    const meta = experienceMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(req.file, `experience/recommendation/${meta.data.experienceId}`);
    return res.json(ok({ url }));
  }],

  cancelledCheque: [single('file'), async (req: Request, res: Response) => {
    try {
      const meta = employeeMetaSchema.safeParse(req.body);
      if (!meta.success) return res.status(400).json(fail(meta.error.message));
      const bank = await prisma.employeeBankInfo.findUnique({
        where: { employeeId: meta.data.employeeId },
        select: { cancelledChequeUrl: true },
      });
      return await respondIdentityUpload({
        req,
        res,
        employeeId: meta.data.employeeId,
        folder: 'bank/cancelled-cheque',
        existingUrl: bank?.cancelledChequeUrl,
        fieldKey: 'cancelledChequeUrl',
        persist: (url) => uploadService.setCancelledCheque(meta.data.employeeId, url, req.user?.id),
      });
    } catch (err: any) {
      return res.status(err.status ?? 500).json(fail(err.message ?? 'Upload failed'));
    }
  }],

  passbook: [single('file'), async (req: Request, res: Response) => {
    try {
      const meta = employeeMetaSchema.safeParse(req.body);
      if (!meta.success) return res.status(400).json(fail(meta.error.message));
      const bank = await prisma.employeeBankInfo.findUnique({
        where: { employeeId: meta.data.employeeId },
        select: { passbookUrl: true },
      });
      return await respondIdentityUpload({
        req,
        res,
        employeeId: meta.data.employeeId,
        folder: 'bank/passbook',
        existingUrl: bank?.passbookUrl,
        fieldKey: 'passbookUrl',
        persist: (url) => uploadService.setPassbook(meta.data.employeeId, url, req.user?.id),
      });
    } catch (err: any) {
      return res.status(err.status ?? 500).json(fail(err.message ?? 'Upload failed'));
    }
  }],

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

  reimbursementProof: [single('file'), async (req: Request, res: Response) => {
    const meta = employeeMetaSchema.safeParse(req.body);
    if (!meta.success) return res.status(400).json(fail(meta.error.message));
    if (!req.file) return res.status(400).json(fail('Missing file'));
    assertUploadAccess(req, meta.data.employeeId);
    const url = await uploadService.uploadToCloudinary(
      req.file,
      `reimbursements/proof/${meta.data.employeeId}`,
    );
    return res.json(ok({ url }));
  }],

  /** Candidate resume upload (recruitment) — returns Cloudinary URL only. */
  resume: [single('file'), async (req: Request, res: Response) => {
    try {
      if (!req.file) return res.status(400).json(fail('Missing file'));
      const roleName = String(req.user?.roleName ?? req.user?.role ?? '').toUpperCase();
      if (!PRIVILEGED_ROLES.includes(roleName)) {
        return res.status(403).json(fail('Only Admin/HR can upload resumes'));
      }
      const url = await uploadService.uploadToCloudinary(req.file, 'recruitment/resumes');
      return res.json(ok({ url }));
    } catch (err: any) {
      return res.status(400).json(fail(err.message ?? 'Upload failed'));
    }
  }],

  /** Resolve a stored Cloudinary URL into a signed, browser-openable link. */
  async viewUrl(req: Request, res: Response) {
    try {
      const raw = String(req.query.url ?? '').trim();
      if (!raw) return res.status(400).json(fail('url query param is required'));
      let decoded = raw;
      try {
        decoded = decodeURIComponent(raw);
      } catch {
        decoded = raw;
      }
      const viewable = await uploadService.getViewableUrl(decoded);
      return res.json(ok({ url: viewable, originalUrl: decoded }));
    } catch (err: any) {
      return res.status(err.status ?? 500).json(fail(err.message ?? 'Failed to resolve document URL'));
    }
  },

  /**
   * Proxy Cloudinary → browser with Content-Disposition: inline.
   * Fixes Chrome downloading PDFs/raw assets from private_download_url.
   */
  async inline(req: Request, res: Response) {
    try {
      const raw = String(req.query.url ?? '').trim();
      if (!raw) return res.status(400).json(fail('url query param is required'));
      let decoded = raw;
      try {
        decoded = decodeURIComponent(raw);
      } catch {
        decoded = raw;
      }

      // Try private_download + signed delivery until Cloudinary returns bytes.
      // Direct signed URLs often 401 in the browser for restricted media.
      const { buffer: buf, contentType: upstreamType } =
        await uploadService.fetchDocumentBytes(decoded);
      const preferredName =
        typeof req.query.filename === 'string' ? req.query.filename.trim() : '';

      let contentType =
        upstreamType ||
        uploadService.guessMimeFromUrl(preferredName || decoded) ||
        'application/octet-stream';

      const lower = `${preferredName} ${decoded}`.toLowerCase();
      if (
        contentType.includes('octet-stream') ||
        contentType.includes('application/force-download')
      ) {
        if (lower.includes('.pdf') || preferredName.toLowerCase().endsWith('.pdf')) {
          contentType = 'application/pdf';
        } else if (lower.includes('.png')) contentType = 'image/png';
        else if (lower.includes('.jpg') || lower.includes('.jpeg')) contentType = 'image/jpeg';
        else if (lower.includes('.webp')) contentType = 'image/webp';
        else if (lower.includes('.doc')) contentType = 'application/msword';
        // Docs without extension in Cloudinary URL — default to PDF preview
        else contentType = 'application/pdf';
      }

      let filename = preferredName || decoded.split('/').pop()?.split('?')[0] || 'document.pdf';
      if (!filename.includes('.')) {
        if (contentType.includes('pdf')) filename = `${filename}.pdf`;
        else if (contentType.startsWith('image/')) {
          filename = `${filename}.${contentType.split('/')[1] || 'png'}`;
        } else filename = `${filename}.pdf`;
      }

      res.setHeader('Content-Type', contentType);
      res.setHeader(
        'Content-Disposition',
        `inline; filename="${filename.replace(/"/g, '')}"`,
      );
      res.setHeader('Content-Length', String(buf.length));
      res.setHeader('Cache-Control', 'private, max-age=60');
      res.setHeader('X-Content-Type-Options', 'nosniff');
      return res.status(200).send(buf);
    } catch (err: any) {
      return res.status(err.status ?? 500).json(fail(err.message ?? 'Failed to stream document'));
    }
  },
};
