import { z } from "zod";

export const experienceSchema = z.object({
  id: z.string().optional(),
  type: z.enum([
    "TEACHING",
    "INDUSTRY",
    "RESEARCH",
    "ADMINISTRATIVE",
    "CONSULTANCY",
    "OTHER",
  ]),
  designation: z.string().min(1, "Designation is required"),
  organizationName: z.string().min(1, "Organization name is required"),
  fromDate: z.string().min(1, "Start date is required"),
  toDate: z.string().min(1, "End date is required"),
  jobDescription: z.string().optional(),
  lastSalary: z.coerce.number().min(0).optional(),
  experienceLetterUrl: z.string().optional(),
  lastPaycheckUrl: z.string().optional(),
  recommendationLetters: z.array(z.string()).optional().default([]),
});

export const experienceListSchema = z.object({
  experiences: z.array(experienceSchema),
});

export type ExperienceFormData = z.infer<typeof experienceSchema>;
export type ExperienceListFormData = z.infer<typeof experienceListSchema>;
