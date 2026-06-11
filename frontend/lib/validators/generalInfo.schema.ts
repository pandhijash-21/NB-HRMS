import { z } from "zod";

export const generalInfoSchema = z.object({
  fullName: z.string().min(1, "Full name is required"),
  originalJoiningDate: z.string().min(1, "Original joining date is required"),
  joiningDate: z.string().min(1, "Joining date is required"),
  incrementMonth: z.string().optional(),
  organization: z.string().min(1, "Organization is required"),
  subOrganization: z.string().optional(),
  department: z.string().min(1, "Department is required"),
  functionalDepartment: z.string().optional(),
  firstApproverUserId: z.string().nullable().optional(),
  secondApproverUserId: z.string().nullable().optional(),
  thirdApproverUserId: z.string().nullable().optional(),
  employeeCategory: z.enum([
    "TEACHING",
    "NON_TEACHING",
    "CONTRACT",
    "VISITING",
  ]),
  designation: z.string().min(1, "Designation is required"),
  shift: z.string().optional(),
  appointmentType: z
    .enum([
      "FULL_TIME_REGULAR",
      "FULL_TIME_CONTRACT",
      "PART_TIME",
      "VISITING",
      "DEPUTATION",
    ])
    .optional(),
});

export type GeneralInfoFormData = z.infer<typeof generalInfoSchema>;
