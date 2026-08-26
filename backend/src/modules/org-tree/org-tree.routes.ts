import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth';
import { ok, fail } from '../../utils/response';
import { orgTreeService, type OrgGrouping } from './org-tree.service';

export const orgTreeRouter = Router();

function requireAdmin(req: Request, res: Response, next: NextFunction) {
  if (!req.user) return res.status(401).json(fail('Unauthenticated'));
  const role = String(req.user.roleName ?? req.user.role ?? '').toUpperCase();
  if (role !== 'ADMIN') {
    return res.status(403).json(fail('Only Admin can generate, edit, or delete the employee tree'));
  }
  return next();
}

const groupingSchema = z.enum(['DEPARTMENT_LEAD', 'REPORTING_CHAIN']);

const createSchema = z.object({
  name: z.string().trim().min(1).max(120),
  description: z.string().trim().max(500).optional().nullable(),
  grouping: groupingSchema.default('DEPARTMENT_LEAD'),
  publish: z.boolean().optional().default(true),
});

const updateSchema = z.object({
  name: z.string().trim().min(1).max(120).optional(),
  description: z.string().trim().max(500).optional().nullable(),
  isActive: z.boolean().optional(),
});

const contactsSchema = z.object({
  contacts: z.array(
    z.object({
      moduleKey: z.string().trim().min(1),
      moduleName: z.string().trim().min(1),
      employeeId: z.number().int().positive().nullable().optional(),
      note: z.string().trim().max(300).optional().nullable(),
    }),
  ),
});

orgTreeRouter.use(requireAuth);

orgTreeRouter.get('/', async (_req: Request, res: Response) => {
  try {
    return res.json(ok(await orgTreeService.list()));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to list org trees'));
  }
});

orgTreeRouter.get('/active', async (_req: Request, res: Response) => {
  try {
    return res.json(ok(await orgTreeService.getActive()));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to load active org tree'));
  }
});

orgTreeRouter.get('/preview', requireAdmin, async (req: Request, res: Response) => {
  try {
    const grouping = groupingSchema.catch('DEPARTMENT_LEAD').parse(req.query.grouping);
    return res.json(ok(await orgTreeService.preview(grouping as OrgGrouping)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to preview org tree'));
  }
});

orgTreeRouter.get('/:id', async (req: Request, res: Response) => {
  try {
    return res.json(ok(await orgTreeService.getById(String(req.params.id))));
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : 'Org tree not found';
    return res.status(msg === 'Org tree not found' ? 404 : 400).json(fail(msg));
  }
});

orgTreeRouter.post('/', requireAdmin, async (req: Request, res: Response) => {
  try {
    const body = createSchema.parse(req.body);
    const data = await orgTreeService.create({
      name: body.name,
      description: body.description,
      grouping: body.grouping,
      publish: body.publish,
      createdById: req.user!.id,
    });
    return res.status(201).json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to create org tree'));
  }
});

orgTreeRouter.post('/:id/regenerate', requireAdmin, async (req: Request, res: Response) => {
  try {
    const grouping = req.body?.grouping
      ? groupingSchema.parse(req.body.grouping)
      : undefined;
    return res.json(ok(await orgTreeService.regenerate(String(req.params.id), grouping)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to regenerate org tree'));
  }
});

orgTreeRouter.patch('/:id', requireAdmin, async (req: Request, res: Response) => {
  try {
    const body = updateSchema.parse(req.body);
    return res.json(ok(await orgTreeService.update(String(req.params.id), body)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to update org tree'));
  }
});

orgTreeRouter.put('/:id/contacts', requireAdmin, async (req: Request, res: Response) => {
  try {
    const body = contactsSchema.parse(req.body);
    return res.json(ok(await orgTreeService.setContacts(String(req.params.id), body.contacts)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to save contacts'));
  }
});

orgTreeRouter.delete('/:id', requireAdmin, async (req: Request, res: Response) => {
  try {
    return res.json(ok(await orgTreeService.remove(String(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to delete org tree'));
  }
});
