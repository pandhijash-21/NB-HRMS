import { Prisma } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { sseService } from '../events/sse.service';
import { employeeService } from '../personal-education/employee.service';
import { parseBirthDateInput } from '../../utils/dobPassword';

const SELECTED = 'SELECTED';
const NEXT_ROUND_STATUSES = new Set(['SELECTED_FOR_NEXT_ROUND', 'FINAL_ROUND']);
/** Outcomes that admin can confirm (locks interviewer edits). */
const CONFIRMABLE_STATUSES = new Set([
  'SELECTED',
  'REJECTED',
  'DROPOUT',
  'NOT_CAME',
  'INTERVIEW_ATTENDED',
  'ON_HOLD',
  'SELECTED_FOR_NEXT_ROUND',
  'FINAL_ROUND',
]);
const OPEN_STATUSES = new Set(['INTERVIEW_SCHEDULED', 'RESCHEDULED']);

async function confirmRoundTx(
  tx: Prisma.TransactionClient,
  roundId: string,
  actorId: string,
) {
  await tx.interviewRound.update({
    where: { id: roundId },
    data: {
      adminConfirmedAt: new Date(),
      adminConfirmedBy: actorId,
      updatedBy: actorId,
    },
  });
}

const requirementInclude = {
  institute: { select: { id: true, code: true, name: true } },
  designation: { select: { id: true, name: true, slug: true } },
  _count: { select: { candidates: true } },
} as const;

const candidateInclude = {
  requirement: {
    include: {
      institute: { select: { id: true, code: true, name: true } },
      designation: { select: { id: true, name: true } },
    },
  },
  rounds: { orderBy: { roundNumber: 'asc' as const } },
  hiredEmployee: {
    select: {
      id: true,
      generalInfo: { select: { fullName: true, employeeCode: true } },
    },
  },
} as const;

function parseDate(v: unknown): Date | null {
  if (v == null || v === '') return null;
  const s = String(v).trim();
  // Date-only (YYYY-MM-DD) — store at UTC noon to avoid off-by-one on @db.Date
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s);
  if (m && !s.includes('T')) {
    return new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]), 12, 0, 0));
  }
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
}

async function interviewerNameMap(userIds: string[]): Promise<Record<string, string>> {
  const ids = [...new Set(userIds.filter(Boolean))];
  if (ids.length === 0) return {};

  const out: Record<string, string> = {};

  const users = await prisma.user.findMany({
    where: { id: { in: ids } },
    select: {
      id: true,
      username: true,
      employee: {
        select: {
          generalInfo: { select: { fullName: true, employeeCode: true } },
        },
      },
      positionSlot: {
        select: {
          name: true,
          code: true,
          designation: { select: { name: true } },
        },
      },
    },
  });

  for (const u of users) {
    const empName = u.employee?.generalInfo?.fullName;
    const empCode = u.employee?.generalInfo?.employeeCode;
    if (empName) {
      out[u.id] = empCode ? `${empName} (${empCode})` : empName;
      continue;
    }
    const slot = u.positionSlot;
    if (slot) {
      const label = slot.name || slot.designation?.name || slot.code;
      out[u.id] = slot.code ? `${label} (${slot.code})` : label;
      continue;
    }
    if (u.username) {
      out[u.id] = u.username;
      continue;
    }
    out[u.id] = u.id;
  }

  // Position slots where userId matches but User.positionSlot reverse relation missed
  const missing = ids.filter((id) => !out[id] || out[id] === id);
  if (missing.length) {
    const slots = await prisma.positionSlot.findMany({
      where: { userId: { in: missing } },
      select: {
        userId: true,
        name: true,
        code: true,
        designation: { select: { name: true } },
      },
    });
    for (const slot of slots) {
      if (!slot.userId) continue;
      const label = slot.name || slot.designation?.name || slot.code;
      out[slot.userId] = slot.code ? `${label} (${slot.code})` : label;
    }
  }

  return out;
}

function attachInterviewerNames<T extends { interviewerUserId: string }>(
  rounds: T[],
  names: Record<string, string>,
) {
  return rounds.map((r) => ({
    ...r,
    interviewerName: names[r.interviewerUserId] ?? null,
  }));
}

async function enrichCandidate<T extends { rounds: { interviewerUserId: string }[] }>(row: T) {
  const names = await interviewerNameMap(row.rounds.map((r) => r.interviewerUserId));
  return {
    ...row,
    rounds: attachInterviewerNames(row.rounds, names),
  };
}

