import { Router, Request, Response } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth';
import { ok, fail } from '../../utils/response';
import { uploadService } from '../personal-education/upload.service';
import { taskService } from './task.service';

export const tasksRouter = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 },
});

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

function isAllowedAttachment(file: Express.Multer.File) {
  const name = (file.originalname || '').toLowerCase();
  const mime = (file.mimetype || '').toLowerCase();
  return (
    mime === 'application/pdf' ||
    mime === 'application/vnd.ms-powerpoint' ||
    mime === 'application/vnd.openxmlformats-officedocument.presentationml.presentation' ||
    name.endsWith('.pdf') ||
    name.endsWith('.ppt') ||
    name.endsWith('.pptx')
  );
}

tasksRouter.use(requireAuth);

tasksRouter.get('/reportees', async (req: Request, res: Response) => {
  try {
    const data = await taskService.listReportees(req.user!.id);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to list reportees'));
  }
});

tasksRouter.get('/summary', async (req: Request, res: Response) => {
  try {
    const data = await taskService.summary(req.user!.id);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to load summary'));
  }
});

tasksRouter.get('/', async (req: Request, res: Response) => {
  try {
    const filter = String(req.query.filter ?? 'all');
    const allowed = ['inbox', 'assigned', 'review', 'extra', 'all'] as const;
    const use = (allowed as readonly string[]).includes(filter) ? (filter as typeof allowed[number]) : 'all';
    const data = await taskService.listMine(req.user!.id, use);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to list tasks'));
  }
});

tasksRouter.get('/:id', async (req: Request, res: Response) => {
  try {
    const data = await taskService.getById(p(req.params.id), req.user!.id);
    return res.json(ok(data));
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : 'Task not found';
    return res.status(msg === 'Task not found' ? 404 : 400).json(fail(msg));
  }
});

tasksRouter.post('/', upload.single('file'), async (req: Request, res: Response) => {
  try {
    const title = String(req.body?.title ?? '').trim();
    const assigneeUserId = String(req.body?.assigneeUserId ?? '').trim();
    const deadline = String(req.body?.deadline ?? '').trim();
    const description = req.body?.description != null ? String(req.body.description) : null;
    const extraApproverUserId = req.body?.extraApproverUserId
      ? String(req.body.extraApproverUserId).trim()
      : null;

    let attachmentUrl: string | null = null;
    let attachmentName: string | null = null;
    let attachmentMime: string | null = null;
    if (req.file) {
      if (!isAllowedAttachment(req.file)) {
        return res.status(400).json(fail('Only PDF or PPT files are allowed'));
      }
      attachmentUrl = await uploadService.uploadToCloudinary(req.file, 'tasks');
      attachmentName = req.file.originalname || 'attachment';
      attachmentMime = req.file.mimetype || null;
    }

    const data = await taskService.create({
      assignerUserId: req.user!.id,
      assigneeUserId,
      title,
      description,
      deadline,
      extraApproverUserId,
      attachmentUrl,
      attachmentName,
      attachmentMime,
    });
    return res.status(201).json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to create task'));
  }
});

tasksRouter.post('/:id/status', async (req: Request, res: Response) => {
  try {
    const Schema = z.object({
      status: z.enum(['ASSIGNED', 'ONGOING', 'COMPLETED', 'CHANGES_REQUESTED', 'APPROVED', 'REJECTED']),
    });
    const body = Schema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));
    const data = await taskService.setStatus({
      taskId: p(req.params.id),
      actorUserId: req.user!.id,
      status: body.data.status,
    });
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to update status'));
  }
});

tasksRouter.post('/:id/extra-approval', async (req: Request, res: Response) => {
  try {
    const Schema = z.object({ extraApproverUserId: z.string().min(1) });
    const body = Schema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail('extraApproverUserId is required'));
    const data = await taskService.requestExtraApproval({
      taskId: p(req.params.id),
      actorUserId: req.user!.id,
      extraApproverUserId: body.data.extraApproverUserId,
    });
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to request approval'));
  }
});

tasksRouter.post('/:id/extra-approval/decide', async (req: Request, res: Response) => {
  try {
    const Schema = z.object({
      approve: z.boolean(),
      remarks: z.string().optional().nullable(),
    });
    const body = Schema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail('approve is required'));
    const data = await taskService.decideExtraApproval({
      taskId: p(req.params.id),
      actorUserId: req.user!.id,
      approve: body.data.approve,
      remarks: body.data.remarks ?? null,
    });
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to decide extra approval'));
  }
});

tasksRouter.post('/:id/review', async (req: Request, res: Response) => {
  try {
    const Schema = z.object({
      action: z.enum(['approve', 'reject', 'changes']),
      remarks: z.string().optional().nullable(),
      newDeadline: z.string().optional().nullable(),
    });
    const body = Schema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));
    const data = await taskService.review({
      taskId: p(req.params.id),
      actorUserId: req.user!.id,
      action: body.data.action,
      remarks: body.data.remarks ?? null,
      newDeadline: body.data.newDeadline ?? null,
    });
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to review task'));
  }
});

tasksRouter.post('/:id/subtasks', upload.single('file'), async (req: Request, res: Response) => {
  try {
    const title = String(req.body?.title ?? '').trim();
    let attachmentUrl: string | null = null;
    let attachmentName: string | null = null;
    let attachmentMime: string | null = null;
    if (req.file) {
      if (!isAllowedAttachment(req.file)) {
        return res.status(400).json(fail('Only PDF or PPT files are allowed'));
      }
      attachmentUrl = await uploadService.uploadToCloudinary(req.file, 'tasks');
      attachmentName = req.file.originalname || 'attachment';
      attachmentMime = req.file.mimetype || null;
    }
    const data = await taskService.addSubtask({
      taskId: p(req.params.id),
      actorUserId: req.user!.id,
      title,
      attachmentUrl,
      attachmentName,
      attachmentMime,
    });
    return res.status(201).json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to add subtask'));
  }
});

tasksRouter.post('/:id/subtasks/:subId/done', async (req: Request, res: Response) => {
  try {
    const Schema = z.object({ isDone: z.boolean() });
    const body = Schema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail('isDone is required'));
    const data = await taskService.setSubtaskDone({
      taskId: p(req.params.id),
      subtaskId: p(req.params.subId),
      actorUserId: req.user!.id,
      isDone: body.data.isDone,
    });
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to update subtask'));
  }
});
