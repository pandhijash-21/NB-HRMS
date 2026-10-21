import { Router } from 'express';
import multer from 'multer';
import { crmController } from './crm.controller';
import { requireAuth } from '../../middleware/auth';
import { requirePermission, requireAnyPermission, type PermissionAction } from '../../middleware/rbac';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 25 * 1024 * 1024 }, // 25 MB limit for Excel
});

export const crmRouter = Router();
export const crmPublicRouter = Router();
export const clientPortalPageRouter = Router();

// Public Client Portal Webpage with inline script & handler support
clientPortalPageRouter.use((_req, res, next) => {
  res.setHeader(
    'Content-Security-Policy',
    "default-src 'self'; script-src 'self' 'unsafe-inline'; script-src-attr 'unsafe-inline'; style-src 'self' https: 'unsafe-inline'; font-src 'self' https: data:; img-src 'self' data: https: blob:; connect-src 'self' https: http:; frame-ancestors 'self';"
  );
  next();
});
clientPortalPageRouter.get('/', crmController.renderClientPortalPage);
clientPortalPageRouter.get('/:token', crmController.renderClientPortalPage);

// Public Webhook for Greeter / Elision Call Logs (No auth required)
crmPublicRouter.post('/telephony/webhook', crmController.handleTelephonyWebhook);
crmRouter.post('/telephony/webhook', crmController.handleTelephonyWebhook);

// Audio stream proxy for in-app call recording playback
crmPublicRouter.get('/telephony/recordings/:id/audio', crmController.streamCallAudio);
crmRouter.get('/telephony/recordings/:id/audio', crmController.streamCallAudio);

// Public Webhooks for Campaign Lead Ingestion
crmPublicRouter.get('/campaigns/:token/webhook', crmController.handleCampaignWebhookVerification);
crmPublicRouter.post('/campaigns/:token/webhook', crmController.handleCampaignWebhook);
crmPublicRouter.get('/webhook/:token', crmController.handleCampaignWebhookVerification);
crmPublicRouter.post('/webhook/:token', crmController.handleCampaignWebhook);

// Public Client Verification & Document Upload Portal Endpoints
crmPublicRouter.get('/client-portal/:token/info', crmController.getClientPortalInfo);
crmPublicRouter.post('/client-portal/:token/send-otp', crmController.sendClientPortalOtp);
crmPublicRouter.post('/client-portal/:token/verify-otp', crmController.verifyClientPortalOtp);
crmPublicRouter.post('/client-portal/:token/submit', crmController.submitClientPortal);
crmPublicRouter.post(
  '/client-portal/:token/upload-doc',
  upload.single('document'),
  crmController.uploadClientPortalDoc,
);
crmPublicRouter.get('/client-portal/:token/download-docs-zip', crmController.downloadLeadDocsZipPublic);
crmPublicRouter.get('/leads/:id/download-docs-zip', crmController.downloadLeadDocsZipPublic);

// Apply auth to all protected CRM routes
crmRouter.use(requireAuth);

function getCrmScope(req: any): string {
  const scopeHeader = (req.headers['x-crm-scope'] || req.query?.scope || req.body?.scope || '').toString().toUpperCase().trim();
  return scopeHeader === 'NB_FINSERVE' ? 'NB_FINSERVE' : 'NB_DEVELOPER';
}

crmRouter.use((req: any, _res: any, next: any) => {
  req.crmScope = getCrmScope(req);
  next();
});

function actionFor(method: string): PermissionAction {
  return ['POST', 'PUT', 'PATCH', 'DELETE'].includes(method) ? 'WRITE' : 'READ';
}

