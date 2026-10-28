import { Request, Response } from 'express';
import * as path from 'path';
import * as fs from 'fs';
import { crmService } from './crm.service';
import { ok, fail } from '../../utils/response';
import { CLIENT_PORTAL_HTML } from './client-portal.template';
import { isAdminRole } from '../auth/permissions-map';
import {
  DEFAULT_BROCHURE_PDF_BASE64,
  BOTBIZ_LEGACY_TOWER_PDF,
  CLOUDINARY_NB_FINSERVE_PDF,
  CLOUDINARY_DEFAULT_IMAGE,
} from './default-brochure';

function getScope(req: Request): string {
  const fromParam = (req.query?.scope || req.body?.scope || req.headers['x-crm-scope'] || '').toString().toUpperCase().trim();
  if (fromParam === 'NB_FINSERVE') return 'NB_FINSERVE';
  return (req as any).crmScope || 'NB_DEVELOPER';
}

export const crmController = {
  // Projects
  async getProjects(req: Request, res: Response) {
    try {
      const projects = await crmService.getProjects(getScope(req));
      res.json(ok(projects));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch projects'));
    }
  },

  async createProject(req: Request, res: Response) {
    try {
      const project = await crmService.createProject(req.body, getScope(req));
      res.json(ok(project));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to create project'));
    }
  },

  async updateProject(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const project = await crmService.updateProject(id, req.body);
      res.json(ok(project));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to update project'));
    }
  },

  async deleteProject(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const result = await crmService.deleteProject(id);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to delete project'));
    }
  },

  // Campaigns
  async getCampaigns(req: Request, res: Response) {
    try {
      const module = (req.query.module as string) || 'PRE_SALES';
      const projectId = req.query.projectId as string | undefined;
      const campaigns = await crmService.getCampaigns(module, projectId, getScope(req));
      res.json(ok(campaigns));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch campaigns'));
    }
  },

  async createCampaign(req: Request, res: Response) {
    try {
      const campaign = await crmService.createCampaign(req.body, getScope(req));
      res.json(ok(campaign));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to create campaign'));
    }
  },

  async updateCampaign(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const campaign = await crmService.updateCampaign(id, req.body);
      res.json(ok(campaign));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to update campaign'));
    }
  },

  async deleteCampaign(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const result = await crmService.deleteCampaign(id);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to delete campaign'));
    }
  },

  async handleCampaignWebhookVerification(req: Request, res: Response) {
    const mode = req.query['hub.mode'];
    const challenge = req.query['hub.challenge'];

    if (mode === 'subscribe' && challenge) {
      return res.status(200).send(challenge);
    }
    res.status(200).json({ status: 'ok', message: 'NB CRM Webhook endpoint is active' });
  },

  async handleCampaignWebhook(req: Request, res: Response) {
    try {
      const token = String(req.params.token);
      const payload = { ...req.body, ...req.query };
      const result = await crmService.handleCampaignWebhook(token, payload);
      res.json(result);
    } catch (err: any) {
      res.status(400).json({ status: 'error', message: err.message || 'Failed to process campaign webhook' });
    }
  },

  async toggleColumnVisibility(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const isVisible = req.body.isVisibleInTable !== false;
      const updated = await crmService.toggleColumnVisibility(id, isVisible);
      res.json(ok(updated));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to toggle column visibility'));
    }
  },

  async mergeColumns(req: Request, res: Response) {
    try {
      const result = await crmService.mergeColumns(req.body);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to merge columns'));
    }
  },

  // Columns
  async getColumns(req: Request, res: Response) {
    try {
      const module = (req.query.module as string) || 'PRE_SALES';
      const campaignId = req.query.campaignId as string | undefined;
      const cols = await crmService.getColumns(module, campaignId, getScope(req));
      res.json(ok(cols));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch columns'));
    }
  },

  async createColumn(req: Request, res: Response) {
    try {
      const col = await crmService.createColumn(req.body, getScope(req));
      res.json(ok(col));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to create column'));
    }
  },

  async updateColumn(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const col = await crmService.updateColumn(id, req.body);
      res.json(ok(col));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to update column'));
    }
  },

  async deleteColumn(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const result = await crmService.deleteColumn(id);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to delete column'));
    }
  },

  // Leads
  async getLeads(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const leads = await crmService.getLeads({
        projectId: req.query.projectId as string,
        campaignId: req.query.campaignId as string,
        status: req.query.status as string,
        search: req.query.search as string,
        assignedToId: req.query.assignedToId ? parseInt(req.query.assignedToId as string, 10) : undefined,
        telecallerId: req.query.telecallerId ? parseInt(req.query.telecallerId as string, 10) : undefined,
        leadFlow: req.query.leadFlow as string,
        userRole: authUser?.role,
        userEmployeeId: authUser?.employeeId,
        page: req.query.page ? parseInt(req.query.page as string, 10) : 1,
        limit: req.query.limit ? parseInt(req.query.limit as string, 10) : 100,
        scope: getScope(req),
        inWaitingQueue: req.query.inWaitingQueue === 'true' || req.query.status === 'WL' || req.query.status === 'WAITING_LIST',
        fromDate: (req.query.fromDate || req.query.startDate) as string,
        toDate: (req.query.toDate || req.query.endDate) as string,
      });
      res.json(ok(leads));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch leads'));
    }
  },

  async exportLeadsExcel(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const buffer = await crmService.exportLeadsExcel({
        projectId: req.query.projectId as string,
        campaignId: req.query.campaignId as string,
        status: req.query.status as string,
        search: req.query.search as string,
        assignedToId: req.query.assignedToId ? parseInt(req.query.assignedToId as string, 10) : undefined,
        telecallerId: req.query.telecallerId ? parseInt(req.query.telecallerId as string, 10) : undefined,
        leadFlow: req.query.leadFlow as string,
        userRole: authUser?.role,
        userEmployeeId: authUser?.employeeId,
        scope: getScope(req),
        fromDate: (req.query.fromDate || req.query.startDate) as string,
        toDate: (req.query.toDate || req.query.endDate) as string,
      });

      const dateTag = new Date().toISOString().split('T')[0];
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename="leads_export_${dateTag}.xlsx"`);
      res.send(buffer);
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to export leads to Excel'));
    }
  },

  async createLead(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const explicitTelecallerId = req.body.telecallerId
        ? Number(req.body.telecallerId)
        : undefined;

      const lead = await crmService.createLead(
        req.body,
        authUser?.id,
        explicitTelecallerId,
        getScope(req),
        authUser?.subOrganization,
      );
      res.json(ok(lead));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to create lead'));
    }
  },

  async importExcel(req: Request, res: Response) {
    try {
      if (!req.file || !req.file.buffer) {
        return res.status(400).json(fail('No Excel file uploaded'));
      }
      const authUser = (req as any).user;
      const isAdmin = isAdminRole(authUser?.roleName || authUser?.role);
      const campaignId = (req.body.campaignId || req.query.campaignId) as string | undefined;
      const assignmentMode = (req.body.assignmentMode || 'ROUND_ROBIN') as 'SPECIFIC' | 'ROUND_ROBIN' | 'UNASSIGNED';

      let assignedTelecallerIds: number[] | undefined = undefined;
      if (req.body.assignedTelecallerIds) {
        try {
          const parsed = typeof req.body.assignedTelecallerIds === 'string'
            ? JSON.parse(req.body.assignedTelecallerIds)
            : req.body.assignedTelecallerIds;
          if (Array.isArray(parsed)) {
            assignedTelecallerIds = parsed.map(Number).filter((n) => !isNaN(n) && n > 0);
          }
        } catch (_) {}
      }

      const explicitTelecallerId = req.body.telecallerId
        ? Number(req.body.telecallerId)
        : (isAdmin ? undefined : authUser?.employeeId);

      const skipDuplicates = req.body.skipDuplicates !== false &&
        req.body.skipDuplicates !== 'false' &&
        req.body.skipDuplicates !== 0;

      const result = await crmService.importExcelLeads(
        req.file.buffer,
        authUser?.id,
        explicitTelecallerId,
        campaignId,
        getScope(req),
        authUser?.subOrganization,
        {
          assignmentMode,
          assignedTelecallerIds,
          skipDuplicates,
        },
      );
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to import Excel leads'));
    }
  },

  async checkPhone(req: Request, res: Response) {
    try {
      const phone = String(req.query.phone || req.body.phone || '');
      const scope = (req.query.scope as string) || getScope(req);
      const result = await crmService.checkPhone(phone, scope);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to check phone duplicate'));
    }
  },

  async mergeLeads(req: Request, res: Response) {
    try {
      const { primaryLeadId, duplicateLeadId, remarks } = req.body;
      const authUser = (req as any).user;
      const result = await crmService.mergeLeads(
        primaryLeadId,
        duplicateLeadId,
        { userId: authUser?.id, employeeId: authUser?.employeeId },
        remarks,
      );
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to merge leads'));
    }
  },

  async transferLead(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const { targetTelecallerId, remarks } = req.body;
      if (!targetTelecallerId || isNaN(Number(targetTelecallerId))) {
        return res.status(400).json(fail('Target telecaller ID is required'));
      }
      const authUser = (req as any).user;
      const role = String(authUser?.roleName || authUser?.role?.name || (typeof authUser?.role === 'string' ? authUser?.role : '')).toUpperCase();
      const perms = authUser?.permissions ?? {};
      const canTransfer = isAdminRole(role) ||
        (Array.isArray(perms['CRM_LEAD_TRANSFER']) && perms['CRM_LEAD_TRANSFER'].length > 0) ||
        (Array.isArray(perms['CRM_TRANSFER_LEADS']) && perms['CRM_TRANSFER_LEADS'].length > 0);
      if (!canTransfer) {
        return res.status(403).json(fail('You do not have permission to transfer leads. Contact your administrator.'));
      }
      const userContext = {
        userId: authUser?.id,
        employeeId: authUser?.employeeId,
        role: authUser?.roleName || authUser?.role?.name || (typeof authUser?.role === 'string' ? authUser?.role : ''),
        username: authUser?.username,
      };
      const result = await crmService.transferLead(
        id,
        Number(targetTelecallerId),
        remarks,
        userContext,
      );
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to transfer lead'));
    }
  },

  async updateLeadStatus(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const {
        status,
        scheduledDate,
        scheduledTime,
        remarks,
        assignedToId,
        notInterestedReason,
        notInterestedRemark,
        scheduledVisitAt,
      } = req.body;
      const authUser = (req as any).user;

      const updated = await crmService.updateLeadStatus(
        id,
        status,
        {
          scheduledDate,
          scheduledTime,
          remarks,
          assignedToId,
          notInterestedReason,
          notInterestedRemark,
          scheduledVisitAt,
        },
        {
          userId: authUser?.id,
          employeeId: authUser?.employeeId,
          role: authUser?.role,
        },
      );
      res.json(ok(updated));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to update lead status'));
    }
  },

  async visitorLookup(req: Request, res: Response) {
    try {
      const phone = String(req.query.phone || '');
      const authUser = (req as any).user;
      const result = await crmService.visitorLookup(phone, {
        employeeId: authUser?.employeeId,
        role: authUser?.role,
      });
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to lookup visitor'));
    }
  },

  async visitorCheckin(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const result = await crmService.visitorCheckin(req.body, {
        userId: authUser?.id,
        employeeId: authUser?.employeeId,
        role: authUser?.role,
      });
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to check-in visitor'));
    }
  },

  async updateLead(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const authUser = (req as any).user;
      const updated = await crmService.updateLead(id, req.body, {
        userId: authUser?.id,
        employeeId: authUser?.employeeId,
        role: authUser?.role,
      });
      res.json(ok(updated));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to update lead'));
    }
  },

  async moveToBin(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const authUser = (req as any).user;
      const result = await crmService.moveToBin(id, {
        userId: authUser?.id,
        employeeId: authUser?.employeeId,
        role: authUser?.role,
      });
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to move lead to bin'));
    }
  },

  async restoreFromBin(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const result = await crmService.restoreFromBin(id);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to restore lead from bin'));
    }
  },

  async getBin(req: Request, res: Response) {
    try {
      const module = (req.query.module as string) || 'PRE_SALES';
      const items = await crmService.getBinLeads(module, getScope(req));
      res.json(ok(items));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch bin leads'));
    }
  },

  // Follow-ups
  async getFollowUps(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const followUps = await crmService.getFollowUps({
        leadId: req.query.leadId as string,
        filter: req.query.filter as any,
        date: req.query.date as string,
        scope: getScope(req),
        userContext: authUser ? {
          userId: authUser.id,
          employeeId: authUser.employeeId,
          role: authUser.role,
        } : undefined,
      });
      res.json(ok(followUps));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch follow-ups'));
    }
  },

  async createFollowUp(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const followUp = await crmService.createFollowUp(req.body, authUser?.id);
      res.json(ok(followUp));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to schedule follow-up'));
    }
  },

  async completeFollowUp(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const { remarks } = req.body;
      const updated = await crmService.completeFollowUp(id, remarks);
      res.json(ok(updated));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to complete follow-up'));
    }
  },

  // Settings & Telephony
  async getSettings(req: Request, res: Response) {
    try {
      const settings = await crmService.getSettings(getScope(req));
      res.json(ok(settings));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch CRM settings'));
    }
  },

  async updateSettings(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const settings = await crmService.updateSettings(req.body, authUser?.id, getScope(req));
      res.json(ok(settings));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to update CRM settings'));
    }
  },

  async listTelecallerTelephony(req: Request, res: Response) {
    try {
      const data = await crmService.listTelecallerTelephony(getScope(req));
      res.json(ok(data));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to list telecaller telephony'));
    }
  },

  async upsertTelecallerTelephony(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const employeeId = parseInt(String(req.params.employeeId), 10);
      const data = await crmService.upsertTelecallerTelephony(
        employeeId,
        req.body ?? {},
        authUser?.id,
        getScope(req),
      );
      res.json(ok(data));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to save telecaller telephony'));
    }
  },

  async clickToCall(req: Request, res: Response) {
    try {
      const { leadId, agentId } = req.body;
      const authUser = (req as any).user;
      const result = await crmService.clickToCall(leadId, agentId, authUser);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to initiate click-to-call'));
    }
  },

  async getKpiMetrics(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const metrics = await crmService.getKpiMetrics(
        req.query.projectId as string | undefined,
        req.query.campaignId as string | undefined,
        getScope(req),
        authUser?.role,
        authUser?.employeeId,
        authUser?.id,
        req.query.date as string | undefined,
      );
      res.json(ok(metrics));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch KPI metrics'));
    }
  },

  async getSalesUsers(req: Request, res: Response) {
    try {
      const users = await crmService.getSalesUsers({
        telecallersOnly: req.query.telecallersOnly as string,
      });
      res.json(ok(users));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch sales users'));
    }
  },

  async handleTelephonyWebhook(req: Request, res: Response) {
    try {
      console.log('[GREETER WEBHOOK RECEIVED]:', JSON.stringify({ body: req.body, query: req.query, headers: req.headers }, null, 2));
      const payload = { ...req.body, ...req.query };
      const result = await crmService.handleTelephonyWebhook(payload);
      console.log('[GREETER WEBHOOK RESULT]:', result);
      res.json(result);
    } catch (err: any) {
      console.error('[GREETER WEBHOOK ERROR]:', err);
      res.status(400).json({ status: 'error', message: err.message || 'Webhook processing failed' });
    }
  },

  async streamCallAudio(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      await crmService.streamCallAudio(id, req, res);
    } catch (err: any) {
      if (!res.headersSent) {
        res.status(404).json({ status: 'error', message: err.message || 'Recording not found' });
      }
    }
  },

  async getCallLogs(req: Request, res: Response) {
    try {
      const logs = await crmService.getCallLogs(req.query as any);
      res.json(ok(logs));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch call logs'));
    }
  },

  async updateCallLog(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const log = await crmService.updateCallLog(id, req.body);
      res.json(ok(log));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to update call log'));
    }
  },

  // WhatsApp Automation
  async getWhatsappConfig(req: Request, res: Response) {
    try {
      const config = await crmService.getWhatsappConfig(getScope(req));
      res.json(ok(config));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch WhatsApp configuration'));
    }
  },

  async updateWhatsappConfig(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const config = await crmService.updateWhatsappConfig(req.body, authUser?.id, getScope(req));
      res.json(ok(config));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to update WhatsApp configuration'));
    }
  },

  async testWhatsappConnection(req: Request, res: Response) {
    try {
      const result = await crmService.testWhatsappConnection(getScope(req));
      res.json(ok(result));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to test BotBiz WhatsApp connection'));
    }
  },

  async syncWhatsappTemplates(req: Request, res: Response) {
    try {
      const result = await crmService.syncWhatsappTemplates(getScope(req));
      res.json(ok(result));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to sync templates from BotBiz'));
    }
  },

  async getWhatsappTemplates(req: Request, res: Response) {
    try {
      const result = await crmService.getWhatsappTemplates(getScope(req));
      res.json(ok(result));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch cached WhatsApp templates'));
    }
  },

  async checkWhatsappTemplateStatus(req: Request, res: Response) {
    try {
      const templateId = String(req.params.templateId);
      if (!templateId) return res.status(400).json(fail('Template ID is required'));
      const result = await crmService.checkWhatsappTemplateStatus(templateId, getScope(req));
      res.json(ok(result));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to check template status'));
    }
  },

  async retryWhatsappLog(req: Request, res: Response) {
    try {
      const logId = String(req.params.logId);
      if (!logId) return res.status(400).json(fail('Log ID is required'));
      const result = await crmService.retryWhatsappLog(logId, getScope(req));
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to retry WhatsApp message'));
    }
  },

  async sendTestWhatsappMessage(req: Request, res: Response) {
    try {
      const { phone, message, templateId } = req.body;
      if (!phone) return res.status(400).json(fail('Phone number is required'));
      const result = await crmService.sendTestWhatsappMessage(phone, message, templateId, getScope(req));
      if (!result.success) {
        return res.status(400).json(fail((result as any).error || (result as any).message || 'Failed to send test WhatsApp message'));
      }
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to send test WhatsApp message'));
    }
  },

  async getWhatsappLogs(req: Request, res: Response) {
    try {
      const limit = req.query.limit ? parseInt(String(req.query.limit), 10) : 50;
      const logs = await crmService.getWhatsappLogs(limit, getScope(req));
      res.json(ok(logs));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch WhatsApp logs'));
    }
  },

  async sendLeadWhatsapp(req: Request, res: Response) {
    try {
      const leadId = String(req.params.id);
      const result = await crmService.sendLeadWhatsapp(leadId, req.body);
      if (!result.success) {
        return res.status(400).json(fail((result as any).error || (result as any).message || 'Failed to send lead WhatsApp message'));
      }
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to send lead WhatsApp message'));
    }
  },

  async wipeRealEstatePreSalesData(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const empId = Number(authUser?.employeeId);
      const role = String(authUser?.roleName || authUser?.role?.name || (typeof authUser?.role === 'string' ? authUser?.role : '')).toUpperCase();
      const username = String(authUser?.username || '').toUpperCase();
      const isAllowed = empId === 1 && (
        role.includes('ITADMIN') ||
        role.includes('ADMIN') ||
        username.includes('ITADMIN') ||
        username === '1'
      );
      if (!isAllowed) {
        return res.status(403).json(fail('Forbidden: Clean CRM Data is only permitted for ITADMIN with employee code 1'));
      }
      const result = await crmService.wipeRealEstatePreSalesData();
      res.json(ok(result));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to clean Real Estate pre-sales data'));
    }
  },

  async servePublicBrochure(req: Request, res: Response) {
    try {
      const rawName = String(req.params.filename || req.query.name || 'legacy-tower.pdf').toLowerCase();
      const isFinserve = rawName.includes('finserve') || rawName.includes('loan');
      const isImage = rawName.endsWith('.jpg') || rawName.endsWith('.jpeg') || rawName.endsWith('.png');

      const safeFilename = isImage
        ? (isFinserve ? 'nb-finserve.jpg' : 'legacy-tower.jpg')
        : (isFinserve ? 'nb-finserve.pdf' : 'legacy-tower.pdf');

      // Check on local disk first
      const diskPaths = [
        path.join(process.cwd(), 'uploads', 'crm', 'brochures', safeFilename),
        path.join(process.cwd(), 'uploads', 'crm', safeFilename),
        path.join(process.cwd(), 'backend', 'uploads', 'crm', 'brochures', safeFilename),
        path.join(process.cwd(), 'backend', 'uploads', 'crm', safeFilename),
      ];

      for (const p of diskPaths) {
        if (fs.existsSync(p)) {
          const stats = fs.statSync(p);
          // If the file is on disk and has reasonable size (< 15MB), serve it directly
          if (stats.size > 0 && stats.size < 15 * 1024 * 1024) {
            const absPath = path.resolve(p);
            res.setHeader('Content-Type', isImage ? 'image/jpeg' : 'application/pdf');
            res.setHeader('Content-Length', String(stats.size));
            res.setHeader('Content-Disposition', `inline; filename="${safeFilename}"`);
            res.setHeader('Access-Control-Allow-Origin', '*');
            res.setHeader('Cache-Control', 'public, max-age=86400');
            return res.sendFile(absPath);
          }
        }
      }

      if (isImage) {
        // Redirect to verified Cloudinary image asset
        return res.redirect(302, CLOUDINARY_DEFAULT_IMAGE);
      }

      // Fast, lightweight, standard 13KB PDF brochure buffer with proper Content-Length and application/pdf headers
      const pdfBuffer = Buffer.from(DEFAULT_BROCHURE_PDF_BASE64, 'base64');
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Length', String(pdfBuffer.length));
      res.setHeader('Content-Disposition', `inline; filename="${safeFilename}"`);
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Cache-Control', 'public, max-age=86400');
      return res.status(200).send(pdfBuffer);
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to serve brochure'));
    }
  },

  async uploadBrochure(req: Request, res: Response) {
    try {
      if (!req.file) {
        return res.status(400).json(fail('No brochure file uploaded'));
      }
      const authUser = (req as any).user;
      const result = await crmService.uploadBrochure(req.file, authUser?.id);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to upload brochure'));
    }
  },

  async getVirtualBuilding(req: Request, res: Response) {
    try {
      const { projectId, towerId } = req.query as { projectId?: string; towerId?: string };
      if (!projectId || !towerId) {
        return res.status(400).json(fail('projectId and towerId query parameters are required'));
      }
      const result = await crmService.getVirtualBuilding(projectId, towerId, (req as any).crmScope);
      res.json(ok(result));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch virtual building elevation'));
    }
  },

  async updateVirtualBuildingUnit(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const result = await crmService.updateVirtualBuildingUnit({
        ...req.body,
        updatedBy: authUser?.name || 'CRM User',
      });
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to update unit'));
    }
  },

  // ---------------------------------------------------------------------------
  // Finserve Application Details & Client Portal
  // ---------------------------------------------------------------------------
  async updateLeadApplicationDetails(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const leadId = String(req.params.id);
      const result = await crmService.updateLeadApplicationDetails(
        leadId,
        req.body,
        authUser?.id,
      );
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to update application details'));
    }
  },

  async updateFinservePipeline(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const leadId = String(req.params.id);
      const result = await crmService.updateFinservePipeline(
        leadId,
        req.body,
        authUser?.name || authUser?.username || 'Staff',
      );
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to update Finserve pipeline'));
    }
  },

  async addBankQuery(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const leadId = String(req.params.id);
      const result = await crmService.addBankQuery(
        leadId,
        req.body,
        authUser?.name || authUser?.username || 'Staff',
      );
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to add bank query'));
    }
  },

  async resolveBankQuery(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const leadId = String(req.params.id);
      const queryId = String(req.params.queryId);
      const result = await crmService.resolveBankQuery(
        leadId,
        queryId,
        req.body,
        authUser?.name || authUser?.username || 'Staff',
      );
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to resolve bank query'));
    }
  },

  async generateClientPortalLink(req: Request, res: Response) {
    try {
      const leadId = String(req.params.id);
      const origin = String(req.headers.origin || `${req.protocol}://${req.get('host')}`);
      const result = await crmService.generateClientPortalLink(leadId, origin);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to generate client portal link'));
    }
  },

  async uploadLeadDoc(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const leadId = String(req.params.id);
      const file = req.file;
      if (!file) return res.status(400).json(fail('No document file uploaded'));
      const { docTypeId, docName } = req.body;
      const result = await crmService.uploadLeadDoc(
        leadId,
        docTypeId || 'document',
        docName || '',
        file,
        authUser?.name || 'SALES_REP',
      );
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to upload lead document'));
    }
  },

  // Public Client Portal
  async getClientPortalInfo(req: Request, res: Response) {
    try {
      const token = String(req.params.token || req.query.token || '');
      const result = await crmService.getClientPortalInfo(token);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to fetch portal info'));
    }
  },

  async sendClientPortalOtp(req: Request, res: Response) {
    try {
      const token = String(req.params.token || req.body.token || '');
      const { mobile } = req.body;
      const result = await crmService.sendClientPortalOtp(token, mobile);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to send verification code'));
    }
  },

  async verifyClientPortalOtp(req: Request, res: Response) {
    try {
      const token = String(req.params.token || req.body.token || '');
      const { mobile, otp } = req.body;
      const result = await crmService.verifyClientPortalOtp(token, mobile, otp);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to verify code'));
    }
  },

  async uploadClientPortalDoc(req: Request, res: Response) {
    try {
      const token = String(req.params.token || req.body.token || '');
      const file = req.file;
      if (!file) return res.status(400).json(fail('No file provided for upload'));
      const { docTypeId, docName } = req.body;
      const result = await crmService.uploadClientPortalDoc(token, docTypeId || 'doc', docName || '', file);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to upload document'));
    }
  },

  async submitClientPortal(req: Request, res: Response) {
    try {
      const token = String(req.params.token || req.body.token || '');
      const result = await crmService.submitClientPortal(token);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to submit application'));
    }
  },

  renderClientPortalPage(_req: Request, res: Response) {
    const candidates = [
      path.join(__dirname, 'client-portal.html'),
      path.join(__dirname, '../../src/modules/crm/client-portal.html'),
      path.join(process.cwd(), 'src/modules/crm/client-portal.html'),
      path.join(process.cwd(), 'dist/modules/crm/client-portal.html'),
      path.join(process.cwd(), 'backend/src/modules/crm/client-portal.html'),
      path.join(process.cwd(), 'backend/dist/modules/crm/client-portal.html'),
    ];
    for (const cand of candidates) {
      if (fs.existsSync(cand)) {
        return res.sendFile(cand);
      }
    }
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.send(CLIENT_PORTAL_HTML);
  },

  async downloadLeadDocsZip(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      await crmService.downloadLeadDocsZip(id, res, false);
    } catch (err: any) {
      if (!res.headersSent) {
        res.status(500).json(fail(err.message || 'Failed to download documents zip'));
      }
    }
  },

  async downloadLeadDocsZipPublic(req: Request, res: Response) {
    try {
      const token = String(req.params.token || req.params.id || req.query.token);
      await crmService.downloadLeadDocsZip(token, res, true);
    } catch (err: any) {
      if (!res.headersSent) {
        res.status(500).send(err.message || 'Failed to download documents zip');
      }
    }
  },

  async reportTelecallerActivity(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const isAdmin = isAdminRole(authUser?.roleName || authUser?.role);
      if (isAdmin) {
        return res.json(ok({ ignored: true, reason: 'Admin activity is not tracked for telecalling presence' }));
      }
      if (!authUser?.employeeId) {
        return res.status(400).json(fail('Employee profile required for telecaller activity'));
      }
      const rawStatus = (req.body.status || 'ACTIVE').toUpperCase();
      const status: 'ACTIVE' | 'ON_BREAK' = rawStatus === 'ON_BREAK' ? 'ON_BREAK' : 'ACTIVE';
      const result = crmService.recordTelecallerActivity(
        authUser.employeeId,
        status,
        authUser.subOrganization,
      );
      if (status === 'ACTIVE') {
        crmService
          .dispatchWaitingQueue(getScope(req), authUser.subOrganization)
          .catch((e) => console.error('[Telecaller Activity Dispatch Error]:', e));
      }
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to record telecaller activity'));
    }
  },

  async getTelecallerActivity(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const scope = getScope(req);
      const subOrg = authUser?.subOrganization;
      const list = await crmService.getTelecallerPresenceList(scope, subOrg);
      res.json(ok(list));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to get telecaller activity'));
    }
  },

  async getWaitingQueueStatus(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const scope = getScope(req);
      const result = await crmService.getWaitingQueueStatus(scope, authUser?.subOrganization);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to get waiting queue status'));
    }
  },

  async dispatchWaitingQueue(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const scope = getScope(req);
      const result = await crmService.dispatchWaitingQueue(scope, authUser?.subOrganization);
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to dispatch waiting queue'));
    }
  },
};


