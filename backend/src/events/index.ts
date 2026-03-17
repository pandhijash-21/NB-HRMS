import { Router } from 'express';
const router = Router();
router.get('/health', (req, res) => res.json({ status: 'events ok' }));
export default router;