async function enrichCandidates<T extends { rounds: { interviewerUserId: string }[] }>(rows: T[]) {
  const ids = rows.flatMap((r) => r.rounds.map((x) => x.interviewerUserId));
  const names = await interviewerNameMap(ids);
  return rows.map((row) => ({
    ...row,
    rounds: attachInterviewerNames(row.rounds, names),
  }));
}

function decimalOrNull(v: unknown): Prisma.Decimal | null {
  if (v == null || v === '') return null;
  const n = Number(v);
  if (!Number.isFinite(n)) return null;
  return new Prisma.Decimal(n);
}

async function resolveReportingManagerEmployeeId(userId: string | null | undefined): Promise<number | null> {
  if (!userId) return null;
  const u = await prisma.user.findUnique({
    where: { id: userId },
    select: { employeeId: true },
  });
  return u?.employeeId ?? null;
}

export const recruitmentService = {
  // ─── Requirements ──────────────────────────────────────────────────────────

  async listActiveRequirements() {
    return prisma.jobRequirement.findMany({
      where: { isActive: true },
      include: requirementInclude,
      orderBy: { createdAt: 'desc' },
    });
  },

  async listAllRequirements(opts?: { activeOnly?: boolean }) {
    return prisma.jobRequirement.findMany({
      where: opts?.activeOnly ? { isActive: true } : undefined,
      include: requirementInclude,
      orderBy: [{ isActive: 'desc' }, { createdAt: 'desc' }],
    });
  },

  async getRequirement(id: string) {
    const row = await prisma.jobRequirement.findUnique({
      where: { id },
      include: {
        ...requirementInclude,
        candidates: {
          include: { rounds: { orderBy: { roundNumber: 'asc' } } },
          orderBy: { createdAt: 'desc' },
        },
      },
    });
    if (!row) throw new Error('Job requirement not found');
    return row;
  },

  async createRequirement(
    input: {
      instituteId: string;
      department: string;
      designationId: string;
      employmentTypeCode: string;
      jobLocation: string;
      branchLocation: string;
      vacancies?: number;
      reportingManagerUserId?: string | null;
      ctc?: unknown;
      requiredEducation?: string | null;
      requiredExperience?: string | null;
      requiredSkills?: string | null;
      isActive?: boolean;
    },
    actorId: string,
  ) {
    const institute = await prisma.institute.findUnique({ where: { id: input.instituteId } });
    if (!institute) throw new Error('Institute not found');
    const designation = await prisma.designation.findUnique({ where: { id: input.designationId } });
    if (!designation) throw new Error('Designation not found — create it under Designations first');
    if (!designation.isActive) throw new Error('Designation is inactive');

    const vacancies = Math.max(1, Number(input.vacancies ?? 1) || 1);

    return prisma.jobRequirement.create({
      data: {
        instituteId: input.instituteId,
        department: String(input.department ?? '').trim(),
        designationId: input.designationId,
        employmentTypeCode: String(input.employmentTypeCode ?? '').trim().toUpperCase(),
        jobLocation: String(input.jobLocation ?? '').trim(),
        branchLocation: String(input.branchLocation ?? '').trim(),
        vacancies,
        reportingManagerUserId: input.reportingManagerUserId || null,
        ctc: decimalOrNull(input.ctc),
        requiredEducation: input.requiredEducation?.trim() || null,
        requiredExperience: input.requiredExperience?.trim() || null,
        requiredSkills: input.requiredSkills?.trim() || null,
        isActive: input.isActive !== false,
        createdBy: actorId,
        updatedBy: actorId,
      },
      include: requirementInclude,
    });
  },

  async updateRequirement(
    id: string,
    input: Partial<{
      instituteId: string;
      department: string;
      designationId: string;
      employmentTypeCode: string;
      jobLocation: string;
      branchLocation: string;
      vacancies: number;
      reportingManagerUserId: string | null;
      ctc: unknown;
      requiredEducation: string | null;
      requiredExperience: string | null;
      requiredSkills: string | null;
      isActive: boolean;
    }>,
    actorId: string,
  ) {
    const existing = await prisma.jobRequirement.findUnique({ where: { id } });
    if (!existing) throw new Error('Job requirement not found');

    if (input.designationId) {
      const designation = await prisma.designation.findUnique({ where: { id: input.designationId } });
      if (!designation) throw new Error('Designation not found');
    }
    if (input.instituteId) {
      const institute = await prisma.institute.findUnique({ where: { id: input.instituteId } });
      if (!institute) throw new Error('Institute not found');
    }

    return prisma.jobRequirement.update({
      where: { id },
      data: {
        ...(input.instituteId != null ? { instituteId: input.instituteId } : {}),
        ...(input.department != null ? { department: String(input.department).trim() } : {}),
        ...(input.designationId != null ? { designationId: input.designationId } : {}),
        ...(input.employmentTypeCode != null
          ? { employmentTypeCode: String(input.employmentTypeCode).trim().toUpperCase() }
          : {}),
        ...(input.jobLocation != null ? { jobLocation: String(input.jobLocation).trim() } : {}),
        ...(input.branchLocation != null ? { branchLocation: String(input.branchLocation).trim() } : {}),
        ...(input.vacancies != null ? { vacancies: Math.max(1, Number(input.vacancies) || 1) } : {}),
        ...(input.reportingManagerUserId !== undefined
          ? { reportingManagerUserId: input.reportingManagerUserId || null }
          : {}),
        ...(input.ctc !== undefined ? { ctc: decimalOrNull(input.ctc) } : {}),
        ...(input.requiredEducation !== undefined
          ? { requiredEducation: input.requiredEducation?.trim() || null }
          : {}),
        ...(input.requiredExperience !== undefined
          ? { requiredExperience: input.requiredExperience?.trim() || null }
          : {}),
        ...(input.requiredSkills !== undefined
          ? { requiredSkills: input.requiredSkills?.trim() || null }
          : {}),
        ...(input.isActive !== undefined ? { isActive: Boolean(input.isActive) } : {}),
        updatedBy: actorId,
      },
      include: requirementInclude,
    });
  },

  async setRequirementActive(id: string, isActive: boolean, actorId: string) {
    return this.updateRequirement(id, { isActive }, actorId);
  },

  // ─── Candidates ────────────────────────────────────────────────────────────

  async listCandidates(opts?: { requirementId?: string }) {
    const rows = await prisma.recruitmentCandidate.findMany({
      where: opts?.requirementId ? { requirementId: opts.requirementId } : undefined,
      include: candidateInclude,
      orderBy: { createdAt: 'desc' },
    });
    return enrichCandidates(rows);
  },

  async getCandidate(id: string) {
    const row = await prisma.recruitmentCandidate.findUnique({
      where: { id },
      include: candidateInclude,
    });
    if (!row) throw new Error('Candidate not found');
    return enrichCandidate(row);
  },

  async createCandidate(
    input: {
      requirementId: string;
      fullName: string;
      contactNumber: string;
      sourceCode: string;
      resumeReceivedDate?: unknown;
      resumeUrl?: string | null;
      resumeFileName?: string | null;
      interviewTypeCode: string;
      interviewerUserId: string;
      scheduledAt?: unknown;
      remarks?: string | null;
    },
    actorId: string,
  ) {
    const req = await prisma.jobRequirement.findUnique({ where: { id: input.requirementId } });
    if (!req) throw new Error('Job requirement not found');
    if (!req.isActive) throw new Error('Can only add candidates to active (open) job requirements');

    const fullName = String(input.fullName ?? '').trim();
    const contactNumber = String(input.contactNumber ?? '').trim();
    if (!fullName) throw new Error('Candidate name is required');
    if (!contactNumber) throw new Error('Contact number is required');
    if (!input.interviewerUserId) throw new Error('Interviewer is required');
    if (!input.interviewTypeCode) throw new Error('Interview type is required');

    const statusCode = 'INTERVIEW_SCHEDULED';

    const created = await prisma.$transaction(async (tx) => {
      const candidate = await tx.recruitmentCandidate.create({
        data: {
          requirementId: input.requirementId,
          fullName,
          contactNumber,
          sourceCode: String(input.sourceCode ?? '').trim().toUpperCase() || 'OTHER',
          resumeReceivedDate: parseDate(input.resumeReceivedDate),
          resumeUrl: input.resumeUrl?.trim() || null,
          resumeFileName: input.resumeFileName?.trim() || null,
          currentStatusCode: statusCode,
          createdBy: actorId,
          updatedBy: actorId,
        },
      });

      await tx.interviewRound.create({
        data: {
          candidateId: candidate.id,
          roundNumber: 1,
          interviewTypeCode: String(input.interviewTypeCode).trim().toUpperCase(),
          interviewerUserId: input.interviewerUserId,
          scheduledAt: parseDate(input.scheduledAt),
          statusCode,
          remarks: input.remarks?.trim() || null,
          createdBy: actorId,
          updatedBy: actorId,
        },
      });

      return tx.recruitmentCandidate.findUniqueOrThrow({
        where: { id: candidate.id },
        include: candidateInclude,
      });
    });
    return enrichCandidate(created);
  },

  async updateCandidate(
    id: string,
    input: Partial<{
      fullName: string;
      contactNumber: string;
      sourceCode: string;
      resumeReceivedDate: unknown;
      resumeUrl: string | null;
      resumeFileName: string | null;
    }>,
    actorId: string,
  ) {
    const existing = await prisma.recruitmentCandidate.findUnique({ where: { id } });
    if (!existing) throw new Error('Candidate not found');

    return enrichCandidate(
      await prisma.recruitmentCandidate.update({
      where: { id },
      data: {
        ...(input.fullName != null ? { fullName: String(input.fullName).trim() } : {}),
        ...(input.contactNumber != null ? { contactNumber: String(input.contactNumber).trim() } : {}),
        ...(input.sourceCode != null
          ? { sourceCode: String(input.sourceCode).trim().toUpperCase() }
          : {}),
        ...(input.resumeReceivedDate !== undefined
          ? { resumeReceivedDate: parseDate(input.resumeReceivedDate) }
          : {}),
        ...(input.resumeUrl !== undefined ? { resumeUrl: input.resumeUrl?.trim() || null } : {}),
        ...(input.resumeFileName !== undefined
          ? { resumeFileName: input.resumeFileName?.trim() || null }
          : {}),
        updatedBy: actorId,
      },
      include: candidateInclude,
    }),
    );
  },

  // ─── Rounds ────────────────────────────────────────────────────────────────

  async scheduleNextRound(
    candidateId: string,
    input: {
      interviewTypeCode: string;
      interviewerUserId: string;
      scheduledAt?: unknown;
      remarks?: string | null;
      statusCode?: string;
    },
    actorId: string,
  ) {
    const candidate = await prisma.recruitmentCandidate.findUnique({
      where: { id: candidateId },
      include: { rounds: { orderBy: { roundNumber: 'desc' }, take: 1 } },
    });
    if (!candidate) throw new Error('Candidate not found');
    if (candidate.hiredEmployeeId) throw new Error('Candidate already hired');
    if (candidate.currentStatusCode === SELECTED) {
      throw new Error('Candidate is Selected — use hire instead of scheduling another round');
    }

    const last = candidate.rounds[0];
    if (last && !NEXT_ROUND_STATUSES.has(last.statusCode) && last.statusCode !== 'RESCHEDULED') {
      // Allow admin to schedule anyway if current status suggests progression
      if (!NEXT_ROUND_STATUSES.has(candidate.currentStatusCode)) {
        throw new Error(
          'Next round is allowed when status is Selected for Next Round or Final Round',
        );
      }
    }

    const nextNumber = (last?.roundNumber ?? 0) + 1;
    const statusCode = String(input.statusCode ?? 'INTERVIEW_SCHEDULED').trim().toUpperCase();

    const updated = await prisma.$transaction(async (tx) => {
      // Scheduling next round confirms the previous outcome for the interviewer.
      if (last && !last.adminConfirmedAt) {
        await confirmRoundTx(tx, last.id, actorId);
      }

      await tx.interviewRound.create({
        data: {
          candidateId,
          roundNumber: nextNumber,
          interviewTypeCode: String(input.interviewTypeCode).trim().toUpperCase(),
          interviewerUserId: input.interviewerUserId,
          scheduledAt: parseDate(input.scheduledAt),
          statusCode,
          remarks: input.remarks?.trim() || null,
          createdBy: actorId,
          updatedBy: actorId,
        },
      });

      await tx.recruitmentCandidate.update({
        where: { id: candidateId },
        data: { currentStatusCode: statusCode, updatedBy: actorId },
      });

      return tx.recruitmentCandidate.findUniqueOrThrow({
        where: { id: candidateId },
        include: candidateInclude,
      });
    });
    return enrichCandidate(updated);
  },

  async listMyPendingInterviews(interviewerUserId: string) {
    // Show all rounds assigned to this interviewer (active candidates):
    // editable until admin confirms; confirmed ones stay visible read-only.
    const rows = await prisma.interviewRound.findMany({
      where: {
        interviewerUserId,
        candidate: { hiredEmployeeId: null },
      },
      include: {
        candidate: {
          include: {
            requirement: {
              include: {
                institute: { select: { id: true, code: true, name: true } },
                designation: { select: { id: true, name: true } },
              },
            },
            rounds: { orderBy: { roundNumber: 'asc' as const } },
          },
        },
      },
      orderBy: [{ adminConfirmedAt: 'asc' }, { scheduledAt: 'asc' }, { createdAt: 'asc' }],
    });

    const nameIds = [
      ...rows.map((r) => r.interviewerUserId),
      ...rows.flatMap((r) => r.candidate.rounds.map((x) => x.interviewerUserId)),
    ];
    const names = await interviewerNameMap(nameIds);
    return rows.map((row) => ({
      ...row,
      interviewerName: names[row.interviewerUserId] ?? null,
      isLocked: row.adminConfirmedAt != null,
      canUpdate: row.adminConfirmedAt == null,
      candidate: {
        ...row.candidate,
        rounds: attachInterviewerNames(row.candidate.rounds, names),
      },
    }));
  },

  async confirmRoundStatus(roundId: string, actorId: string) {
    const round = await prisma.interviewRound.findUnique({
      where: { id: roundId },
      include: {
        candidate: {
          include: {
            requirement: {
              include: { designation: { select: { name: true } } },
            },
          },
        },
      },
    });
    if (!round) throw new Error('Interview round not found');
    if (round.adminConfirmedAt) {
      return enrichCandidate(
        await prisma.recruitmentCandidate.findUniqueOrThrow({
          where: { id: round.candidateId },
          include: candidateInclude,
        }),
      );
    }
    if (OPEN_STATUSES.has(round.statusCode)) {
      throw new Error('Confirm is only allowed after the interviewer sets an outcome status');
    }
    if (!CONFIRMABLE_STATUSES.has(round.statusCode)) {
      throw new Error(`Cannot confirm status ${round.statusCode}`);
    }

    const updated = await prisma.$transaction(async (tx) => {
      await confirmRoundTx(tx, roundId, actorId);
      return tx.recruitmentCandidate.findUniqueOrThrow({
        where: { id: round.candidateId },
        include: candidateInclude,
      });
    });

    sseService.toAdmins('recruitment_status_updated', {
      candidateId: round.candidateId,
      candidateName: round.candidate.fullName,
      roundId,
      roundNumber: round.roundNumber,
      statusCode: round.statusCode,
      designation: round.candidate.requirement.designation.name,
      remarks: round.remarks ?? null,
      updatedBy: actorId,
      adminConfirmed: true,
      at: new Date().toISOString(),
    });

    return enrichCandidate(updated);
  },

  async updateRoundStatus(
    roundId: string,
    input: { statusCode: string; remarks?: string | null },
    actorUserId: string,
    opts?: { privilegedAdmin?: boolean },
  ) {
    const round = await prisma.interviewRound.findUnique({
      where: { id: roundId },
      include: {
        candidate: {
          include: {
            requirement: {
              include: { designation: { select: { name: true } } },
            },
          },
        },
      },
    });
    if (!round) throw new Error('Interview round not found');
    if (!opts?.privilegedAdmin && round.interviewerUserId !== actorUserId) {
      throw new Error('Only the assigned interviewer can update this round');
    }
    if (!opts?.privilegedAdmin && round.adminConfirmedAt) {
      throw new Error(
        'This round is confirmed by Admin — details are view-only for the interviewer',
      );
    }

    const statusCode = String(input.statusCode ?? '').trim().toUpperCase();
    if (!statusCode) throw new Error('Status is required');

    const terminalish = [
      'SELECTED',
      'REJECTED',
      'DROPOUT',
      'NOT_CAME',
      'INTERVIEW_ATTENDED',
      'ON_HOLD',
      'SELECTED_FOR_NEXT_ROUND',
      'FINAL_ROUND',
    ];
    const completedAt = terminalish.includes(statusCode) ? new Date() : null;

    const updated = await prisma.$transaction(async (tx) => {
      await tx.interviewRound.update({
        where: { id: roundId },
        data: {
          statusCode,
          remarks: input.remarks !== undefined ? input.remarks?.trim() || null : undefined,
          completedAt,
          updatedBy: actorUserId,
          // Admin changing status after confirm keeps lock; interviewer path is blocked above.
          // If admin edits an unconfirmed round, leave confirmation unset.
        },
      });

      await tx.recruitmentCandidate.update({
        where: { id: round.candidateId },
        data: { currentStatusCode: statusCode, updatedBy: actorUserId },
      });

      return tx.recruitmentCandidate.findUniqueOrThrow({
        where: { id: round.candidateId },
        include: candidateInclude,
      });
    });

    sseService.toAdmins('recruitment_status_updated', {
      candidateId: round.candidateId,
      candidateName: round.candidate.fullName,
      roundId,
      roundNumber: round.roundNumber,
      statusCode,
      designation: round.candidate.requirement.designation.name,
      remarks: input.remarks ?? null,
      updatedBy: actorUserId,
      at: new Date().toISOString(),
    });

    return enrichCandidate(updated);
  },

  // ─── Hire ──────────────────────────────────────────────────────────────────

  async hireCandidate(
    candidateId: string,
    input: {
      employeeCode: string;
      offeredSalary?: unknown;
      expectedJoiningDate?: unknown;
      actualJoiningDate?: unknown;
      hireRemarks?: string | null;
      personalEmail?: string | null;
      birthDate?: unknown;
    },
    actorId: string,
  ) {
    const candidate = await prisma.recruitmentCandidate.findUnique({
      where: { id: candidateId },
      include: {
        requirement: {
          include: {
            designation: true,
            institute: true,
          },
        },
        rounds: { orderBy: { roundNumber: 'desc' }, take: 1 },
      },
    });
    if (!candidate) throw new Error('Candidate not found');
    if (candidate.hiredEmployeeId) throw new Error('Candidate already hired');
    if (candidate.currentStatusCode !== SELECTED) {
      throw new Error('Hire is only allowed when candidate status is Selected');
    }

    const employeeCode = String(input.employeeCode ?? '').trim();
    if (!employeeCode) throw new Error('Employee code is required');

    const birthRaw = input.birthDate;
    if (birthRaw == null || String(birthRaw).trim() === '') {
      throw new Error('Birth date is required to generate login credentials');
    }
    const birthDate = parseBirthDateInput(String(birthRaw).trim());

    const joining =
      parseDate(input.actualJoiningDate) ??
      parseDate(input.expectedJoiningDate) ??
      new Date();

    const personalEmail =
      String(input.personalEmail ?? '').trim() ||
      `${employeeCode.toLowerCase().replace(/[^a-z0-9]/g, '')}@pending.local`;

    const reportingEmpId = await resolveReportingManagerEmployeeId(
      candidate.requirement.reportingManagerUserId,
    );

    const created = await employeeService.createFull(
      {
        fullName: candidate.fullName,
        personalEmail,
        designation: candidate.requirement.designation.name,
        department: candidate.requirement.department,
        joiningDate: joining,
        employeeCategory: 'NON_TEACHING',
        employeeCode,
        birthDate,
        // Job designation comes from the requirement; do not pass it as positionDesignationId
        // (that field is for institutional position aliases only).
        firstReportingId: reportingEmpId,
        instituteId: candidate.requirement.instituteId,
        subOrganization: candidate.requirement.institute.name,
      },
      actorId,
    );

    const last = candidate.rounds[0];
    const updated = await prisma.$transaction(async (tx) => {
      if (last && !last.adminConfirmedAt) {
        await confirmRoundTx(tx, last.id, actorId);
      }
      return tx.recruitmentCandidate.update({
        where: { id: candidateId },
        data: {
          hiredEmployeeId: created.id,
          offeredSalary: decimalOrNull(input.offeredSalary),
          expectedJoiningDate: parseDate(input.expectedJoiningDate),
          actualJoiningDate: parseDate(input.actualJoiningDate) ?? joining,
          hireRemarks: input.hireRemarks?.trim() || null,
          updatedBy: actorId,
        },
        include: candidateInclude,
      });
    });

    return { candidate: updated, employee: created };
  },
};
