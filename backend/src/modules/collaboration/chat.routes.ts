import { Router, Request, Response } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { requireAuth } from '../../middleware/auth';
import { ok, fail } from '../../utils/response';
import { chatService } from './chat.service';
import { emitChatNewMessage, getIo, isOnline } from './socket';

export const chatRouter = Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 25 * 1024 * 1024 },
});

const p = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v) ?? '';

chatRouter.use(requireAuth);

chatRouter.get('/directory', async (req: Request, res: Response) => {
  try {
    const q = String(req.query.q ?? '');
    const limit = Number(req.query.limit ?? 40);
    const skip = Number(req.query.skip ?? 0);
    const data = await chatService.searchDirectory(
      q,
      req.user!.id,
      Number.isFinite(limit) ? limit : 40,
      Number.isFinite(skip) ? skip : 0,
    );
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Search failed'));
  }
});

chatRouter.get('/channels', async (req: Request, res: Response) => {
  try {
    const data = await chatService.listChannels(req.user!.id, isOnline);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to list chats'));
  }
});

chatRouter.post('/channels/dm', async (req: Request, res: Response) => {
  try {
    const body = z.object({ userId: z.string().min(1) }).parse(req.body);
    const data = await chatService.getOrCreateDm(req.user!.id, body.userId);
    return res.status(201).json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to start chat'));
  }
});

chatRouter.post('/channels/group', async (req: Request, res: Response) => {
  try {
    const body = z
      .object({
        name: z.string().min(2),
        memberIds: z.array(z.string()).min(1),
        topic: z.string().optional(),
      })
      .parse(req.body);
    const data = await chatService.createGroup(req.user!.id, body.name, body.memberIds, body.topic);
    return res.status(201).json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to create group'));
  }
});

chatRouter.get('/channels/:id', async (req: Request, res: Response) => {
  try {
    const data = await chatService.getChannel(p(req.params.id), req.user!.id, isOnline);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(404).json(fail(e instanceof Error ? e.message : 'Chat not found'));
  }
});

chatRouter.patch('/channels/:id', async (req: Request, res: Response) => {
  try {
    const body = z
      .object({
        name: z.string().optional(),
        topic: z.string().optional(),
        avatarUrl: z.string().nullable().optional(),
        addMemberIds: z.array(z.string()).optional(),
        removeMemberIds: z.array(z.string()).optional(),
      })
      .parse(req.body);
    const data = await chatService.updateGroup(p(req.params.id), req.user!.id, body);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to update group'));
  }
});

chatRouter.post('/channels/:id/leave', async (req: Request, res: Response) => {
  try {
    const data = await chatService.leaveGroup(p(req.params.id), req.user!.id);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to leave group'));
  }
});

chatRouter.patch('/channels/:id/members/:userId', async (req: Request, res: Response) => {
  try {
    const body = z.object({ role: z.enum(['admin', 'member']) }).parse(req.body);
    const data = await chatService.setMemberRole(p(req.params.id), req.user!.id, p(req.params.userId), body.role);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to update member'));
  }
});

chatRouter.get('/channels/:id/messages', async (req: Request, res: Response) => {
  try {
    const data = await chatService.listMessages(
      p(req.params.id),
      req.user!.id,
      typeof req.query.cursor === 'string' ? req.query.cursor : undefined,
      Number(req.query.limit ?? 50),
    );
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to load messages'));
  }
});

chatRouter.get('/channels/:id/search', async (req: Request, res: Response) => {
  try {
    const data = await chatService.searchMessages(p(req.params.id), req.user!.id, String(req.query.q ?? ''));
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Search failed'));
  }
});

chatRouter.post('/channels/:id/messages', async (req: Request, res: Response) => {
  try {
    const body = z
      .object({
        content: z.string().optional(),
        replyToId: z.string().optional(),
        attachments: z
          .array(
            z.object({
              bucketKey: z.string(),
              fileUrl: z.string(),
              fileName: z.string(),
              mimeType: z.string(),
              sizeBytes: z.number(),
            }),
          )
          .optional(),
      })
      .parse(req.body);
    const data = await chatService.sendMessage({
      channelId: p(req.params.id),
      senderId: req.user!.id,
      content: body.content,
      replyToId: body.replyToId,
      attachments: body.attachments,
    });
    emitChatNewMessage(p(req.params.id), data);
    return res.status(201).json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to send'));
  }
});

chatRouter.post('/channels/:id/read', async (req: Request, res: Response) => {
  try {
    const data = await chatService.markRead(p(req.params.id), req.user!.id);
    getIo()?.to(`channel:${data.channelId}`).emit('channel_read', data);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

chatRouter.get('/attachments/:id', async (req: Request, res: Response) => {
  try {
    const data = await chatService.attachmentUrl(p(req.params.id), req.user!.id);
    return res.json(ok(data));
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : 'File not found';
    return res.status(message.includes('not found') || message.includes('not a member') ? 404 : 400).json(fail(message));
  }
});

chatRouter.patch('/messages/:id', async (req: Request, res: Response) => {
  try {
    const body = z.object({ content: z.string().min(1) }).parse(req.body);
    const data = await chatService.editMessage(p(req.params.id), req.user!.id, body.content);
    getIo()?.to(`channel:${data.channelId}`).emit('message_updated', data);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to edit'));
  }
});

chatRouter.delete('/messages/:id', async (req: Request, res: Response) => {
  try {
    const data = await chatService.deleteMessage(p(req.params.id), req.user!.id);
    getIo()?.to(`channel:${data.channelId}`).emit('message_updated', data);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to delete'));
  }
});

chatRouter.post('/messages/:id/reactions', async (req: Request, res: Response) => {
  try {
    const body = z.object({ emoji: z.string().min(1).max(16) }).parse(req.body);
    const data = await chatService.toggleReaction(p(req.params.id), req.user!.id, body.emoji);
    getIo()?.to(`channel:${data.channelId}`).emit('message_updated', data);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

chatRouter.post('/uploads', upload.single('file'), async (req: Request, res: Response) => {
  try {
    if (!req.file) return res.status(400).json(fail('File is required'));
    const data = await chatService.uploadAndAttach(req.file);
    return res.status(201).json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Upload failed'));
  }
});
