import { z } from "zod";

export const bankInfoSchema = z.object({
  bankName: z.string().optional(),
  accountNo: z.string().optional(),
  ifscCode: z
    .string()
    .regex(/^[A-Z]{4}0[A-Z0-9]{6}$/, "Invalid IFSC code")
    .optional()
    .or(z.literal("")),
  accountType: z.enum(["SAVINGS", "CURRENT", "SALARY"]).optional(),
  branchName: z.string().optional(),
});

export const otherInfoSchema = z.object({
  bank: bankInfoSchema,
  physicallyHandicapped: z.boolean().default(false),
  exServiceman: z.boolean().default(false),
  handicapPercentage: z.coerce.number().min(0).max(100).optional(),
  passportNo: z.string().optional(),
  passportExpiry: z.string().optional(),
  drivingLicenceNo: z.string().optional(),
  drivingLicenceExpiry: z.string().optional(),
  voterId: z.string().optional(),
});

export type OtherInfoFormData = z.infer<typeof otherInfoSchema>;
