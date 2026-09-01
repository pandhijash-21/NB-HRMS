import { Request, Response } from 'express';
import { crmService } from './crm.service';
import { ok, fail } from '../../utils/response';

export const crmController = {
  // Projects
  async getProjects(req: Request, res: Response) {
    try {
      const projects = await crmService.getProjects();
      res.json(ok(projects));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch projects'));
    }
  },

  async createProject(req: Request, res: Response) {
    try {
      const project = await crmService.createProject(req.body);
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
      const campaigns = await crmService.getCampaigns(module, projectId);
      res.json(ok(campaigns));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch campaigns'));
    }
  },

  async createCampaign(req: Request, res: Response) {
    try {
      const campaign = await crmService.createCampaign(req.body);
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
      const cols = await crmService.getColumns(module, campaignId);
      res.json(ok(cols));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch columns'));
    }
  },

  async createColumn(req: Request, res: Response) {
    try {
      const col = await crmService.createColumn(req.body);
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
      const leads = await crmService.getLeads({
        projectId: req.query.projectId as string,
        campaignId: req.query.campaignId as string,
        status: req.query.status as string,
        search: req.query.search as string,
        assignedToId: req.query.assignedToId ? parseInt(req.query.assignedToId as string, 10) : undefined,
        telecallerId: req.query.telecallerId ? parseInt(req.query.telecallerId as string, 10) : undefined,
        page: req.query.page ? parseInt(req.query.page as string, 10) : 1,
        limit: req.query.limit ? parseInt(req.query.limit as string, 10) : 50,
      });
      res.json(ok(leads));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch leads'));
    }
  },

  async createLead(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const lead = await crmService.createLead(
        req.body,
        authUser?.id,
        authUser?.employeeId,
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
      const campaignId = (req.body.campaignId || req.query.campaignId) as string | undefined;
      const result = await crmService.importExcelLeads(
        req.file.buffer,
        authUser?.id,
        authUser?.employeeId,
        campaignId,
      );
      res.json(ok(result));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to import Excel leads'));
    }
  },

  async updateLeadStatus(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const { status, scheduledDate, scheduledTime, remarks, assignedToId } = req.body;
      const authUser = (req as any).user;

      const updated = await crmService.updateLeadStatus(
        id,
        status,
        { scheduledDate, scheduledTime, remarks, assignedToId },
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
      const items = await crmService.getBinLeads(module);
      res.json(ok(items));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch bin leads'));
    }
  },

  // Follow-ups
  async getFollowUps(req: Request, res: Response) {
    try {
      const followUps = await crmService.getFollowUps({
        leadId: req.query.leadId as string,
        filter: req.query.filter as any,
        date: req.query.date as string,
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
      const settings = await crmService.getSettings();
      res.json(ok(settings));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch CRM settings'));
    }
  },

  async updateSettings(req: Request, res: Response) {
    try {
      const authUser = (req as any).user;
      const settings = await crmService.updateSettings(req.body, authUser?.id);
      res.json(ok(settings));
    } catch (err: any) {
      res.status(400).json(fail(err.message || 'Failed to update CRM settings'));
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
      const metrics = await crmService.getKpiMetrics(
        req.query.projectId as string | undefined,
        req.query.campaignId as string | undefined,
      );
      res.json(ok(metrics));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch KPI metrics'));
    }
  },

  async getSalesUsers(req: Request, res: Response) {
    try {
      const users = await crmService.getSalesUsers();
      res.json(ok(users));
    } catch (err: any) {
      res.status(500).json(fail(err.message || 'Failed to fetch sales users'));
    }
  },

  async handleTelephonyWebhook(req: Request, res: Response) {
    try {
      const payload = { ...req.body, ...req.query };
      const result = await crmService.handleTelephonyWebhook(payload);
      res.json(result);
    } catch (err: any) {
      res.status(400).json({ status: 'error', message: err.message || 'Webhook processing failed' });
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
};

