import { prisma } from '../../config/prisma';
import { getRedisClient } from '../../config/redis';
import { isSmtpConfigured, sendOtpEmail } from '../../utils/mailer';

const OTP_EXPIRY_SECONDS = 300; // 5 minutes
const OTP_RESEND_COOLDOWN_SECONDS = 120; // 2 minutes
const MAX_VERIFY_ATTEMPTS = 3;

export type PendingEmailKind = 'personal' | 'institute';

export type PendingEmail = {
  kind: PendingEmailKind;
  email: string;
  verified: boolean;
};

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function generateOtp(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function getOtpKey(email: string): string {
  return `otp:${normalizeEmail(email)}`;
}

function getCooldownKey(email: string): string {
  return `otp_cooldown:${normalizeEmail(email)}`;
}

function httpError(message: string, status: number): Error & { status: number } {
  const err = new Error(message) as Error & { status: number };
  err.status = status;
  return err;
}

async function getLocalAddress(employeeId: number) {
  return prisma.employeeAddress.findUnique({
    where: {
      employeeId_addressType: { employeeId, addressType: 'LOCAL' },
    },
  });
}

export const otpService = {
  async getEmailVerificationStatus(userId: string, employeeId: number | null) {
    if (employeeId == null) {
      return {
        needsEmailVerification: false,
        emails: [] as PendingEmail[],
      };
    }

    const addr = await getLocalAddress(employeeId);
    const emails: PendingEmail[] = [];

    const personal = addr?.personalEmail?.trim();
    if (personal) {
      emails.push({
        kind: 'personal',
        email: personal,
        verified: !!addr?.personalEmailVerifiedAt,
      });
    }

    const institute = addr?.instituteEmail?.trim();
    if (institute) {
      emails.push({
        kind: 'institute',
        email: institute,
        verified: !!addr?.instituteEmailVerifiedAt,
      });
    }

    // OTP cannot be delivered without mail, so do not block the app.
    const needsEmailVerification = isSmtpConfigured() && emails.some((e) => !e.verified);
    return { needsEmailVerification, emails };
  },

  /** True when employee must finish OTP before using the app (after first password change). */
  async needsEmailVerification(userId: string, employeeId: number | null, isFirstLogin: boolean) {
    if (isFirstLogin) return false;
    const status = await this.getEmailVerificationStatus(userId, employeeId);
    return status.needsEmailVerification;
  },

  async assertOwnsEmail(employeeId: number | null, email: string): Promise<PendingEmailKind> {
    if (employeeId == null) {
      throw httpError('Position accounts do not have employee emails to verify', 400);
    }
    const addr = await getLocalAddress(employeeId);
    const target = normalizeEmail(email);
    if (addr?.personalEmail && normalizeEmail(addr.personalEmail) === target) {
      return 'personal';
    }
    if (addr?.instituteEmail && normalizeEmail(addr.instituteEmail) === target) {
      return 'institute';
    }
    throw httpError('You can only verify your own personal or institutional email', 403);
  },

  async sendOtp(email: string, userId: string): Promise<{ cooldownSeconds: number }> {
    if (!isSmtpConfigured()) {
      throw httpError(
        'SMTP is not configured. Set SMTP_HOST, SMTP_USER, and SMTP_PASS in backend/.env',
        503,
      );
    }

    const redis = getRedisClient();
    const cooldownKey = getCooldownKey(email);
    const remaining = await redis.ttl(cooldownKey);
    if (remaining > 0) {
      throw httpError(
        `Please wait ${remaining} seconds before requesting a new OTP`,
        429,
      );
    }

    const otp = generateOtp();
    const otpData = JSON.stringify({
      otp,
      userId,
      createdAt: Date.now(),
      attempts: 0,
    });

    await redis.setEx(getOtpKey(email), OTP_EXPIRY_SECONDS, otpData);
    await redis.setEx(cooldownKey, OTP_RESEND_COOLDOWN_SECONDS, '1');

    try {
      await sendOtpEmail(email, otp);
    } catch (err: any) {
      await redis.del(getOtpKey(email));
      await redis.del(cooldownKey);
      if (err?.status) throw err;
      console.error('Failed to send OTP email:', err);
      throw httpError('Failed to send verification email', 502);
    }

    return { cooldownSeconds: OTP_RESEND_COOLDOWN_SECONDS };
  },

  async verifyOtp(
    email: string,
    otp: string,
    userId: string,
    employeeId: number | null,
  ): Promise<{ verified: true; kind: PendingEmailKind; needsEmailVerification: boolean }> {
    const kind = await this.assertOwnsEmail(employeeId, email);
    const redis = getRedisClient();
    const key = getOtpKey(email);
    const storedData = await redis.get(key);

    if (!storedData) {
      throw httpError('Invalid or expired OTP. Please request a new code.', 400);
    }

    const data = JSON.parse(storedData) as {
      otp: string;
      userId: string;
      attempts: number;
    };

    if (data.userId !== userId) {
      throw httpError('Invalid or expired OTP. Please request a new code.', 400);
    }

    if (data.otp !== otp) {
      data.attempts += 1;
      const left = MAX_VERIFY_ATTEMPTS - data.attempts;
      if (data.attempts >= MAX_VERIFY_ATTEMPTS) {
        await redis.del(key);
        throw httpError(
          'Too many failed attempts. Please wait and request a new OTP.',
          400,
        );
      }
      await redis.setEx(key, OTP_EXPIRY_SECONDS, JSON.stringify(data));
      throw httpError(
        `Incorrect OTP. ${left} attempt${left === 1 ? '' : 's'} remaining.`,
        400,
      );
    }

    if (employeeId == null) {
      throw httpError('No employee profile linked to this account', 400);
    }

    const field =
      kind === 'personal'
        ? { personalEmailVerifiedAt: new Date() }
        : { instituteEmailVerifiedAt: new Date() };

    await prisma.employeeAddress.update({
      where: {
        employeeId_addressType: { employeeId, addressType: 'LOCAL' },
      },
      data: field,
    });

    await redis.del(key);

    const status = await this.getEmailVerificationStatus(userId, employeeId);
    return {
      verified: true,
      kind,
      needsEmailVerification: status.needsEmailVerification,
    };
  },

  /** Resend cooldown remaining for an email (0 if ready). */
  async getCooldownRemaining(email: string): Promise<number> {
    const redis = getRedisClient();
    const ttl = await redis.ttl(getCooldownKey(email));
    return ttl > 0 ? ttl : 0;
  },

  /**
   * HR/Admin create-employee wizard: validate OTP without writing employee flags.
   * Still enforces 3 failed attempts then invalidates the code.
   */
  async verifyOtpCodeOnly(email: string, otp: string, userId: string): Promise<void> {
    const redis = getRedisClient();
    const key = getOtpKey(email);
    const storedData = await redis.get(key);
    if (!storedData) {
      throw httpError('Invalid or expired OTP. Please request a new code.', 400);
    }
    const data = JSON.parse(storedData) as {
      otp: string;
      userId: string;
      attempts: number;
    };
    if (data.userId !== userId) {
      throw httpError('Invalid or expired OTP. Please request a new code.', 400);
    }
    if (data.otp !== otp) {
      data.attempts += 1;
      if (data.attempts >= MAX_VERIFY_ATTEMPTS) {
        await redis.del(key);
        throw httpError(
          'Too many failed attempts. Please wait and request a new OTP.',
          400,
        );
      }
      await redis.setEx(key, OTP_EXPIRY_SECONDS, JSON.stringify(data));
      const left = MAX_VERIFY_ATTEMPTS - data.attempts;
      throw httpError(
        `Incorrect OTP. ${left} attempt${left === 1 ? '' : 's'} remaining.`,
        400,
      );
    }
    await redis.del(key);
  },
};
