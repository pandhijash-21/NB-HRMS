import { z } from "zod";

export const personalInfoSchema = z.object({
  fatherName: z.string().optional(),
  motherName: z.string().optional(),
  spouseName: z.string().optional(),
  dateOfBirth: z.string().min(1, "Date of birth is required"),
  gender: z.enum(["MALE", "FEMALE", "OTHER"]),
  category: z.enum(["GENERAL", "OBC", "SC", "ST", "EWS"]).optional(),
  religion: z.string().optional(),
  maritalStatus: z
    .enum(["SINGLE", "MARRIED", "DIVORCED", "WIDOWED"])
    .optional(),
  nationality: z.string().optional(),
  bloodGroup: z
    .enum(["A_POS", "A_NEG", "B_POS", "B_NEG", "O_POS", "O_NEG", "AB_POS", "AB_NEG"])
    .optional(),
  aadhaarNo: z.string().regex(/^\d{12}$/, "Aadhaar must be 12 digits").optional().or(z.literal("")),
  panNo: z.string().regex(/^[A-Z]{5}[0-9]{4}[A-Z]$/, "Invalid PAN format").optional().or(z.literal("")),
  pfNo: z.string().optional(),
  uanNo: z.string().optional(),
  emergencyContactName: z.string().optional(),
  emergencyContactPhone: z.string().optional(),
});

export type PersonalInfoFormData = z.infer<typeof personalInfoSchema>;
