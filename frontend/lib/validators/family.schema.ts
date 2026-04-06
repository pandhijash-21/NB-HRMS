import { z } from "zod";

export const familyMemberSchema = z.object({
  id: z.string().optional(),
  name: z.string().min(1, "Name is required"),
  relation: z.enum(["SPOUSE", "CHILD", "PARENT", "SIBLING", "OTHER"]),
  otherRelation: z.string().optional(),
  dateOfBirth: z.string().optional(),
  aadhaarNo: z
    .string()
    .min(1, "Aadhaar number is required")
    .regex(/^\d{12}$/, "Aadhaar must be 12 digits"),
  aadhaarUrl: z.string().min(1, "Aadhaar upload is required"),
  city: z.string().min(1, "City is required"),
  phoneNo: z
    .string()
    .min(1, "Phone number is required")
    .regex(/^\d{10}$/, "Phone must be 10 digits"),
  personalEmail: z
    .string()
    .min(1, "Personal email is required")
    .email("Invalid email format"),
  dependent: z.boolean().default(false),
  employed: z.boolean().default(false),
  isNominee: z.boolean().default(false),
  employerName: z.string().optional(),
});

export const familySchema = z.object({
  members: z.array(familyMemberSchema).min(1, "At least one family member is required"),
});

export type FamilyMemberFormData = z.infer<typeof familyMemberSchema>;
export type FamilyFormData = z.infer<typeof familySchema>;
