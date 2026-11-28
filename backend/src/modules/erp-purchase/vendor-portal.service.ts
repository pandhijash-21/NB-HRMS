import { createHash, randomBytes, randomInt } from 'crypto';
import { randomUUID } from 'crypto';
import { ErpPurchaseQuotationStatus, ErpPurchaseRequestStatus } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { env } from '../../config/env';
import {
  isSmtpConfigured,
  sendOtpEmail,
  sendVendorQuotationConfirmationEmail,
  sendVendorQuotationInviteEmail,
} from '../../utils/mailer';
import { quotationService } from './quotation.service';
import { purchaseService } from './purchase.service';

const OTP_TTL_MS = 5 * 60 * 1000;
const OTP_COOLDOWN_MS = 2 * 60 * 1000;
const SESSION_TTL_MS = 24 * 60 * 60 * 1000;
const MAX_OTP_ATTEMPTS = 5;

const str = (v: unknown) => {
  if (v == null) return null;
  const s = String(v).trim();
  return s.length ? s : null;
};

function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

function hashOtp(otp: string, salt: string) {
  return createHash('sha256').update(`${salt}:${otp}`).digest('hex');
}

function portalBaseUrl() {
  return env.FRONTEND_URL.replace(/\/$/, '');
}

function inviteLink(token: string) {
  return `${portalBaseUrl()}/vendor-quote/${token}`;
}

function httpError(message: string, status = 400): Error & { status: number } {
  const err = new Error(message) as Error & { status: number };
  err.status = status;
  return err;
}

async function assertPortalEnabled() {
  const settings = await purchaseService.getSettings();
  if (!settings.vendorPortalEnabled) {
    throw httpError('Vendor quotation portal is disabled by admin', 403);
  }
  return settings;
}

async function loadInviteByToken(token: string) {
  const invite = await prisma.erpPurchaseVendorInvite.findUnique({
    where: { token },
    include: {
      purchaseRequest: {
        include: {
          project: { select: { id: true, name: true } },
          lines: { orderBy: { sortOrder: 'asc' } },
        },
      },
    },
  });
  if (!invite || !invite.isActive) throw httpError('Invalid or inactive invitation link', 404);
  if (invite.purchaseRequest.status !== ErpPurchaseRequestStatus.APPROVED) {
    throw httpError('This purchase request is not open for quotations', 400);
  }
  return invite;
}

async function requireSession(inviteId: string, sessionToken: string | null) {
  const token = str(sessionToken);
  if (!token) throw httpError('Session required. Verify email OTP first.', 401);
  const session = await prisma.erpPurchaseVendorSession.findUnique({ where: { token } });
  if (!session || session.inviteId !== inviteId) {
    throw httpError('Invalid session. Please verify OTP again.', 401);
  }
  if (session.expiresAt.getTime() < Date.now()) {
    throw httpError('Session expired. Please verify OTP again.', 401);
  }
  return session;
}

