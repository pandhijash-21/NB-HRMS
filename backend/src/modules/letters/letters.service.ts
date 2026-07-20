import { LetterDocumentStatus } from '@prisma/client';
import { prisma } from '../../config/prisma';

type EmployeePlaceholderContext = Record<string, string>;

function escapeHtml(input: string) {
  return input
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function formatDateHuman(d: Date) {
  // en-IN style: DD/MM/YYYY
  const dd = String(d.getDate()).padStart(2, '0');
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const yyyy = d.getFullYear();
  return `${dd}/${mm}/${yyyy}`;
}

async function buildEmployeePlaceholderContext(employeeId: number): Promise<EmployeePlaceholderContext> {
  const employee = await prisma.employee.findUnique({
    where: { id: employeeId },
    include: {
      generalInfo: {
        select: {
          fullName: true,
          employeeCode: true,
          designation: true,
          department: true,
          organization: true,
          institute: { select: { name: true } },
          subOrganization: true,
          joiningDate: true,
        },
      },
      personalInfo: {
        select: {
          birthDate: true,
          aadhaarNo: true,
          panNo: true,
          passportNo: true,
          passportIssueDate: true,
          passportExpiryDate: true,
        },
      },
      otherInfo: true,
    },
  });

  if (!employee) throw new Error('Employee not found');

  const g = employee.generalInfo;
  const p = employee.personalInfo;

  return {
    fullName: g?.fullName ?? '',
    employeeCode: g?.employeeCode ?? '',
    designation: g?.designation ?? '',
    department: g?.department ?? '',
    organization: g?.organization ?? '',
    subOrganization: g?.subOrganization ?? '',
    instituteName: g?.institute?.name ?? g?.subOrganization ?? '',
    joiningDate: g?.joiningDate ? formatDateHuman(new Date(g.joiningDate)) : '',
    birthDate: p?.birthDate ? formatDateHuman(new Date(p.birthDate)) : '',
    aadhaarNo: p?.aadhaarNo ?? '',
    panNo: p?.panNo ?? '',
    passportNo: p?.passportNo ?? '',
    passportIssueDate: p?.passportIssueDate ? formatDateHuman(new Date(p.passportIssueDate)) : '',
    passportExpiryDate: p?.passportExpiryDate ? formatDateHuman(new Date(p.passportExpiryDate)) : '',
    todayDate: formatDateHuman(new Date()),
  };
}

function renderTemplate(templateHtml: string, context: EmployeePlaceholderContext) {
  // Replace tokens like {{fullName}} with escaped values.
  // If a placeholder is unknown, keep it blank.
  return templateHtml.replace(/{{\s*([a-zA-Z0-9_]+)\s*}}/g, (_match, key) => {
    const raw = context[key as keyof EmployeePlaceholderContext] ?? '';
    return escapeHtml(String(raw));
  });
}

export const lettersService = {
  async listTemplates() {
    const templates = await prisma.letterTemplate.findMany({
      where: {
        isActive: true,
        // Hide one-off custom letters from the global Letters config list
        NOT: { key: { startsWith: 'custom_' } },
      },
      orderBy: { updatedAt: 'desc' },
    });
    return templates;
  },

  async upsertTemplate(input: {
    id?: string | null;
    key: string;
    name: string;
    description?: string | null;
    templateHtml: string;
    logoUrl?: string | null;
    placeholders?: any;
    updatedBy: string;
  }) {
    if (input.id) {
      const t = await prisma.letterTemplate.update({
        where: { id: input.id },
        data: {
          key: input.key,
          name: input.name,
          description: input.description ?? null,
          templateHtml: input.templateHtml,
          logoUrl: input.logoUrl ?? null,
          placeholders: input.placeholders ?? undefined,
          updatedBy: input.updatedBy,
        },
      });
      return t;
    }

    const t = await prisma.letterTemplate.upsert({
      where: { key: input.key },
      create: {
        key: input.key,
        name: input.name,
        description: input.description ?? null,
        templateHtml: input.templateHtml,
        logoUrl: input.logoUrl ?? null,
        placeholders: input.placeholders ?? undefined,
        updatedBy: input.updatedBy,
      },
      update: {
        name: input.name,
        description: input.description ?? null,
        templateHtml: input.templateHtml,
        logoUrl: input.logoUrl ?? null,
        placeholders: input.placeholders ?? undefined,
        updatedBy: input.updatedBy,
      },
    });
    return t;
  },

  async getEmployeeDocuments(employeeId: number, opts?: { onlyFinal?: boolean }) {
    return prisma.employeeLetterDocument.findMany({
      where: {
        employeeId,
        ...(opts?.onlyFinal ? { status: LetterDocumentStatus.FINAL } : {}),
      },
      include: { template: true },
      orderBy: [{ status: 'asc' }, { updatedAt: 'desc' }],
    });
  },

  async deleteDocument(params: { documentId: string }) {
    const doc = await prisma.employeeLetterDocument.findUnique({
      where: { id: params.documentId },
      include: { template: true },
    });
    if (!doc) throw new Error('Document not found');
    await prisma.employeeLetterDocument.delete({ where: { id: params.documentId } });

    // Clean up orphaned ad-hoc custom templates
    if (doc.template?.key?.startsWith('custom_')) {
      const remaining = await prisma.employeeLetterDocument.count({
        where: { templateId: doc.templateId },
      });
      if (remaining === 0) {
        await prisma.letterTemplate.delete({ where: { id: doc.templateId } }).catch(() => null);
      }
    }

    return { id: params.documentId, deleted: true };
  },

  /** Create a free-form letter draft for one employee (not from Letters config). */
  async createCustomDraft(params: {
    employeeId: number;
    title?: string | null;
    actorId: string;
  }) {
    const employee = await prisma.employee.findUnique({ where: { id: params.employeeId } });
    if (!employee) throw new Error('Employee not found');

    const title = (params.title ?? '').trim() || 'Custom Letter';
    const key = `custom_${params.employeeId}_${Date.now()}`;
    const templateHtml = `<div style="font-family:Arial,sans-serif;font-size:14px;line-height:1.6;">
  <p>Dear {{fullName}},</p>
  <p></p>
  <p>Sincerely,</p>
  <p>HR Department</p>
  <p>{{todayDate}}</p>
</div>`;

    const template = await prisma.letterTemplate.create({
      data: {
        key,
        name: title,
        description: 'Ad-hoc letter created from employee Documents',
        templateHtml,
        isActive: false,
        placeholders: [
          'fullName',
          'employeeCode',
          'designation',
          'department',
          'organization',
          'joiningDate',
          'todayDate',
        ],
        updatedBy: params.actorId,
      },
    });

    const ctx = await buildEmployeePlaceholderContext(params.employeeId);
    const rendered = renderTemplate(template.templateHtml, ctx);

    return prisma.employeeLetterDocument.create({
      data: {
        employeeId: params.employeeId,
        templateId: template.id,
        status: LetterDocumentStatus.DRAFT,
        contentHtml: rendered,
        createdBy: params.actorId,
        updatedBy: params.actorId,
      },
      include: { template: true },
    });
  },

  async createOrUpdateDraft(params: {
    employeeId: number;
    templateId: string;
    actorId: string;
  }) {
    const template = await prisma.letterTemplate.findUnique({ where: { id: params.templateId } });
    if (!template || !template.isActive) throw new Error('Template not found');

    const ctx = await buildEmployeePlaceholderContext(params.employeeId);
    const rendered = renderTemplate(template.templateHtml, ctx);

    const existing = await prisma.employeeLetterDocument.findFirst({
      where: {
        employeeId: params.employeeId,
        templateId: params.templateId,
        status: LetterDocumentStatus.DRAFT,
      },
    });

    if (!existing) {
      return prisma.employeeLetterDocument.create({
        data: {
          employeeId: params.employeeId,
          templateId: params.templateId,
          status: LetterDocumentStatus.DRAFT,
          contentHtml: rendered,
          createdBy: params.actorId,
          updatedBy: params.actorId,
        },
      });
    }

    return prisma.employeeLetterDocument.update({
      where: { id: existing.id },
      data: {
        contentHtml: rendered,
        updatedBy: params.actorId,
      },
    });
  },

  async updateDraft(params: { documentId: string; contentHtml: string; actorId: string }) {
    const doc = await prisma.employeeLetterDocument.findUnique({ where: { id: params.documentId } });
    if (!doc) throw new Error('Document not found');
    if (doc.status !== LetterDocumentStatus.DRAFT) {
      throw new Error('Only draft documents are editable');
    }
    return prisma.employeeLetterDocument.update({
      where: { id: params.documentId },
      data: { contentHtml: params.contentHtml, updatedBy: params.actorId },
    });
  },

  async finalizeDraft(params: { draftId: string; actorId: string }) {
    const draft = await prisma.employeeLetterDocument.findUnique({
      where: { id: params.draftId },
      include: { template: true },
    });
    if (!draft) throw new Error('Draft not found');
    if (draft.status !== LetterDocumentStatus.DRAFT) {
      throw new Error('Document is not a draft');
    }

    const existingFinal = await prisma.employeeLetterDocument.findFirst({
      where: {
        employeeId: draft.employeeId,
        templateId: draft.templateId,
        status: LetterDocumentStatus.FINAL,
      },
    });

    if (!existingFinal) {
      return prisma.employeeLetterDocument.create({
        data: {
          employeeId: draft.employeeId,
          templateId: draft.templateId,
          status: LetterDocumentStatus.FINAL,
          contentHtml: draft.contentHtml,
          createdBy: params.actorId,
          updatedBy: params.actorId,
        },
      });
    }

    return prisma.employeeLetterDocument.update({
      where: { id: existingFinal.id },
      data: {
        contentHtml: draft.contentHtml,
        updatedBy: params.actorId,
      },
    });
  },
};

