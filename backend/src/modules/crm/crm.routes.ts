import { Router } from 'express';
import multer from 'multer';
import { crmController } from './crm.controller';
import { requireAuth } from '../../middleware/auth';
import { requirePermission, type PermissionAction } from '../../middleware/rbac';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 25 * 1024 * 1024 }, // 25 MB limit for Excel
});

export const crmRouter = Router();

// Public Webhook for Greeter / Elision Call Logs (No auth required)
crmRouter.post('/telephony/webhook', crmController.handleTelephonyWebhook);

// Public Webhook for Campaign Lead Ingestion (No auth required)
crmRouter.get('/campaigns/:token/webhook', crmController.handleCampaignWebhookVerification);
crmRouter.post('/campaigns/:token/webhook', crmController.handleCampaignWebhook);
crmRouter.get('/webhook/:token', crmController.handleCampaignWebhookVerification);
crmRouter.post('/webhook/:token', crmController.handleCampaignWebhook);

// Apply auth + RBAC to all protected CRM routes
crmRouter.use(requireAuth);
crmRouter.use((req, res, next) => {
  const action: PermissionAction = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)
    ? 'WRITE'
    : 'READ';
  return requirePermission('CRM', action)(req, res, next);
});

// Projects
crmRouter.get('/projects', crmController.getProjects);
crmRouter.post('/projects', crmController.createProject);
crmRouter.put('/projects/:id', crmController.updateProject);
crmRouter.delete('/projects/:id', crmController.deleteProject);

// Campaigns
crmRouter.get('/campaigns', crmController.getCampaigns);
crmRouter.post('/campaigns', crmController.createCampaign);
crmRouter.put('/campaigns/:id', crmController.updateCampaign);
crmRouter.delete('/campaigns/:id', crmController.deleteCampaign);

// Columns & Headers Management
crmRouter.get('/columns', crmController.getColumns);
crmRouter.post('/columns', crmController.createColumn);
crmRouter.patch('/columns/:id/visibility', crmController.toggleColumnVisibility);
crmRouter.post('/columns/merge', crmController.mergeColumns);
crmRouter.put('/columns/:id', crmController.updateColumn);
crmRouter.delete('/columns/:id', crmController.deleteColumn);

// Leads & Excel
crmRouter.get('/leads', crmController.getLeads);
crmRouter.post('/leads', crmController.createLead);
crmRouter.post('/leads/import-excel', upload.single('file'), crmController.importExcel);
crmRouter.patch('/leads/:id/status', crmController.updateLeadStatus);
crmRouter.patch('/leads/:id', crmController.updateLead);
crmRouter.delete('/leads/:id', crmController.moveToBin);
crmRouter.patch('/leads/:id/restore', crmController.restoreFromBin);

// Bin (Recycle Bin / Archive)
crmRouter.get('/bin', crmController.getBin);
crmRouter.post('/bin/restore/:id', crmController.restoreFromBin);

// Follow-ups
crmRouter.get('/follow-ups', crmController.getFollowUps);
crmRouter.post('/follow-ups', crmController.createFollowUp);
crmRouter.patch('/follow-ups/:id/complete', crmController.completeFollowUp);

// Settings & Telephony
crmRouter.get('/settings', crmController.getSettings);
crmRouter.put('/settings', crmController.updateSettings);
crmRouter.post('/telephony/click-to-call', crmController.clickToCall);
crmRouter.get('/telephony/call-logs', crmController.getCallLogs);

// KPI Metrics & HRMS Sales Users
crmRouter.get('/kpi', crmController.getKpiMetrics);
crmRouter.get('/sales-users', crmController.getSalesUsers);

