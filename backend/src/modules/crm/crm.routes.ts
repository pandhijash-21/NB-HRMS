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

// Apply auth to all protected CRM routes
crmRouter.use(requireAuth);

function actionFor(method: string): PermissionAction {
  return ['POST', 'PUT', 'PATCH', 'DELETE'].includes(method) ? 'WRITE' : 'READ';
}

function requireCrmSubmodule(submodule: string) {
  return (req: any, res: any, next: any) => {
    return requirePermission(submodule, actionFor(req.method))(req, res, next);
  };
}

// Columns & Headers Management
crmRouter.get('/columns', requireCrmSubmodule('CRM_HEADERS'), crmController.getColumns);
crmRouter.post('/columns', requireCrmSubmodule('CRM_HEADERS'), crmController.createColumn);
crmRouter.patch('/columns/:id/visibility', requireCrmSubmodule('CRM_HEADERS'), crmController.toggleColumnVisibility);
crmRouter.post('/columns/merge', requireCrmSubmodule('CRM_HEADERS'), crmController.mergeColumns);
crmRouter.put('/columns/:id', requireCrmSubmodule('CRM_HEADERS'), crmController.updateColumn);
crmRouter.delete('/columns/:id', requireCrmSubmodule('CRM_HEADERS'), crmController.deleteColumn);

// Bin (Recycle Bin / Archive)
crmRouter.get('/bin', requireCrmSubmodule('CRM_BIN'), crmController.getBin);
crmRouter.post('/bin/restore/:id', requireCrmSubmodule('CRM_BIN'), crmController.restoreFromBin);

// Settings & Telephony
crmRouter.get('/settings', requireCrmSubmodule('CRM_SETTINGS'), crmController.getSettings);
crmRouter.put('/settings', requireCrmSubmodule('CRM_SETTINGS'), crmController.updateSettings);
crmRouter.post('/telephony/click-to-call', requireCrmSubmodule('CRM_SETTINGS'), crmController.clickToCall);
crmRouter.get('/telephony/call-logs', requireCrmSubmodule('CRM_SETTINGS'), crmController.getCallLogs);

// KPI Metrics & Dashboard
crmRouter.get('/kpi', requireCrmSubmodule('CRM_DASHBOARD'), crmController.getKpiMetrics);

// General CRM (Leads, Campaigns, Follow-ups, Projects) - gated on CRM
const generalCrmGuard = (req: any, res: any, next: any) => {
  return requirePermission('CRM', actionFor(req.method))(req, res, next);
};

// Projects
crmRouter.get('/projects', generalCrmGuard, crmController.getProjects);
crmRouter.post('/projects', generalCrmGuard, crmController.createProject);
crmRouter.put('/projects/:id', generalCrmGuard, crmController.updateProject);
crmRouter.delete('/projects/:id', generalCrmGuard, crmController.deleteProject);

// Campaigns
crmRouter.get('/campaigns', generalCrmGuard, crmController.getCampaigns);
crmRouter.post('/campaigns', generalCrmGuard, crmController.createCampaign);
crmRouter.put('/campaigns/:id', generalCrmGuard, crmController.updateCampaign);
crmRouter.delete('/campaigns/:id', generalCrmGuard, crmController.deleteCampaign);

// Leads & Excel
crmRouter.get('/leads', generalCrmGuard, crmController.getLeads);
crmRouter.post('/leads', generalCrmGuard, crmController.createLead);
crmRouter.post('/leads/import-excel', generalCrmGuard, upload.single('file'), crmController.importExcel);
crmRouter.patch('/leads/:id/status', generalCrmGuard, crmController.updateLeadStatus);
crmRouter.patch('/leads/:id', generalCrmGuard, crmController.updateLead);
crmRouter.delete('/leads/:id', generalCrmGuard, crmController.moveToBin);
crmRouter.patch('/leads/:id/restore', generalCrmGuard, crmController.restoreFromBin);

// Follow-ups
crmRouter.get('/follow-ups', generalCrmGuard, crmController.getFollowUps);
crmRouter.post('/follow-ups', generalCrmGuard, crmController.createFollowUp);
crmRouter.patch('/follow-ups/:id/complete', generalCrmGuard, crmController.completeFollowUp);

// HRMS Sales Users
crmRouter.get('/sales-users', generalCrmGuard, crmController.getSalesUsers);


