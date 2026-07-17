import { prisma } from '../../config/prisma';

type AcademicInput = {
  id?: string;
  degreeType: string;
  degreeName?: string | null;
  medium?: string | null;
  boardUniversity: string;
  schoolCollege: string;
  passingYear: number;
  percentage?: number | null;
  grade?: string | null;
  specialization?: string | null;
  durationYears?: number | null;
  totalSemesters?: number | null;
  certificateUrl?: string | null;
  sem1MarksheetUrl?: string | null;
  sem2MarksheetUrl?: string | null;
  sem3MarksheetUrl?: string | null;
  sem4MarksheetUrl?: string | null;
  sem5MarksheetUrl?: string | null;
  sem6MarksheetUrl?: string | null;
  sem7MarksheetUrl?: string | null;
  sem8MarksheetUrl?: string | null;
  displayOrder?: number;
  updatedBy?: string | null;
};

export const academicService = {
  list(employeeId: number) {
    return prisma.academicQualification.findMany({
      where: { employeeId, isActive: true },
      orderBy: [{ displayOrder: 'asc' }, { createdAt: 'asc' }],
    });
  },

  async create(employeeId: number, input: AcademicInput, actorId?: string) {
    try {
      return await prisma.academicQualification.create({
        data: {
          ...(input.id ? { id: input.id } : {}),
          employeeId,
          degreeType: input.degreeType,
          degreeName: input.degreeName ?? null,
          medium: input.medium ?? null,
          boardUniversity: input.boardUniversity,
          schoolCollege: input.schoolCollege,
          passingYear: input.passingYear,
          percentage: input.percentage ?? null,
          grade: input.grade ?? null,
          specialization: input.specialization ?? null,
          durationYears: input.durationYears ?? null,
          totalSemesters: input.totalSemesters ?? null,
          certificateUrl: input.certificateUrl ?? null,
          sem1MarksheetUrl: input.sem1MarksheetUrl ?? null,
          sem2MarksheetUrl: input.sem2MarksheetUrl ?? null,
          sem3MarksheetUrl: input.sem3MarksheetUrl ?? null,
          sem4MarksheetUrl: input.sem4MarksheetUrl ?? null,
          sem5MarksheetUrl: input.sem5MarksheetUrl ?? null,
          sem6MarksheetUrl: input.sem6MarksheetUrl ?? null,
          sem7MarksheetUrl: input.sem7MarksheetUrl ?? null,
          sem8MarksheetUrl: input.sem8MarksheetUrl ?? null,
          displayOrder: input.displayOrder ?? 0,
          updatedBy: input.updatedBy ?? actorId ?? null,
        },
      });
    } catch (err: any) {
      if (err.code === 'P2002') {
        throw { status: 409, message: `A ${input.degreeType} qualification already exists for this employee. Use PATCH to update it.` };
      }
      throw err;
    }
  },

  async softDelete(qualId: string, employeeId: number) {
    const qual = await prisma.academicQualification.findFirst({
      where: { id: qualId, employeeId, isActive: true },
    });
    if (!qual) throw { status: 404, message: 'Qualification not found' };

    return prisma.academicQualification.update({
      where: { id: qualId },
      data: { isActive: false },
    });
  },

  async update(employeeId: number, qualId: string, patch: Partial<AcademicInput>, actorId?: string) {
    const exists = await prisma.academicQualification.findFirst({
      where: { id: qualId, employeeId, isActive: true },
    });
    if (!exists) return null;

    return prisma.academicQualification.update({
      where: { id: qualId },
      data: {
        degreeName: patch.degreeName ?? undefined,
        medium: patch.medium ?? undefined,
        boardUniversity: patch.boardUniversity ?? undefined,
        schoolCollege: patch.schoolCollege ?? undefined,
        passingYear: patch.passingYear ?? undefined,
        percentage: patch.percentage ?? undefined,
        grade: patch.grade ?? undefined,
        specialization: patch.specialization ?? undefined,
        durationYears: patch.durationYears ?? undefined,
        totalSemesters: patch.totalSemesters ?? undefined,
        certificateUrl: patch.certificateUrl ?? undefined,
        sem1MarksheetUrl: patch.sem1MarksheetUrl ?? undefined,
        sem2MarksheetUrl: patch.sem2MarksheetUrl ?? undefined,
        sem3MarksheetUrl: patch.sem3MarksheetUrl ?? undefined,
        sem4MarksheetUrl: patch.sem4MarksheetUrl ?? undefined,
        sem5MarksheetUrl: patch.sem5MarksheetUrl ?? undefined,
        sem6MarksheetUrl: patch.sem6MarksheetUrl ?? undefined,
        sem7MarksheetUrl: patch.sem7MarksheetUrl ?? undefined,
        sem8MarksheetUrl: patch.sem8MarksheetUrl ?? undefined,
        displayOrder: patch.displayOrder ?? undefined,
        updatedBy: patch.updatedBy ?? actorId ?? undefined,
      },
    });
  },
};

