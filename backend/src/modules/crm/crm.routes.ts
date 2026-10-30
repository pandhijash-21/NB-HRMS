import { Router } from 'express';
import multer from 'multer';
import { crmController } from './crm.controller';
import { hubRouter } from '../hub';
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

// Public Webhook for 9ance / provider call events (No auth required)
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

// Public Brochure Delivery for WhatsApp Media Headers & Client Downloads
crmPublicRouter.get('/brochures/:filename', crmController.servePublicBrochure);
crmPublicRouter.get('/brochure/:filename', crmController.servePublicBrochure);
crmPublicRouter.get('/brochures', crmController.servePublicBrochure);

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
crmRouter.post(
  '/telephony/click-to-call',
  requireAnyPermission(
    ['CRM_SETTINGS', 'CRM_PRE_SALES', 'FIN_CRM_SETTINGS', 'FIN_CRM_PRE_SALES'],
    'WRITE',
  ),
  crmController.clickToCall,
);
crmRouter.get('/telephony/call-logs', requireCrmSubmodule('CRM_SETTINGS'), crmController.getCallLogs);
crmRouter.patch('/telephony/call-logs/:id', requireCrmSubmodule('CRM_SETTINGS'), crmController.updateCallLog);

// 9ance Cloud Telephony
crmRouter.post('/telephony/test-connection', requireCrmSubmodule('CRM_SETTINGS'), crmController.testNineanceConnection);
crmRouter.post('/telephony/activate', requireCrmSubmodule('CRM_SETTINGS'), crmController.activateNineance);
crmRouter.get('/telephony/agents', requireCrmSubmodule('CRM_SETTINGS'), crmController.listNineanceAgents);
crmRouter.post('/telephony/agents', requireCrmSubmodule('CRM_SETTINGS'), crmController.createNineanceAgent);
crmRouter.post('/telephony/agents/sync', requireCrmSubmodule('CRM_SETTINGS'), crmController.syncNineanceAgents);
crmRouter.post('/telephony/agents/bulk-assign', requireCrmSubmodule('CRM_SETTINGS'), crmController.bulkAssignNineanceAgents);
crmRouter.get('/telephony/agents/me', requireCrmSubmodule('CRM_SETTINGS'), crmController.getNineanceMyAgent);
crmRouter.get('/telephony/agents/me/status', requireCrmSubmodule('CRM_SETTINGS'), crmController.getNineanceMyAgentStatus);
crmRouter.post('/telephony/agents/me/status', requireCrmSubmodule('CRM_SETTINGS'), crmController.setNineanceMyAgentStatus);
crmRouter.get('/telephony/agents/me/softphone-config', requireCrmSubmodule('CRM_SETTINGS'), crmController.getNineanceSoftphoneConfig);
crmRouter.post('/telephony/agents/:id/assign', requireCrmSubmodule('CRM_SETTINGS'), crmController.assignNineanceAgent);
crmRouter.delete('/telephony/agents/:id', requireCrmSubmodule('CRM_SETTINGS'), crmController.deleteNineanceAgent);
crmRouter.get('/telephony/dids', requireCrmSubmodule('CRM_SETTINGS'), crmController.listNineanceDids);
crmRouter.post('/telephony/dids/sync', requireCrmSubmodule('CRM_SETTINGS'), crmController.syncNineanceDids);
crmRouter.post('/telephony/dids/:id/set-default', requireCrmSubmodule('CRM_SETTINGS'), crmController.setNineanceDefaultDid);
crmRouter.post('/telephony/calls/sync', requireCrmSubmodule('CRM_SETTINGS'), crmController.syncNineanceCalls);
crmRouter.get('/telephony/webhook-urls', requireCrmSubmodule('CRM_SETTINGS'), crmController.getNineanceWebhookUrls);
crmRouter.get('/telephony/provider-configs', requireCrmSubmodule('CRM_SETTINGS'), crmController.listNineanceProviderConfigs);
crmRouter.post('/telephony/provider-configs', requireCrmSubmodule('CRM_SETTINGS'), crmController.createNineanceProviderConfig);
crmRouter.patch('/telephony/provider-configs/:id', requireCrmSubmodule('CRM_SETTINGS'), crmController.updateNineanceProviderConfig);
crmRouter.delete('/telephony/provider-configs/:id', requireCrmSubmodule('CRM_SETTINGS'), crmController.deleteNineanceProviderConfig);
crmRouter.post('/telephony/provider-configs/:id/enable', requireCrmSubmodule('CRM_SETTINGS'), crmController.enableNineanceProviderConfig);
crmRouter.get('/telephony/call-groups', requireCrmSubmodule('CRM_SETTINGS'), crmController.listNineanceCallGroups);
crmRouter.post('/telephony/call-groups', requireCrmSubmodule('CRM_SETTINGS'), crmController.createNineanceCallGroup);
crmRouter.get('/telephony/transcription/capability', requireCrmSubmodule('CRM_SETTINGS'), crmController.nineanceTranscriptionCapability);
crmRouter.get('/telephony/transcription/settings', requireCrmSubmodule('CRM_SETTINGS'), crmController.getNineanceTranscriptionSettings);
crmRouter.post('/telephony/transcription/settings', requireCrmSubmodule('CRM_SETTINGS'), crmController.updateNineanceTranscriptionSettings);
crmRouter.get('/telephony/config', requireCrmSubmodule('CRM_SETTINGS'), crmController.getNineanceRemoteConfig);
crmRouter.put('/telephony/config', requireCrmSubmodule('CRM_SETTINGS'), crmController.updateNineanceRemoteConfig);
crmRouter.delete('/telephony/config', requireCrmSubmodule('CRM_SETTINGS'), crmController.deleteNineanceRemoteConfig);
crmRouter.get('/telephony/auth/products', requireCrmSubmodule('CRM_SETTINGS'), crmController.listNineanceAuthProducts);
crmRouter.get(
  '/telephony/dialer-config',
  requireAnyPermission(['CRM_SETTINGS', 'CRM_PRE_SALES', 'FIN_CRM_SETTINGS', 'FIN_CRM_PRE_SALES'], 'READ'),
  crmController.getNineanceDialerConfig,
);
crmRouter.get(
  '/telephony/ws-token',
  requireAnyPermission(['CRM_SETTINGS', 'CRM_PRE_SALES', 'FIN_CRM_SETTINGS', 'FIN_CRM_PRE_SALES'], 'READ'),
  crmController.getNineanceWsToken,
);
crmRouter.get(
  '/telephony/live-calls',
  requireAnyPermission(['CRM_SETTINGS', 'CRM_PRE_SALES', 'FIN_CRM_SETTINGS', 'FIN_CRM_PRE_SALES'], 'READ'),
  crmController.listNineanceLiveCalls,
);
crmRouter.get(
  '/telephony/match-phone',
  requireAnyPermission(['CRM_SETTINGS', 'CRM_PRE_SALES', 'FIN_CRM_SETTINGS', 'FIN_CRM_PRE_SALES'], 'READ'),
  crmController.matchNineancePhone,
);
crmRouter.post(
  '/telephony/calls/:callId/disposition',
  requireAnyPermission(['CRM_SETTINGS', 'CRM_PRE_SALES', 'FIN_CRM_SETTINGS', 'FIN_CRM_PRE_SALES'], 'WRITE'),
  crmController.dispositionNineanceCall,
);
crmRouter.post(
  '/telephony/agents/:id/status',
  requireAnyPermission(['CRM_SETTINGS', 'CRM_PRE_SALES', 'FIN_CRM_SETTINGS', 'FIN_CRM_PRE_SALES'], 'WRITE'),
  crmController.setNineanceAgentStatus,
);
crmRouter.get('/telephony/campaigns', requireCrmSubmodule('CRM_SETTINGS'), crmController.listNineanceCampaigns);
crmRouter.post('/telephony/campaigns', requireCrmSubmodule('CRM_SETTINGS'), crmController.createNineanceCampaign);
crmRouter.post('/telephony/campaigns/preview', requireCrmSubmodule('CRM_SETTINGS'), crmController.previewNineanceDialList);
crmRouter.post('/telephony/campaigns/:id/start', requireCrmSubmodule('CRM_SETTINGS'), crmController.startNineanceCampaign);
crmRouter.post('/telephony/campaigns/:id/stop', requireCrmSubmodule('CRM_SETTINGS'), crmController.stopNineanceCampaign);
crmRouter.get('/telephony/campaigns/:id/report', requireCrmSubmodule('CRM_SETTINGS'), crmController.nineanceCampaignReport);
crmRouter.get('/telephony/dispositions', requireCrmSubmodule('CRM_SETTINGS'), crmController.listNineanceDispositions);
crmRouter.post('/telephony/dispositions', requireCrmSubmodule('CRM_SETTINGS'), crmController.createNineanceDisposition);
crmRouter.put('/telephony/dispositions/:id', requireCrmSubmodule('CRM_SETTINGS'), crmController.updateNineanceDisposition);
crmRouter.delete('/telephony/dispositions/:id', requireCrmSubmodule('CRM_SETTINGS'), crmController.deleteNineanceDisposition);
crmRouter.get('/telephony/analytics', requireCrmSubmodule('CRM_SETTINGS'), crmController.nineanceAnalytics);
crmRouter.get('/telephony/analytics/me', requireCrmSubmodule('CRM_SETTINGS'), crmController.nineanceMyAnalytics);
crmRouter.get('/telephony/dashboard', requireCrmSubmodule('CRM_SETTINGS'), crmController.nineanceProviderDashboard);

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

