import nodemailer from 'nodemailer';
import { v4 as uuidv4 } from 'uuid';
import { env } from '../../config/env';
import { getRedisClient } from '../../config/redis';

const OTP_EXPIRY_SECONDS = 300; // 5 minutes
const OTP_LENGTH = 6;

function generateOtp(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function getOtpKey(email: string): string {
  return `otp:${email.toLowerCase()}`;
}

export const otpService = {
  async sendOtp(email: string, userId: string): Promise<void> {
    const redis = getRedisClient();
    const otp = generateOtp();
    const token = uuidv4();
    
    const otpData = JSON.stringify({
      otp,
      userId,
      createdAt: Date.now(),
      attempts: 0,
    });

    // Store OTP in Redis
    await redis.setEx(getOtpKey(email), OTP_EXPIRY_SECONDS, otpData);

    // Create email transporter
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: env.SMTP_USER,
        pass: env.SMTP_PASS,
      },
    });

    const mailOptions = {
      from: env.SMTP_FROM || 'noreply@gandhinagaruni.ac.in',
      to: email,
      subject: 'HRMS Email Verification - One Time Password',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="background: linear-gradient(135deg, #1d3459 0%, #2a4a7f 100%); padding: 30px; text-align: center;">
            <h1 style="color: white; margin: 0; font-size: 24px;">Gandhinagar University HRMS</h1>
            <p style="color: rgba(255,255,255,0.8); margin: 10px 0 0;">Email Verification</p>
          </div>
          <div style="padding: 30px; background: #f8fafc;">
            <p style="font-size: 16px; color: #333;">Hello,</p>
            <p style="font-size: 16px; color: #333;">Your one-time password (OTP) for email verification is:</p>
            <div style="background: white; border: 2px dashed #1d3459; border-radius: 8px; padding: 20px; text-align: center; margin: 20px 0;">
              <span style="font-size: 36px; font-weight: bold; color: #1d3459; letter-spacing: 8px;">${otp}</span>
            </div>
            <p style="font-size: 14px; color: #666;">This OTP is valid for <strong>5 minutes</strong>. Please do not share this code with anyone.</p>
            <p style="font-size: 12px; color: #999; margin-top: 20px;">If you did not request this OTP, please ignore this email.</p>
          </div>
          <div style="padding: 20px; text-align: center; color: #999; font-size: 12px;">
            <p>Gandhinagar University HRMS System</p>
            <p>This is an automated message. Please do not reply.</p>
          </div>
        </div>
      `,
    };

    try {
      await transporter.sendMail(mailOptions);
    } catch (err: any) {
      console.error('Failed to send OTP email:', err);
      // If email fails, still keep the OTP in Redis for testing
      // In production, you'd want to handle this differently
      if (env.NODE_ENV === 'production') {
        throw new Error('Failed to send verification email');
      }
    }
  },

  async verifyOtp(email: string, otp: string, userId: string): Promise<boolean> {
    const redis = getRedisClient();
    const key = getOtpKey(email);
    
    const storedData = await redis.get(key);
    
    if (!storedData) {
      return false;
    }

    const data = JSON.parse(storedData);
    
    // Check if OTP matches and user matches
    if (data.otp !== otp) {
      // Increment attempts
      data.attempts += 1;
      if (data.attempts >= 3) {
        // Too many failed attempts, delete the OTP
        await redis.del(key);
        throw new Error('Too many failed attempts. Please request a new OTP.');
      }
      await redis.setEx(key, OTP_EXPIRY_SECONDS, JSON.stringify(data));
      return false;
    }

    if (data.userId !== userId) {
      return false;
    }

    // Mark email as verified in Redis (longer expiry or permanent)
    await redis.set(`verified:${email.toLowerCase()}`, userId, { EX: 86400 * 30 }); // 30 days
    
    // Delete the used OTP
    await redis.del(key);

    return true;
  },

  async isEmailVerified(email: string): Promise<boolean> {
    const redis = getRedisClient();
    const verified = await redis.get(`verified:${email.toLowerCase()}`);
    return !!verified;
  },
};
