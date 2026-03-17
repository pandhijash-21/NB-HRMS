import { Router } from 'express';
const router = Router();
router.get('/health', (req, res) => res.json({ status: 'actions ok' }));
export default router;
