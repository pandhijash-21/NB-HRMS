import { z } from "zod";

export const academicQualSchema = z.object({
  id: z.string().optional(),
  level: z.enum(["SSC", "HSC", "DIPLOMA", "UG", "PG", "PHD", "OTHER"]),
  degreeName: z.string().min(1, "Degree name is required"),
  stream: z.string().optional(),
  institution: z.string().min(1, "Institution is required"),
  board: z.string().optional(),
  passingYear: z.coerce
    .number()
    .int()
    .min(1970)
    .max(new Date().getFullYear() + 1),
  percentage: z.coerce.number().min(0).max(100).optional(),
  cgpa: z.coerce.number().min(0).max(10).optional(),
  semMarksheetUrls: z.array(z.string().url()).optional(),
  certificateUrl: z.string().url().optional().or(z.literal("")),
});

export const academicSchema = z.object({
  qualifications: z.array(academicQualSchema),
});

export type AcademicQualFormData = z.infer<typeof academicQualSchema>;
export type AcademicFormData = z.infer<typeof academicSchema>;