function requireCrmSubmodule(submodule: string) {
  return (req: any, res: any, next: any) => {
    const isFinserve = req.crmScope === 'NB_FINSERVE';
    const effectiveModule = isFinserve ? `FIN_${submodule}` : submodule;
    return requirePermission(effectiveModule, actionFor(req.method))(req, res, next);
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
crmRouter.get(
  '/telephony/telecallers',
  requireCrmSubmodule('CRM_SETTINGS'),
  crmController.listTelecallerTelephony,
);
crmRouter.put(
  '/telephony/telecallers/:employeeId',
  requireCrmSubmodule('CRM_SETTINGS'),
  crmController.upsertTelecallerTelephony,
);
crmRouter.post('/telephony/click-to-call', requireCrmSubmodule('CRM_SETTINGS'), crmController.clickToCall);
crmRouter.get('/telephony/call-logs', requireCrmSubmodule('CRM_SETTINGS'), crmController.getCallLogs);
crmRouter.patch('/telephony/call-logs/:id', requireCrmSubmodule('CRM_SETTINGS'), crmController.updateCallLog);

// WhatsApp Automation Configuration, Testing & Logs (BotBiz WhatsApp Integration)
crmRouter.get('/whatsapp/config', requireCrmSubmodule('CRM_SETTINGS'), crmController.getWhatsappConfig);
crmRouter.put('/whatsapp/config', requireCrmSubmodule('CRM_SETTINGS'), crmController.updateWhatsappConfig);
crmRouter.post('/whatsapp/test-connection', requireCrmSubmodule('CRM_SETTINGS'), crmController.testWhatsappConnection);
crmRouter.post('/whatsapp/test', requireCrmSubmodule('CRM_SETTINGS'), crmController.sendTestWhatsappMessage);
crmRouter.post('/whatsapp/sync-templates', requireCrmSubmodule('CRM_SETTINGS'), crmController.syncWhatsappTemplates);
crmRouter.get('/whatsapp/templates', requireCrmSubmodule('CRM_SETTINGS'), crmController.getWhatsappTemplates);
crmRouter.post('/whatsapp/template-status/:templateId', requireCrmSubmodule('CRM_SETTINGS'), crmController.checkWhatsappTemplateStatus);
crmRouter.get('/whatsapp/logs', requireCrmSubmodule('CRM_SETTINGS'), crmController.getWhatsappLogs);
crmRouter.post('/whatsapp/retry/:logId', requireCrmSubmodule('CRM_SETTINGS'), crmController.retryWhatsappLog);
crmRouter.post(
  '/whatsapp/upload-brochure',
  requireCrmSubmodule('CRM_SETTINGS'),
  upload.single('brochure'),
  crmController.uploadBrochure,
);

// KPI Metrics & Dashboard
crmRouter.get('/kpi', requireCrmSubmodule('CRM_DASHBOARD'), crmController.getKpiMetrics);

// General CRM (Leads, Campaigns, Follow-ups, Projects, Sales) - gated on CRM / PRE_SALES / SALES
const generalCrmGuard = (req: any, res: any, next: any) => {
  const isFinserve = req.crmScope === 'NB_FINSERVE';
  const modules = isFinserve
    ? ['FIN_CRM_PRE_SALES', 'FIN_CRM_SALES', 'FIN_CRM_DASHBOARD']
    : ['CRM', 'CRM_PRE_SALES', 'CRM_SALES'];
  return requireAnyPermission(modules, actionFor(req.method))(req, res, next);
};

const visitorDeskGuard = (req: any, res: any, next: any) => {
  if (req.crmScope === 'NB_FINSERVE') {
    return res.status(403).json({
      success: false,
      message: 'Visitor desk is not available for NB Finserve CRM',
    });
  }
  const modules = ['CRM_VISITOR_DESK', 'CRM', 'CRM_PRE_SALES', 'CRM_DASHBOARD'];
  return requireAnyPermission(modules, actionFor(req.method))(req, res, next);
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
crmRouter.post('/leads/:id/transfer', generalCrmGuard, crmController.transferLead);
crmRouter.patch('/leads/:id/status', generalCrmGuard, crmController.updateLeadStatus);
crmRouter.patch('/leads/:id', generalCrmGuard, crmController.updateLead);
crmRouter.post('/leads/:id/whatsapp', generalCrmGuard, crmController.sendLeadWhatsapp);
crmRouter.delete('/leads/:id', generalCrmGuard, crmController.moveToBin);
crmRouter.patch('/leads/:id/restore', generalCrmGuard, crmController.restoreFromBin);
crmRouter.put('/leads/:id/application-details', generalCrmGuard, crmController.updateLeadApplicationDetails);
crmRouter.put('/leads/:id/finserve-pipeline', generalCrmGuard, crmController.updateFinservePipeline);
crmRouter.post('/leads/:id/bank-queries', generalCrmGuard, crmController.addBankQuery);
crmRouter.patch('/leads/:id/bank-queries/:queryId/resolve', generalCrmGuard, crmController.resolveBankQuery);
crmRouter.post('/leads/:id/portal-link', generalCrmGuard, crmController.generateClientPortalLink);
crmRouter.post('/leads/:id/upload-doc', generalCrmGuard, upload.single('document'), crmController.uploadLeadDoc);
crmRouter.get('/leads/:id/download-docs-zip', generalCrmGuard, crmController.downloadLeadDocsZip);

// Follow-ups
crmRouter.get('/follow-ups', generalCrmGuard, crmController.getFollowUps);
crmRouter.post('/follow-ups', generalCrmGuard, crmController.createFollowUp);
crmRouter.patch('/follow-ups/:id/complete', generalCrmGuard, crmController.completeFollowUp);

// Visitor Check-In Desk
crmRouter.get('/visitor-lookup', visitorDeskGuard, crmController.visitorLookup);
crmRouter.post('/visitor-checkin', visitorDeskGuard, crmController.visitorCheckin);

// HRMS Sales Users
crmRouter.get('/sales-users', generalCrmGuard, crmController.getSalesUsers);

// Virtual Building Elevation & Inventory Matrix
crmRouter.get('/virtual-building', generalCrmGuard, crmController.getVirtualBuilding);
crmRouter.post('/virtual-building/unit-action', generalCrmGuard, crmController.updateVirtualBuildingUnit);

// Telecaller Screen Activity & Heartbeat / Inactivity Break
crmRouter.post('/telecallers/activity', generalCrmGuard, crmController.reportTelecallerActivity);
crmRouter.get('/telecallers/activity', generalCrmGuard, crmController.getTelecallerActivity);

// Waiting Queue Management & Dispatch
crmRouter.get('/waiting-queue/status', generalCrmGuard, crmController.getWaitingQueueStatus);
crmRouter.post('/waiting-queue/dispatch', generalCrmGuard, crmController.dispatchWaitingQueue);