export const vendorPortalService = {
  inviteLink,

  async ensureInvite(purchaseRequestId: string) {
    const settings = await purchaseService.getSettings();
    const pr = await prisma.erpPurchaseRequest.findUnique({
      where: { id: purchaseRequestId },
      include: { project: { select: { name: true } } },
    });
    if (!pr) throw httpError('Purchase request not found', 404);

    if (!settings.vendorPortalEnabled) {
      return {
        inviteId: null as string | null,
        token: null as string | null,
        link: null as string | null,
        prNumber: pr.prNumber,
        projectName: pr.project?.name ?? null,
        vendorPortalEnabled: false,
        vendorPortalAutoEmail: settings.vendorPortalAutoEmail,
        smtpConfigured: isSmtpConfigured(),
      };
    }

    if (pr.status !== ErpPurchaseRequestStatus.APPROVED) {
      throw httpError('Quotations portal link is only available for approved purchase requests');
    }

    let invite = await prisma.erpPurchaseVendorInvite.findUnique({
      where: { purchaseRequestId },
    });
    if (!invite) {
      invite = await prisma.erpPurchaseVendorInvite.create({
        data: {
          id: randomUUID(),
          purchaseRequestId,
          token: randomBytes(24).toString('hex'),
          isActive: true,
        },
      });
    } else if (!invite.isActive) {
      invite = await prisma.erpPurchaseVendorInvite.update({
        where: { id: invite.id },
        data: { isActive: true },
      });
    }

    return {
      inviteId: invite.id,
      token: invite.token,
      link: inviteLink(invite.token),
      prNumber: pr.prNumber,
      projectName: pr.project?.name ?? null,
      vendorPortalEnabled: settings.vendorPortalEnabled,
      vendorPortalAutoEmail: settings.vendorPortalAutoEmail,
      smtpConfigured: isSmtpConfigured(),
    };
  },

  async rotateInvite(purchaseRequestId: string) {
    await assertPortalEnabled();
    const existing = await this.ensureInvite(purchaseRequestId);
    if (!existing.inviteId) throw httpError('Vendor portal is not enabled', 403);
    const invite = await prisma.erpPurchaseVendorInvite.update({
      where: { id: existing.inviteId },
      data: { token: randomBytes(24).toString('hex'), isActive: true },
    });
    await prisma.erpPurchaseVendorSession.deleteMany({ where: { inviteId: invite.id } });
    await prisma.erpPurchaseVendorOtp.deleteMany({ where: { inviteId: invite.id } });
    return {
      ...existing,
      inviteId: invite.id,
      token: invite.token,
      link: inviteLink(invite.token),
    };
  },

  async emailInvite(purchaseRequestId: string, emails: string[]) {
    await assertPortalEnabled();
    const invite = await this.ensureInvite(purchaseRequestId);
    if (!invite.link) throw httpError('Vendor portal invite link is not available', 400);
    const list = [...new Set(emails.map(normalizeEmail).filter(Boolean))];
    if (list.length === 0) throw httpError('At least one email is required');
    for (const email of list) {
      await sendVendorQuotationInviteEmail(email, {
        prNumber: invite.prNumber,
        link: invite.link,
        projectName: invite.projectName,
      });
    }
    return { sent: list.length, emails: list, link: invite.link };
  },

  async getPublicSummary(token: string) {
    await assertPortalEnabled();
    const invite = await loadInviteByToken(token);
    const pr = invite.purchaseRequest;
    return {
      token: invite.token,
      prNumber: pr.prNumber,
      projectName: pr.project?.name ?? null,
      requiredByDate: pr.requiredByDate,
      lines: pr.lines.map((l) => ({
        id: l.id,
        itemName: l.itemName,
        brand: l.brand,
        unitCode: l.unitCode,
        size: l.size,
        qty: Number(l.qty),
      })),
    };
  },

  async sendOtp(token: string, emailRaw: string) {
    await assertPortalEnabled();
    const invite = await loadInviteByToken(token);
    const email = normalizeEmail(emailRaw);
    if (!email || !email.includes('@')) throw httpError('Valid email is required');

    const existing = await prisma.erpPurchaseVendorOtp.findUnique({
      where: { inviteId_email: { inviteId: invite.id, email } },
    });
    if (existing?.cooldownUntil && existing.cooldownUntil.getTime() > Date.now()) {
      const wait = Math.ceil((existing.cooldownUntil.getTime() - Date.now()) / 1000);
      throw httpError(`Please wait ${wait}s before requesting another OTP`, 429);
    }

    const otp = String(randomInt(100000, 999999));
    const salt = randomBytes(8).toString('hex');
    const otpHash = `${salt}.${hashOtp(otp, salt)}`;
    const now = new Date();
    await prisma.erpPurchaseVendorOtp.upsert({
      where: { inviteId_email: { inviteId: invite.id, email } },
      create: {
        id: randomUUID(),
        inviteId: invite.id,
        email,
        otpHash,
        attempts: 0,
        expiresAt: new Date(now.getTime() + OTP_TTL_MS),
        cooldownUntil: new Date(now.getTime() + OTP_COOLDOWN_MS),
      },
      update: {
        otpHash,
        attempts: 0,
        expiresAt: new Date(now.getTime() + OTP_TTL_MS),
        cooldownUntil: new Date(now.getTime() + OTP_COOLDOWN_MS),
      },
    });

    await sendOtpEmail(email, otp, {
      subject: `OTP for quotation ${invite.purchaseRequest.prNumber}`,
      heading: 'Vendor quotation portal',
      purpose: `Verify email to quote on ${invite.purchaseRequest.prNumber}`,
    });

    return {
      ok: true,
      email,
      expiresInSeconds: Math.floor(OTP_TTL_MS / 1000),
      smtpConfigured: isSmtpConfigured(),
    };
  },

  async verifyOtp(token: string, emailRaw: string, otpRaw: string) {
    await assertPortalEnabled();
    const invite = await loadInviteByToken(token);
    const email = normalizeEmail(emailRaw);
    const otp = String(otpRaw ?? '').trim();
    if (!email || !otp) throw httpError('Email and OTP are required');

    const row = await prisma.erpPurchaseVendorOtp.findUnique({
      where: { inviteId_email: { inviteId: invite.id, email } },
    });
    if (!row) throw httpError('No OTP requested for this email', 400);
    if (row.expiresAt.getTime() < Date.now()) throw httpError('OTP expired. Request a new one.', 400);
    if (row.attempts >= MAX_OTP_ATTEMPTS) {
      throw httpError('Too many invalid attempts. Request a new OTP.', 429);
    }

    const [salt, digest] = row.otpHash.split('.');
    const ok = salt && digest && hashOtp(otp, salt) === digest;
    if (!ok) {
      await prisma.erpPurchaseVendorOtp.update({
        where: { id: row.id },
        data: { attempts: { increment: 1 } },
      });
      throw httpError('Invalid OTP', 400);
    }

    await prisma.erpPurchaseVendorOtp.delete({ where: { id: row.id } });
    const sessionToken = randomBytes(32).toString('hex');
    await prisma.erpPurchaseVendorSession.create({
      data: {
        id: randomUUID(),
        inviteId: invite.id,
        email,
        token: sessionToken,
        expiresAt: new Date(Date.now() + SESSION_TTL_MS),
      },
    });

    // Prefill from agency master if email matches
    const contractor = await prisma.erpContractor.findFirst({
      where: { email: { equals: email, mode: 'insensitive' }, isActive: true },
      include: {
        locations: { orderBy: { sortOrder: 'asc' }, take: 1 },
      },
    });

    const paymentTerms = await prisma.systemLookup.findMany({
      where: { category: 'PAYMENT_TERMS', isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { label: 'asc' }],
      select: { code: true, label: true },
    });

    return {
      sessionToken,
      email,
      expiresInSeconds: Math.floor(SESSION_TTL_MS / 1000),
      vendor: contractor
        ? {
            id: contractor.id,
            name: contractor.name,
            address: [
              contractor.locations[0]?.address1,
              contractor.locations[0]?.address2,
              contractor.locations[0]?.cityCode,
              contractor.locations[0]?.stateCode,
            ]
              .filter(Boolean)
              .join(', '),
            gstNo: contractor.locations[0]?.gstNo ?? null,
            panNo: contractor.locations[0]?.panNo ?? null,
            stateCode: contractor.locations[0]?.stateCode ?? null,
            paymentTerms: contractor.paymentTerms ?? null,
          }
        : null,
      paymentTermsOptions: paymentTerms,
      lines: invite.purchaseRequest.lines.map((l) => ({
        id: l.id,
        materialId: l.materialId,
        itemCode: l.itemCode,
        brand: l.brand,
        itemName: l.itemName,
        unitCode: l.unitCode,
        size: l.size,
        qty: Number(l.qty),
      })),
      prNumber: invite.purchaseRequest.prNumber,
      projectName: invite.purchaseRequest.project?.name ?? null,
    };
  },

  async submitQuotation(token: string, sessionToken: string | null, body: Record<string, unknown>) {
    await assertPortalEnabled();
    const invite = await loadInviteByToken(token);
    const session = await requireSession(invite.id, sessionToken);

    const vendorName = str(body.vendorName);
    if (!vendorName) throw httpError('Company / vendor name is required');

    // Match contractor by verified email when possible
    const contractor = await prisma.erpContractor.findFirst({
      where: { email: { equals: session.email, mode: 'insensitive' }, isActive: true },
      select: { id: true },
    });

    const quote = await quotationService.create(
      invite.purchaseRequestId,
      {
        ...body,
        vendorId: contractor?.id ?? str(body.vendorId),
        vendorName,
        vendorEmail: session.email,
        vendorStateCode: str(body.vendorStateCode),
      },
      { userId: `vendor-portal:${session.email}` },
    );

    // Mark as submitted via portal
    const updated = await prisma.erpPurchaseQuotation.update({
      where: { id: quote.id },
      data: {
        vendorEmail: session.email,
        submittedViaPortal: true,
        status: ErpPurchaseQuotationStatus.SUBMITTED,
        submittedAt: new Date(),
      },
      include: { lines: { orderBy: { sortOrder: 'asc' } } },
    });

    try {
      await sendVendorQuotationConfirmationEmail(session.email, {
        prNumber: invite.purchaseRequest.prNumber,
        quotationNo: updated.quotationNo,
        vendorName: updated.vendorName,
        finalAmount: Number(updated.finalAmount || updated.totalAmount),
        lines: updated.lines.map((l) => ({
          itemName: l.itemName,
          qty: Number(l.qty),
          rate: Number(l.rate),
          amount: Number(l.amount),
        })),
      });
    } catch (e) {
      console.warn('Vendor quotation confirmation email failed', e);
    }

    return {
      id: updated.id,
      quotationNo: updated.quotationNo,
      status: updated.status,
      totalAmount: Number(updated.totalAmount),
      finalAmount: Number(updated.finalAmount),
      vendorEmail: updated.vendorEmail,
      message: 'Quotation submitted successfully. A confirmation email has been sent.',
    };
  },
};