// NB Hub Partners Integration (Read & Manage NB Hub partners, onboarding & profiles via HTTP API)
crmRouter.use('/partners', generalCrmGuard, hubRouter);
crmRouter.use('/hub/partners', generalCrmGuard, hubRouter);

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

// Admin-only operations within CRM (Excel import & export)
const crmAdminGuard = (req: any, res: any, next: any) => {
  const role = String(req.user?.roleName ?? req.user?.role ?? '').toUpperCase();
  const isAdmin = ['ADMIN', 'SUPER_ADMIN', 'SUPERADMIN', 'SYSTEM_ADMIN', 'ITADMIN'].some((r) => role.includes(r));
  if (!isAdmin) {
    return res.status(403).json({
      success: false,
      message: 'Forbidden: Administrator privileges required for this action',
    });
  }
  return next();
};

// Leads & Excel
crmRouter.get('/leads/export-excel', generalCrmGuard, crmAdminGuard, crmController.exportLeadsExcel);
crmRouter.get('/leads', generalCrmGuard, crmController.getLeads);
crmRouter.get('/leads/check-phone', generalCrmGuard, crmController.checkPhone);
crmRouter.post('/leads', generalCrmGuard, crmController.createLead);
crmRouter.post('/leads/merge', generalCrmGuard, crmController.mergeLeads);
crmRouter.post('/leads/import-excel', generalCrmGuard, crmAdminGuard, upload.single('file'), crmController.importExcel);
crmRouter.post('/leads/:id/transfer', generalCrmGuard, crmController.transferLead);
crmRouter.patch('/leads/:id/status', generalCrmGuard, crmController.updateLeadStatus);
crmRouter.patch('/leads/:id', generalCrmGuard, crmController.updateLead);
crmRouter.post('/admin/wipe-real-estate-presales', generalCrmGuard, crmController.wipeRealEstatePreSalesData);
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
