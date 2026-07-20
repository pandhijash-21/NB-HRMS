import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission, requireRole, requireSelfEmployeeOrPermission } from '../../middleware/rbac';
import { fail, ok } from '../../utils/response';
import { lettersService } from './letters.service';

export const lettersRouter = Router();

// ─── Templates (ADMIN / HR / HR_MANAGER) ───────────────────────────────────────

lettersRouter.get(
  '/templates',
  requireAuth,
  requirePermission('DOCUMENTS', 'READ'),
  async (_req: Request, res: Response) => {
    try {
      const data = await lettersService.listTemplates();
      res.json(ok(data));
    } catch (e: any) {
      res.status(400).json(fail(e.message));
    }
  },
);

lettersRouter.post(
  '/templates',
  requireAuth,
  requireRole(['ADMIN', 'HR', 'HR_MANAGER']),
  async (req: Request, res: Response) => {
    try {
      const updatedBy = String((req.user as any)?.id ?? 'unknown');
      const input = {
        id: req.body?.id ?? null,
        key: String(req.body?.key ?? ''),
        name: String(req.body?.name ?? ''),
        description: req.body?.description != null ? String(req.body.description) : null,
        templateHtml: String(req.body?.templateHtml ?? ''),
        logoUrl: req.body?.logoUrl != null ? String(req.body.logoUrl) : null,
        placeholders: req.body?.placeholders ?? undefined,
        updatedBy,
      };

      if (!input.key || !input.name || !input.templateHtml) {
        return res.status(400).json(fail('Missing template key/name/templateHtml'));
      }

      const data = await lettersService.upsertTemplate(input);
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

// ─── Employee documents (employee self read; admin manage) ───────────────────

lettersRouter.get(
  '/employees/:employeeId/documents',
  requireAuth,
  requireSelfEmployeeOrPermission('employeeId', 'DOCUMENTS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const employeeId = Number(req.params.employeeId);
      if (!Number.isFinite(employeeId) || employeeId <= 0) {
        return res.status(400).json(fail('Invalid employeeId'));
      }

      // Employees only see FINAL letters. Admins/HR see drafts too.
      const role = String((req.user as any)?.roleName ?? (req.user as any)?.role ?? '');
      const isManager = ['ADMIN', 'HR', 'HR_MANAGER'].includes(role);
      const writeActions = (req.user as any)?.permissions?.DOCUMENTS ?? [];
      const canManage = isManager || writeActions.includes('WRITE');
      const onlyFinal = !canManage;

      const data = await lettersService.getEmployeeDocuments(employeeId, { onlyFinal });
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

lettersRouter.post(
  '/employees/:employeeId/custom-draft',
  requireAuth,
  requireRole(['ADMIN', 'HR', 'HR_MANAGER']),
  async (req: Request, res: Response) => {
    try {
      const employeeId = Number(req.params.employeeId);
      if (!Number.isFinite(employeeId) || employeeId <= 0) {
        return res.status(400).json(fail('Invalid employeeId'));
      }
      const actorId = String((req.user as any)?.id ?? 'unknown');
      const title = req.body?.title != null ? String(req.body.title) : null;
      const data = await lettersService.createCustomDraft({ employeeId, title, actorId });
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

lettersRouter.post(
  '/employees/:employeeId/templates/:templateId/draft',
  requireAuth,
  requireRole(['ADMIN', 'HR', 'HR_MANAGER']),
  async (req: Request, res: Response) => {
    try {
      const employeeId = Number(req.params.employeeId);
      const templateId = String(req.params.templateId);
      const actorId = String((req.user as any)?.id ?? 'unknown');
      const data = await lettersService.createOrUpdateDraft({ employeeId, templateId, actorId });
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

lettersRouter.patch(
  '/documents/:documentId',
  requireAuth,
  requireRole(['ADMIN', 'HR', 'HR_MANAGER']),
  async (req: Request, res: Response) => {
    try {
      const documentId = String(req.params.documentId ?? '');
      const contentHtml = String(req.body?.contentHtml ?? '');
      const actorId = String((req.user as any)?.id ?? 'unknown');
      const data = await lettersService.updateDraft({ documentId, contentHtml, actorId });
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

lettersRouter.post(
  '/documents/:draftId/finalize',
  requireAuth,
  requireRole(['ADMIN', 'HR', 'HR_MANAGER']),
  async (req: Request, res: Response) => {
    try {
      const draftId = String(req.params.draftId ?? '');
      const actorId = String((req.user as any)?.id ?? 'unknown');
      const data = await lettersService.finalizeDraft({ draftId, actorId });
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

lettersRouter.post(
  '/documents/:documentId/delete',
  requireAuth,
  requireRole(['ADMIN', 'HR', 'HR_MANAGER']),
  async (req: Request, res: Response) => {
    try {
      const documentId = String(req.params.documentId ?? '');
      const data = await lettersService.deleteDocument({ documentId });
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

lettersRouter.delete(
  '/documents/:documentId',
  requireAuth,
  requireRole(['ADMIN', 'HR', 'HR_MANAGER']),
  async (req: Request, res: Response) => {
    try {
      const documentId = String(req.params.documentId ?? '');
      const data = await lettersService.deleteDocument({ documentId });
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

