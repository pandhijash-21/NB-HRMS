import { z } from "zod";

/** Single dropdown "HSC/Diploma" → user picks HSC vs Diploma here. */
export const academicQualSchema = z
  .object({
    id: z.string().optional(),
    level: z.enum(["SSC", "HSC_DIPLOMA", "UG", "PG", "PHD", "OTHER"]),
    hscDiplomaTrack: z.enum(["HSC", "DIPLOMA"]).optional(),
    medium: z.enum(["GUJARATI", "HINDI", "ENGLISH", "OTHER"]).default("ENGLISH"),
  degreeName: z.string().min(1, "Degree name is required"),
  stream: z.string().optional(),
  hscStream: z.enum(["SCIENCE", "COMMERCE", "ARTS_HUMANITIES"]).optional(),
  institution: z.string().min(1, "Institution is required"),
  schoolCollege: z.string().optional(),
  board: z.string().optional(),
  passingYear: z.coerce
    .number()
    .int()
    .min(1970)
    .max(new Date().getFullYear() + 1),
  percentage: z.coerce.number().min(0).max(100).optional(),
  cgpa: z.coerce.number().min(0).max(10).optional(),
  semMarksheetUrls: z.array(z.string().url()).optional(),
  certificateUrl: z.string().optional(),
  marksheetUrl: z.string().optional(),
  })
  .superRefine((data, ctx) => {
    if (data.level === "HSC_DIPLOMA" && !data.hscDiplomaTrack) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "Select HSC or Diploma",
        path: ["hscDiplomaTrack"],
      });
    }
  });

export const academicSchema = z.object({
  qualifications: z.array(academicQualSchema),
});

export type AcademicQualFormData = z.infer<typeof academicQualSchema>;
export type AcademicFormData = z.infer<typeof academicSchema>;

/** Resolves stored form level to legacy HSC | DIPLOMA | UG | … for UI + API. */
export function getEffectiveAcademicLevel(
  q: Pick<AcademicQualFormData, "level" | "hscDiplomaTrack">
): "SSC" | "HSC" | "DIPLOMA" | "UG" | "PG" | "PHD" | "OTHER" {
  if (q.level === "HSC_DIPLOMA") {
    return (q.hscDiplomaTrack ?? "HSC") as "HSC" | "DIPLOMA";
  }
  return q.level as "SSC" | "UG" | "PG" | "PHD" | "OTHER";
}
