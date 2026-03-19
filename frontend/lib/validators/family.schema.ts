import { z } from "zod";

export const familyMemberSchema = z.object({
  id: z.string().optional(),
  name: z.string().min(1, "Name is required"),
  relation: z.enum(["SPOUSE", "CHILD", "PARENT", "SIBLING", "OTHER"]),
  dateOfBirth: z.string().optional(),
  aadhaarNo: z
    .string()
    .regex(/^\d{12}$/, "Aadhaar must be 12 digits")
    .optional()
    .or(z.literal("")),
  dependent: z.boolean().default(false),
  employed: z.boolean().default(false),
  employerName: z.string().optional(),
});

export const familySchema = z.object({
  members: z.array(familyMemberSchema),
});

export type FamilyMemberFormData = z.infer<typeof familyMemberSchema>;
export type FamilyFormData = z.infer<typeof familySchema>;
