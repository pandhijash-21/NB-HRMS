import { PrismaClient } from '@prisma/client';

type SeedOpt = { category: string; code: string; label: string; sortOrder: number };

const SEED: SeedOpt[] = [
  // Organization
  { category: 'ORGANIZATION', code: 'GANDHINAGAR_UNIVERSITY', label: 'Gandhinagar University', sortOrder: 1 },
  { category: 'ORGANIZATION', code: 'PLATINUM_FOUNDATION', label: 'Platinum Foundation', sortOrder: 2 },

  // Blood group
  { category: 'BLOOD_GROUP', code: 'A_POS', label: 'A+', sortOrder: 1 },
  { category: 'BLOOD_GROUP', code: 'A_NEG', label: 'A−', sortOrder: 2 },
  { category: 'BLOOD_GROUP', code: 'B_POS', label: 'B+', sortOrder: 3 },
  { category: 'BLOOD_GROUP', code: 'B_NEG', label: 'B−', sortOrder: 4 },
  { category: 'BLOOD_GROUP', code: 'O_POS', label: 'O+', sortOrder: 5 },
  { category: 'BLOOD_GROUP', code: 'O_NEG', label: 'O−', sortOrder: 6 },
  { category: 'BLOOD_GROUP', code: 'AB_POS', label: 'AB+', sortOrder: 7 },
  { category: 'BLOOD_GROUP', code: 'AB_NEG', label: 'AB−', sortOrder: 8 },

  // Gender
  { category: 'GENDER', code: 'MALE', label: 'Male', sortOrder: 1 },
  { category: 'GENDER', code: 'FEMALE', label: 'Female', sortOrder: 2 },
  { category: 'GENDER', code: 'OTHER', label: 'Other', sortOrder: 3 },

  // Marital
  { category: 'MARITAL_STATUS', code: 'SINGLE', label: 'Single', sortOrder: 1 },
  { category: 'MARITAL_STATUS', code: 'MARRIED', label: 'Married', sortOrder: 2 },
  { category: 'MARITAL_STATUS', code: 'DIVORCED', label: 'Divorced', sortOrder: 3 },
  { category: 'MARITAL_STATUS', code: 'WIDOWED', label: 'Widowed', sortOrder: 4 },

  // Nationality / tongue / caste / religion
  { category: 'NATIONALITY', code: 'INDIAN', label: 'Indian', sortOrder: 1 },
  { category: 'MOTHER_TONGUE', code: 'GUJARATI', label: 'Gujarati', sortOrder: 1 },
  { category: 'MOTHER_TONGUE', code: 'HINDI', label: 'Hindi', sortOrder: 2 },
  { category: 'MOTHER_TONGUE', code: 'ENGLISH', label: 'English', sortOrder: 3 },
  { category: 'CASTE_CATEGORY', code: 'OPEN', label: 'Open / General', sortOrder: 1 },
  { category: 'CASTE_CATEGORY', code: 'OBC', label: 'OBC', sortOrder: 2 },
  { category: 'CASTE_CATEGORY', code: 'SC', label: 'SC', sortOrder: 3 },
  { category: 'CASTE_CATEGORY', code: 'ST', label: 'ST', sortOrder: 4 },
  { category: 'CASTE_CATEGORY', code: 'EWS', label: 'EWS', sortOrder: 5 },
  { category: 'RELIGION', code: 'HINDU', label: 'Hindu', sortOrder: 1 },
  { category: 'RELIGION', code: 'MUSLIM', label: 'Muslim', sortOrder: 2 },
  { category: 'RELIGION', code: 'CHRISTIAN', label: 'Christian', sortOrder: 3 },
  { category: 'RELIGION', code: 'SIKH', label: 'Sikh', sortOrder: 4 },
  { category: 'RELIGION', code: 'JAIN', label: 'Jain', sortOrder: 5 },
  { category: 'RELIGION', code: 'OTHER', label: 'Other', sortOrder: 6 },

  // Employment
  { category: 'EMPLOYEE_CATEGORY', code: 'TEACHING', label: 'Teaching', sortOrder: 1 },
  { category: 'EMPLOYEE_CATEGORY', code: 'NON_TEACHING', label: 'Non Teaching', sortOrder: 2 },
  { category: 'EMPLOYEE_CATEGORY', code: 'CONTRACT', label: 'Contract', sortOrder: 3 },
  { category: 'EMPLOYEE_CATEGORY', code: 'VISITING', label: 'Visiting', sortOrder: 4 },
  { category: 'APPOINTMENT_TYPE', code: 'FULL_TIME_REGULAR', label: 'Full Time Regular', sortOrder: 1 },
  { category: 'APPOINTMENT_TYPE', code: 'FULL_TIME_CONTRACT', label: 'Full Time Contract', sortOrder: 2 },
  { category: 'APPOINTMENT_TYPE', code: 'PART_TIME', label: 'Part Time', sortOrder: 3 },
  { category: 'APPOINTMENT_TYPE', code: 'VISITING', label: 'Visiting', sortOrder: 4 },
  { category: 'APPOINTMENT_TYPE', code: 'DEPUTATION', label: 'Deputation', sortOrder: 5 },
  { category: 'SHIFT', code: 'GENERAL', label: 'General', sortOrder: 1 },
  { category: 'SHIFT', code: 'MORNING', label: 'Morning', sortOrder: 2 },
  { category: 'SHIFT', code: 'EVENING', label: 'Evening', sortOrder: 3 },

  // Family
  { category: 'FAMILY_RELATION', code: 'FATHER', label: 'Father', sortOrder: 1 },
  { category: 'FAMILY_RELATION', code: 'MOTHER', label: 'Mother', sortOrder: 2 },
  { category: 'FAMILY_RELATION', code: 'SPOUSE', label: 'Spouse', sortOrder: 3 },
  { category: 'FAMILY_RELATION', code: 'SON', label: 'Son', sortOrder: 4 },
  { category: 'FAMILY_RELATION', code: 'DAUGHTER', label: 'Daughter', sortOrder: 5 },
  { category: 'FAMILY_RELATION', code: 'BROTHER', label: 'Brother', sortOrder: 6 },
  { category: 'FAMILY_RELATION', code: 'SISTER', label: 'Sister', sortOrder: 7 },
  { category: 'FAMILY_RELATION', code: 'OTHER', label: 'Other', sortOrder: 8 },

  // Academic
  { category: 'DEGREE_TYPE', code: 'SSC', label: 'SSC', sortOrder: 1 },
  { category: 'DEGREE_TYPE', code: 'HSC', label: 'HSC', sortOrder: 2 },
  { category: 'DEGREE_TYPE', code: 'DIPLOMA', label: 'Diploma', sortOrder: 3 },
  { category: 'DEGREE_TYPE', code: 'BACHELOR', label: 'Bachelor', sortOrder: 4 },
  { category: 'DEGREE_TYPE', code: 'MASTER', label: 'Master', sortOrder: 5 },
  { category: 'DEGREE_TYPE', code: 'PHD', label: 'PhD', sortOrder: 6 },
  { category: 'DEGREE_TYPE', code: 'OTHER', label: 'Other', sortOrder: 7 },
  { category: 'ACADEMIC_MEDIUM', code: 'GUJARATI', label: 'Gujarati', sortOrder: 1 },
  { category: 'ACADEMIC_MEDIUM', code: 'HINDI', label: 'Hindi', sortOrder: 2 },
  { category: 'ACADEMIC_MEDIUM', code: 'ENGLISH', label: 'English', sortOrder: 3 },
  { category: 'ACADEMIC_MEDIUM', code: 'MARATHI', label: 'Marathi', sortOrder: 4 },
  { category: 'ACADEMIC_MEDIUM', code: 'OTHER', label: 'Other', sortOrder: 5 },
  { category: 'HSC_STREAM', code: 'SCIENCE', label: 'Science', sortOrder: 1 },
  { category: 'HSC_STREAM', code: 'COMMERCE', label: 'Commerce', sortOrder: 2 },
  { category: 'HSC_STREAM', code: 'ARTS_HUMANITIES', label: 'Arts / Humanities', sortOrder: 3 },

  // Experience
  { category: 'EXPERIENCE_TYPE', code: 'TEACHING', label: 'Teaching', sortOrder: 1 },
  { category: 'EXPERIENCE_TYPE', code: 'INDUSTRY', label: 'Industry', sortOrder: 2 },
  { category: 'EXPERIENCE_TYPE', code: 'RESEARCH', label: 'Research', sortOrder: 3 },
  { category: 'EXPERIENCE_TYPE', code: 'ADMINISTRATIVE', label: 'Administrative', sortOrder: 4 },
  { category: 'EXPERIENCE_TYPE', code: 'CONSULTANCY', label: 'Consultancy', sortOrder: 5 },
  { category: 'EXPERIENCE_TYPE', code: 'OTHER', label: 'Other', sortOrder: 6 },

  // Banks (starter set)
  { category: 'BANK_NAME', code: 'SBI', label: 'State Bank of India', sortOrder: 1 },
  { category: 'BANK_NAME', code: 'HDFC', label: 'HDFC Bank', sortOrder: 2 },
  { category: 'BANK_NAME', code: 'ICICI', label: 'ICICI Bank', sortOrder: 3 },
  { category: 'BANK_NAME', code: 'AXIS', label: 'Axis Bank', sortOrder: 4 },
  { category: 'BANK_NAME', code: 'BOB', label: 'Bank of Baroda', sortOrder: 5 },

  // Recruitment
  { category: 'INTERVIEW_TYPE', code: 'HR_SCREEN', label: 'HR Screen', sortOrder: 1 },
  { category: 'INTERVIEW_TYPE', code: 'TECHNICAL', label: 'Technical', sortOrder: 2 },
  { category: 'INTERVIEW_TYPE', code: 'DIRECTOR', label: 'Director', sortOrder: 3 },
  { category: 'INTERVIEW_TYPE', code: 'FINAL', label: 'Final Round', sortOrder: 4 },

  { category: 'INTERVIEW_STATUS', code: 'INTERVIEW_SCHEDULED', label: 'Interview Scheduled', sortOrder: 1 },
  { category: 'INTERVIEW_STATUS', code: 'INTERVIEW_ATTENDED', label: 'Interview Attended', sortOrder: 2 },
  { category: 'INTERVIEW_STATUS', code: 'NOT_CAME', label: 'Not came for Interview', sortOrder: 3 },
  { category: 'INTERVIEW_STATUS', code: 'RESCHEDULED', label: 'Rescheduled', sortOrder: 4 },
  { category: 'INTERVIEW_STATUS', code: 'SELECTED_FOR_NEXT_ROUND', label: 'Selected for Next Round', sortOrder: 5 },
  { category: 'INTERVIEW_STATUS', code: 'FINAL_ROUND', label: 'Final Round', sortOrder: 6 },
  { category: 'INTERVIEW_STATUS', code: 'SELECTED', label: 'Selected', sortOrder: 7 },
  { category: 'INTERVIEW_STATUS', code: 'ON_HOLD', label: 'On Hold', sortOrder: 8 },
  { category: 'INTERVIEW_STATUS', code: 'REJECTED', label: 'Rejected', sortOrder: 9 },
  { category: 'INTERVIEW_STATUS', code: 'DROPOUT', label: 'Dropout / Backout', sortOrder: 10 },

  { category: 'CANDIDATE_SOURCE', code: 'REFERRAL', label: 'Referral', sortOrder: 1 },
  { category: 'CANDIDATE_SOURCE', code: 'NAUKRI', label: 'Naukri', sortOrder: 2 },
  { category: 'CANDIDATE_SOURCE', code: 'WALK_IN', label: 'Walk-in', sortOrder: 3 },
  { category: 'CANDIDATE_SOURCE', code: 'LINKEDIN', label: 'LinkedIn', sortOrder: 4 },
  { category: 'CANDIDATE_SOURCE', code: 'WEBSITE', label: 'Website', sortOrder: 5 },
  { category: 'CANDIDATE_SOURCE', code: 'OTHER', label: 'Other', sortOrder: 6 },
];

export async function seedSystemLookups(prisma: PrismaClient) {
  for (const row of SEED) {
    await prisma.systemLookup.upsert({
      where: { category_code: { category: row.category, code: row.code } },
      create: row,
      update: { label: row.label, sortOrder: row.sortOrder },
    });
  }
  console.log(`Seeded ${SEED.length} system lookup options`);
}
