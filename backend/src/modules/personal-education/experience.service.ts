import { prisma } from '../../config/prisma';

export type ExperienceInput = {
  type: string;
  designation: string;
  organizationName: string;
  fromDate: Date;
  toDate: Date;
  jobDescription?: string | null;
  lastSalary?: number | null;
  experienceLetterUrl?: string | null;
  lastPaycheckUrl?: string | null;
  recommendationLetters?: string[];
};

export const experienceService = {
  list(employeeId: number) {
    return prisma.employeeExperience.findMany({
      where: { employeeId },
      orderBy: [{ fromDate: 'desc' }, { createdAt: 'desc' }],
    });
  },

  create(employeeId: number, input: ExperienceInput) {
    return prisma.employeeExperience.create({
      data: {
        employeeId,
        ...input,
        recommendationLetters: input.recommendationLetters ?? [],
      },
    });
  },

  async update(employeeId: number, experienceId: string, input: Partial<ExperienceInput>) {
    const existing = await prisma.employeeExperience.findFirst({
      where: { id: experienceId, employeeId },
      select: { id: true },
    });
    if (!existing) return null;
    return prisma.employeeExperience.update({
      where: { id: experienceId },
      data: input,
    });
  },

  async remove(employeeId: number, experienceId: string) {
    const existing = await prisma.employeeExperience.findFirst({
      where: { id: experienceId, employeeId },
      select: { id: true },
    });
    if (!existing) return null;
    return prisma.employeeExperience.delete({ where: { id: experienceId } });
  },
};
