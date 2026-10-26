import type { Request, Response } from 'express';
import { CrmLeadStatus } from '@prisma/client';
import { prisma } from '../../config/prisma';
import * as crypto from 'crypto';
import * as path from 'path';
import * as fs from 'fs';
import * as xlsx from 'xlsx';
import * as archiverModule from 'archiver';

function initZipArchive(options: any = { zlib: { level: 9 } }): any {
  const mod: any = archiverModule;
  if (mod.ZipArchive) {
    return new mod.ZipArchive(options);
  }
  if (mod.default?.ZipArchive) {
    return new mod.default.ZipArchive(options);
  }
  if (typeof mod.default === 'function') {
    return mod.default('zip', options);
  }
  if (typeof mod === 'function') {
    return mod('zip', options);
  }
  try {
    const directReq = require('archiver');
    if (directReq.ZipArchive) return new directReq.ZipArchive(options);
    if (directReq.default?.ZipArchive) return new directReq.default.ZipArchive(options);
    if (typeof directReq === 'function') return directReq('zip', options);
    if (typeof directReq.default === 'function') return directReq.default('zip', options);
  } catch (_) {}
  throw new Error('Unable to initialize zip archive stream');
}
import { uploadService } from '../personal-education/upload.service';
import { whatsappService } from './whatsapp.service';
import { sendFinserveClientOtpEmail } from '../../utils/mailer';
import { isAdminRole } from '../auth/permissions-map';
import { deriveDayInOut } from '../attendance/dayPunch.rules';

interface TelecallerPresence {
  employeeId: number;
  lastActiveAt: number;
  status: 'ACTIVE' | 'ON_BREAK';
  subOrganization?: string | null;
}

const telecallerPresenceMap = new Map<number, TelecallerPresence>();

import {
  CreateProjectDto,
  UpdateProjectDto,
  CreateCampaignDto,
  UpdateCampaignDto,
  MergeColumnsDto,
  CreateColumnDto,
  UpdateColumnDto,
  CreateLeadDto,
  UpdateLeadDto,
  ScheduleFollowUpDto,
  UpdateCrmSettingsDto,
  UpdateLeadApplicationDetailsDto,
  UpdateFinservePipelineDto,
  BankApplicationItem,
  FinalBankDetails,
  BankQueryItem,
  DisbursementDetails,
} from './crm.types';

const DEFAULT_PRE_SALES_COLUMNS: Array<{
  columnKey: string;
  label: string;
  dataType: string;
  options?: string[];
  isRequired: boolean;
  isSystem: boolean;
  displayOrder: number;
}> = [
  { columnKey: 'Client_Name', label: 'Client Name', dataType: 'TEXT', isRequired: true, isSystem: true, displayOrder: 1 },
  { columnKey: 'Phone', label: 'Phone Number', dataType: 'PHONE', isRequired: true, isSystem: true, displayOrder: 2 },
  { columnKey: 'Email', label: 'Email Address', dataType: 'EMAIL', isRequired: false, isSystem: false, displayOrder: 3 },
  { columnKey: 'Project_Type', label: 'Requirement / Project', dataType: 'TEXT', isRequired: false, isSystem: false, displayOrder: 4 },
  { columnKey: 'Budget', label: 'Budget', dataType: 'TEXT', isRequired: false, isSystem: false, displayOrder: 5 },
  { columnKey: 'Location', label: 'Location / City', dataType: 'TEXT', isRequired: false, isSystem: false, displayOrder: 6 },
  {
    columnKey: 'Source',
    label: 'Lead Source',
    dataType: 'SELECT',
    options: ['Website', 'Direct Call', 'Referral', 'Walk-in', 'Social Media', 'Excel Import', 'Meta Ads', 'Google Ads'],
    isRequired: false,
    isSystem: false,
    displayOrder: 7,
  },
  { columnKey: 'Notes', label: 'Remarks / Notes', dataType: 'TEXT', isRequired: false, isSystem: false, displayOrder: 8 },
];

const DEFAULT_FINSERVE_PRE_SALES_COLUMNS: Array<{
  columnKey: string;
  label: string;
  dataType: string;
  options?: string[];
  isRequired: boolean;
  isSystem: boolean;
  displayOrder: number;
}> = [
  { columnKey: 'Client_Name', label: 'Client Name', dataType: 'TEXT', isRequired: true, isSystem: true, displayOrder: 1 },
  { columnKey: 'Phone', label: 'Phone Number', dataType: 'PHONE', isRequired: true, isSystem: true, displayOrder: 2 },
  { columnKey: 'Email', label: 'Email Address', dataType: 'EMAIL', isRequired: false, isSystem: false, displayOrder: 3 },
  {
    columnKey: 'Loan_Type',
    label: 'Type of Loan',
    dataType: 'SELECT',
    options: ['Home Loan', 'Personal Loan', 'Business Loan', 'Mortgage / LAP', 'Auto Loan', 'Education Loan'],
    isRequired: false,
    isSystem: false,
    displayOrder: 4,
  },
  { columnKey: 'Amount', label: 'Amount', dataType: 'TEXT', isRequired: false, isSystem: false, displayOrder: 5 },
  { columnKey: 'Location', label: 'Location / City', dataType: 'TEXT', isRequired: false, isSystem: false, displayOrder: 6 },
  {
    columnKey: 'Source',
    label: 'Lead Source',
    dataType: 'SELECT',
    options: ['Website', 'Direct Call', 'Referral', 'Walk-in', 'Social Media', 'Excel Import', 'Meta Ads', 'Google Ads'],
    isRequired: false,
    isSystem: false,
    displayOrder: 7,
  },
  { columnKey: 'Notes', label: 'Remarks / Notes', dataType: 'TEXT', isRequired: false, isSystem: false, displayOrder: 8 },
];

export const crmService = {
  // ---------------------------------------------------------------------------
  // Key Normalization Helper
  // Rule 1: Always first letter capitalized for each word (e.g. name -> Name, client name -> Client_Name)
  // Rule 2: Spacing stored as underscores (e.g. follow up -> Follow_Up)
  // ---------------------------------------------------------------------------
  normalizeHeaderKey(rawKey: string): string {
    if (!rawKey) return '';
    const parts = String(rawKey)
      .trim()
      .replace(/[\s\-.]+/g, '_')
      .split('_')
      .filter((p) => p.length > 0);

    return parts
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join('_');
  },

  // ---------------------------------------------------------------------------
  // Projects Management
  // ---------------------------------------------------------------------------
  async getProjects(scope: string = 'NB_DEVELOPER') {
    return prisma.crmProject.findMany({
      where: { scope },
      orderBy: { createdAt: 'desc' },
      include: {
        campaigns: {
          where: { isActive: true, scope },
          select: {
            id: true,
            name: true,
            code: true,
            adId: true,
            webhookToken: true,
            startDate: true,
            isActive: true,
            _count: { select: { leads: { where: { isDeleted: false, scope } } } },
          },
        },
        _count: {
          select: { campaigns: { where: { isActive: true, scope } } },
        },
      },
    });
  },

  async createProject(dto: CreateProjectDto, scope: string = 'NB_DEVELOPER') {
    const code = (dto.code && dto.code.trim())
      ? dto.code.trim().toUpperCase().replace(/[^A-Z0-9_]/g, '_')
      : dto.name.trim().toUpperCase().replace(/[^A-Z0-9_]/g, '_') + '_' + Date.now().toString().slice(-4);

    return prisma.crmProject.create({
      data: {
        name: dto.name.trim(),
        code,
        scope,
        description: dto.description?.trim() || null,
        location: dto.location?.trim() || null,
        startDate: dto.startDate ? new Date(dto.startDate) : null,
        isActive: true,
      },
    });
  },

  async updateProject(id: string, dto: UpdateProjectDto) {
    return prisma.crmProject.update({
      where: { id },
      data: {
        ...(dto.name && { name: dto.name.trim() }),
        ...(dto.description !== undefined && { description: dto.description?.trim() || null }),
        ...(dto.location !== undefined && { location: dto.location?.trim() || null }),
        ...(dto.startDate !== undefined && { startDate: dto.startDate ? new Date(dto.startDate) : null }),
        ...(dto.isActive !== undefined && { isActive: dto.isActive }),
      },
    });
  },

  async deleteProject(id: string) {
    return prisma.crmProject.delete({
      where: { id },
    });
  },

  // ---------------------------------------------------------------------------
  // Campaigns Management & Webhook Token Generation
  // ---------------------------------------------------------------------------
  async ensureDefaultCampaign(module = 'PRE_SALES', scope: string = 'NB_DEVELOPER') {
    const isFinserve = scope === 'NB_FINSERVE';
    const defaultCode = isFinserve
      ? (module === 'PRE_SALES' ? 'FINSERVE_DEFAULT' : `FINSERVE_DEFAULT_${module}`)
      : (module === 'PRE_SALES' ? 'DEFAULT' : `DEFAULT_${module}`);

    let campaign = await prisma.crmCampaign.findUnique({
      where: { code: defaultCode },
    });

    // Legacy rows may have code DEFAULT but a mismatched / empty module value.
    if (!campaign && defaultCode === 'DEFAULT') {
      campaign = await prisma.crmCampaign.findFirst({
        where: { code: 'DEFAULT' },
      });
    }

    if (!campaign) {
      const webhookToken = crypto.randomBytes(12).toString('hex');
      try {
        campaign = await prisma.crmCampaign.create({
          data: {
            name: isFinserve ? 'NB Finserve Primary Campaign' : 'Default Campaign',
            code: defaultCode,
            description: isFinserve
              ? 'Primary NB Finserve Campaign'
              : (module === 'PRE_SALES'
                ? 'Primary Pre-Sales Campaign'
                : `Primary ${module} Campaign`),
            webhookToken,
            module,
            scope,
            isActive: true,
          },
        });
      } catch (err: any) {
        // Concurrent ensure / leftover unique code — re-fetch instead of failing the leads list.
        if (err?.code === 'P2002') {
          campaign = await prisma.crmCampaign.findUnique({
            where: { code: defaultCode },
          });
          if (!campaign && defaultCode === 'DEFAULT') {
            campaign = await prisma.crmCampaign.findFirst({
              where: { code: 'DEFAULT' },
            });
          }
          if (!campaign) throw err;
        } else {
          throw err;
        }
      }
    }

    if (campaign.scope !== scope) {
      campaign = await prisma.crmCampaign.update({
        where: { id: campaign.id },
        data: { scope },
      });
    }

    if (campaign.module !== module && campaign.code === defaultCode) {
      campaign = await prisma.crmCampaign.update({
        where: { id: campaign.id },
        data: { module },
      });
    }

    if (!campaign.webhookToken) {
      const webhookToken = crypto.randomBytes(12).toString('hex');
      campaign = await prisma.crmCampaign.update({
        where: { id: campaign.id },
        data: { webhookToken },
      });
    }

    // Attach any orphan columns/leads with null campaignId to this default campaign if same scope
    await prisma.crmColumnConfig.updateMany({
      where: { module, campaignId: null, scope },
      data: { campaignId: campaign.id },
    });

    await prisma.crmLead.updateMany({
      where: { campaignId: null, scope },
      data: { campaignId: campaign.id },
    });

    // Check if columns exist for this campaign
    if (module === 'PRE_SALES') {
      const existingColKeys = new Set(
        (
          await prisma.crmColumnConfig.findMany({
            where: { module, campaignId: campaign.id, scope },
            select: { columnKey: true },
          })
        ).map((c) => c.columnKey)
      );

      const defaultCols = isFinserve ? DEFAULT_FINSERVE_PRE_SALES_COLUMNS : DEFAULT_PRE_SALES_COLUMNS;
      for (const col of defaultCols) {
        if (!existingColKeys.has(col.columnKey)) {
          try {
            await prisma.crmColumnConfig.create({
              data: {
                scope,
                module,
                campaignId: campaign.id,
                columnKey: col.columnKey,
                label: col.label,
                dataType: col.dataType,
                options: col.options || [],
                isRequired: col.isRequired,
                isSystem: col.isSystem,
                displayOrder: col.displayOrder,
                isVisibleInTable: true,
                isActive: true,
              },
            });
          } catch (err: any) {
            if (err?.code !== 'P2002') {
              throw err;
            }
          }
        }
      }
    }

    return campaign;
  },

  async getCampaigns(module = 'PRE_SALES', projectId?: string, scope: string = 'NB_DEVELOPER') {
    if (!projectId) {
      await this.ensureDefaultCampaign(module, scope);
    }
    const where: any = { module, isActive: true, scope };
    if (projectId) {
      where.projectId = projectId;
    }

    const campaigns = await prisma.crmCampaign.findMany({
      where,
      include: {
        project: {
          select: { id: true, name: true, code: true },
        },
        _count: {
          select: {
            columns: { where: { isActive: true, scope } },
            leads: { where: { isDeleted: false, scope } },
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    return campaigns.map((c) => ({
      id: c.id,
      projectId: c.projectId,
      projectName: c.project?.name || null,
      name: c.name,
      code: c.code,
      adId: c.adId,
      webhookToken: c.webhookToken,
      description: c.description,
      startDate: c.startDate,
      module: c.module,
      isActive: c.isActive,
      columnsCount: c._count.columns,
      leadsCount: c._count.leads,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
    }));
  },

  async createCampaign(dto: CreateCampaignDto, scope: string = 'NB_DEVELOPER') {
    const module = dto.module || 'PRE_SALES';
    const defaultCamp = await this.ensureDefaultCampaign(module, scope);

    const generatedCode = (dto.code && dto.code.trim())
      ? dto.code.trim().toUpperCase().replace(/[^A-Z0-9_]/g, '_')
      : dto.name.trim().toUpperCase().replace(/[^A-Z0-9_]/g, '_') + '_' + Date.now().toString().slice(-4);

    const webhookToken = crypto.randomBytes(12).toString('hex');

    const created = await prisma.crmCampaign.create({
      data: {
        projectId: dto.projectId || null,
        name: dto.name.trim(),
        code: generatedCode,
        adId: dto.adId?.trim() || null,
        webhookToken,
        description: dto.description?.trim() || null,
        startDate: dto.startDate ? new Date(dto.startDate) : null,
        module,
        scope,
        assignedTelecallerIds: (dto.assignedTelecallerIds || []).map(Number).filter((n) => !isNaN(n) && n > 0),
        assignmentMode: dto.assignmentMode || 'ROUND_ROBIN',
        isActive: true,
      },
      include: {
        project: { select: { id: true, name: true } },
      },
    });

    // Clone columns from source campaign (or default campaign)
    const sourceCampaignId = dto.copyFromCampaignId || defaultCamp.id;
    const sourceColumns = await prisma.crmColumnConfig.findMany({
      where: { campaignId: sourceCampaignId, isActive: true, scope },
      orderBy: { displayOrder: 'asc' },
    });

    if (sourceColumns.length > 0) {
      for (const col of sourceColumns) {
        await prisma.crmColumnConfig.create({
          data: {
            scope,
            module,
            campaignId: created.id,
            columnKey: col.columnKey,
            label: col.label,
            dataType: col.dataType,
            options: col.options,
            isRequired: col.isRequired,
            isSystem: col.isSystem,
            isVisibleInTable: col.isVisibleInTable,
            displayOrder: col.displayOrder,
            isActive: true,
          },
        });
      }
    } else {
      // Default fallback columns
      for (const col of DEFAULT_PRE_SALES_COLUMNS) {
        await prisma.crmColumnConfig.create({
          data: {
            scope,
            module,
            campaignId: created.id,
            columnKey: col.columnKey,
            label: col.label,
            dataType: col.dataType,
            options: col.options || [],
            isRequired: col.isRequired,
            isSystem: col.isSystem,
            isVisibleInTable: true,
            displayOrder: col.displayOrder,
            isActive: true,
          },
        });
      }
    }

    return created;
  },

  async updateCampaign(id: string, dto: UpdateCampaignDto) {
    return prisma.crmCampaign.update({
      where: { id },
      data: {
        ...(dto.name && { name: dto.name.trim() }),
        ...(dto.adId !== undefined && { adId: dto.adId?.trim() || null }),
        ...(dto.projectId !== undefined && { projectId: dto.projectId }),
        ...(dto.description !== undefined && { description: dto.description?.trim() || null }),
        ...(dto.startDate !== undefined && { startDate: dto.startDate ? new Date(dto.startDate) : null }),
        ...(dto.isActive !== undefined && { isActive: dto.isActive }),
        ...(dto.assignedTelecallerIds !== undefined && {
          assignedTelecallerIds: (dto.assignedTelecallerIds || []).map(Number).filter((n) => !isNaN(n) && n > 0),
        }),
        ...(dto.assignmentMode !== undefined && { assignmentMode: dto.assignmentMode }),
      },
      include: {
        project: { select: { id: true, name: true } },
      },
    });
  },

  async deleteCampaign(id: string) {
    const existing = await prisma.crmCampaign.findUnique({ where: { id } });
    if (!existing) throw new Error('Campaign not found');
    if (existing.code === 'DEFAULT') {
      throw new Error('Default campaign cannot be deleted');
    }
    return prisma.crmCampaign.update({
      where: { id },
      data: { isActive: false },
    });
  },

  // ---------------------------------------------------------------------------
  // Inbound Campaign Webhook Ingestion
  // ---------------------------------------------------------------------------
  async handleCampaignWebhook(token: string, payload: any) {
    const campaign = await prisma.crmCampaign.findFirst({
      where: {
        OR: [
          { webhookToken: token },
          { id: token },
        ],
      },
      include: { project: true },
    });
    if (!campaign) {
      throw new Error(`Invalid campaign webhook token: ${token}`);
    }

    if (!payload || typeof payload !== 'object') {
      throw new Error('Invalid JSON payload');
    }

    let sourceData: Record<string, any> = { ...payload };

    // Support Meta Graph API field_data array format (from n8n / Graph API)
    if (Array.isArray(payload.field_data)) {
      for (const item of payload.field_data) {
        if (item && item.name && Array.isArray(item.values) && item.values.length > 0) {
          sourceData[item.name] = item.values[0];
        }
      }
    }

    // Support Meta Webhook raw entry format
    if (Array.isArray(payload.entry) && payload.entry.length > 0) {
      const entry = payload.entry[0];
      if (Array.isArray(entry.changes) && entry.changes.length > 0) {
        const val = entry.changes[0].value;
        if (val && typeof val === 'object') {
          sourceData = { ...sourceData, ...val };
        }
      }
    }

    // Preserve Meta IDs explicitly if present
    if (payload.id && !sourceData.leadgen_id) {
      sourceData.leadgen_id = payload.id;
    }

    // Normalize all keys in payload
    const normalizedPayload: Record<string, any> = {};
    for (const [rawK, rawV] of Object.entries(sourceData)) {
      if (rawK === 'field_data' || rawK === 'entry') continue;
      const normKey = this.normalizeHeaderKey(rawK);
      if (normKey) {
        normalizedPayload[normKey] = rawV;
      }
    }

    // Auto-discover and register any new headers in crm_column_configs for this campaign
    const existingColumns = await prisma.crmColumnConfig.findMany({
      where: {
        campaignId: campaign.id,
        module: campaign.module,
        scope: campaign.scope || 'NB_DEVELOPER',
      },
    });
    const existingKeys = new Set(existingColumns.map((c) => c.columnKey));

    let displayOrder = existingColumns.length;
    for (const key of Object.keys(normalizedPayload)) {
      if (!existingKeys.has(key)) {
        const label = key.replace(/_/g, ' ');
        await prisma.crmColumnConfig.create({
          data: {
            scope: campaign.scope || 'NB_DEVELOPER',
            campaignId: campaign.id,
            module: campaign.module,
            columnKey: key,
            label,
            dataType:
              key.toLowerCase().includes('phone') || key.toLowerCase().includes('mobile')
                ? 'PHONE'
                : key.toLowerCase().includes('email')
                ? 'EMAIL'
                : key.toLowerCase().includes('date')
                ? 'DATE'
                : 'TEXT',
            isVisibleInTable: true,
            isActive: true,
            displayOrder: ++displayOrder,
          },
        });
        existingKeys.add(key);
      }
    }

    // Extract phone & name
    const rawPhone = String(
      normalizedPayload['Phone'] ||
      normalizedPayload['Mobile'] ||
      normalizedPayload['Phone_Number'] ||
      normalizedPayload['Mobile_Number'] ||
      normalizedPayload['Contact'] ||
      normalizedPayload['Contact_Number'] ||
      normalizedPayload['Customer_No'] ||
      ''
    ).replace(/[^0-9]/g, '');

    const name = String(
      normalizedPayload['Name'] ||
      normalizedPayload['Full_Name'] ||
      normalizedPayload['Client_Name'] ||
      normalizedPayload['Customer_Name'] ||
      (rawPhone ? `Lead (${rawPhone})` : 'New Inbound Lead')
    ).trim();

    const campaignScope = campaign.scope || 'NB_DEVELOPER';

    // Campaign-specific telecaller routing
    let webhookAssignedTelecallerId: number | null = null;
    const campaignAssignedIds = Array.isArray((campaign as any).assignedTelecallerIds)
      ? (campaign as any).assignedTelecallerIds.map(Number).filter((n: number) => !isNaN(n) && n > 0)
      : [];

    if (campaignAssignedIds.length > 0) {
      if ((campaign as any).assignmentMode === 'SPECIFIC') {
        webhookAssignedTelecallerId = campaignAssignedIds[0];
      } else {
        // Round-robin among campaign telecallers (pick least loaded in this campaign)
        const counts = await prisma.crmLead.groupBy({
          by: ['telecallerId'],
          where: {
            campaignId: campaign.id,
            telecallerId: { in: campaignAssignedIds },
            isDeleted: false,
          },
          _count: { id: true },
        });
        const countMap = new Map<number, number>();
        for (const c of counts) {
          if (c.telecallerId) countMap.set(c.telecallerId, c._count.id);
        }
        let minCount = Infinity;
        let selectedId = campaignAssignedIds[0];
        for (const id of campaignAssignedIds) {
          const count = countMap.get(id) || 0;
          if (count < minCount) {
            minCount = count;
            selectedId = id;
          }
        }
        webhookAssignedTelecallerId = selectedId;
      }
    }

    const lead = await prisma.crmLead.create({
      data: {
        scope: campaignScope,
        campaignId: campaign.id,
        phone: rawPhone || '0000000000',
        name,
        status: CrmLeadStatus.NOT_STARTED,
        customFields: {
          ...normalizedPayload,
          ...(webhookAssignedTelecallerId ? { allocatedAt: new Date().toISOString() } : {}),
        },
        telecallerId: webhookAssignedTelecallerId,
        assignedToId: null,
        leadSource: 'WEBHOOK',
      },
    });

    // If no campaign-specific telecaller was configured, use waiting queue / global auto-dispatch
    if (!webhookAssignedTelecallerId) {
      await this.dispatchWaitingQueue(campaignScope);
    }

    // WhatsApp Automation: Auto-welcome message with brochure on new webhook lead
    whatsappService
      .triggerEvent('LEAD_CREATED', lead, {
        projectName: campaign.project?.name || (campaign.scope === 'NB_FINSERVE' ? 'NB Finserve' : 'Legacy Tower'),
      })
      .catch((err) => console.error('[CRM WhatsApp Hook Error - Webhook]:', err));

    return {
      status: 'success',
      message: 'Lead received and registered under campaign',
      leadId: lead.id,
      campaignId: campaign.id,
      campaignName: campaign.name,
      projectName: campaign.project?.name || null,
      headersDiscovered: Object.keys(normalizedPayload),
    };
  },

  // ---------------------------------------------------------------------------
  // Column Visibility Toggle & Merging
  // ---------------------------------------------------------------------------
  async toggleColumnVisibility(id: string, isVisibleInTable: boolean) {
    return prisma.crmColumnConfig.update({
      where: { id },
      data: { isVisibleInTable },
    });
  },

  async mergeColumns(dto: MergeColumnsDto) {
    const module = dto.module || 'PRE_SALES';
    const defaultCamp = await this.ensureDefaultCampaign(module);
    const campaignId = dto.campaignId || defaultCamp.id;

    const sourceKey = this.normalizeHeaderKey(dto.sourceKey);
    const targetKey = this.normalizeHeaderKey(dto.targetKey);

    if (sourceKey === targetKey) {
      throw new Error('Source and target columns cannot be the same');
    }

    // Find all leads for this campaign/module
    const leads = await prisma.crmLead.findMany({
      where: { campaignId },
    });

    let updatedCount = 0;
    for (const lead of leads) {
      const custom = (lead.customFields && typeof lead.customFields === 'object')
        ? { ...(lead.customFields as Record<string, any>) }
        : {};

      if (custom[sourceKey] !== undefined) {
        // If target key is empty, copy source value
        if (custom[targetKey] === undefined || custom[targetKey] === null || custom[targetKey] === '') {
          custom[targetKey] = custom[sourceKey];
        }
        delete custom[sourceKey];
        await prisma.crmLead.update({
          where: { id: lead.id },
          data: { customFields: custom },
        });
        updatedCount++;
      }
    }

    // Delete or mark source column config as merged
    await prisma.crmColumnConfig.deleteMany({
      where: {
        campaignId,
        module,
        columnKey: sourceKey,
      },
    });

    // Update target label if requested
    if (dto.targetLabel && dto.targetLabel.trim()) {
      await prisma.crmColumnConfig.updateMany({
        where: {
          campaignId,
          module,
          columnKey: targetKey,
        },
        data: {
          label: dto.targetLabel.trim(),
        },
      });
    }

    return {
      status: 'success',
      message: `Merged column "${sourceKey}" into "${targetKey}" across ${updatedCount} leads`,
      sourceKey,
      targetKey,
      updatedLeadsCount: updatedCount,
    };
  },

  // ---------------------------------------------------------------------------
  // Column Configuration (Campaign-Scoped)
  // ---------------------------------------------------------------------------
  async ensureDefaultColumns(module = 'PRE_SALES', scope: string = 'NB_DEVELOPER') {
    await this.ensureDefaultCampaign(module, scope);
  },

  async getColumns(module = 'PRE_SALES', campaignId?: string, scope: string = 'NB_DEVELOPER') {
    const isFinserve = scope === 'NB_FINSERVE';
    const defaultCamp = await this.ensureDefaultCampaign(module, scope);
    const targetCampaignId = campaignId || defaultCamp.id;

    // For Finserve Pre-Sales, dynamically migrate and sync Type of Loan and Amount
    if (isFinserve && module === 'PRE_SALES') {
      const settings = await this.getSettings('NB_FINSERVE');
      let loanTypeOptions = ['Home Loan', 'Personal Loan', 'Business Loan', 'Mortgage / LAP', 'Auto Loan', 'Education Loan'];
      try {
        if (settings.loan_types) {
          const parsed = typeof settings.loan_types === 'string' ? JSON.parse(settings.loan_types) : settings.loan_types;
          if (Array.isArray(parsed) && parsed.length > 0) loanTypeOptions = parsed;
        }
      } catch (_) {}

      // Safely migrate and deduplicate Project_Type and Budget columns without unique constraint collisions
      try {
        const existingCols = await prisma.crmColumnConfig.findMany({
          where: {
            scope: 'NB_FINSERVE',
            module: 'PRE_SALES',
            campaignId: targetCampaignId,
          },
        });

        const hasLoanType = existingCols.some((c) => c.columnKey === 'Loan_Type');
        const hasAmount = existingCols.some((c) => c.columnKey === 'Amount');

        for (const col of existingCols) {
          const isProjectCol = col.columnKey === 'Project_Type' || col.label.includes('Requirement') || col.label.includes('Project');
          if (isProjectCol) {
            if (!hasLoanType) {
              await prisma.crmColumnConfig.update({
                where: { id: col.id },
                data: { columnKey: 'Loan_Type', label: 'Type of Loan', dataType: 'SELECT', options: loanTypeOptions },
              });
            } else if (col.columnKey !== 'Loan_Type') {
              await prisma.crmColumnConfig.delete({ where: { id: col.id } });
            }
          } else if (col.columnKey === 'Loan_Type') {
            await prisma.crmColumnConfig.update({
              where: { id: col.id },
              data: { label: 'Type of Loan', dataType: 'SELECT', options: loanTypeOptions },
            });
          }

          const isBudgetCol = col.columnKey === 'Budget' || col.label === 'Budget';
          if (isBudgetCol) {
            if (!hasAmount) {
              await prisma.crmColumnConfig.update({
                where: { id: col.id },
                data: { columnKey: 'Amount', label: 'Amount' },
              });
            } else if (col.columnKey !== 'Amount') {
              await prisma.crmColumnConfig.delete({ where: { id: col.id } });
            }
          }
        }
      } catch (err: any) {
        console.warn('[CRM Finserve Column Sync Warning]:', err?.message || err);
      }
    }

    // Check if columns exist for this campaign, if not clone default
    const count = await prisma.crmColumnConfig.count({
      where: { module, campaignId: targetCampaignId, isActive: true, scope },
    });

    const defaultCols = isFinserve ? DEFAULT_FINSERVE_PRE_SALES_COLUMNS : DEFAULT_PRE_SALES_COLUMNS;

    if (count === 0 && module === 'PRE_SALES') {
      for (const col of defaultCols) {
        try {
          await prisma.crmColumnConfig.create({
            data: {
              scope,
              module,
              campaignId: targetCampaignId,
              columnKey: col.columnKey,
              label: col.label,
              dataType: col.dataType,
              options: col.options || [],
              isRequired: col.isRequired,
              isSystem: col.isSystem,
              displayOrder: col.displayOrder,
              isActive: true,
            },
          });
        } catch (err: any) {
          if (err?.code !== 'P2002') {
            throw err;
          }
        }
      }
    }

    return prisma.crmColumnConfig.findMany({
      where: { module, campaignId: targetCampaignId, isActive: true, scope },
      orderBy: { displayOrder: 'asc' },
    });
  },

  async createColumn(dto: CreateColumnDto, scope: string = 'NB_DEVELOPER') {
    const module = dto.module || 'PRE_SALES';
    const defaultCamp = await this.ensureDefaultCampaign(module, scope);
    const campaignId = dto.campaignId || defaultCamp.id;

    const key = dto.columnKey
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9_]/g, '_');

    // Determine max order
    const last = await prisma.crmColumnConfig.findFirst({
      where: { module, campaignId, scope },
      orderBy: { displayOrder: 'desc' },
    });
    const nextOrder = dto.displayOrder ?? (last ? last.displayOrder + 1 : 1);

    return prisma.crmColumnConfig.upsert({
      where: {
        module_campaignId_columnKey_scope: {
          module,
          campaignId,
          columnKey: key,
          scope,
        },
      },
      update: {
        label: dto.label,
        dataType: dto.dataType || 'TEXT',
        options: dto.options || [],
        isRequired: dto.isRequired ?? false,
        isActive: true,
        displayOrder: nextOrder,
      },
      create: {
        scope,
        module,
        campaignId,
        columnKey: key,
        label: dto.label,
        dataType: dto.dataType || 'TEXT',
        options: dto.options || [],
        isRequired: dto.isRequired ?? false,
        isSystem: dto.isSystem ?? false,
        displayOrder: nextOrder,
        isActive: true,
      },
    });
  },

  async updateColumn(id: string, dto: UpdateColumnDto) {
    return prisma.crmColumnConfig.update({
      where: { id },
      data: {
        ...(dto.label !== undefined && { label: dto.label }),
        ...(dto.dataType !== undefined && { dataType: dto.dataType }),
        ...(dto.options !== undefined && { options: dto.options }),
        ...(dto.isRequired !== undefined && { isRequired: dto.isRequired }),
        ...(dto.displayOrder !== undefined && { displayOrder: dto.displayOrder }),
        ...(dto.isActive !== undefined && { isActive: dto.isActive }),
      },
    });
  },

  async deleteColumn(id: string) {
    const col = await prisma.crmColumnConfig.findUnique({ where: { id } });
    if (!col) throw new Error('Column not found');
    if (col.isSystem) {
      throw new Error('System columns cannot be deleted');
    }
    return prisma.crmColumnConfig.delete({ where: { id } });
  },

  // ---------------------------------------------------------------------------
  // Leads Management (Campaign-Scoped)
  // ---------------------------------------------------------------------------
  async getLeads(query: {
    projectId?: string;
    campaignId?: string;
    status?: string;
    search?: string;
    assignedToId?: number;
    telecallerId?: number;
    leadFlow?: string;
    userRole?: string;
    userEmployeeId?: number;
    page?: number;
    limit?: number;
    scope?: string;
    inWaitingQueue?: boolean;
  }) {
    const scope = query.scope || 'NB_DEVELOPER';
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, query.limit || 50);
    const skip = (page - 1) * limit;

    const where: any = {
      isDeleted: false,
      scope,
    };

    const isAdmin = ['ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'].includes(
      query.userRole?.toUpperCase() || ''
    );

    // If non-admin user is logged in, enforce flow and assignment scoping
    if (!isAdmin && query.userEmployeeId) {
      const pools = await this.getAssignedTelecallerPools(scope);
      const isExcelAssigned = pools.excelIds.includes(query.userEmployeeId);
      const isWebhookAssigned = pools.webhookIds.includes(query.userEmployeeId);

      // Non-admin sees leads assigned to them either as telecaller OR as sales rep/manager
      const userAssignmentCond = [
        { telecallerId: query.userEmployeeId },
        { assignedToId: query.userEmployeeId },
      ];

      if (isExcelAssigned && !isWebhookAssigned) {
        where.AND = [
          { OR: userAssignmentCond },
          { OR: [{ leadSource: 'EXCEL' }, { leadSource: 'MANUAL' }, { leadSource: null }] },
        ];
      } else if (isWebhookAssigned && !isExcelAssigned) {
        where.AND = [
          { OR: userAssignmentCond },
          { leadSource: { in: ['WEBHOOK', 'META'] } },
        ];
      } else {
        where.OR = userAssignmentCond;
      }
    }

    if (query.leadFlow && query.leadFlow !== 'ALL') {
      const flow = query.leadFlow.toUpperCase();
      if (flow === 'MANUAL') {
        const manualCond = [{ leadSource: 'MANUAL' }];
        if (where.AND) {
          where.AND.push({ OR: manualCond });
        } else if (where.OR) {
          where.AND = [{ OR: where.OR }, { OR: manualCond }];
          delete where.OR;
        } else {
          where.OR = manualCond;
        }
      } else if (flow === 'EXCEL') {
        const excelCond = [{ leadSource: 'EXCEL' }, { leadSource: null }];
        if (where.AND) {
          where.AND.push({ OR: excelCond });
        } else if (where.OR) {
          where.AND = [{ OR: where.OR }, { OR: excelCond }];
          delete where.OR;
        } else {
          where.OR = excelCond;
        }
      } else if (flow === 'WEBHOOK' || flow === 'META') {
        if (where.AND) {
          where.AND.push({ leadSource: { in: ['WEBHOOK', 'META'] } });
        } else {
          where.leadSource = { in: ['WEBHOOK', 'META'] };
        }
      }
    }

    if (query.campaignId && query.campaignId !== 'ALL') {
      where.campaignId = query.campaignId;
    } else if (query.projectId && query.projectId !== 'ALL') {
      where.campaign = { projectId: query.projectId, scope };
    }

    if (
      query.status === 'WL' ||
      query.status === 'WAITING_LIST' ||
      (query as any).inWaitingQueue === true ||
      (query as any).inWaitingQueue === 'true'
    ) {
      where.telecallerId = null;
      where.assignedToId = null;
    } else if (query.status && query.status !== 'ALL') {
      where.status = query.status as CrmLeadStatus;
    }

    if (query.assignedToId) {
      where.assignedToId = query.assignedToId;
    }

    if (query.telecallerId) {
      where.telecallerId = query.telecallerId;
    }

    if (query.search && query.search.trim()) {
      const s = query.search.trim();
      const searchCond = [
        { name: { contains: s, mode: 'insensitive' } },
        { phone: { contains: s, mode: 'insensitive' } },
      ];
      if (where.OR) {
        where.AND = [{ OR: where.OR }, { OR: searchCond }];
        delete where.OR;
      } else {
        where.OR = searchCond;
      }
    }

    const [total, items] = await Promise.all([
      prisma.crmLead.count({ where }),
      prisma.crmLead.findMany({
        where,
        skip,
        take: limit,
        orderBy: { updatedAt: 'desc' },
        include: {
          campaign: { select: { id: true, name: true, code: true, projectId: true } },
          assignedTo: {
            include: { generalInfo: { select: { fullName: true, designation: true } } },
          },
          telecaller: {
            include: { generalInfo: { select: { fullName: true } } },
          },
          followUps: {
            where: { status: 'PENDING' },
            orderBy: { scheduledDate: 'desc' },
            take: 1,
          },
        },
      }),
    ]);

    // Resolve creator display names for manual leads
    const creatorIds = Array.from(new Set(items.map((i) => i.createdById).filter(Boolean))) as string[];
    const creators = creatorIds.length > 0
      ? await prisma.user.findMany({
          where: { id: { in: creatorIds } },
          select: {
            id: true,
            username: true,
            employee: { select: { generalInfo: { select: { fullName: true } } } },
            role: { select: { name: true } },
          },
        })
      : [];
    const creatorMap = new Map<string, string>();
    for (const c of creators) {
      const name = c.employee?.generalInfo?.fullName || c.username || c.role?.name || 'Admin';
      creatorMap.set(c.id, name);
    }

    const enrichedItems = items.map((item) => {
      const custom = (item.customFields && typeof item.customFields === 'object') ? (item.customFields as Record<string, any>) : {};
      const creatorName = custom.createdByName || (item.createdById ? creatorMap.get(item.createdById) : undefined);
      return {
        ...item,
        createdByName: creatorName,
      };
    });

    return {
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
      items: enrichedItems,
    };
  },

  async createLead(
    dto: CreateLeadDto,
    createdById?: string,
    telecallerId?: number,
    scope: string = 'NB_DEVELOPER',
    subOrganization?: string | null,
  ) {
    const custom = (dto.customFields && typeof dto.customFields === 'object') ? dto.customFields : {};
    const phone = (dto.phone || custom.phone || custom.Phone || custom.Phone_Number || custom.phone_number || '').toString().trim();
    const name = (dto.name || custom.client_name || custom.Client_Name || custom.full_name || custom.Full_Name || custom.Name || custom.name || 'Unnamed Lead').toString().trim();
    const defaultCamp = await this.ensureDefaultCampaign('PRE_SALES', scope);
    const campaignId = dto.campaignId || defaultCamp.id;

    const requestedSource = (dto.leadSource || custom.leadSource || custom.lead_source || 'MANUAL').toString().toUpperCase();
    const finalSource = requestedSource.includes('WEBHOOK') || requestedSource.includes('META')
      ? 'WEBHOOK'
      : (requestedSource === 'EXCEL' ? 'EXCEL' : 'MANUAL');

    let creatorName = 'Admin';
    if (createdById) {
      const creatorUser = await prisma.user.findUnique({
        where: { id: createdById },
        include: { employee: { include: { generalInfo: true } }, role: true },
      });
      if (creatorUser) {
        creatorName = creatorUser.employee?.generalInfo?.fullName || creatorUser.username || creatorUser.role?.name || 'Admin';
      }
    }
    custom.createdByName = creatorName;
    if (finalSource === 'MANUAL') {
      custom.isManual = true;
    }

    let allocatedTelecallerId = dto.telecallerId || telecallerId;
    if (allocatedTelecallerId) {
      custom.allocatedAt = new Date().toISOString();
    }

    const initialStatus = (dto.status as CrmLeadStatus) ||
      (dto.assignedToId ? CrmLeadStatus.ASSIGNED : CrmLeadStatus.NOT_STARTED);

    if (dto.channelPartnerPhone || custom.channelPartnerPhone) {
      custom.channelPartnerPhone = dto.channelPartnerPhone || custom.channelPartnerPhone;
    }
    const finalCpName = dto.channelPartnerName || custom.channelPartnerName || custom.cpName || null;
    const finalRefType = dto.referenceType || custom.referenceType || null;
    const finalRefName = dto.referenceName || custom.referenceName || null;

    const newLead = await prisma.crmLead.create({
      data: {
        scope,
        campaignId,
        phone: phone || '0000000000',
        name,
        status: initialStatus,
        customFields: custom,
        leadSource: finalSource,
        channelPartnerName: finalCpName,
        referenceType: finalRefType,
        referenceName: finalRefName,
        assignedToId: dto.assignedToId || null,
        telecallerId: allocatedTelecallerId || null,
        createdById,
      },
      include: {
        campaign: {
          select: {
            id: true,
            name: true,
            code: true,
            projectId: true,
            project: { select: { name: true } },
          },
        },
        assignedTo: {
          include: { generalInfo: { select: { fullName: true } } },
        },
      },
    });

    // WhatsApp Automation: Auto-welcome message with brochure on manual lead creation
    whatsappService
      .triggerEvent('LEAD_CREATED', newLead, {
        projectName: (newLead.campaign as any)?.project?.name || (scope === 'NB_FINSERVE' ? 'NB Finserve' : 'Legacy Tower'),
        agentName: newLead.assignedTo?.generalInfo?.fullName,
      })
      .catch((err) => console.error('[CRM WhatsApp Hook Error - Manual Lead]:', err));

    // If lead was not explicitly allocated to a telecaller, dispatch waiting queue
    if (!allocatedTelecallerId) {
      await this.dispatchWaitingQueue(scope, subOrganization);
    }

    return newLead;
  },

  async importExcelLeads(
    fileBuffer: Buffer,
    createdById?: string,
    telecallerId?: number,
    campaignId?: string,
    scope: string = 'NB_DEVELOPER',
    subOrganization?: string | null,
    options?: {
      assignmentMode?: 'SPECIFIC' | 'ROUND_ROBIN' | 'UNASSIGNED';
      assignedTelecallerIds?: number[];
    },
  ) {
    const workbook = xlsx.read(fileBuffer, { type: 'buffer' });
    const firstSheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[firstSheetName];
    const rows: Array<Record<string, any>> = xlsx.utils.sheet_to_json(worksheet, { defval: '' });

    if (!rows || rows.length === 0) {
      return { count: 0, message: 'No rows found in Excel sheet' };
    }

    const defaultCamp = await this.ensureDefaultCampaign('PRE_SALES', scope);
    const targetCampaignId = campaignId || defaultCamp.id;

    const targetCampaign = await prisma.crmCampaign.findUnique({
      where: { id: targetCampaignId },
      include: { project: true },
    });
    const campaignScope = targetCampaign?.scope || scope;

    // Fetch column configs to map header aliases for THIS campaign
    const cols = await this.getColumns('PRE_SALES', targetCampaignId, campaignScope);
    const colMap: Record<string, string> = {};
    for (const c of cols) {
      colMap[c.label.toLowerCase().trim()] = c.columnKey;
      colMap[c.columnKey.toLowerCase().trim()] = c.columnKey;
    }

    const pools = await this.getAssignedTelecallerPools(campaignScope);

    // Pre-fetch active employees to match any Assigned To column in Excel
    const activeEmployees = await prisma.employee.findMany({
      where: { status: 'ACTIVE' },
      include: { generalInfo: true, user: true },
    });
    const empLookup = new Map<string, number>();
    for (const e of activeEmployees) {
      empLookup.set(String(e.id), e.id);
      if (e.generalInfo?.fullName) {
        empLookup.set(e.generalInfo.fullName.toLowerCase().trim(), e.id);
      }
      if (e.user?.username) {
        empLookup.set(e.user.username.toLowerCase().trim(), e.id);
      }
    }

    let insertedCount = 0;
    const leadsToInsert: any[] = [];

    for (const row of rows) {
      const customFields: Record<string, any> = {};
      let phone = '';
      let name = '';
      let assignedHeaderValue = '';

      for (const [header, val] of Object.entries(row)) {
        const cleanHeader = header.trim();
        const lowerHeader = cleanHeader.toLowerCase();
        const mappedKey = colMap[lowerHeader] || lowerHeader.replace(/[^a-z0-9_]/g, '_');
        const strVal = String(val).trim();

        if (mappedKey === 'phone' || lowerHeader.includes('phone') || lowerHeader.includes('mobile') || lowerHeader.includes('contact')) {
          phone = strVal;
        } else if (mappedKey === 'client_name' || mappedKey === 'name' || lowerHeader.includes('name') || lowerHeader.includes('client')) {
          name = strVal;
        }

        if (
          lowerHeader.includes('assigned') ||
          lowerHeader.includes('telecaller') ||
          lowerHeader.includes('caller') ||
          lowerHeader.includes('sales rep') ||
          lowerHeader.includes('manager') ||
          lowerHeader.includes('advisor')
        ) {
          assignedHeaderValue = strVal;
        }

        customFields[mappedKey] = strVal;
      }

      if (!phone && customFields.phone) phone = String(customFields.phone);
      if (!name && customFields.client_name) name = String(customFields.client_name);

      if (phone || name) {
        let rowTelecallerId = telecallerId;
        let rowAssignedToId: number | undefined = undefined;

        // Custom allocation options passed from upload dialog
        if (options?.assignmentMode === 'ROUND_ROBIN' && options.assignedTelecallerIds && options.assignedTelecallerIds.length > 0) {
          const targetId = options.assignedTelecallerIds[leadsToInsert.length % options.assignedTelecallerIds.length];
          rowTelecallerId = targetId;
          customFields.allocatedAt = new Date().toISOString();
        } else if (options?.assignmentMode === 'SPECIFIC' && options.assignedTelecallerIds && options.assignedTelecallerIds.length > 0) {
          const targetId = options.assignedTelecallerIds[0];
          rowTelecallerId = targetId;
          customFields.allocatedAt = new Date().toISOString();
        } else if (options?.assignmentMode === 'UNASSIGNED') {
          rowTelecallerId = undefined;
        }

        if (assignedHeaderValue && !rowTelecallerId) {
          const matched = empLookup.get(assignedHeaderValue.toLowerCase().trim()) ||
            (!isNaN(Number(assignedHeaderValue)) ? Number(assignedHeaderValue) : undefined);
          if (matched) {
            rowTelecallerId = matched;
            customFields.allocatedAt = new Date().toISOString();
          }
        }

        leadsToInsert.push({
          campaignId: targetCampaignId,
          scope: campaignScope,
          phone: phone || 'N/A',
          name: name || 'Unnamed Lead',
          status: CrmLeadStatus.NOT_STARTED,
          customFields,
          leadSource: 'EXCEL',
          telecallerId: rowTelecallerId,
          assignedToId: null,
          createdById,
        });
      }
    }

    const campaignProjectName = targetCampaign?.project?.name || (campaignScope === 'NB_FINSERVE' ? 'NB Finserve' : 'Legacy Tower');

    if (leadsToInsert.length > 0) {
      for (const lead of leadsToInsert) {
        const createdLead = await prisma.crmLead.create({ data: lead });
        insertedCount++;

        // WhatsApp Automation: Auto-welcome message with brochure on Excel imported lead
        whatsappService
          .triggerEvent('LEAD_CREATED', createdLead, {
            projectName: campaignProjectName,
          })
          .catch((err) => console.error('[CRM WhatsApp Hook Error - Excel]:', err));
      }
    }

    const dispatchResult = await this.dispatchWaitingQueue(campaignScope, subOrganization);

    return {
      count: insertedCount,
      totalRows: rows.length,
      dispatchedCount: dispatchResult.dispatchedCount,
      queuedCount: dispatchResult.remainingQueuedCount,
      message: `Successfully imported ${insertedCount} leads from Excel (${dispatchResult.dispatchedCount} dispatched to active telecallers, ${dispatchResult.remainingQueuedCount} waiting in queue)`,
    };
  },

  async updateLeadStatus(
    leadId: string,
    status: 'NOT_STARTED' | 'ASSIGNED' | 'CNR' | 'SCHEDULED_VISIT' | 'NOT_INTERESTED' | 'SITE_VISIT_DONE' | 'FOLLOW_UP' | 'INTERESTED',
    payload: {
      scheduledDate?: string;
      scheduledTime?: string;
      scheduledVisitAt?: string | Date;
      remarks?: string;
      assignedToId?: number;
      telecallerId?: number;
      notInterestedReason?: string;
      notInterestedRemark?: string;
    },
    userContext?: { userId?: string; employeeId?: number; role?: string },
  ) {
    const existing = await prisma.crmLead.findUnique({
      where: { id: leadId },
      include: { assignedTo: true },
    });
    if (!existing) throw new Error('Lead not found');

    const isSuperAdmin = ['ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'].includes(userContext?.role?.toUpperCase() || '');
    const isAssignedSalesRep = userContext?.employeeId != null && userContext?.employeeId === existing.assignedToId;
    const isFinserve = existing.scope === 'NB_FINSERVE';

    // Booking Confirmed Rule:
    if (existing.status === 'BOOKING_CONFIRMED') {
      throw new Error('This lead has a Confirmed Booking and is locked. Status modifications are blocked.');
    }

    // In Real Estate CRM, once assigned to sales, telecallers have view-only access.
    // In Finserve CRM, telecallers can assign and manage leads with sales managers freely.
    if (!isFinserve && existing.assignedToId && !isSuperAdmin && !isAssignedSalesRep) {
      throw new Error('This lead is assigned to a sales representative. Telecallers have view-only access.');
    }

    const updateData: any = {
      status: status as CrmLeadStatus,
    };

    if (status === 'NOT_INTERESTED') {
      updateData.notInterestedAt = new Date();
      if (payload.notInterestedReason) {
        updateData.notInterestedReason = payload.notInterestedReason;
      }
      if (payload.notInterestedRemark) {
        updateData.notInterestedRemark = payload.notInterestedRemark;
      }
    } else {
      updateData.notInterestedAt = null;
    }

    if (status === 'SCHEDULED_VISIT') {
      if (payload.scheduledVisitAt) {
        updateData.scheduledVisitAt = new Date(payload.scheduledVisitAt);
      } else if (payload.scheduledDate) {
        updateData.scheduledVisitAt = new Date(payload.scheduledDate);
      }
    }

    if (status === 'SITE_VISIT_DONE') {
      updateData.visitedAt = new Date();
      if (!payload.scheduledDate) {
        await prisma.crmFollowUp.updateMany({
          where: { leadId, status: 'PENDING' },
          data: { status: 'COMPLETED' },
        });
      }
    }

    let safeAssignedId = existing.assignedToId;
    if (payload.assignedToId !== undefined) {
      if (payload.assignedToId === null || payload.assignedToId === 0) {
        updateData.assignedToId = null;
      } else {
        const emp = await prisma.employee.findUnique({ where: { id: payload.assignedToId } });
        if (emp) {
          updateData.assignedToId = emp.id;
          safeAssignedId = emp.id;
        }
      }
    } else if ((isFinserve || status === 'ASSIGNED' || status === 'INTERESTED' || status === 'SITE_VISIT_DONE') && safeAssignedId) {
      updateData.assignedToId = safeAssignedId;
    }

    if (payload.telecallerId !== undefined) {
      updateData.telecallerId = payload.telecallerId && payload.telecallerId > 0 ? payload.telecallerId : null;
    }

    // Schedule or reschedule single active follow-up if date and time provided
    if (payload.scheduledDate && payload.scheduledTime) {
      const scheduledDateTime = new Date(payload.scheduledDate);
      const existingPending = await prisma.crmFollowUp.findFirst({
        where: { leadId, status: 'PENDING' },
        orderBy: { createdAt: 'desc' },
      });

      const defaultRemark = status === 'CNR'
          ? 'CNR - Call rescheduled (Call Not Received)'
          : (status === 'SCHEDULED_VISIT'
              ? 'Site Visit Scheduled'
              : (status === 'INTERESTED' ? 'Interested client sales meeting scheduled' : 'Follow-up scheduled'));

      if (existingPending) {
        await prisma.crmFollowUp.update({
          where: { id: existingPending.id },
          data: {
            scheduledDate: scheduledDateTime,
            scheduledTime: payload.scheduledTime,
            remarks: payload.remarks || defaultRemark,
            assignedToId: safeAssignedId,
            ...(userContext?.userId && { createdById: userContext.userId }),
          },
        });
      } else {
        await prisma.crmFollowUp.create({
          data: {
            leadId,
            scheduledDate: scheduledDateTime,
            scheduledTime: payload.scheduledTime,
            remarks: payload.remarks || defaultRemark,
            assignedToId: safeAssignedId,
            createdById: userContext?.userId,
          },
        });
      }
    }

    const updatedLead = await prisma.crmLead.update({
      where: { id: leadId },
      data: updateData,
      include: {
        campaign: {
          select: {
            id: true,
            name: true,
            code: true,
            projectId: true,
            project: { select: { name: true, location: true } },
          },
        },
        assignedTo: {
          include: { generalInfo: { select: { fullName: true } } },
        },
        followUps: {
          where: { status: 'PENDING' },
          orderBy: { scheduledDate: 'desc' },
          take: 1,
        },
      },
    });

    // WhatsApp Automation: Trigger event on status changes (e.g. SCHEDULED_VISIT with calendar reminder & map, SITE_VISIT_DONE, FOLLOW_UP, etc.)
    const projectName = (updatedLead.campaign as any)?.project?.name || 'Legacy Tower';
    whatsappService
      .triggerEvent(status, updatedLead, {
        projectName,
        visitDate: payload.scheduledVisitAt || payload.scheduledDate,
        visitTime: payload.scheduledTime,
        remarks: payload.remarks,
        agentName: updatedLead.assignedTo?.generalInfo?.fullName,
      })
      .catch((err) => console.error('[CRM WhatsApp Hook Error - Status Update]:', err));

    return updatedLead;
  },

  async updateLead(
    leadId: string,
    dto: UpdateLeadDto & {
      notInterestedReason?: string;
      notInterestedRemark?: string;
      scheduledVisitAt?: string | Date;
      visitedAt?: string | Date;
      leadSource?: string;
      channelPartnerName?: string;
      referenceType?: string;
      referenceName?: string;
    },
    userContext?: { userId?: string; employeeId?: number; role?: string },
  ) {
    const existing = await prisma.crmLead.findUnique({ where: { id: leadId } });
    if (!existing) throw new Error('Lead not found');

    // Telecaller Edit Lock Rule:
    // If lead is already assigned to a sales user (`assignedToId != null`),
    // and current user is a telecaller (not ADMIN, and not the assigned sales employee),
    // they can only VIEW and cannot alter customFields or name/phone.
    const isSuperAdmin = ['ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'].includes(userContext?.role?.toUpperCase() || '');
    const isAssignedSalesRep = userContext?.employeeId != null && userContext?.employeeId === existing.assignedToId;
    const isFinserve = existing.scope === 'NB_FINSERVE';

    // Booking Confirmed Rule:
    // Once booking is confirmed, the lead cannot be modified by anyone.
    if (existing.status === 'BOOKING_CONFIRMED') {
      throw new Error('This lead has a Confirmed Booking and is locked. Modifications are blocked.');
    }

    if (!isFinserve && existing.assignedToId && !isSuperAdmin && !isAssignedSalesRep) {
      throw new Error('This lead is assigned to a sales representative. Telecallers have view-only access.');
    }

    let safeAssignedToId: number | null | undefined = undefined;
    if (dto.assignedToId !== undefined) {
      if (dto.assignedToId && dto.assignedToId > 0) {
        const emp = await prisma.employee.findUnique({ where: { id: dto.assignedToId } });
        safeAssignedToId = emp ? emp.id : null;
      } else {
        safeAssignedToId = null;
      }
    }

    if (dto.status === 'SITE_VISIT_DONE' || dto.status === 'PROPOSAL_SENT' || dto.status === 'BOOKING_CONFIRMED' || dto.visitedAt) {
      await prisma.crmFollowUp.updateMany({
        where: {
          leadId,
          status: 'PENDING',
        },
        data: { status: 'COMPLETED' },
      });
    }

    const validPrismaStatuses = [
      ...Object.values(CrmLeadStatus || {}),
      'ASSIGNED',
    ] as string[];
    const isStatusValid = dto.status && validPrismaStatuses.includes(dto.status);
    const targetStatus = isStatusValid
      ? (dto.status as CrmLeadStatus)
      : (safeAssignedToId && safeAssignedToId > 0 && !dto.status ? ('ASSIGNED' as any) : undefined);

    const rawPhoneVal = dto.phone || (dto.customFields && (dto.customFields['Phone'] || dto.customFields['phone'] || dto.customFields['phoneNumber'] || dto.customFields['mobile']));
    const resolvedPhone = rawPhoneVal ? String(rawPhoneVal).replace(/\D/g, '').slice(-10) : undefined;

    const rawNameVal = dto.name || (dto.customFields && (dto.customFields['Client_Name'] || dto.customFields['client_name'] || dto.customFields['name'] || dto.customFields['customer_name']));
    const resolvedName = rawNameVal ? String(rawNameVal).trim() : undefined;

    const updated = await prisma.crmLead.update({
      where: { id: leadId },
      data: {
        ...(resolvedName ? { name: resolvedName } : {}),
        ...(resolvedPhone ? { phone: resolvedPhone } : {}),
        ...(targetStatus ? { status: targetStatus } : {}),
        ...((dto.customFields || (!isStatusValid && dto.status) || resolvedPhone || resolvedName) && {
          customFields: {
            ...((existing.customFields as Record<string, any>) || {}),
            ...(dto.customFields || {}),
            ...(resolvedPhone ? { Phone: resolvedPhone, phone: resolvedPhone } : {}),
            ...(resolvedName ? { Client_Name: resolvedName, client_name: resolvedName } : {}),
            ...(!isStatusValid && dto.status ? { status: dto.status } : {}),
          },
        }),
        ...(safeAssignedToId !== undefined && { assignedToId: safeAssignedToId }),
        ...(dto.notInterestedReason !== undefined && { notInterestedReason: dto.notInterestedReason }),
        ...(dto.notInterestedRemark !== undefined && { notInterestedRemark: dto.notInterestedRemark }),
        ...(dto.scheduledVisitAt !== undefined && { scheduledVisitAt: dto.scheduledVisitAt ? new Date(dto.scheduledVisitAt) : null }),
        ...(dto.visitedAt !== undefined && { visitedAt: dto.visitedAt ? new Date(dto.visitedAt) : null }),
        ...(dto.leadSource !== undefined && { leadSource: dto.leadSource }),
        ...(dto.channelPartnerName !== undefined && { channelPartnerName: dto.channelPartnerName }),
        ...(dto.referenceType !== undefined && { referenceType: dto.referenceType }),
        ...(dto.referenceName !== undefined && { referenceName: dto.referenceName }),
      },
      include: {
        assignedTo: {
          include: { generalInfo: { select: { fullName: true } } },
        },
        followUps: {
          where: { status: 'PENDING' },
          orderBy: { scheduledDate: 'desc' },
          take: 1,
        },
        campaign: {
          select: { project: { select: { name: true } } },
        },
      },
    });

    // WhatsApp Automation: Triggers for Lead Updates
    try {
      const projectName = (updated.campaign as any)?.project?.name || 'Legacy Tower';
      const agentName = updated.assignedTo?.generalInfo?.fullName;
      const agentPhone = '';

      if (dto.status === 'BOOKING_CONFIRMED') {
        whatsappService
          .triggerEvent('BOOKING_CONFIRMED', updated, { projectName, agentName, agentPhone })
          .catch((err) => console.error('[CRM WhatsApp Hook Error - Booking Confirmed]:', err));
      } else if (dto.status === 'SITE_VISIT_DONE' && existing.status !== 'SITE_VISIT_DONE') {
        whatsappService
          .triggerEvent('SITE_VISIT_DONE', updated, { projectName, agentName, agentPhone })
          .catch((err) => console.error('[CRM WhatsApp Hook Error - Site Visit Done]:', err));
      }

      if (safeAssignedToId && safeAssignedToId !== existing.assignedToId) {
        whatsappService
          .triggerEvent('LEAD_ASSIGNED', updated, { projectName, agentName, agentPhone })
          .catch((err) => console.error('[CRM WhatsApp Hook Error - Lead Assigned]:', err));
      }

      if (dto.scheduledVisitAt && String(dto.scheduledVisitAt) !== String(existing.scheduledVisitAt)) {
        const visitEvent = existing.scheduledVisitAt ? 'SITE_VISIT_RESCHEDULED' : 'SITE_VISIT_SCHEDULED';
        whatsappService
          .triggerEvent(visitEvent, updated, {
            projectName,
            agentName,
            agentPhone,
            visitDate: dto.scheduledVisitAt,
          })
          .catch((err) => console.error(`[CRM WhatsApp Hook Error - ${visitEvent}]:`, err));
      }
    } catch (whErr) {
      console.error('[CRM WhatsApp Hook Error in updateLead]:', whErr);
    }

    return updated;
  },

  async transferLead(
    leadId: string,
    targetTelecallerId: number,
    remarks?: string,
    userContext?: { userId?: string; employeeId?: number; role?: string; username?: string },
  ) {
    const existing = await prisma.crmLead.findUnique({
      where: { id: leadId },
      include: {
        telecaller: { include: { generalInfo: true } },
        assignedTo: { include: { generalInfo: true } },
      },
    });
    if (!existing) throw new Error('Lead not found');
    if (existing.status === 'BOOKING_CONFIRMED') {
      throw new Error('This lead has a Confirmed Booking and is locked. Transfers are blocked.');
    }

    const isAdmin = ['ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'].includes(
      userContext?.role?.toUpperCase() || ''
    );
    const isCurrentTelecaller = userContext?.employeeId != null && (
      userContext.employeeId === existing.telecallerId ||
      userContext.employeeId === existing.assignedToId
    );

    if (!isAdmin && !isCurrentTelecaller) {
      throw new Error('You do not have permission to transfer this lead. Only the currently allocated telecaller or an Admin can transfer it.');
    }

    if (existing.telecallerId === targetTelecallerId) {
      throw new Error('Lead is already allocated to this telecaller.');
    }

    const targetEmp = await prisma.employee.findUnique({
      where: { id: targetTelecallerId },
      include: { generalInfo: true, user: true },
    });
    if (!targetEmp) throw new Error('Target telecaller employee not found');

    const fromName = existing.telecaller?.generalInfo?.fullName || (existing.telecallerId ? `Telecaller #${existing.telecallerId}` : 'Waiting List / Unallocated');
    const toName = targetEmp.generalInfo?.fullName || targetEmp.user?.username || `Telecaller #${targetTelecallerId}`;

    const existingCustom = (existing.customFields as Record<string, any>) || {};
    const transferHistory = Array.isArray(existingCustom.transferHistory) ? [...existingCustom.transferHistory] : [];
    transferHistory.push({
      fromEmployeeId: existing.telecallerId || null,
      fromName,
      toEmployeeId: targetTelecallerId,
      toName,
      transferredBy: userContext?.userId || 'SYSTEM',
      transferredByName: userContext?.username || userContext?.role || 'Admin',
      transferredAt: new Date().toISOString(),
      remarks: remarks?.trim() || null,
    });

    const updated = await prisma.crmLead.update({
      where: { id: leadId },
      data: {
        telecallerId: targetTelecallerId,
        customFields: {
          ...existingCustom,
          transferHistory,
          allocatedAt: new Date().toISOString(),
          lastTransferredAt: new Date().toISOString(),
          lastTransferredFrom: fromName,
          lastTransferredTo: toName,
        },
      },
      include: {
        telecaller: { include: { generalInfo: true } },
        assignedTo: { include: { generalInfo: true } },
      },
    });

    try {
      const now = new Date();
      await prisma.crmFollowUp.create({
        data: {
          leadId,
          scheduledDate: now,
          scheduledTime: `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`,
          remarks: `[LEAD TRANSFERRED] Transferred from ${fromName} to ${toName}. Reason: ${remarks?.trim() || 'Internal re-allocation'}`,
          status: 'COMPLETED',
          createdById: userContext?.userId || null,
          assignedToId: targetTelecallerId,
        },
      });
    } catch (e) {
      console.error('[CRM Lead Transfer Note Error]:', e);
    }

    return updated;
  },

  async moveToBin(
    leadId: string,
    userContext?: { userId?: string; employeeId?: number; role?: string },
  ) {
    const existing = await prisma.crmLead.findUnique({ where: { id: leadId } });
    if (!existing) throw new Error('Lead not found');

    const isSuperAdmin = ['ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'].includes(userContext?.role?.toUpperCase() || '');
    const isAssignedSalesRep = userContext?.employeeId != null && userContext?.employeeId === existing.assignedToId;
    const isFinserve = existing.scope === 'NB_FINSERVE';

    if (existing.status === 'BOOKING_CONFIRMED') {
      throw new Error('This lead has a Confirmed Booking and is locked. It cannot be moved to Bin.');
    }

    if (!isFinserve && existing.assignedToId && !isSuperAdmin && !isAssignedSalesRep) {
      throw new Error('This lead is assigned to a sales representative. Telecallers have view-only access.');
    }

    // Cancel all pending follow-ups for this binned lead
    await prisma.crmFollowUp.updateMany({
      where: { leadId, status: 'PENDING' },
      data: { status: 'CANCELLED' },
    });

    return prisma.crmLead.update({
      where: { id: leadId },
      data: {
        isDeleted: true,
        deletedAt: new Date(),
      },
    });
  },

  async restoreFromBin(leadId: string) {
    return prisma.crmLead.update({
      where: { id: leadId },
      data: {
        isDeleted: false,
        deletedAt: null,
        notInterestedAt: null,
        status: CrmLeadStatus.NOT_STARTED,
      },
    });
  },

  async getBinLeads(module = 'PRE_SALES', scope: string = 'NB_DEVELOPER') {
    // Return leads marked as isDeleted: true OR marked as NOT_INTERESTED
    const retentionKey = scope === 'NB_FINSERVE' ? 'finserve_not_interested_retention_days' : 'not_interested_retention_days';
    const retentionSetting = await prisma.crmSetting.findUnique({
      where: { key: retentionKey },
    });
    const retentionDays = parseInt(retentionSetting?.value || '30', 10);
    const thresholdDate = new Date();
    thresholdDate.setDate(thresholdDate.getDate() - retentionDays);

    return prisma.crmLead.findMany({
      where: {
        scope,
        OR: [
          { isDeleted: true },
          {
            status: CrmLeadStatus.NOT_INTERESTED,
            notInterestedAt: { lte: thresholdDate },
          },
        ],
      },
      orderBy: { updatedAt: 'desc' },
      include: {
        assignedTo: {
          include: { generalInfo: { select: { fullName: true } } },
        },
        telecaller: {
          include: { generalInfo: { select: { fullName: true } } },
        },
      },
    });
  },

  // ---------------------------------------------------------------------------
  // Follow-ups & Scheduled Calls (Only for Active Leads)
  // ---------------------------------------------------------------------------
  async getFollowUps(query: {
    leadId?: string;
    filter?: 'today' | 'upcoming' | 'all' | 'overdue';
    date?: string;
    scope?: string;
  }) {
    const scope = query.scope || 'NB_DEVELOPER';
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    // Strictly ensure follow-ups are only returned for ACTIVE (non-deleted / non-binned) leads
    const where: any = {
      lead: {
        isDeleted: false,
        scope,
      },
    };

    if (query.leadId) {
      where.leadId = query.leadId;
    }

    if (query.filter === 'today') {
      where.scheduledDate = {
        gte: today,
        lt: tomorrow,
      };
      where.status = { not: 'CANCELLED' };
    } else if (query.filter === 'upcoming') {
      where.scheduledDate = {
        gte: tomorrow,
      };
      where.status = { not: 'CANCELLED' };
    } else if (query.filter === 'overdue') {
      where.scheduledDate = {
        lt: today,
      };
      where.status = 'PENDING';
    }

    return prisma.crmFollowUp.findMany({
      where,
      orderBy: [{ scheduledDate: 'asc' }, { scheduledTime: 'asc' }],
      include: {
        lead: {
          select: {
            id: true,
            name: true,
            phone: true,
            status: true,
            customFields: true,
          },
        },
        assignedTo: {
          include: { generalInfo: { select: { fullName: true } } },
        },
      },
    });
  },

  async createFollowUp(dto: ScheduleFollowUpDto, createdById?: string) {
    const date = new Date(dto.scheduledDate);

    // Look for existing PENDING follow-up for this lead to update (preventing duplicate active follow-ups)
    const existingFollowUp = await prisma.crmFollowUp.findFirst({
      where: {
        leadId: dto.leadId,
        status: 'PENDING',
      },
      orderBy: { createdAt: 'desc' },
    });

    let followUp;
    if (existingFollowUp) {
      followUp = await prisma.crmFollowUp.update({
        where: { id: existingFollowUp.id },
        data: {
          scheduledDate: date,
          scheduledTime: dto.scheduledTime,
          remarks: dto.remarks !== undefined ? dto.remarks : existingFollowUp.remarks,
          assignedToId: dto.assignedToId !== undefined ? dto.assignedToId : existingFollowUp.assignedToId,
          ...(createdById && { createdById }),
        },
        include: {
          lead: true,
          assignedTo: {
            include: { generalInfo: { select: { fullName: true } } },
          },
        },
      });
    } else {
      followUp = await prisma.crmFollowUp.create({
        data: {
          leadId: dto.leadId,
          scheduledDate: date,
          scheduledTime: dto.scheduledTime,
          remarks: dto.remarks,
          assignedToId: dto.assignedToId,
          createdById,
        },
        include: {
          lead: true,
          assignedTo: {
            include: { generalInfo: { select: { fullName: true } } },
          },
        },
      });
    }

    // Update lead status to FOLLOW_UP
    await prisma.crmLead.update({
      where: { id: dto.leadId },
      data: { status: CrmLeadStatus.FOLLOW_UP },
    });

    return followUp;
  },

  async completeFollowUp(id: string, remarks?: string) {
    return prisma.crmFollowUp.update({
      where: { id },
      data: {
        status: 'COMPLETED',
        ...(remarks && { remarks }),
      },
    });
  },

  // ---------------------------------------------------------------------------
  // Visitor Lookup & Check-In (Front Desk / Site Visit Desk)
  // ---------------------------------------------------------------------------
  async assertVisitorDeskAccess(userContext?: { employeeId?: number; role?: string }) {
    const isSuperAdmin = ['ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'].includes(
      userContext?.role?.toUpperCase() || '',
    );
    if (isSuperAdmin) return;
    const settings = await this.getSettings('NB_DEVELOPER');
    const designatedId = settings.site_visit_desk_employee_id
      ? parseInt(String(settings.site_visit_desk_employee_id), 10)
      : null;
    if (!designatedId || userContext?.employeeId !== designatedId) {
      throw new Error(
        'Unauthorized: Only System Admins or the Designated Site Visit Desk In-Charge can use the Front Desk.',
      );
    }
  },

  async visitorLookup(phone: string, userContext?: { employeeId?: number; role?: string }) {
    await this.assertVisitorDeskAccess(userContext);
    if (!phone || !phone.trim()) {
      return { exists: false, message: 'Phone number is required' };
    }
    const cleanDigits = phone.replace(/\D/g, '');
    const last10 = cleanDigits.length >= 10 ? cleanDigits.slice(-10) : cleanDigits;

    const leads = await prisma.crmLead.findMany({
      where: {
        isDeleted: false,
        phone: {
          contains: last10,
        },
      },
      include: {
        assignedTo: {
          include: {
            generalInfo: {
              select: { fullName: true, designation: true },
            },
          },
        },
        followUps: {
          where: { status: 'PENDING' },
          orderBy: { scheduledDate: 'desc' },
          take: 1,
        },
      },
      orderBy: { updatedAt: 'desc' },
    });

    if (!leads || leads.length === 0) {
      return { exists: false, phone: last10 };
    }

    const lead = leads[0];

    // Check if scheduled for today
    let isScheduledToday = false;
    const now = new Date();
    const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

    if (lead.scheduledVisitAt) {
      const visitDate = new Date(lead.scheduledVisitAt);
      const visitStr = `${visitDate.getFullYear()}-${String(visitDate.getMonth() + 1).padStart(2, '0')}-${String(visitDate.getDate()).padStart(2, '0')}`;
      if (visitStr === todayStr) {
        isScheduledToday = true;
      }
    }

    if (!isScheduledToday && lead.followUps && lead.followUps.length > 0) {
      const fu = lead.followUps[0];
      const fuDate = new Date(fu.scheduledDate);
      const fuStr = `${fuDate.getFullYear()}-${String(fuDate.getMonth() + 1).padStart(2, '0')}-${String(fuDate.getDate()).padStart(2, '0')}`;
      if (fuStr === todayStr && lead.status === 'SCHEDULED_VISIT') {
        isScheduledToday = true;
      }
    }

    // Helper for visit wording: once, twice, thrice, N times
    const formatVisitCount = (count: number) => {
      if (count <= 1) return { wording: 'once', ordinal: '1st' };
      if (count === 2) return { wording: 'twice', ordinal: '2nd' };
      if (count === 3) return { wording: 'thrice', ordinal: '3rd' };
      return { wording: `${count} times`, ordinal: `${count}th` };
    };

    const custom = (lead.customFields as Record<string, any>) || {};
    const siteVisitsList: any[] = Array.isArray(custom.siteVisits) ? custom.siteVisits : [];
    let pastVisitCount = typeof custom.siteVisitCount === 'number' ? custom.siteVisitCount : siteVisitsList.length;
    if (pastVisitCount === 0 && (lead.status === 'SITE_VISIT_DONE' || lead.visitedAt)) {
      pastVisitCount = 1;
    }
    const nextVisitNumber = pastVisitCount + 1;
    const pastInfo = pastVisitCount > 0 ? formatVisitCount(pastVisitCount) : null;
    const nextInfo = formatVisitCount(nextVisitNumber);

    const previousSalesManager = lead.assignedTo ? {
      id: lead.assignedTo.id,
      fullName: lead.assignedTo.generalInfo?.fullName || `Employee #${lead.assignedTo.id}`,
      designation: lead.assignedTo.generalInfo?.designation || 'Sales Manager',
    } : null;

    return {
      exists: true,
      isScheduledToday,
      pastVisitCount,
      pastVisitWording: pastInfo?.wording || null,
      pastVisitOrdinal: pastInfo?.ordinal || null,
      nextVisitNumber,
      nextVisitWording: nextInfo.wording,
      nextVisitOrdinal: nextInfo.ordinal,
      previousSalesManager,
      siteVisitsHistory: siteVisitsList,
      lead,
    };
  },

  async visitorCheckin(
    dto: {
      leadId?: string;
      phone: string;
      name?: string;
      assignedToId: number;
      leadSource?: string;
      channelPartnerName?: string;
      referenceType?: string;
      referenceName?: string;
      remarks?: string;
    },
    userContext?: { userId?: string; employeeId?: number; role?: string },
  ) {
    const settings = await this.getSettings('NB_DEVELOPER');
    const designatedId = settings.site_visit_desk_employee_id
      ? parseInt(String(settings.site_visit_desk_employee_id), 10)
      : null;
    const isSuperAdmin = ['ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'].includes(
      userContext?.role?.toUpperCase() || '',
    );
    if (!isSuperAdmin) {
      if (!designatedId || userContext?.employeeId !== designatedId) {
        throw new Error(
          'Unauthorized: Only System Admins or the Designated Site Visit Desk In-Charge can register visitors and assign sales representatives.',
        );
      }
    }

    if (!dto.assignedToId) {
      throw new Error('Assigned Sales Representative is required for visitor check-in');
    }

    const emp = await prisma.employee.findUnique({
      where: { id: dto.assignedToId },
      include: { generalInfo: { select: { fullName: true, designation: true } } },
    });
    if (!emp) {
      throw new Error('Assigned sales representative not found');
    }

    const now = new Date();

    const formatVisitCount = (count: number) => {
      if (count <= 1) return { wording: 'once', ordinal: '1st' };
      if (count === 2) return { wording: 'twice', ordinal: '2nd' };
      if (count === 3) return { wording: 'thrice', ordinal: '3rd' };
      return { wording: `${count} times`, ordinal: `${count}th` };
    };

    if (dto.leadId) {
      const existing = await prisma.crmLead.findUnique({
        where: { id: dto.leadId },
        include: {
          assignedTo: {
            include: { generalInfo: { select: { fullName: true, designation: true } } },
          },
        },
      });
      if (!existing) throw new Error('Lead not found');

      const custom = (existing.customFields as Record<string, any>) || {};
      const previousVisits: any[] = Array.isArray(custom.siteVisits) ? [...custom.siteVisits] : [];
      let pastVisitCount = typeof custom.siteVisitCount === 'number' ? custom.siteVisitCount : previousVisits.length;
      if (pastVisitCount === 0 && (existing.status === 'SITE_VISIT_DONE' || existing.visitedAt)) {
        pastVisitCount = 1;
      }
      const currentVisitNumber = pastVisitCount + 1;
      const { wording, ordinal } = formatVisitCount(currentVisitNumber);

      const salesRepName = emp.generalInfo?.fullName || `Employee #${emp.id}`;
      const previousManagerName = existing.assignedTo?.generalInfo?.fullName;
      const isReassigned = existing.assignedToId && existing.assignedToId !== emp.id;

      let logNote = `Site visit done ${wording} (${ordinal} visit). Assigned to ${salesRepName}.`;
      if (isReassigned && previousManagerName) {
        logNote += ` (Previously attended by ${previousManagerName}).`;
      }
      if (dto.remarks && dto.remarks.trim()) {
        logNote += ` Reception Notes: ${dto.remarks.trim()}`;
      }

      previousVisits.push({
        visitNumber: currentVisitNumber,
        wording,
        ordinal,
        visitedAt: now.toISOString(),
        salesRepId: emp.id,
        salesRepName,
        previousRepName: previousManagerName,
        remarks: dto.remarks?.trim() || null,
      });

      const updated = await prisma.crmLead.update({
        where: { id: dto.leadId },
        data: {
          status: 'SITE_VISIT_DONE',
          visitedAt: now,
          scheduledVisitAt: existing.scheduledVisitAt || now,
          assignedToId: emp.id,
          customFields: {
            ...custom,
            siteVisitCount: currentVisitNumber,
            lastVisitWording: wording,
            lastVisitOrdinal: ordinal,
            siteVisits: previousVisits,
          },
          ...(dto.leadSource && { leadSource: dto.leadSource }),
          ...(dto.channelPartnerName && { channelPartnerName: dto.channelPartnerName }),
          ...(dto.referenceType && { referenceType: dto.referenceType }),
          ...(dto.referenceName && { referenceName: dto.referenceName }),
        },
        include: {
          assignedTo: {
            include: { generalInfo: { select: { fullName: true, designation: true } } },
          },
          campaign: { select: { project: { select: { name: true } } } },
        },
      });

      await prisma.crmFollowUp.create({
        data: {
          leadId: existing.id,
          scheduledDate: now,
          scheduledTime: `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`,
          status: 'COMPLETED',
          remarks: logNote,
          assignedToId: emp.id,
          createdById: userContext?.userId,
        },
      });

      // WhatsApp Automation: Post Site Visit Follow-up & Feedback
      whatsappService
        .triggerEvent('SITE_VISIT_DONE', updated, {
          projectName: (updated as any).campaign?.project?.name || 'Legacy Tower',
          agentName: emp.generalInfo?.fullName,
        })
        .catch((err) => console.error('[CRM WhatsApp Hook Error - Visitor Checkin]:', err));

      return updated;
    }

    // New visitor registration
    if (!dto.phone || !dto.name) {
      throw new Error('Name and Phone are required for new visitor check-in');
    }

    const cleanDigits = dto.phone.replace(/\D/g, '');
    const defaultCamp = await this.ensureDefaultCampaign('PRE_SALES');

    const { wording, ordinal } = formatVisitCount(1);
    const salesRepName = emp.generalInfo?.fullName || `Employee #${emp.id}`;
    let logNote = `Site visit done ${wording} (${ordinal} visit). Assigned to ${salesRepName}.`;
    if (dto.remarks && dto.remarks.trim()) {
      logNote += ` Reception Notes: ${dto.remarks.trim()}`;
    }

    const newLead = await prisma.crmLead.create({
      data: {
        campaignId: defaultCamp.id,
        phone: cleanDigits || dto.phone,
        name: dto.name.trim(),
        status: 'SITE_VISIT_DONE',
        scheduledVisitAt: now,
        visitedAt: now,
        assignedToId: emp.id,
        leadSource: dto.leadSource || 'Walk IN',
        channelPartnerName: dto.channelPartnerName,
        referenceType: dto.referenceType,
        referenceName: dto.referenceName,
        createdById: userContext?.userId,
        customFields: {
          source: dto.leadSource || 'Walk IN',
          siteVisitCount: 1,
          lastVisitWording: 'once',
          lastVisitOrdinal: '1st',
          siteVisits: [
            {
              visitNumber: 1,
              wording: 'once',
              ordinal: '1st',
              visitedAt: now.toISOString(),
              salesRepId: emp.id,
              salesRepName,
              remarks: dto.remarks?.trim() || null,
            },
          ],
          ...(dto.channelPartnerName && { channel_partner: dto.channelPartnerName }),
          ...(dto.referenceType && { reference_type: dto.referenceType }),
          ...(dto.referenceName && { reference_name: dto.referenceName }),
        },
      },
      include: {
        assignedTo: {
          include: { generalInfo: { select: { fullName: true, designation: true } } },
        },
      },
    });

    await prisma.crmFollowUp.create({
      data: {
        leadId: newLead.id,
        scheduledDate: now,
        scheduledTime: `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`,
        status: 'COMPLETED',
        remarks: logNote,
        assignedToId: emp.id,
        createdById: userContext?.userId,
      },
    });

    // WhatsApp Automation: Post Site Visit Follow-up & Feedback on new walk-in registration
    whatsappService
      .triggerEvent('SITE_VISIT_DONE', newLead, {
        projectName: 'Legacy Tower',
        agentName: emp.generalInfo?.fullName,
      })
      .catch((err) => console.error('[CRM WhatsApp Hook Error - Walkin Visitor]:', err));

    return newLead;
  },

  // ---------------------------------------------------------------------------
  // Settings & Elision Telephony
  // ---------------------------------------------------------------------------
  async getSettings(scope: string = 'NB_DEVELOPER') {
    const isFinserve = scope === 'NB_FINSERVE';
    const settings = await prisma.crmSetting.findMany();
    const map: Record<string, string> = {
      elision_api_url: 'https://greeter.co.in/api/click2call',
      elision_user_id: '634550',
      elision_did: '9484700070',
      elision_route_number: '98',
      elision_default_agent_number: '8511139384',
      elision_api_key: '',
      elision_campaign_id: '',
      elision_agent_id: '',
      not_interested_retention_days: '30',
      bin_retention_days: '30',
      not_interested_reasons: JSON.stringify([
        'Budget mismatch',
        'Found somewhere else',
        'Locality mismatch',
        'Others',
      ]),
      lead_sources: JSON.stringify([
        'Walk IN',
        'Channel Partner',
        'Reference',
      ]),
      reference_types: JSON.stringify([
        'B2B',
        'Employee',
        'Other Client',
      ]),
      site_visit_desk_employee_id: '',
      kpi_show_active_leads: 'true',
      kpi_show_today_followups: 'true',
      kpi_show_interested_deals: 'true',
      kpi_show_bin_count: 'true',
      kpi_show_total_calls: 'true',
      kpi_show_answered_calls: 'true',
      kpi_show_missed_calls: 'true',
      kpi_show_talk_time: 'true',
      kpi_show_fresh_leads: 'true',
      kpi_show_conversion_rate: 'true',
      excel_assigned_telecaller_ids: JSON.stringify([]),
      webhook_assigned_telecaller_ids: JSON.stringify([]),
      max_telecaller_active_workload: '20',
      telecaller_max_workload_map: JSON.stringify({}),
      untouched_lead_timeout_minutes: '30',
      idle_timeout_minutes: '5',
      quotation_general_remarks: `1. Prices and availability are subject to change without prior notice.
2. Applicable Government GST and Stamp Duty charges are subject to statutory revisions.
3. Booking is subject to clearance of booking token and standard terms of agreement.
4. All payments to be made via Cheque / Demand Draft / RTGS in favor of NB Developers.`,
      loan_types: JSON.stringify([
        'Home Loan',
        'Personal Loan',
        'Business Loan',
        'Mortgage / LAP',
        'Auto Loan',
        'Education Loan',
      ]),
      loan_doc_types: JSON.stringify([
        { id: 'pan_card', name: 'PAN Card', maxFileSizeMb: 5, allowedFormats: ['pdf', 'jpg', 'jpeg', 'png'] },
        { id: 'aadhaar_card', name: 'Aadhaar Card', maxFileSizeMb: 5, allowedFormats: ['pdf', 'jpg', 'jpeg', 'png'] },
        { id: 'salary_slips', name: 'Salary Slips (Last 3 Months)', maxFileSizeMb: 10, allowedFormats: ['pdf', 'jpg', 'png'] },
        { id: 'bank_statement', name: 'Bank Statement (Last 6 Months)', maxFileSizeMb: 15, allowedFormats: ['pdf'] },
        { id: 'itr_docs', name: 'ITR / Form 16 (Last 2 Years)', maxFileSizeMb: 10, allowedFormats: ['pdf'] },
        { id: 'property_docs', name: 'Property Chain Deeds / Title / Registry', maxFileSizeMb: 25, allowedFormats: ['pdf'] },
        { id: 'business_proof', name: 'Business Registration / GST Certificate', maxFileSizeMb: 10, allowedFormats: ['pdf', 'jpg', 'png'] },
        { id: 'utility_bill', name: 'Utility Bill / Residence Proof', maxFileSizeMb: 5, allowedFormats: ['pdf', 'jpg', 'jpeg', 'png'] },
      ]),
      loan_type_docs_map: JSON.stringify({
        'Home Loan': ['pan_card', 'aadhaar_card', 'salary_slips', 'bank_statement', 'property_docs'],
        'Personal Loan': ['pan_card', 'aadhaar_card', 'salary_slips', 'bank_statement'],
        'Business Loan': ['pan_card', 'aadhaar_card', 'bank_statement', 'itr_docs', 'business_proof'],
        'Mortgage / LAP': ['pan_card', 'aadhaar_card', 'bank_statement', 'property_docs', 'itr_docs'],
        'Auto Loan': ['pan_card', 'aadhaar_card', 'salary_slips', 'bank_statement'],
        'Education Loan': ['pan_card', 'aadhaar_card', 'bank_statement', 'salary_slips'],
      }),
      finserve_application_fields: JSON.stringify([
        { key: 'mobileNo', label: 'Mobile No', section: 'PERSONAL', type: 'phone', required: true, enabled: true },
        { key: 'alternateNo', label: 'Alternate No', section: 'PERSONAL', type: 'phone', required: false, enabled: true },
        { key: 'personalEmail', label: 'Personal Mail ID', section: 'PERSONAL', type: 'email', required: true, enabled: true },
        { key: 'maritalStatus', label: 'Marital Status', section: 'PERSONAL', type: 'select', options: ['Single', 'Married', 'Divorced', 'Widowed'], required: true, enabled: true },
        { key: 'motherName', label: 'Mother Name', section: 'PERSONAL', type: 'text', required: true, enabled: true },
        { key: 'spouseName', label: 'Spouse Name', section: 'PERSONAL', type: 'text', required: false, enabled: true },
        { key: 'education', label: 'Education', section: 'PERSONAL', type: 'select', options: ['High School', 'Graduate', 'Post Graduate', 'Doctorate', 'Professional', 'Other'], required: true, enabled: true },
        { key: 'currentAddress', label: 'Current Address', section: 'PERSONAL', type: 'textarea', required: true, enabled: true },
        { key: 'currentAddressType', label: 'Current Address (Rent/Owned)', section: 'PERSONAL', type: 'select', options: ['Owned', 'Rented', 'Parental', 'Company Provided'], required: true, enabled: true },
        { key: 'permanentAddress', label: 'Permanent Address', section: 'PERSONAL', type: 'textarea', required: true, enabled: true },
        { key: 'permanentAddressType', label: 'Permanent Address (Rent/Owned)', section: 'PERSONAL', type: 'select', options: ['Owned', 'Rented', 'Parental'], required: true, enabled: true },
        { key: 'requiredLoanAmount', label: 'Require Loan Amount', section: 'PERSONAL', type: 'number', required: true, enabled: true },
        { key: 'loanPurpose', label: 'Loan Purpose', section: 'PERSONAL', type: 'text', required: true, enabled: true },

        { key: 'companyName', label: 'Company Name', section: 'COMPANY', type: 'text', required: true, enabled: true },
        { key: 'companyAddress', label: 'Company Address', section: 'COMPANY', type: 'textarea', required: true, enabled: true },
        { key: 'currentWorkExp', label: 'Current Work Exp', section: 'COMPANY', type: 'text', required: true, enabled: true },
        { key: 'totalWorkExp', label: 'Total Work Exp', section: 'COMPANY', type: 'text', required: true, enabled: true },
        { key: 'officialEmail', label: 'Official Mail ID', section: 'COMPANY', type: 'email', required: false, enabled: true },
        { key: 'officeLandlineNo', label: 'Office Landline No', section: 'COMPANY', type: 'phone', required: false, enabled: true },

        { key: 'ref1Name', label: '1. Name', section: 'REFERENCE', type: 'text', required: true, enabled: true },
        { key: 'ref1Mobile', label: '1. Mobile No', section: 'REFERENCE', type: 'phone', required: true, enabled: true },
        { key: 'ref1Relation', label: '1. Relation', section: 'REFERENCE', type: 'text', required: true, enabled: true },
        { key: 'ref1Address', label: '1. Address', section: 'REFERENCE', type: 'textarea', required: true, enabled: true },

        { key: 'ref2Name', label: '2. Name', section: 'REFERENCE', type: 'text', required: true, enabled: true },
        { key: 'ref2Mobile', label: '2. Mobile No', section: 'REFERENCE', type: 'phone', required: true, enabled: true },
        { key: 'ref2Relation', label: '2. Relation', section: 'REFERENCE', type: 'text', required: true, enabled: true },
        { key: 'ref2Address', label: '2. Address', section: 'REFERENCE', type: 'textarea', required: true, enabled: true },
      ]),
    };

    if (isFinserve) {
      for (const s of settings) {
        if (s.key.startsWith('finserve_')) {
          const rawKey = s.key.substring('finserve_'.length);
          if (s.value !== undefined && s.value !== null) {
            map[rawKey] = s.value;
          }
        }
      }
    } else {
      for (const s of settings) {
        if (!s.key.startsWith('finserve_')) {
          if (s.value !== undefined && s.value !== null) {
            map[s.key] = s.value;
          }
        }
      }
    }
    return map;
  },

  async updateSettings(dto: UpdateCrmSettingsDto, updatedBy?: string, scope: string = 'NB_DEVELOPER') {
    const isFinserve = scope === 'NB_FINSERVE';
    const entries = Object.entries(dto);
    for (const [key, value] of entries) {
      if (value !== undefined) {
        const dbKey = isFinserve ? `finserve_${key}` : key;
        const serializedValue = Array.isArray(value) || (typeof value === 'object' && value !== null)
          ? JSON.stringify(value)
          : String(value);
        await prisma.crmSetting.upsert({
          where: { key: dbKey },
          update: { value: serializedValue, updatedBy },
          create: { key: dbKey, value: serializedValue, updatedBy },
        });
      }
    }

    // If Finserve loan_types were updated, synchronize options in crm_column_configs safely
    if (isFinserve && dto.loan_types !== undefined) {
      let optionsList: string[] = [];
      try {
        optionsList = Array.isArray(dto.loan_types)
          ? dto.loan_types
          : JSON.parse(dto.loan_types);
      } catch (_) {}
      if (Array.isArray(optionsList) && optionsList.length > 0) {
        await prisma.crmColumnConfig.updateMany({
          where: {
            scope: 'NB_FINSERVE',
            columnKey: 'Loan_Type',
          },
          data: {
            label: 'Type of Loan',
            dataType: 'SELECT',
            options: optionsList,
          },
        });
      }
    }

    return this.getSettings(scope);
  },

  /**
   * Discovers all active employees eligible to receive telecaller leads for the given CRM scope.
   * Checks:
   * 1. Employee is ACTIVE and has an active User account (excluding administrative roles).
   * 2. Permission Matrix: User's role has READ or WRITE permission on CRM modules:
   *    - For Real Estate CRM (NB_DEVELOPER): CRM_PRE_SALES, CRM_SALES, or CRM
   *    - For Finserve CRM (NB_FINSERVE): FIN_CRM_PRE_SALES, FIN_CRM_SALES, or FIN_CRM
   * 3. Sub-organization: Matches creator or campaign sub-organization if provided (graceful fallback).
   */
  async getEligibleTelecallers(
    scope: string = 'NB_DEVELOPER',
    subOrganization?: string | null,
    options?: {
      requirePunchIn?: boolean;
      requireActive?: boolean;
    },
  ): Promise<number[]> {
    const isFinserve = scope === 'NB_FINSERVE';
    const targetModuleKeys = isFinserve
      ? ['FIN_CRM_PRE_SALES', 'FIN_CRM_SALES', 'FIN_CRM']
      : ['CRM_PRE_SALES', 'CRM_SALES', 'CRM'];

    const users = await prisma.user.findMany({
      where: {
        isActive: true,
        employeeId: { not: null },
        employee: {
          status: 'ACTIVE',
        },
      },
      include: {
        employee: {
          include: {
            generalInfo: {
              select: {
                fullName: true,
                subOrganization: true,
                organization: true,
                department: true,
                designation: true,
              },
            },
          },
        },
        role: {
          include: {
            permissions: {
              where: {
                moduleKey: { in: targetModuleKeys },
                OR: [{ canRead: true }, { canWrite: true }],
              },
            },
          },
        },
      },
    });

    // 1. Exclude administrators, IT, and executive management roles
    const isExcludedAdmin = (roleName?: string | null) => {
      const r = String(roleName || '').toLowerCase().trim();
      return isAdminRole(roleName) || /admin|superadmin|itadmin/i.test(r);
    };

    // 2. Telecaller check: role or designation must indicate telecalling
    const isTelecallerUser = (u: any) => {
      const roleName = String(u.role?.name || '').toLowerCase().trim();
      const desig = String(u.employee?.generalInfo?.designation || '').toLowerCase().trim();
      if (isExcludedAdmin(u.role?.name)) return false;
      return roleName.includes('telecall') || desig.includes('telecall');
    };

    const telecallerUsers = users.filter(isTelecallerUser);

    // 3. Permission matrix: ensure they have access to this CRM scope
    const permittedUsers = telecallerUsers.filter((u) => (u.role?.permissions?.length || 0) > 0);
    const candidatePool = permittedUsers.length > 0 ? permittedUsers : telecallerUsers;

    // 4. Filter by subOrganization if specified
    let scopedUsers = candidatePool;
    if (subOrganization && subOrganization.trim().length > 0) {
      const subOrgClean = subOrganization.trim().toLowerCase();
      const matched = candidatePool.filter((u) => {
        const empSub = (u.subOrganization || u.employee?.generalInfo?.subOrganization || '').toLowerCase().trim();
        return empSub === subOrgClean;
      });
      if (matched.length > 0) {
        scopedUsers = matched;
      }
    }

    // 5. Candidate IDs sorted by employee ID
    let candidateIds: number[] = [];
    if (scopedUsers.length > 0) {
      candidateIds = Array.from(
        new Set(
          scopedUsers
            .map((u) => u.employeeId)
            .filter((id): id is number => typeof id === 'number' && id > 0),
        ),
      ).sort((a, b) => a - b);
    } else {
      // Fallback: Check if explicit pools were configured in CRM Settings
      const pools = await this.getAssignedTelecallerPools(scope);
      const configuredPool = Array.from(new Set([...pools.excelIds, ...pools.webhookIds]));
      if (configuredPool.length > 0) {
        const nonAdminPool = configuredPool.filter((id) => {
          const user = users.find((u) => u.employeeId === id);
          return !isExcludedAdmin(user?.role?.name);
        });
        candidateIds = nonAdminPool;
      }
    }

    // Filter by Daily Attendance punch-in if required
    if (options?.requirePunchIn) {
      const punchChecks = await Promise.all(
        candidateIds.map(async (id) => ({ id, punched: await this.isPunchedInToday(id) })),
      );
      candidateIds = punchChecks.filter((p) => p.punched).map((p) => p.id);
    }

    // Filter by Screen Activity (not on break, heartbeat within idle timeout) if required
    if (options?.requireActive) {
      const settings = await this.getSettings(scope);
      const idleMin = parseInt(String(settings.idle_timeout_minutes || '5'), 10) || 5;
      candidateIds = candidateIds.filter((id) => this.isTelecallerActiveOnScreen(id, idleMin));
    }

    return candidateIds;
  },

  // ---------------------------------------------------------------------------
  // Telecaller Presence & Screen Activity Tracking
  // ---------------------------------------------------------------------------
  recordTelecallerActivity(
    employeeId: number,
    status: 'ACTIVE' | 'ON_BREAK' = 'ACTIVE',
    subOrganization?: string | null,
  ): TelecallerPresence {
    const existing = telecallerPresenceMap.get(employeeId);
    const updated: TelecallerPresence = {
      employeeId,
      lastActiveAt: status === 'ACTIVE' ? Date.now() : (existing?.lastActiveAt || Date.now()),
      status,
      subOrganization: subOrganization !== undefined ? subOrganization : existing?.subOrganization,
    };
    telecallerPresenceMap.set(employeeId, updated);
    return updated;
  },

  getTelecallerActivity(employeeId: number): TelecallerPresence | undefined {
    return telecallerPresenceMap.get(employeeId);
  },

  isTelecallerActiveOnScreen(employeeId: number, idleTimeoutMinutes: number = 5): boolean {
    const presence = telecallerPresenceMap.get(employeeId);
    if (!presence) return false;
    if (presence.status === 'ON_BREAK') return false;
    const elapsedMs = Date.now() - presence.lastActiveAt;
    if (elapsedMs > idleTimeoutMinutes * 60 * 1000) {
      presence.status = 'ON_BREAK';
      return false;
    }
    return true;
  },

  async isPunchedInToday(employeeId: number): Promise<boolean> {
    const ymd = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Asia/Kolkata',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(new Date());

    const fromUtc = new Date(`${ymd}T00:00:00+05:30`);
    const toExclusive = new Date(fromUtc.getTime() + 24 * 60 * 60 * 1000);

    const punches = await prisma.attendancePunch.findMany({
      where: {
        employeeId,
        punchAt: { gte: fromUtc, lt: toExclusive },
      },
      orderBy: { punchAt: 'asc' },
      select: { punchAt: true, source: true },
    });

    if (punches.length === 0) return false;

    const mobilePunches = punches.filter((p) => String(p.source) === 'MOBILE_APP');
    if (mobilePunches.length > 0) {
      return mobilePunches.length % 2 === 1;
    }

    // Biometric machine (ESSL/ETIMEOFFICE) or manual punches:
    // If odd number of punches, currently on duty.
    if (punches.length % 2 === 1) return true;

    const { firstIn, lastOut } = deriveDayInOut(punches);
    if (firstIn && !lastOut) return true;

    // Has at least 1 punch today
    return punches.length > 0;
  },

  // ---------------------------------------------------------------------------
  // Telecaller Active Workload & Capacity Management
  // ---------------------------------------------------------------------------
  /**
   * Workload = count of active untouched or in-progress leads:
   * status IN ['NOT_STARTED', 'CNR', 'ASSIGNED']
   */
  async getTelecallerWorkload(employeeId: number, scope: string = 'NB_DEVELOPER'): Promise<number> {
    return await prisma.crmLead.count({
      where: {
        isDeleted: false,
        scope,
        OR: [
          { telecallerId: employeeId },
          { assignedToId: employeeId },
        ],
        status: { in: [CrmLeadStatus.NOT_STARTED, CrmLeadStatus.CNR, CrmLeadStatus.ASSIGNED] },
      },
    });
  },

  async getTelecallerCapacity(
    employeeId: number,
    scope: string = 'NB_DEVELOPER',
    settings?: any,
  ): Promise<{ maxCapacity: number; currentWorkload: number; availableCapacity: number }> {
    if (!settings) {
      settings = await this.getSettings(scope);
    }
    let maxCapacity = 20;
    if (settings.max_telecaller_active_workload) {
      const val = parseInt(String(settings.max_telecaller_active_workload), 10);
      if (!isNaN(val) && val > 0) maxCapacity = val;
    }

    if (settings.telecaller_max_workload_map) {
      try {
        const map = typeof settings.telecaller_max_workload_map === 'string'
          ? JSON.parse(settings.telecaller_max_workload_map)
          : settings.telecaller_max_workload_map;
        if (map && map[String(employeeId)] !== undefined) {
          const custom = parseInt(String(map[String(employeeId)]), 10);
          if (!isNaN(custom) && custom > 0) maxCapacity = custom;
        }
      } catch {}
    }

    const currentWorkload = await this.getTelecallerWorkload(employeeId, scope);
    const availableCapacity = Math.max(0, maxCapacity - currentWorkload);

    return { maxCapacity, currentWorkload, availableCapacity };
  },

  // ---------------------------------------------------------------------------
  // Waiting Queue Dispatcher
  // ---------------------------------------------------------------------------
  async dispatchWaitingQueue(
    scope: string = 'NB_DEVELOPER',
    subOrganization?: string | null,
  ): Promise<{
    dispatchedCount: number;
    remainingQueuedCount: number;
    activeTelecallersCount: number;
    candidateDetails: any[];
  }> {
    const queuedLeads = await prisma.crmLead.findMany({
      where: {
        scope,
        isDeleted: false,
        telecallerId: null,
        assignedToId: null,
      },
      orderBy: { createdAt: 'asc' },
      select: { id: true, customFields: true },
    });

    if (queuedLeads.length === 0) {
      return {
        dispatchedCount: 0,
        remainingQueuedCount: 0,
        activeTelecallersCount: 0,
        candidateDetails: [],
      };
    }

    // 1. Primary: Find telecallers who have punched in today AND are active on screen
    let eligibleIds = await this.getEligibleTelecallers(scope, subOrganization, {
      requirePunchIn: true,
      requireActive: true,
    });

    // Fallback: If no one has screen activity right this second (e.g. idle timeout / brief pause),
    // fallback to telecallers who ARE PUNCHED IN today (on duty), so leads only go to people at work.
    // If an employee is NOT punched in today, leads will NEVER go to them.
    if (eligibleIds.length === 0) {
      eligibleIds = await this.getEligibleTelecallers(scope, subOrganization, {
        requirePunchIn: true,
        requireActive: false,
      });
    }

    if (eligibleIds.length === 0) {
      return {
        dispatchedCount: 0,
        remainingQueuedCount: queuedLeads.length,
        activeTelecallersCount: 0,
        candidateDetails: [],
      };
    }

    const settings = await this.getSettings(scope);

    // 2. Compute workload and available capacity for each active telecaller
    const candidates: Array<{
      employeeId: number;
      maxCapacity: number;
      currentWorkload: number;
      availableCapacity: number;
    }> = [];

    for (const empId of eligibleIds) {
      const cap = await this.getTelecallerCapacity(empId, scope, settings);
      if (cap.availableCapacity > 0) {
        candidates.push({
          employeeId: empId,
          maxCapacity: cap.maxCapacity,
          currentWorkload: cap.currentWorkload,
          availableCapacity: cap.availableCapacity,
        });
      }
    }

    if (candidates.length === 0) {
      return {
        dispatchedCount: 0,
        remainingQueuedCount: queuedLeads.length,
        activeTelecallersCount: eligibleIds.length,
        candidateDetails: [],
      };
    }

    // 3. Dispatch leads round-robin across candidates with available capacity
    let dispatchedCount = 0;
    let candidateIndex = 0;

    for (const lead of queuedLeads) {
      let candidateWithCapacity: typeof candidates[0] | null = null;
      let attempts = 0;
      const prevTelecallerId = (lead.customFields as any)?.previousTelecallerId;

      while (attempts < candidates.length) {
        const cand = candidates[candidateIndex % candidates.length];
        candidateIndex++;
        attempts++;

        // If candidates length > 1, avoid immediately assigning back to telecaller who left it untouched
        if (cand.availableCapacity > 0) {
          if (candidates.length > 1 && prevTelecallerId && cand.employeeId === Number(prevTelecallerId) && attempts < candidates.length) {
            continue;
          }
          candidateWithCapacity = cand;
          break;
        }
      }

      // If skipping previous telecaller failed to find someone, accept any candidate with capacity
      if (!candidateWithCapacity) {
        candidateWithCapacity = candidates.find((c) => c.availableCapacity > 0) || null;
      }

      if (!candidateWithCapacity) {
        // All active telecallers have reached their maximum workload limit
        break;
      }

      const assignedAt = new Date().toISOString();
      const existingCustom = (lead.customFields as any) || {};

      await prisma.crmLead.update({
        where: { id: lead.id },
        data: {
          telecallerId: candidateWithCapacity.employeeId,
          assignedToId: candidateWithCapacity.employeeId,
          status: CrmLeadStatus.NOT_STARTED,
          customFields: {
            ...existingCustom,
            assignedAt,
          },
        },
      });

      candidateWithCapacity.availableCapacity--;
      candidateWithCapacity.currentWorkload++;
      dispatchedCount++;
    }

    const remainingQueuedCount = queuedLeads.length - dispatchedCount;

    return {
      dispatchedCount,
      remainingQueuedCount,
      activeTelecallersCount: candidates.length,
      candidateDetails: candidates,
    };
  },

  // ---------------------------------------------------------------------------
  // 30-Minute Untouched Lead Recovery
  // ---------------------------------------------------------------------------
  async recoverUntouchedLeads(scope: string = 'NB_DEVELOPER'): Promise<{ recoveredCount: number }> {
    const settings = await this.getSettings(scope);
    let timeoutMinutes = 30;
    if (settings.untouched_lead_timeout_minutes) {
      const parsed = parseInt(String(settings.untouched_lead_timeout_minutes), 10);
      if (!isNaN(parsed) && parsed > 0) timeoutMinutes = parsed;
    }

    const cutoff = new Date(Date.now() - timeoutMinutes * 60 * 1000);

    // Find leads assigned to a telecaller that have NOT been touched:
    // status in [NOT_STARTED, ASSIGNED], lastCallAt is null, and assignedAt or updatedAt <= cutoff
    const potentialLeads = await prisma.crmLead.findMany({
      where: {
        scope,
        isDeleted: false,
        telecallerId: { not: null },
        status: { in: [CrmLeadStatus.NOT_STARTED, CrmLeadStatus.ASSIGNED] },
        lastCallAt: null,
        updatedAt: { lte: cutoff },
      },
      include: {
        callLogs: { select: { id: true }, take: 1 },
      },
      take: 200,
    });

    let recoveredCount = 0;
    for (const lead of potentialLeads) {
      if (lead.callLogs && lead.callLogs.length > 0) {
        continue;
      }

      const custom = (lead.customFields as any) || {};
      let assignedTime = lead.updatedAt.getTime();
      if (custom.assignedAt) {
        const parsedAssigned = new Date(custom.assignedAt).getTime();
        if (!isNaN(parsedAssigned)) assignedTime = parsedAssigned;
      }

      if (Date.now() - assignedTime >= timeoutMinutes * 60 * 1000) {
        await prisma.crmLead.update({
          where: { id: lead.id },
          data: {
            telecallerId: null,
            assignedToId: null,
            status: CrmLeadStatus.NOT_STARTED,
            customFields: {
              ...custom,
              returnedToQueueAt: new Date().toISOString(),
              unassignedReason: `UNTOUCHED_${timeoutMinutes}_MIN`,
              previousTelecallerId: lead.telecallerId,
            },
          },
        });
        recoveredCount++;
      }
    }

    return { recoveredCount };
  },

  async recoverUntouchedLeadsAndDispatch(scope: string = 'NB_DEVELOPER') {
    const { recoveredCount } = await this.recoverUntouchedLeads(scope);
    const dispatchRes = await this.dispatchWaitingQueue(scope);
    return { recoveredCount, ...dispatchRes };
  },

  // ---------------------------------------------------------------------------
  // Waiting Queue & Telecaller Status Queries
  // ---------------------------------------------------------------------------
  async getWaitingQueueStatus(scope: string = 'NB_DEVELOPER', subOrganization?: string | null) {
    const queuedLeadsCount = await prisma.crmLead.count({
      where: {
        scope,
        isDeleted: false,
        telecallerId: null,
        assignedToId: null,
      },
    });

    const presenceList = await this.getTelecallerPresenceList(scope, subOrganization);
    const activeTelecallers = presenceList.filter((p) => p.isEligibleForDispatch);
    const totalAvailableCapacity = activeTelecallers.reduce((acc, p) => acc + p.availableCapacity, 0);

    return {
      queuedLeadsCount,
      activeTelecallersCount: activeTelecallers.length,
      totalTelecallersCount: presenceList.length,
      totalAvailableCapacity,
      telecallers: presenceList,
    };
  },

  async getTelecallerPresenceList(scope: string = 'NB_DEVELOPER', subOrganization?: string | null) {
    const allEligibleIds = await this.getEligibleTelecallers(scope, subOrganization, {
      requirePunchIn: false,
      requireActive: false,
    });

    const settings = await this.getSettings(scope);
    const idleMin = parseInt(String(settings.idle_timeout_minutes || '5'), 10) || 5;

    const employees = await prisma.employee.findMany({
      where: { id: { in: allEligibleIds } },
      select: {
        id: true,
        generalInfo: {
          select: {
            fullName: true,
            subOrganization: true,
            department: true,
            designation: true,
          },
        },
      },
      orderBy: { generalInfo: { fullName: 'asc' } },
    });

    const results = [];
    for (const emp of employees) {
      const isPunchedIn = await this.isPunchedInToday(emp.id);
      const presence = telecallerPresenceMap.get(emp.id);
      const isActiveOnScreen = this.isTelecallerActiveOnScreen(emp.id, idleMin);
      const capacity = await this.getTelecallerCapacity(emp.id, scope, settings);

      const isEligibleForDispatch = isPunchedIn && isActiveOnScreen && capacity.availableCapacity > 0;

      let inactiveSeconds = 0;
      if (presence?.lastActiveAt) {
        const elapsed = Math.floor((Date.now() - presence.lastActiveAt) / 1000);
        if (!isActiveOnScreen || presence.status === 'ON_BREAK') {
          inactiveSeconds = Math.max(0, elapsed);
        }
      } else if (!isActiveOnScreen) {
        inactiveSeconds = idleMin * 60;
      }

      let ineligibleReason: string | null = null;
      if (!isPunchedIn) {
        ineligibleReason = 'Not punched in today';
      } else if (!isActiveOnScreen || presence?.status === 'ON_BREAK') {
        const mins = Math.floor(inactiveSeconds / 60);
        ineligibleReason = mins > 0 ? `On break / Inactive (${mins}m)` : 'Inactive on screen';
      } else if (capacity.availableCapacity <= 0) {
        ineligibleReason = `Workload full (${capacity.currentWorkload}/${capacity.maxCapacity})`;
      }

      results.push({
        employeeId: emp.id,
        fullName: emp.generalInfo?.fullName || `Employee #${emp.id}`,
        subOrganization: emp.generalInfo?.subOrganization || null,
        department: emp.generalInfo?.department || null,
        designation: emp.generalInfo?.designation || null,
        isPunchedIn,
        presenceStatus: presence?.status || (isActiveOnScreen ? 'ACTIVE' : 'ON_BREAK'),
        lastActiveAt: presence?.lastActiveAt ? new Date(presence.lastActiveAt).toISOString() : null,
        isActiveOnScreen,
        inactiveSeconds,
        ineligibleReason,
        maxCapacity: capacity.maxCapacity,
        currentWorkload: capacity.currentWorkload,
        availableCapacity: capacity.availableCapacity,
        isEligibleForDispatch,
      });
    }

    return results;
  },

  /**
   * Deterministic round-robin lead distribution across eligible telecallers.
   * Uses total lead count + batchOffset modulo candidate count.
   */
  async getNextRoundRobinTelecaller(
    scope: string = 'NB_DEVELOPER',
    subOrganization?: string | null,
    source: string = 'EXCEL',
    batchOffset: number = 0,
  ): Promise<number | undefined> {
    const eligibleIds = await this.getEligibleTelecallers(scope, subOrganization);
    if (eligibleIds.length === 0) return undefined;
    if (eligibleIds.length === 1) return eligibleIds[0];

    const totalLeadsCount = await prisma.crmLead.count({
      where: { scope },
    });

    const index = (totalLeadsCount + batchOffset) % eligibleIds.length;
    return eligibleIds[index];
  },

  async getAssignedTelecallerPools(scope: string = 'NB_DEVELOPER') {
    const settings = await this.getSettings(scope);
    let excelIds: number[] = [];
    let webhookIds: number[] = [];
    try {
      excelIds = typeof settings.excel_assigned_telecaller_ids === 'string'
        ? JSON.parse(settings.excel_assigned_telecaller_ids)
        : (settings.excel_assigned_telecaller_ids || []);
      if (!Array.isArray(excelIds)) excelIds = [];
    } catch {
      excelIds = [];
    }
    try {
      webhookIds = typeof settings.webhook_assigned_telecaller_ids === 'string'
        ? JSON.parse(settings.webhook_assigned_telecaller_ids)
        : (settings.webhook_assigned_telecaller_ids || []);
      if (!Array.isArray(webhookIds)) webhookIds = [];
    } catch {
      webhookIds = [];
    }
    return {
      excelIds: excelIds.map(Number).filter((n) => !isNaN(n) && n > 0),
      webhookIds: webhookIds.map(Number).filter((n) => !isNaN(n) && n > 0),
    };
  },

  /** JSON map: { [employeeId]: { api_url, user_id, did, route_number, agent_number } } */
  async _readTelecallerConfigMap(scope: string = 'NB_DEVELOPER'): Promise<
    Record<
      string,
      {
        api_url?: string;
        user_id?: string;
        did?: string;
        route_number?: string;
        agent_number?: string;
      }
    >
  > {
    const isFinserve = scope === 'NB_FINSERVE';
    const key = isFinserve ? 'finserve_elision_telecaller_configs' : 'elision_telecaller_configs';
    const row = await prisma.crmSetting.findUnique({
      where: { key },
    });
    if (!row?.value) return {};
    try {
      const parsed = JSON.parse(row.value);
      return parsed && typeof parsed === 'object' ? parsed : {};
    } catch {
      return {};
    }
  },

  async _writeTelecallerConfigMap(
    map: Record<string, unknown>,
    updatedBy?: string,
    scope: string = 'NB_DEVELOPER',
  ) {
    const isFinserve = scope === 'NB_FINSERVE';
    const key = isFinserve ? 'finserve_elision_telecaller_configs' : 'elision_telecaller_configs';
    await prisma.crmSetting.upsert({
      where: { key },
      update: { value: JSON.stringify(map), updatedBy },
      create: {
        key,
        value: JSON.stringify(map),
        description: `Per-telecaller Elision/Greeter Click2Call credentials for ${isFinserve ? 'NB Finserve' : 'NB Developer'}`,
        updatedBy,
      },
    });
  },

  async listTelecallerTelephony(scope: string = 'NB_DEVELOPER') {
    const defaults = await this.getSettings(scope);
    const configs = await this._readTelecallerConfigMap(scope);

    const telecallers = await prisma.employee.findMany({
      where: {
        status: 'ACTIVE',
        OR: [
          {
            generalInfo: {
              designation: { equals: 'Telecaller', mode: 'insensitive' },
            },
          },
          {
            generalInfo: {
              designationRef: {
                name: { equals: 'Telecaller', mode: 'insensitive' },
              },
            },
          },
        ],
      },
      select: {
        id: true,
        userId: true,
        generalInfo: {
          select: {
            fullName: true,
            employeeCode: true,
            designation: true,
          },
        },
      },
      orderBy: { generalInfo: { fullName: 'asc' } },
    });

    return {
      defaults: {
        api_url: defaults.elision_api_url,
        user_id: defaults.elision_user_id,
        did: defaults.elision_did,
        route_number: defaults.elision_route_number,
        agent_number: defaults.elision_default_agent_number,
      },
      telecallers: telecallers.map((e) => {
        const cfg = configs[String(e.id)] ?? {};
        return {
          employeeId: e.id,
          userId: e.userId,
          name: e.generalInfo?.fullName ?? `Employee #${e.id}`,
          employeeCode: e.generalInfo?.employeeCode ?? null,
          designation: e.generalInfo?.designation ?? 'Telecaller',
          configured: Boolean(
            cfg.agent_number || cfg.user_id || cfg.did || cfg.api_url || cfg.route_number,
          ),
          config: {
            api_url: cfg.api_url ?? defaults.elision_api_url,
            user_id: cfg.user_id ?? defaults.elision_user_id,
            did: cfg.did ?? defaults.elision_did,
            route_number: cfg.route_number ?? defaults.elision_route_number,
            agent_number: cfg.agent_number ?? defaults.elision_default_agent_number,
          },
        };
      }),
    };
  },

  async upsertTelecallerTelephony(
    employeeId: number,
    body: Record<string, unknown>,
    updatedBy?: string,
    scope: string = 'NB_DEVELOPER',
  ) {
    if (!Number.isFinite(employeeId) || employeeId <= 0) {
      throw new Error('Invalid employee id');
    }
    const emp = await prisma.employee.findUnique({
      where: { id: employeeId },
      include: {
        generalInfo: {
          select: {
            designation: true,
            designationRef: { select: { name: true } },
          },
        },
      },
    });
    if (!emp) throw new Error('Employee not found');
    const desig =
      emp.generalInfo?.designationRef?.name ?? emp.generalInfo?.designation ?? '';
    if (!/telecaller/i.test(desig)) {
      throw new Error('Employee designation must be Telecaller');
    }

    const map = await this._readTelecallerConfigMap(scope);
    map[String(employeeId)] = {
      api_url: body.api_url != null ? String(body.api_url).trim() : map[String(employeeId)]?.api_url,
      user_id: body.user_id != null ? String(body.user_id).trim() : map[String(employeeId)]?.user_id,
      did: body.did != null ? String(body.did).trim() : map[String(employeeId)]?.did,
      route_number:
        body.route_number != null
          ? String(body.route_number).trim()
          : map[String(employeeId)]?.route_number,
      agent_number:
        body.agent_number != null
          ? String(body.agent_number).trim()
          : map[String(employeeId)]?.agent_number,
    };
    await this._writeTelecallerConfigMap(map, updatedBy, scope);
    const list = await this.listTelecallerTelephony(scope);
    return list.telecallers.find((t) => t.employeeId === employeeId) ?? null;
  },

  async clickToCall(leadId: string, agentPhoneOrId?: string, userContext?: any) {
    const lead = await prisma.crmLead.findUnique({ where: { id: leadId } });
    if (!lead) throw new Error('Lead not found');

    const leadScope = lead.scope || 'NB_DEVELOPER';
    const settings = await this.getSettings(leadScope);
    const telecallerMap = await this._readTelecallerConfigMap(leadScope);
    const empId = userContext?.employeeId != null ? Number(userContext.employeeId) : null;
    const personal =
      empId != null && Number.isFinite(empId) ? telecallerMap[String(empId)] : undefined;

    const apiUrl =
      personal?.api_url || settings.elision_api_url || 'https://greeter.co.in/api/click2call';
    const userId = personal?.user_id || settings.elision_user_id || '634550';
    const routeNumber = personal?.route_number || settings.elision_route_number || '98';
    const did = personal?.did || settings.elision_did || '9484700070';

    // Normalize customer phone number (strip spaces/dashes)
    let customerNumber = lead.phone.replace(/[^0-9]/g, '');
    if (customerNumber.length > 10 && customerNumber.startsWith('91')) {
      customerNumber = customerNumber.substring(2);
    }

    // Resolve Agent Mobile Number — prefer personal telephony config, then explicit arg, then profile, then global default
    let agentNumber: string | null | undefined =
      personal?.agent_number || agentPhoneOrId || null;
    if (!agentNumber && userContext?.employeeId) {
      try {
        const emp = await prisma.employee.findUnique({
          where: { id: userContext.employeeId },
          include: { addresses: true },
        });
        const addrWithPhone = emp?.addresses?.find((a: any) => a.mobileNo || a.phoneNo);
        if (addrWithPhone) {
          agentNumber = addrWithPhone.mobileNo || addrWithPhone.phoneNo;
        }
      } catch (_) {}
    }
    let resolvedAgentNumber = agentNumber || settings.elision_default_agent_number || '8511139384';
    resolvedAgentNumber = resolvedAgentNumber.replace(/[^0-9]/g, '');
    if (resolvedAgentNumber.length > 10 && resolvedAgentNumber.startsWith('91')) {
      resolvedAgentNumber = resolvedAgentNumber.substring(2);
    }

    // Log call attempt timestamp on the lead
    await prisma.crmLead.update({
      where: { id: leadId },
      data: { lastCallAt: new Date() },
    });

    try {
      // Greeter / Elision Click2Call API payload (multipart form / URLSearchParams)
      const formParams = new URLSearchParams();
      formParams.append('user_id', userId);
      formParams.append('customer_number', customerNumber);
      formParams.append('agen_number', resolvedAgentNumber); // Note key name is agen_number
      formParams.append('number', routeNumber);
      formParams.append('did', did);

      const response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formParams.toString(),
      });

      const responseText = await response.text();
      let responseData: any = {};
      try {
        responseData = JSON.parse(responseText);
      } catch (_) {
        responseData = { rawResponse: responseText };
      }

      // Record call log attempt
      await prisma.crmCallLog.create({
        data: {
          leadId: lead.id,
          customerNumber,
          agentNumber: resolvedAgentNumber,
          did,
          callStatus: response.ok ? 'INITIATED' : 'FAILED',
          callTime: new Date(),
          rawPayload: responseData,
        },
      });

      return {
        success: response.ok,
        message: response.ok
          ? `Call initiated! Dialing agent (${resolvedAgentNumber}) first, then customer (${customerNumber}).`
          : `Telephony API returned error: ${responseText}`,
        customerNumber,
        agentNumber: resolvedAgentNumber,
        did,
        data: responseData,
      };
    } catch (err: any) {
      // Record failed call attempt log
      await prisma.crmCallLog.create({
        data: {
          leadId: lead.id,
          customerNumber,
          agentNumber: resolvedAgentNumber,
          did,
          callStatus: 'CONNECTION_ERROR',
          callTime: new Date(),
          rawPayload: { error: err.message },
        },
      });

      return {
        success: false,
        error: err.message || 'Failed to connect to Elision Telephony API',
      };
    }
  },

  async handleTelephonyWebhook(payload: any) {
    // Greeter / Elision Call Log Post Payload Parser
    const rawCustomer = String(
      payload.customer_number ||
      payload.Customer_No ||
      payload.customer_no ||
      payload.phone ||
      payload.customerNumber ||
      payload.Customer_Mobile ||
      payload.mobile ||
      payload.cli ||
      payload.caller ||
      payload.caller_id ||
      payload.callerId ||
      payload.destination ||
      payload.dst ||
      payload.src ||
      ''
    ).replace(/[^0-9]/g, '');

    const rawAgent = String(
      payload.agent_number ||
      payload.agen_number ||
      payload.Agent_No ||
      payload.agent_no ||
      payload.agentNumber ||
      payload.agent ||
      payload.user ||
      payload.extension ||
      payload.agent_id ||
      ''
    ).replace(/[^0-9]/g, '');

    if (!rawCustomer) {
      return {
        status: 'ignored',
        message: 'No valid customer phone number found in payload',
      };
    }

    const rawStatus = String(
      payload.call_status ||
      payload.status ||
      payload.Status ||
      payload.disposition ||
      payload.Call_Status ||
      payload.callStatus ||
      payload.dispo ||
      'COMPLETED'
    ).trim();

    let callStatus = rawStatus.toUpperCase();
    if (['ANSWER', 'ANSWERED', 'COMPLETED', 'SUCCESS', 'CONNECTED'].includes(callStatus)) {
      callStatus = 'ANSWERED';
    } else if (['NOANSWER', 'NO_ANSWER', 'MISSED', 'UNANSWERED', 'CANCEL'].includes(callStatus)) {
      callStatus = 'MISSED';
    } else if (['BUSY', 'LINE_BUSY', 'USER_BUSY'].includes(callStatus)) {
      callStatus = 'BUSY';
    }

    const duration = parseInt(
      String(
        payload.AnsDur ||
        payload.ansdur ||
        payload.ans_dur ||
        payload.duration ||
        payload.talk_time ||
        payload.Duration ||
        payload.call_duration ||
        payload.billsec ||
        payload.answered_time ||
        payload.talktime ||
        0
      ),
      10
    ) || 0;

    let recordingUrl =
      payload.recording_url ||
      payload.recording_path ||
      payload.Recording_Path ||
      payload.RecordingPath ||
      payload.recording ||
      payload.Recording ||
      payload.Audio_URL ||
      payload.audio_url ||
      payload.record_url ||
      payload.recording_file ||
      payload.record_file ||
      payload.AudioUrl ||
      payload.RecordingUrl ||
      payload.filename ||
      payload.file_url ||
      payload.call_recording ||
      payload.rec_path ||
      payload.call_audio ||
      payload.audio ||
      null;

    if (recordingUrl && typeof recordingUrl === 'string') {
      recordingUrl = recordingUrl.trim();
      if (
        !recordingUrl.startsWith('http://') &&
        !recordingUrl.startsWith('https://') &&
        recordingUrl.length > 3
      ) {
        if (recordingUrl.startsWith('/')) {
          recordingUrl = `https://greeter.co.in${recordingUrl}`;
        } else {
          recordingUrl = `https://greeter.co.in/recordings/${recordingUrl}`;
        }
      }
    }

    const did = payload.did || payload.DID || payload.did_number || payload.virtual_number || payload.ivr_number || null;
    const callId = payload.call_id || payload.unique_id || payload.Call_ID || payload.callId || null;
    const callTime = payload.call_time || payload.Call_Time || payload.start_time || payload.calldate || payload.timestamp
      ? new Date(payload.call_time || payload.Call_Time || payload.start_time || payload.calldate || payload.timestamp)
      : new Date();

    // Match with lead by customer number (last 10 digits)
    let leadId: string | null = null;
    if (rawCustomer.length >= 10) {
      const last10 = rawCustomer.slice(-10);
      const matchedLead = await prisma.crmLead.findFirst({
        where: {
          phone: { contains: last10 },
        },
      });
      if (matchedLead) {
        leadId = matchedLead.id;
        await prisma.crmLead.update({
          where: { id: matchedLead.id },
          data: { lastCallAt: callTime },
        });
      } else {
        // Auto-create inbound lead so telecallers see incoming inquiries from IVR
        try {
          const newLead = await prisma.crmLead.create({
            data: {
              phone: rawCustomer,
              name: `Inbound (${rawCustomer})`,
              status: 'NOT_STARTED',
              customFields: {
                source: did ? `IVR ${did}` : 'IVR Inbound',
                did: did || '',
              },
              lastCallAt: callTime,
            },
          });
          leadId = newLead.id;
        } catch (_) {}
      }
    }

    // Check if there is an existing recent INITIATED log for this customer to update
    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
    const existingInitiatedLog = rawCustomer.length >= 10
      ? await prisma.crmCallLog.findFirst({
          where: {
            customerNumber: { contains: rawCustomer.slice(-10) },
            callStatus: 'INITIATED',
            createdAt: { gte: thirtyMinutesAgo },
          },
          orderBy: { createdAt: 'desc' },
        })
      : null;

    let callLog;
    if (existingInitiatedLog) {
      callLog = await prisma.crmCallLog.update({
        where: { id: existingInitiatedLog.id },
        data: {
          leadId: leadId || existingInitiatedLog.leadId,
          callStatus,
          duration: duration || existingInitiatedLog.duration,
          recordingUrl: recordingUrl || existingInitiatedLog.recordingUrl,
          callTime,
          did: did || existingInitiatedLog.did,
          agentNumber: rawAgent || existingInitiatedLog.agentNumber,
          callId: callId || existingInitiatedLog.callId,
          rawPayload: payload,
        },
      });
    } else {
      callLog = await prisma.crmCallLog.create({
        data: {
          leadId,
          customerNumber: rawCustomer,
          agentNumber: rawAgent,
          did,
          callStatus,
          duration,
          recordingUrl,
          callTime,
          callId,
          rawPayload: payload,
        },
      });
    }

    // WhatsApp Automation: Post-call relationship greeting message
    if (leadId && (callStatus === 'ANSWERED' || callStatus === 'COMPLETED' || duration > 0)) {
      prisma.crmLead
        .findUnique({
          where: { id: leadId },
          include: {
            campaign: { select: { project: { select: { name: true } } } },
            assignedTo: { include: { generalInfo: { select: { fullName: true } } } },
          },
        })
        .then((matchedLead) => {
          if (matchedLead) {
            whatsappService
              .triggerEvent('AFTER_CALL', matchedLead, {
                projectName: (matchedLead.campaign as any)?.project?.name || 'Legacy Tower',
                callDuration: duration,
                agentName: matchedLead.assignedTo?.generalInfo?.fullName,
              })
              .catch((err) => console.error('[CRM WhatsApp Hook Error - After Call]:', err));
          }
        })
        .catch(() => {});
    }

    return {
      status: 'success',
      message: 'Call log saved successfully',
      logId: callLog.id,
      leadMatched: leadId !== null,
    };
  },

  async streamCallAudio(logId: string, req: Request, res: Response) {
    const log = await prisma.crmCallLog.findUnique({
      where: { id: logId },
      select: { id: true, recordingUrl: true, customerNumber: true },
    });

    if (!log || !log.recordingUrl) {
      return res.status(404).send('Recording not found');
    }

    let audioUrl = log.recordingUrl.trim();
    if (!audioUrl.startsWith('http://') && !audioUrl.startsWith('https://')) {
      if (audioUrl.startsWith('/')) {
        audioUrl = `https://greeter.co.in${audioUrl}`;
      } else {
        audioUrl = `https://greeter.co.in/recordings/${audioUrl}`;
      }
    }


    try {
      const headers: Record<string, string> = {
        'User-Agent': 'NB-CRM-Audio-Streamer/1.0',
      };
      if (req.headers.range) {
        headers['Range'] = req.headers.range;
      }

      const upstreamRes = await fetch(audioUrl, {
        method: 'GET',
        headers,
      });

      const contentType = upstreamRes.headers.get('content-type') || 'audio/mpeg';

      // If PBX returned HTML (such as 404 page or login redirect), do not stream as audio
      if (contentType.includes('text/html')) {
        return res.status(404).send('Audio recording file not found on PBX server');
      }

      res.status(upstreamRes.status);
      res.setHeader('Content-Type', contentType);
      res.setHeader('Accept-Ranges', 'bytes');
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Headers', 'Range, Authorization, Content-Type');

      const cl = upstreamRes.headers.get('content-length');
      if (cl) res.setHeader('Content-Length', cl);
      const cr = upstreamRes.headers.get('content-range');
      if (cr) res.setHeader('Content-Range', cr);

      if (upstreamRes.body) {
        // @ts-ignore
        const { Readable } = await import('stream');
        // @ts-ignore
        Readable.fromWeb(upstreamRes.body).pipe(res);
      } else {
        res.end();
      }
    } catch (err: any) {
      if (!res.headersSent) {
        res.status(502).send(`Error streaming recording: ${err.message}`);
      }
    }
  },

  async getCallLogs(query: {
    leadId?: string;
    hasRecording?: boolean | string;
    search?: string;
    dateFilter?: string;
    startDate?: string;
    endDate?: string;
    callStatus?: string;
    did?: string;
    limit?: number | string;
  }) {
    const where: any = {
      customerNumber: { not: '' },
    };
    if (query.leadId) {
      where.leadId = query.leadId;
    }

    if (query.hasRecording === true || query.hasRecording === 'true') {
      where.recordingUrl = { not: null };
    }

    if (query.callStatus && query.callStatus !== 'ALL') {
      where.callStatus = query.callStatus.toUpperCase();
    }

    if (query.did && query.did !== 'ALL') {
      where.did = query.did;
    }

    if (query.search) {
      const s = String(query.search).trim();
      where.OR = [
        { customerNumber: { contains: s, mode: 'insensitive' } },
        { agentNumber: { contains: s, mode: 'insensitive' } },
        { lead: { name: { contains: s, mode: 'insensitive' } } },
      ];
    }

    // Date filters (today, yesterday, this_week, this_month, custom)
    const now = new Date();
    if (query.dateFilter === 'today') {
      const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      where.callTime = { gte: todayStart };
    } else if (query.dateFilter === 'yesterday') {
      const yesterdayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
      const yesterdayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      where.callTime = { gte: yesterdayStart, lt: yesterdayEnd };
    } else if (query.dateFilter === 'this_week') {
      const weekStart = new Date(now);
      weekStart.setDate(now.getDate() - now.getDay());
      weekStart.setHours(0, 0, 0, 0);
      where.callTime = { gte: weekStart };
    } else if (query.dateFilter === 'this_month') {
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
      where.callTime = { gte: monthStart };
    } else if (query.startDate || query.endDate) {
      where.callTime = {};
      if (query.startDate) where.callTime.gte = new Date(query.startDate);
      if (query.endDate) {
        const end = new Date(query.endDate);
        end.setHours(23, 59, 59, 999);
        where.callTime.lte = end;
      }
    }

    const logs = await prisma.crmCallLog.findMany({
      where,
      orderBy: { callTime: 'desc' },
      take: Number(query.limit) || 100,
      include: {
        lead: {
          select: { id: true, name: true, phone: true, status: true },
        },
      },
    });

    return logs;
  },

  async updateCallLog(
    id: string,
    data: {
      recordingUrl?: string;
      duration?: number;
      callStatus?: string;
    }
  ) {
    const updateData: any = {};
    if (data.recordingUrl !== undefined) updateData.recordingUrl = data.recordingUrl;
    if (data.duration !== undefined) updateData.duration = Number(data.duration);
    if (data.callStatus !== undefined) updateData.callStatus = data.callStatus.toUpperCase();

    const updated = await prisma.crmCallLog.update({
      where: { id },
      data: updateData,
      include: {
        lead: {
          select: { id: true, name: true, phone: true, status: true },
        },
      },
    });

    return updated;
  },

  // ---------------------------------------------------------------------------
  // KPI Metrics for Dashboard
  // ---------------------------------------------------------------------------
  async getKpiMetrics(
    projectId?: string,
    campaignId?: string,
    scope: string = 'NB_DEVELOPER',
    userRole?: string,
    userEmployeeId?: number,
  ) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const isAdmin = ['ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'].includes(
      userRole?.toUpperCase() || ''
    );

    const leadWhere: Record<string, unknown> = { isDeleted: false, scope };
    if (campaignId && campaignId !== 'ALL') {
      leadWhere.campaignId = campaignId;
    } else if (projectId && projectId !== 'ALL') {
      leadWhere.campaign = { projectId, scope };
    }

    // Only admin can see ALL TOTAL KPIs across the whole organization.
    // Non-admin individuals only see their own assigned KPIs.
    if (!isAdmin && userEmployeeId) {
      leadWhere.OR = [
        { telecallerId: userEmployeeId },
        { assignedToId: userEmployeeId },
      ];
    }

    const followUpWhere: Record<string, unknown> = {
      scheduledDate: { gte: today, lt: tomorrow },
      status: 'PENDING',
      lead: { ...leadWhere },
    };
    if (!isAdmin && userEmployeeId) {
      followUpWhere.OR = [
        { assignedToId: userEmployeeId },
        { lead: { isDeleted: false, scope, OR: [{ telecallerId: userEmployeeId }, { assignedToId: userEmployeeId }] } },
      ];
    }

    const callLogWhere: Record<string, unknown> = {};
    if (!isAdmin && userEmployeeId) {
      callLogWhere.lead = {
        isDeleted: false,
        scope,
        OR: [
          { telecallerId: userEmployeeId },
          { assignedToId: userEmployeeId },
        ],
      };
    }

    const [
      totalActiveLeads,
      todayFollowUps,
      interestedDeals,
      binCount,
      freshLeads,
      followUpLeads,
      totalCalls,
      answeredCalls,
      missedCalls,
      callDurationSum,
    ] = await Promise.all([
      prisma.crmLead.count({ where: leadWhere }),
      prisma.crmFollowUp.count({ where: followUpWhere }),
      prisma.crmLead.count({
        where: { ...leadWhere, status: CrmLeadStatus.INTERESTED },
      }),
      prisma.crmLead.count({
        where: {
          isDeleted: true,
          scope,
          ...(!isAdmin && userEmployeeId
            ? { OR: [{ telecallerId: userEmployeeId }, { assignedToId: userEmployeeId }] }
            : {}),
          ...(campaignId && campaignId !== 'ALL'
            ? { campaignId }
            : projectId && projectId !== 'ALL'
              ? { campaign: { projectId, scope } }
              : {}),
        },
      }),
      prisma.crmLead.count({
        where: { ...leadWhere, status: CrmLeadStatus.NOT_STARTED },
      }),
      prisma.crmLead.count({
        where: { ...leadWhere, status: CrmLeadStatus.FOLLOW_UP },
      }),
      prisma.crmCallLog.count({ where: callLogWhere }),
      prisma.crmCallLog.count({
        where: {
          ...callLogWhere,
          callStatus: { in: ['ANSWERED', 'ANSWER', 'COMPLETED', 'SUCCESS'] },
        },
      }),
      prisma.crmCallLog.count({
        where: {
          ...callLogWhere,
          callStatus: { in: ['MISSED', 'NOANSWER', 'BUSY', 'FAILED', 'CANCELLED'] },
        },
      }),
      prisma.crmCallLog.aggregate({
        where: callLogWhere,
        _sum: { duration: true },
      }),
    ]);

    const totalSeconds = callDurationSum._sum.duration || 0;
    const totalTalkTimeMinutes = Math.round(totalSeconds / 60);
    const conversionRate = totalActiveLeads > 0
      ? parseFloat(((interestedDeals / totalActiveLeads) * 100).toFixed(1))
      : 0;

    return {
      totalActiveLeads,
      todayFollowUps,
      interestedDeals,
      binCount,
      freshLeads,
      followUpLeads,
      totalCalls,
      answeredCalls,
      missedCalls,
      totalTalkTimeMinutes,
      conversionRate,
      isPersonal: !isAdmin,
      employeeId: !isAdmin ? userEmployeeId : undefined,
    };
  },

  // ---------------------------------------------------------------------------
  // Sales Users & Employees from HRMS
  // ---------------------------------------------------------------------------
  async getSalesUsers(query?: { telecallersOnly?: boolean | string }) {
    const isTelecallersOnly =
      query?.telecallersOnly === true || query?.telecallersOnly === 'true';

    const employees = await prisma.employee.findMany({
      where: {
        status: 'ACTIVE',
        ...(isTelecallersOnly
          ? {
              OR: [
                { user: { role: { name: { contains: 'telecall', mode: 'insensitive' } } } },
                { generalInfo: { designation: { contains: 'telecall', mode: 'insensitive' } } },
              ],
            }
          : {}),
      },
      include: {
        generalInfo: {
          select: {
            fullName: true,
            designation: true,
            department: true,
          },
        },
        user: {
          select: {
            id: true,
            username: true,
            role: { select: { name: true } },
          },
        },
      },
      orderBy: { id: 'asc' },
    });

    const mapped = employees.map((emp) => ({
      employeeId: emp.id,
      userId: emp.userId,
      fullName: emp.generalInfo?.fullName || emp.user?.username || `Employee #${emp.id}`,
      designation: emp.generalInfo?.designation || 'Sales Executive',
      department: emp.generalInfo?.department || 'Sales & Marketing',
      role: emp.user?.role?.name || 'SALES',
    }));

    if (isTelecallersOnly) {
      return mapped.filter((e) => {
        const r = (e.role || '').toLowerCase();
        return !/admin|superadmin|itadmin/i.test(r);
      });
    }

    return mapped;
  },

  // ---------------------------------------------------------------------------
  // WhatsApp Automation Configuration & Execution (BotBiz WhatsApp API)
  // ---------------------------------------------------------------------------
  async getWhatsappConfig(scope: string = 'NB_DEVELOPER') {
    return whatsappService.getConfig(scope);
  },

  async updateWhatsappConfig(dto: any, updatedBy?: string, scope: string = 'NB_DEVELOPER') {
    return whatsappService.updateConfig(dto, updatedBy, scope);
  },

  async testWhatsappConnection(scope: string = 'NB_DEVELOPER') {
    return whatsappService.testConnection(scope);
  },

  async syncWhatsappTemplates(scope: string = 'NB_DEVELOPER') {
    return whatsappService.syncTemplates(scope);
  },

  async getWhatsappTemplates(scope: string = 'NB_DEVELOPER') {
    return whatsappService.getCachedTemplates(scope);
  },

  async checkWhatsappTemplateStatus(templateId: string, scope: string = 'NB_DEVELOPER') {
    return whatsappService.checkTemplateStatus(templateId, scope);
  },

  async retryWhatsappLog(logId: string, scope: string = 'NB_DEVELOPER') {
    return whatsappService.retryLog(logId, scope);
  },

  async sendTestWhatsappMessage(phone: string, message?: string, templateId?: string, scope: string = 'NB_DEVELOPER') {
    const isFinserve = scope === 'NB_FINSERVE';
    const cached = await whatsappService.getCachedTemplates(scope);

    // Default to first approved template if templateId is not provided
    const targetTemplateId =
      templateId ||
      cached.templates.find((t) => t.status === 'APPROVED' && t.name === 'newlead')?.id ||
      cached.templates.find((t) => t.status === 'APPROVED')?.id;

    if (targetTemplateId) {
      const tmpl = cached.templates.find(
        (t) =>
          t.id === targetTemplateId ||
          String(t.raw?.id) === targetTemplateId ||
          t.name === targetTemplateId,
      );
      return whatsappService.sendDirect({
        phone,
        message:
          message ||
          (tmpl ? `Test of template: ${tmpl.name}` : `Test template dispatch (${isFinserve ? 'NB Finserve' : 'NB Developer'})`),
        event: 'TEST',
        messageType: 'TEMPLATE',
        templateId: tmpl?.id || targetTemplateId,
        templateName: tmpl?.name,
        variables: {
          name: 'Jash',
          customerName: 'Jash',
          client_name: 'Jash',
          pname: isFinserve ? 'NB Finserve' : 'Legacy Tower',
        },
        scope,
      });
    }

    const text =
      message ||
      (isFinserve
        ? 'Hello from NB Finserve WhatsApp Automation! 💼 Test notification for NB Finserve.'
        : 'Hello from NB CRM WhatsApp Automation! 🏢 Test notification for Legacy Tower.');
    return whatsappService.sendDirect({
      phone,
      message: text,
      event: 'TEST',
      messageType: 'TEXT',
      scope,
    });
  },

  async getWhatsappLogs(limit = 50, scope: string = 'NB_DEVELOPER') {
    return whatsappService.getLogs(limit, scope);
  },

  async sendLeadWhatsapp(
    leadId: string,
    payload: {
      phone?: string;
      event?: string;
      message?: string;
      mediaUrl?: string;
      headerMediaUrl?: string;
      headerText?: string;
      messageType?: any;
      templateId?: string;
      templateName?: string;
      templateEndpoint?: string;
      variables?: Record<string, string>;
    },
  ) {
    const lead: any = await prisma.crmLead.findUnique({
      where: { id: leadId },
      include: {
        campaign: { select: { project: { select: { name: true } } } },
        assignedTo: { include: { generalInfo: { select: { fullName: true } } } },
      },
    });
    if (!lead) throw new Error('Lead not found');

    const leadScope = lead.scope || 'NB_DEVELOPER';

    if (payload.event) {
      await whatsappService.triggerEvent(payload.event, lead, {
        projectName: lead.campaign?.project?.name || (leadScope === 'NB_FINSERVE' ? 'NB Finserve' : 'Legacy Tower'),
        agentName: lead.assignedTo?.generalInfo?.fullName,
        scope: leadScope,
      });
      return { success: true, message: `Triggered ${payload.event} for lead` };
    }

    if (!payload.message && !payload.templateId) throw new Error('Message content or Template ID is required');

    // Resolve target recipient phone (from payload, variables, or lead record)
    const recipientPhone =
      (payload.phone && String(payload.phone).trim()) ||
      (payload.variables?.phone && String(payload.variables.phone).trim()) ||
      (payload.variables?.number && String(payload.variables.number).trim()) ||
      lead.phone;

    // Resolve dynamic lead variables for BotBiz template (name, phone, date, time, calendar_link, etc.)
    const config = await whatsappService.getRawConfig(leadScope);
    const now = new Date();
    const formattedDate = `${String(now.getDate()).padStart(2, '0')}/${String(now.getMonth() + 1).padStart(2, '0')}/${now.getFullYear()}`;
    const formattedTime = now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });
    const leadName = lead.name || (lead.customFields as any)?.client_name || (lead.customFields as any)?.Client_Name || (lead.customFields as any)?.name || 'Valued Client';
    const calendarLink = config.defaultCalendarLink || '';
    const projectName = lead.campaign?.project?.name || (leadScope === 'NB_FINSERVE' ? 'NB Finserve' : 'Legacy Tower');
    const agentName = lead.assignedTo?.generalInfo?.fullName || 'Property Advisor';

    const mergedVariables: Record<string, string> = {
      name: leadName,
      customerName: leadName,
      client_name: leadName,
      phone: recipientPhone,
      number: recipientPhone,
      date: formattedDate,
      time: formattedTime,
      calendar_link: calendarLink,
      calendarLink: calendarLink,
      link: calendarLink,
      project: projectName,
      projectName,
      pname: projectName,
      advisor: agentName,
      salespersonName: agentName,
      ...(payload.variables || {}),
    };

    return whatsappService.sendDirect({
      phone: recipientPhone,
      message: payload.message || '',
      mediaUrl: payload.mediaUrl,
      headerMediaUrl: payload.headerMediaUrl || payload.mediaUrl,
      headerText: payload.headerText,
      event: 'MANUAL_DISPATCH',
      leadId: lead.id,
      messageType: payload.templateId ? 'TEMPLATE' : (payload.messageType || 'TEXT'),
      templateId: payload.templateId,
      templateName: payload.templateName,
      templateEndpoint: payload.templateEndpoint,
      variables: mergedVariables,
      scope: leadScope,
    });
  },

  async uploadBrochure(
    file: { buffer: Buffer; originalname?: string; mimetype?: string },
    updatedBy?: string,
  ) {
    try {
      const dir = path.join(process.cwd(), 'uploads', 'crm', 'brochures');
      fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(path.join(dir, 'legacy-tower.pdf'), file.buffer);
    } catch (_) {}

    let url = 'https://crm.nbdeveloper.co.in/api/crm-public/brochures/legacy-tower.pdf';
    try {
      const cloudUrl = await uploadService.uploadToCloudinary(file, 'crm/brochures');
      if (cloudUrl) url = cloudUrl;
    } catch (_) {}

    await prisma.crmSetting.upsert({
      where: { key: 'whatsapp_default_brochure_url' },
      update: { value: url, updatedBy },
      create: {
        key: 'whatsapp_default_brochure_url',
        value: url,
        description: 'Uploaded Legacy Tower Brochure PDF URL',
        updatedBy,
      },
    });
    const filename = file.originalname || 'Legacy_Tower_Brochure.pdf';
    await prisma.crmSetting.upsert({
      where: { key: 'whatsapp_default_brochure_name' },
      update: { value: filename, updatedBy },
      create: {
        key: 'whatsapp_default_brochure_name',
        value: filename,
        description: 'Uploaded Legacy Tower Brochure Filename',
        updatedBy,
      },
    });
    return {
      url,
      filename,
      message: 'Brochure PDF uploaded and stored permanently',
    };
  },

  async getVirtualBuilding(projectId: string, towerId: string, scope = 'NB_DEVELOPER') {
    const project = await prisma.erpProject.findUnique({
      where: { id: projectId },
      select: { id: true, name: true, projectNo: true, address: true },
    });
    if (!project) throw new Error('Project not found');

    const tower = await prisma.erpProjectTower.findFirst({
      where: { id: towerId, projectId },
      include: {
        units: {
          orderBy: [
            { floorNo: 'desc' },
            { sortOrder: 'asc' },
            { unitNo: 'asc' },
          ],
        },
      },
    });
    if (!tower) throw new Error('Tower not found');

    // Fetch active CRM leads in current scope
    const leads = await prisma.crmLead.findMany({
      where: {
        isDeleted: false,
        scope,
      },
      select: {
        id: true,
        name: true,
        phone: true,
        status: true,
        scheduledVisitAt: true,
        visitedAt: true,
        customFields: true,
        createdAt: true,
        assignedTo: {
          select: {
            id: true,
            generalInfo: {
              select: { fullName: true },
            },
          },
        },
      },
    });

    interface VisitorItem {
      leadId: string;
      leadName: string;
      leadPhone: string;
      status: string;
      visitDate: string;
      salesAgent: string;
      remarks?: string;
    }

    const enrichedUnits = tower.units.map((unit) => {
      const visitors: VisitorItem[] = [];
      let heldBy: {
        leadId?: string;
        name: string;
        phone: string;
        heldAt?: string;
        expiryAt?: string;
        salesAgent?: string;
        notes?: string;
      } | null = null;

      let bookedBy: {
        leadId?: string;
        name: string;
        phone: string;
        bookedAt?: string;
        agreementValue?: number | null;
        notes?: string;
      } | null = null;

      const unitNoUpper = unit.unitNo.toUpperCase().trim();

      for (const lead of leads) {
        const cf = (lead.customFields || {}) as Record<string, any>;
        const unitShown = cf.unitShown as Record<string, any> | undefined;
        let isMatch = false;
        let visitRemark = '';

        if (unitShown) {
          const shownUnitNo = (unitShown.unitNo || '').toString().toUpperCase().trim();
          const shownUnitId = (unitShown.unitId || '').toString();
          if (shownUnitId === unit.id || shownUnitNo === unitNoUpper) {
            isMatch = true;
            visitRemark = unitShown.remarks || '';
          }
        }

        // Also check activityLogs
        if (!isMatch && Array.isArray(cf.activityLogs)) {
          for (const log of cf.activityLogs) {
            if (log && typeof log === 'object') {
              const desc = (log.description || log.title || '').toString().toUpperCase();
              if (desc.includes(unitNoUpper) || (log.unitNo && log.unitNo.toString().toUpperCase() === unitNoUpper)) {
                isMatch = true;
                visitRemark = log.description || '';
                break;
              }
            }
          }
        }

        // Also check proposals
        if (!isMatch && Array.isArray(cf.proposals)) {
          for (const prop of cf.proposals) {
            if (prop && (prop.unitNo || '').toString().toUpperCase().trim() === unitNoUpper) {
              isMatch = true;
              break;
            }
          }
        }

        if (isMatch) {
          const vDate = lead.visitedAt
            ? lead.visitedAt.toISOString()
            : (unitShown?.shownAt ? new Date(unitShown.shownAt).toISOString() : lead.createdAt.toISOString());

          const agentName = lead.assignedTo?.generalInfo?.fullName || unitShown?.shownByName || 'Sales Rep';

          visitors.push({
            leadId: lead.id,
            leadName: lead.name || 'Prospect',
            leadPhone: lead.phone,
            status: lead.status,
            visitDate: vDate,
            salesAgent: agentName,
            remarks: visitRemark,
          });

          // Check if booked
          if (lead.status === 'BOOKING_CONFIRMED' || cf.bookingConfirmedUnit === unit.unitNo) {
            bookedBy = {
              leadId: lead.id,
              name: lead.name || 'Confirmed Buyer',
              phone: lead.phone,
              bookedAt: lead.visitedAt?.toISOString() || lead.createdAt.toISOString(),
              agreementValue: unit.totalValue ? Number(unit.totalValue) : null,
              notes: `Booking confirmed for ${lead.name || lead.phone}`,
            };
          }

          // Check if held
          if (cf.unitHold && cf.unitHold.unitNo === unit.unitNo) {
            heldBy = {
              leadId: lead.id,
              name: lead.name || 'Prospect',
              phone: lead.phone,
              heldAt: cf.unitHold.heldAt || lead.createdAt.toISOString(),
              expiryAt: cf.unitHold.expiryAt,
              salesAgent: agentName,
              notes: cf.unitHold.notes,
            };
          }
        }
      }

      // Check ERP unit status fallback if not bound to a lead
      if (unit.statusCode === 'HOLD' && !heldBy) {
        heldBy = {
          name: unit.remarks ? unit.remarks.replace(/^HOLD:?\s*/i, '') : 'On Hold',
          phone: '',
          notes: unit.remarks || 'Reserved unit',
        };
      }

      if ((unit.statusCode === 'BOOKED' || unit.statusCode === 'SOLD') && !bookedBy) {
        bookedBy = {
          name: unit.remarks ? unit.remarks.replace(/^(BOOKED|SOLD):?\s*/i, '') : 'Booked',
          phone: '',
          agreementValue: unit.totalValue ? Number(unit.totalValue) : null,
          notes: unit.remarks || 'Booked unit',
        };
      }

      // Effective status
      let effectiveStatus = unit.statusCode;
      if (bookedBy) effectiveStatus = 'BOOKED';
      else if (heldBy && unit.statusCode !== 'BOOKED' && unit.statusCode !== 'SOLD') effectiveStatus = 'HOLD';

      return {
        id: unit.id,
        unitNo: unit.unitNo,
        floorNo: unit.floorNo,
        unitTypeCode: unit.unitTypeCode || 'Flat',
        statusCode: effectiveStatus,
        carpetArea: unit.carpetArea ? Number(unit.carpetArea) : null,
        superBuiltUp: unit.superBuiltUp ? Number(unit.superBuiltUp) : null,
        baseRate: unit.baseRate ? Number(unit.baseRate) : null,
        totalValue: unit.totalValue ? Number(unit.totalValue) : (unit.totalUnitValue ? Number(unit.totalUnitValue) : null),
        grandTotal: unit.grandTotal ? Number(unit.grandTotal) : null,
        isDuplex: unit.isDuplex,
        facingCode: unit.facingCode,
        remarks: unit.remarks,
        sortOrder: unit.sortOrder,
        visitorCount: visitors.length,
        visitors,
        heldBy,
        bookedBy,
      };
    });

    // Group units by floor
    const floorMap = new Map<number, typeof enrichedUnits>();
    for (const u of enrichedUnits) {
      if (!floorMap.has(u.floorNo)) {
        floorMap.set(u.floorNo, []);
      }
      floorMap.get(u.floorNo)!.push(u);
    }

    const sortedFloorNumbers = Array.from(floorMap.keys()).sort((a, b) => b - a);

    const floors = sortedFloorNumbers.map((floorNo) => {
      let floorLabel = `Floor ${floorNo}`;
      if (floorNo === 0) floorLabel = 'Ground Floor (GF)';
      else if (floorNo < 0) floorLabel = `Basement ${Math.abs(floorNo)} (B${Math.abs(floorNo)})`;

      const units = floorMap.get(floorNo) || [];
      units.sort((a, b) => a.sortOrder - b.sortOrder || a.unitNo.localeCompare(b.unitNo));

      return {
        floorNo,
        floorLabel,
        units,
      };
    });

    const totalUnits = enrichedUnits.length;
    const availableCount = enrichedUnits.filter((u) => u.statusCode === 'AVAILABLE').length;
    const holdCount = enrichedUnits.filter((u) => u.statusCode === 'HOLD').length;
    const bookedCount = enrichedUnits.filter((u) => u.statusCode === 'BOOKED' || u.statusCode === 'SOLD').length;
    const duplexCount = enrichedUnits.filter((u) => u.isDuplex).length;
    const totalVisits = enrichedUnits.reduce((sum, u) => sum + u.visitorCount, 0);

    return {
      project,
      tower: {
        id: tower.id,
        name: tower.name,
        phase: tower.phase,
        floorCount: tower.floorCount,
        flatsPerFloor: tower.flatsPerFloor,
        hasGround: tower.hasGround,
        basementCount: tower.basementCount,
      },
      summary: {
        totalUnits,
        availableCount,
        holdCount,
        bookedCount,
        duplexCount,
        totalVisits,
      },
      floors,
    };
  },

  async updateVirtualBuildingUnit(payload: {
    unitId: string;
    statusCode: string;
    leadId?: string;
    heldByName?: string;
    heldByPhone?: string;
    holdExpiryDate?: string;
    ownerName?: string;
    ownerPhone?: string;
    remarks?: string;
    updatedBy?: string;
  }) {
    const unit = await prisma.erpProjectUnit.findUnique({
      where: { id: payload.unitId },
      include: { tower: { include: { project: true } } },
    });
    if (!unit) throw new Error('Unit not found');

    let newRemarks = payload.remarks || unit.remarks || '';
    if (payload.statusCode === 'HOLD') {
      newRemarks = `HOLD: ${payload.heldByName || 'Reserved'} (${payload.heldByPhone || ''}) ${payload.holdExpiryDate ? `until ${payload.holdExpiryDate}` : ''}. ${payload.remarks || ''}`.trim();
    } else if (payload.statusCode === 'BOOKED' || payload.statusCode === 'SOLD') {
      newRemarks = `BOOKED: ${payload.ownerName || 'Owner'} (${payload.ownerPhone || ''}). ${payload.remarks || ''}`.trim();
    } else if (payload.statusCode === 'AVAILABLE') {
      newRemarks = payload.remarks || '';
    }

    const updatedUnit = await prisma.erpProjectUnit.update({
      where: { id: payload.unitId },
      data: {
        statusCode: payload.statusCode,
        remarks: newRemarks,
      },
    });

    // If unit is part of a duplex, also sync the counterpart unit (upper or lower level)
    if (unit.isDuplex) {
      const counterpartUnitNo = unit.unitNo.endsWith('-2')
        ? unit.unitNo.slice(0, -2)
        : `${unit.unitNo}-2`;

      await prisma.erpProjectUnit.updateMany({
        where: {
          towerId: unit.towerId,
          unitNo: counterpartUnitNo,
        },
        data: {
          statusCode: payload.statusCode,
          remarks: newRemarks,
        },
      });
    }

    if (payload.leadId) {
      const lead = await prisma.crmLead.findUnique({ where: { id: payload.leadId } });
      if (lead) {
        const cf = (lead.customFields || {}) as Record<string, any>;
        const activityLogs = Array.isArray(cf.activityLogs) ? [...cf.activityLogs] : [];

        let newLeadStatus = lead.status;
        if (payload.statusCode === 'BOOKED' || payload.statusCode === 'SOLD') {
          newLeadStatus = 'BOOKING_CONFIRMED' as any;
          cf.bookingConfirmedUnit = unit.unitNo;
          activityLogs.unshift({
            id: `LOG-${Date.now()}`,
            title: `Unit ${unit.unitNo} Booking Confirmed`,
            description: `Unit ${unit.unitNo} in ${unit.tower.name} booked. ${payload.remarks || ''}`,
            type: 'UNIT_BOOKED',
            timestamp: new Date().toISOString(),
            performedByName: payload.updatedBy || 'Sales Manager',
          });
        } else if (payload.statusCode === 'HOLD') {
          cf.unitHold = {
            unitNo: unit.unitNo,
            unitId: unit.id,
            towerName: unit.tower.name,
            heldAt: new Date().toISOString(),
            expiryAt: payload.holdExpiryDate,
            notes: payload.remarks,
          };
          activityLogs.unshift({
            id: `LOG-${Date.now()}`,
            title: `Unit ${unit.unitNo} Placed On Hold`,
            description: `Unit ${unit.unitNo} in ${unit.tower.name} placed on hold. Expiry: ${payload.holdExpiryDate || 'N/A'}. ${payload.remarks || ''}`,
            type: 'UNIT_HOLD',
            timestamp: new Date().toISOString(),
            performedByName: payload.updatedBy || 'Sales Manager',
          });
        }

        cf.activityLogs = activityLogs;

        await prisma.crmLead.update({
          where: { id: payload.leadId },
          data: {
            status: newLeadStatus,
            customFields: cf,
          },
        });
      }
    }

    return updatedUnit;
  },

  // ---------------------------------------------------------------------------
  // Finserve Application Form, Details & Client Portal
  // ---------------------------------------------------------------------------
  async updateLeadApplicationDetails(
    leadId: string,
    dto: UpdateLeadApplicationDetailsDto,
    _updatedById?: string,
  ) {
    const lead = await prisma.crmLead.findUnique({ where: { id: leadId } });
    if (!lead) throw new Error('Lead not found');

    const currentCustom = (lead.customFields as any) || {};
    const updatedCustom = {
      ...currentCustom,
      ...(dto.loanType && { loanType: dto.loanType }),
      applicationDetails: {
        ...(currentCustom.applicationDetails || {}),
        ...(dto.applicationDetails || {}),
        ...(dto.loanType && { loanType: dto.loanType }),
      },
    };

    if (dto.applicationDetails?.personalEmail) {
      updatedCustom.email = dto.applicationDetails.personalEmail;
    }

    const updateData: any = {
      customFields: updatedCustom,
      updatedAt: new Date(),
    };

    if (dto.status) {
      updateData.status = dto.status;
    }

    const updated = await prisma.crmLead.update({
      where: { id: leadId },
      data: updateData,
      include: {
        assignedTo: {
          include: { generalInfo: { select: { fullName: true } } },
        },
        telecaller: {
          include: { generalInfo: { select: { fullName: true } } },
        },
      },
    });

    return updated;
  },

  async updateFinservePipeline(
    leadId: string,
    dto: UpdateFinservePipelineDto,
    updatedByName?: string,
  ) {
    const lead = await prisma.crmLead.findUnique({ where: { id: leadId } });
    if (!lead) throw new Error('Lead not found');

    const currentCustom = (lead.customFields as any) || {};
    const updatedCustom: any = {
      ...currentCustom,
    };

    if (dto.forwardedForProcessing) {
      updatedCustom.forwardedForProcessing = {
        ...(currentCustom.forwardedForProcessing || {}),
        ...dto.forwardedForProcessing,
        forwardedAt: dto.forwardedForProcessing.forwardedAt || new Date().toISOString(),
        forwardedBy: updatedByName || dto.forwardedForProcessing.forwardedBy || 'System',
      };
    }

    if (dto.bankApplications) {
      updatedCustom.bankApplications = dto.bankApplications;
    }

    if (dto.finalBank) {
      updatedCustom.finalBank = {
        ...(currentCustom.finalBank || {}),
        ...dto.finalBank,
        finalizedAt: dto.finalBank.finalizedAt || new Date().toISOString(),
        finalizedBy: updatedByName || dto.finalBank.finalizedBy || 'System',
      };
    }

    if (dto.disbursementDetails) {
      updatedCustom.disbursementDetails = {
        ...(currentCustom.disbursementDetails || {}),
        ...dto.disbursementDetails,
      };
    }

    if (dto.loanStage) {
      updatedCustom.loanStage = dto.loanStage;
    }

    const updateData: any = {
      customFields: updatedCustom,
      updatedAt: new Date(),
    };

    if (dto.forwardedForProcessing?.forwardedToId) {
      updateData.assignedToId = Number(dto.forwardedForProcessing.forwardedToId);
    }

    if (dto.status) {
      updateData.status = dto.status;
    }

    const updated = await prisma.crmLead.update({
      where: { id: leadId },
      data: updateData,
      include: {
        assignedTo: {
          include: { generalInfo: { select: { fullName: true } } },
        },
        telecaller: {
          include: { generalInfo: { select: { fullName: true } } },
        },
      },
    });

    return updated;
  },

  async addBankQuery(
    leadId: string,
    dto: { query: string; required: string; stage?: string },
    raisedByName?: string,
  ) {
    const lead = await prisma.crmLead.findUnique({ where: { id: leadId } });
    if (!lead) throw new Error('Lead not found');
    if (!dto.query || !dto.required) {
      throw new Error('Query and Required details are mandatory');
    }

    const currentCustom = (lead.customFields as any) || {};
    const queries: BankQueryItem[] = Array.isArray(currentCustom.bankQueries)
      ? [...currentCustom.bankQueries]
      : [];

    const newQuery: BankQueryItem = {
      id: `query_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      query: dto.query.trim(),
      required: dto.required.trim(),
      stage: dto.stage || 'General',
      status: 'OPEN',
      raisedAt: new Date().toISOString(),
      raisedBy: raisedByName || 'Staff',
    };

    queries.unshift(newQuery);

    const updatedCustom = {
      ...currentCustom,
      bankQueries: queries,
    };

    const updated = await prisma.crmLead.update({
      where: { id: leadId },
      data: {
        customFields: updatedCustom,
        updatedAt: new Date(),
      },
      include: {
        assignedTo: {
          include: { generalInfo: { select: { fullName: true } } },
        },
        telecaller: {
          include: { generalInfo: { select: { fullName: true } } },
        },
      },
    });

    return { updatedLead: updated, query: newQuery };
  },

  async resolveBankQuery(
    leadId: string,
    queryId: string,
    dto: { resolutionNotes?: string },
    resolvedByName?: string,
  ) {
    const lead = await prisma.crmLead.findUnique({ where: { id: leadId } });
    if (!lead) throw new Error('Lead not found');

    const currentCustom = (lead.customFields as any) || {};
    const queries: BankQueryItem[] = Array.isArray(currentCustom.bankQueries)
      ? [...currentCustom.bankQueries]
      : [];

    const idx = queries.findIndex((q) => q.id === queryId);
    if (idx === -1) throw new Error('Query not found');

    queries[idx] = {
      ...queries[idx],
      status: 'RESOLVED',
      resolvedAt: new Date().toISOString(),
      resolvedBy: resolvedByName || 'Staff',
      resolutionNotes: dto.resolutionNotes?.trim() || '',
    };

    const updatedCustom = {
      ...currentCustom,
      bankQueries: queries,
    };

    const updated = await prisma.crmLead.update({
      where: { id: leadId },
      data: {
        customFields: updatedCustom,
        updatedAt: new Date(),
      },
      include: {
        assignedTo: {
          include: { generalInfo: { select: { fullName: true } } },
        },
        telecaller: {
          include: { generalInfo: { select: { fullName: true } } },
        },
      },
    });

    return { updatedLead: updated, query: queries[idx] };
  },

  async generateClientPortalLink(leadId: string, baseUrl?: string) {
    const lead = await prisma.crmLead.findUnique({ where: { id: leadId } });
    if (!lead) throw new Error('Lead not found');

    const custom = (lead.customFields as any) || {};
    let token = custom.portalToken;
    if (!token) {
      token = crypto.randomBytes(16).toString('hex');
      custom.portalToken = token;
    }

    const port = process.env.PORT || '4000';
    const base = (baseUrl || `http://localhost:${port}`).replace(/\/+$/, '');
    const link = `${base}/client-portal?token=${token}`;
    custom.portalLink = link;

    const updatedLead = await prisma.crmLead.update({
      where: { id: leadId },
      data: { customFields: custom },
    });

    return {
      token,
      link,
      portalUrl: link,
      leadId: lead.id,
      leadName: lead.name,
      phone: lead.phone,
      lead: updatedLead,
    };
  },

  async getClientPortalInfo(token: string) {
    if (!token) throw new Error('Portal token is required');
    const leads = await prisma.crmLead.findMany({
      where: { isDeleted: false },
    });
    const lead = leads.find((l) => (l.customFields as any)?.portalToken === token);
    if (!lead) throw new Error('Invalid or expired application link');

    const custom = (lead.customFields as any) || {};
    const appDetails = custom.applicationDetails || {};
    const candidatePhones = [
      appDetails.mobileNo,
      lead.phone,
      custom.Phone,
      custom.phone,
      custom.mobile,
      appDetails.alternateNo,
      custom.alternateNo,
    ]
      .filter(Boolean)
      .map((p) => String(p).replace(/\D/g, '').slice(-10))
      .filter((p) => p.length >= 4);

    const primaryPhone = candidatePhones[0] || '';
    const maskedPhone = primaryPhone.length >= 10
      ? `+91 ******${primaryPhone.slice(-4)}`
      : (primaryPhone ? `******${primaryPhone.slice(-4)}` : 'Registered Mobile Number');

    return {
      valid: true,
      leadName: lead.name || custom.Client_Name || 'Valued Client',
      maskedPhone,
      phoneHint: primaryPhone.length >= 4 ? primaryPhone.slice(-4) : '',
      loanType: custom.Loan_Type || custom.loanType || appDetails.loanType || 'Personal Loan',
    };
  },

  async sendClientPortalOtp(token: string, mobile: string) {
    if (!token || !mobile) throw new Error('Token and registered mobile number are required');
    const leads = await prisma.crmLead.findMany({
      where: { isDeleted: false },
    });
    const lead = leads.find((l) => (l.customFields as any)?.portalToken === token);
    if (!lead) throw new Error('Invalid or expired application link');

    const cleanInput = mobile.replace(/\D/g, '').slice(-10);
    const custom = (lead.customFields as any) || {};
    const appDetails = custom.applicationDetails || {};
    
    // Support all lead phone sources: application details, lead record, and custom fields
    const validPhones = [
      appDetails.mobileNo,
      lead.phone,
      custom.Phone,
      custom.phone,
      custom.mobile,
      appDetails.alternateNo,
      custom.alternateNo,
    ]
      .filter(Boolean)
      .map((p) => String(p).replace(/\D/g, '').slice(-10))
      .filter((p) => p.length === 10);

    const isMatch = validPhones.length === 0 || validPhones.includes(cleanInput);
    if (!isMatch) {
      const hint = validPhones[0] ? `ending in ****${validPhones[0].slice(-4)}` : 'registered with application';
      throw new Error(`Entered mobile does not match registered number (${hint})`);
    }

    const email =
      appDetails.personalEmail ||
      appDetails.officialEmail ||
      custom.email ||
      custom.Email ||
      (lead as any).email ||
      '';

    // Rate Limiting: 30s cooldown between sends, max 3 attempts per 1-hour window, otherwise 1-hour lockout.
    const now = Date.now();
    const rateLimit = custom.portalOtpRateLimit || { attempts: 0, firstAttemptAt: 0, lastSentAt: 0, lockoutUntil: 0 };

    if (rateLimit.lockoutUntil && now < rateLimit.lockoutUntil) {
      const remainingMins = Math.ceil((rateLimit.lockoutUntil - now) / 60000);
      throw new Error(`Maximum verification attempts reached (3/3). For security, please try again after ${remainingMins} minute(s).`);
    }

    if (rateLimit.lockoutUntil && now >= rateLimit.lockoutUntil) {
      rateLimit.attempts = 0;
      rateLimit.firstAttemptAt = 0;
      rateLimit.lastSentAt = 0;
      rateLimit.lockoutUntil = 0;
    } else if (rateLimit.firstAttemptAt && (now - rateLimit.firstAttemptAt > 60 * 60 * 1000)) {
      rateLimit.attempts = 0;
      rateLimit.firstAttemptAt = 0;
      rateLimit.lastSentAt = 0;
      rateLimit.lockoutUntil = 0;
    }

    if (rateLimit.lastSentAt && (now - rateLimit.lastSentAt < 30 * 1000)) {
      const waitSecs = Math.ceil((30 * 1000 - (now - rateLimit.lastSentAt)) / 1000);
      throw new Error(`Please wait ${waitSecs}s before requesting a new verification code.`);
    }

    if (rateLimit.attempts >= 3) {
      rateLimit.lockoutUntil = now + 60 * 60 * 1000;
      custom.portalOtpRateLimit = rateLimit;
      await prisma.crmLead.update({
        where: { id: lead.id },
        data: { customFields: custom },
      });
      throw new Error('Maximum verification attempts reached (3/3). Please try again after 1 hour.');
    }

    rateLimit.attempts += 1;
    if (!rateLimit.firstAttemptAt) rateLimit.firstAttemptAt = now;
    rateLimit.lastSentAt = now;
    custom.portalOtpRateLimit = rateLimit;

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    custom.portalOtp = {
      code: otp,
      expiresAt: Date.now() + 10 * 60 * 1000,
      mobile: cleanInput,
    };

    await prisma.crmLead.update({
      where: { id: lead.id },
      data: { customFields: custom },
    });

    let emailSent = false;
    if (email) {
      try {
        await sendFinserveClientOtpEmail(email, lead.name || 'Valued Client', otp);
        emailSent = true;
      } catch (err: any) {
        console.error('[sendFinserveClientOtpEmail error]', err?.message || err);
      }
    }

    const parts = (email || 'client@registered.phone').split('@');
    const maskedEmail = email
      ? (parts[0].length > 2 ? `${parts[0].slice(0, 2)}***@${parts[1]}` : `*@${parts[1]}`)
      : `SMS / Registered Mobile (+91 ******${cleanInput.slice(-4)})`;

    const remainingAttempts = Math.max(0, 3 - rateLimit.attempts);
    return {
      success: true,
      maskedEmail,
      message: emailSent
        ? `Verification code sent to registered email (${maskedEmail})`
        : `Verification code sent to registered email (${maskedEmail})`,
      cooldownSeconds: 30,
      attemptsRemaining: remainingAttempts,
      lockoutUntil: rateLimit.attempts >= 3 ? rateLimit.lockoutUntil : null,
    };
  },

  async verifyClientPortalOtp(token: string, mobile: string, otp: string) {
    if (!token || !mobile || !otp) throw new Error('Token, mobile number, and OTP are required');
    const leads = await prisma.crmLead.findMany({
      where: { isDeleted: false },
    });
    const lead = leads.find((l) => (l.customFields as any)?.portalToken === token);
    if (!lead) throw new Error('Invalid or expired application link');

    const cleanInput = mobile.replace(/\D/g, '').slice(-10);
    const custom = (lead.customFields as any) || {};
    const portalOtp = custom.portalOtp;

    if (!portalOtp || portalOtp.code !== otp.trim()) {
      throw new Error('Invalid verification code entered');
    }
    if (Date.now() > portalOtp.expiresAt) {
      throw new Error('Verification code has expired. Please request a new code.');
    }

    const settings = await this.getSettings('NB_FINSERVE');
    const loanTypeDocsMap: Record<string, string[]> = JSON.parse(settings.loan_type_docs_map || '{}');
    const loanDocTypes: any[] = JSON.parse(settings.loan_doc_types || '[]');

    const rawAppDetails = custom.applicationDetails || {};
    const loanAmountVal =
      rawAppDetails.requiredLoanAmount ||
      custom.Amount ||
      custom.amount ||
      custom.loanAmount ||
      custom.Budget ||
      (lead as any).value ||
      '';

    const appDetails = {
      requiredLoanAmount: loanAmountVal ? String(loanAmountVal) : '',
      loanPurpose:
        rawAppDetails.loanPurpose ||
        custom.Loan_Type ||
        custom.loanType ||
        custom.purpose ||
        custom.Project_Type ||
        'Personal / Home Loan',
      personalEmail:
        rawAppDetails.personalEmail ||
        custom.Email ||
        custom.email ||
        (lead as any).email ||
        '',
      mobileNo:
        rawAppDetails.mobileNo ||
        lead.phone ||
        custom.Phone ||
        custom.phone ||
        custom.mobile ||
        '',
      alternateNo:
        rawAppDetails.alternateNo ||
        custom.alternateNo ||
        custom.Alternate_Phone ||
        '',
      currentAddress:
        rawAppDetails.currentAddress ||
        custom.Address ||
        custom.address ||
        custom.Location ||
        custom.location ||
        '',
      permanentAddress:
        rawAppDetails.permanentAddress ||
        custom.Address ||
        custom.address ||
        custom.Location ||
        custom.location ||
        '',
      companyName:
        rawAppDetails.companyName ||
        custom.Company ||
        custom.company ||
        custom.companyName ||
        '',
      companyAddress:
        rawAppDetails.companyAddress ||
        custom.Company_Address ||
        custom.companyAddress ||
        '',
      ...rawAppDetails,
    };
    if (!appDetails.requiredLoanAmount && loanAmountVal) {
      appDetails.requiredLoanAmount = String(loanAmountVal);
    }

    const loanType = custom.Loan_Type || custom.loanType || appDetails.loanType || 'Personal Loan';
    const requiredDocIds = loanTypeDocsMap[loanType] || loanTypeDocsMap['Personal Loan'] || loanTypeDocsMap['Home Loan'] || [];

    const uploadedDocs: any[] = custom.documents || [];

    const requiredDocsList = requiredDocIds.map((docId) => {
      const docDef = loanDocTypes.find((d) => d.id === docId) || {
        id: docId,
        name: docId.replace(/_/g, ' ').toUpperCase(),
        maxFileSizeMb: 10,
        allowedFormats: ['pdf', 'jpg', 'png'],
      };
      const uploaded = uploadedDocs.find((u) => u.docTypeId === docId);
      return {
        id: docDef.id,
        name: docDef.name,
        maxFileSizeMb: docDef.maxFileSizeMb || 10,
        allowedFormats: docDef.allowedFormats || ['pdf', 'jpg', 'jpeg', 'png'],
        isUploaded: !!uploaded,
        uploadedItem: uploaded || null,
      };
    });

    return {
      success: true,
      lead: {
        id: lead.id,
        name: lead.name,
        phone: lead.phone,
        loanType,
        applicationDetails: appDetails,
        requiredDocs: requiredDocsList,
        uploadedDocs,
        isSubmitted: !!custom.clientPortalSubmitted,
        submittedAt: custom.clientPortalSubmittedAt || null,
        clientPortalStatus: custom.clientPortalStatus || 'DRAFT',
      },
    };
  },

  async submitClientPortal(token: string) {
    if (!token) throw new Error('Application token is required');
    const leads = await prisma.crmLead.findMany({
      where: { isDeleted: false },
    });
    const lead = leads.find((l) => (l.customFields as any)?.portalToken === token);
    if (!lead) throw new Error('Invalid or expired application link');

    const custom = (lead.customFields as any) || {};
    if (custom.clientPortalSubmitted) {
      return {
        success: true,
        alreadySubmitted: true,
        message: 'Application has already been confirmed and submitted.',
        submittedAt: custom.clientPortalSubmittedAt,
      };
    }

    const documents = custom.documents || [];
    if (!documents.length) {
      throw new Error('Please upload at least one required loan document before submitting.');
    }

    const submittedAt = new Date().toISOString();
    custom.clientPortalSubmitted = true;
    custom.clientPortalStatus = 'SUBMITTED';
    custom.clientPortalSubmittedAt = submittedAt;
    custom.clientPortalConfirmed = true;

    await prisma.crmLead.update({
      where: { id: lead.id },
      data: { customFields: custom },
    });

    return {
      success: true,
      message: 'Application confirmed and locked successfully. Your loan advisor can now review your file.',
      submittedAt,
    };
  },

  async uploadClientPortalDoc(token: string, docTypeId: string, docName: string, file: { originalname: string; buffer: Buffer; size: number; mimetype: string }) {
    if (!token || !docTypeId || !file) throw new Error('Token, document type, and file are required');
    const leads = await prisma.crmLead.findMany({
      where: { isDeleted: false },
    });
    const lead = leads.find((l) => (l.customFields as any)?.portalToken === token);
    if (!lead) throw new Error('Invalid or expired application link');

    const custom = (lead.customFields as any) || {};
    // Allow updating or replacing documents so applicants and staff can update their file

    // Verify file size & format against doc definition from settings
    const settings = await this.getSettings('NB_FINSERVE');
    const loanDocTypes: any[] = JSON.parse(settings.loan_doc_types || '[]');
    const docDef = loanDocTypes.find((d) => d.id === docTypeId);

    const maxMb = Number(docDef?.maxFileSizeMb) || 10;
    const maxBytes = maxMb * 1024 * 1024;
    if (file.size > maxBytes) {
      throw new Error(`File size (${(file.size / (1024 * 1024)).toFixed(1)}MB) exceeds the maximum allowed limit of ${maxMb}MB for this document.`);
    }

    const ext = path.extname(file.originalname) || '.pdf';
    const cleanExt = ext.replace('.', '').toLowerCase();
    const allowed = (docDef?.allowedFormats || ['pdf', 'jpg', 'jpeg', 'png']).map((f: string) => f.toLowerCase().replace('.', ''));
    if (!allowed.includes(cleanExt)) {
      throw new Error(`File format .${cleanExt} is not permitted. Allowed formats: ${allowed.join(', ').toUpperCase()}`);
    }

    let fileUrl = '';
    const safeName = `${lead.id}_${docTypeId}_${Date.now()}${ext}`;
    try {
      const uploadsDir = path.join(process.cwd(), 'uploads', 'crm', 'client-docs');
      fs.mkdirSync(uploadsDir, { recursive: true });
      fs.writeFileSync(path.join(uploadsDir, safeName), file.buffer);
      fileUrl = `/uploads/crm/client-docs/${safeName}`;
    } catch (_) {}

    try {
      const cloudUrl = await uploadService.uploadToCloudinary(file, 'crm/client-docs');
      if (cloudUrl) fileUrl = cloudUrl;
    } catch (e) {
      console.warn('[uploadClientPortalDoc] Cloudinary upload fallback to local storage:', e);
      if (!fileUrl) {
        const uploadsDir = path.join(process.cwd(), 'uploads', 'crm', 'client-docs');
        fs.mkdirSync(uploadsDir, { recursive: true });
        fs.writeFileSync(path.join(uploadsDir, safeName), file.buffer);
        fileUrl = `/uploads/crm/client-docs/${safeName}`;
      }
    }

    const documents: any[] = custom.documents || [];

    const existingIndex = documents.findIndex((d) => d.docTypeId === docTypeId);
    const newDocItem = {
      id: `doc_${Date.now()}`,
      docTypeId,
      docName: docName || docTypeId.replace(/_/g, ' ').toUpperCase(),
      fileName: file.originalname,
      fileUrl,
      fileSize: file.size,
      uploadedAt: new Date().toISOString(),
      uploadedBy: 'CLIENT',
      status: 'VERIFIED',
    };

    if (existingIndex >= 0) {
      documents[existingIndex] = newDocItem;
    } else {
      documents.push(newDocItem);
    }

    custom.documents = documents;

    await prisma.crmLead.update({
      where: { id: lead.id },
      data: { customFields: custom },
    });

    return {
      success: true,
      document: newDocItem,
      uploadedDocs: documents,
    };
  },

  async uploadLeadDoc(leadId: string, docTypeId: string, docName: string, file: { originalname: string; buffer: Buffer; size: number; mimetype: string }, uploadedBy?: string) {
    const lead = await prisma.crmLead.findUnique({ where: { id: leadId } });
    if (!lead) throw new Error('Lead not found');

    const ext = path.extname(file.originalname) || '.pdf';
    const safeName = `${lead.id}_${docTypeId}_${Date.now()}${ext}`;
    let fileUrl = '';
    try {
      const uploadsDir = path.join(process.cwd(), 'uploads', 'crm', 'client-docs');
      fs.mkdirSync(uploadsDir, { recursive: true });
      fs.writeFileSync(path.join(uploadsDir, safeName), file.buffer);
      fileUrl = `/uploads/crm/client-docs/${safeName}`;
    } catch (_) {}

    try {
      const cloudUrl = await uploadService.uploadToCloudinary(file, 'crm/client-docs');
      if (cloudUrl) fileUrl = cloudUrl;
    } catch (e) {
      console.warn('[uploadLeadDoc] Cloudinary upload fallback to local storage:', e);
      if (!fileUrl) {
        const uploadsDir = path.join(process.cwd(), 'uploads', 'crm', 'client-docs');
        fs.mkdirSync(uploadsDir, { recursive: true });
        fs.writeFileSync(path.join(uploadsDir, safeName), file.buffer);
        fileUrl = `/uploads/crm/client-docs/${safeName}`;
      }
    }

    const custom = (lead.customFields as any) || {};
    const documents: any[] = custom.documents || [];

    const existingIndex = documents.findIndex((d) => d.docTypeId === docTypeId);
    const newDocItem = {
      id: `doc_${Date.now()}`,
      docTypeId,
      docName: docName || docTypeId.replace(/_/g, ' ').toUpperCase(),
      fileName: file.originalname,
      fileUrl,
      fileSize: file.size,
      uploadedAt: new Date().toISOString(),
      uploadedBy: uploadedBy || 'SALES_REP',
      status: 'VERIFIED',
    };

    if (existingIndex >= 0) {
      documents[existingIndex] = newDocItem;
    } else {
      documents.push(newDocItem);
    }

    custom.documents = documents;

    await prisma.crmLead.update({
      where: { id: lead.id },
      data: { customFields: custom },
    });

    return {
      success: true,
      document: newDocItem,
      uploadedDocs: documents,
    };
  },

  async downloadLeadDocsZip(leadIdOrToken: string, res: Response, isToken: boolean = false) {
    let lead: any = null;
    if (isToken) {
      const leads = await prisma.crmLead.findMany({ where: { isDeleted: false } });
      lead = leads.find((l) => (l.customFields as any)?.portalToken === leadIdOrToken);
    } else {
      lead = await prisma.crmLead.findUnique({ where: { id: leadIdOrToken } });
      if (!lead) {
        // Fallback: search by portalToken
        const leads = await prisma.crmLead.findMany({ where: { isDeleted: false } });
        lead = leads.find((l) => (l.customFields as any)?.portalToken === leadIdOrToken);
      }
    }

    if (!lead) {
      res.status(404).send('Lead or client application not found');
      return;
    }

    const custom = (lead.customFields as any) || {};
    const documents: any[] = custom.documents || [];

    if (!documents || documents.length === 0) {
      res.status(400).send('No documents have been uploaded for this client application.');
      return;
    }

    const archive = initZipArchive({ zlib: { level: 9 } });

    const safeClientName = (lead.name || 'Client')
      .replace(/[^a-zA-Z0-9_\- ]/g, '')
      .trim()
      .replace(/\s+/g, '_');
    const zipFilename = `${safeClientName}_Application_Documents.zip`;

    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Disposition', `attachment; filename="${zipFilename}"; filename*=UTF-8''${encodeURIComponent(zipFilename)}`);

    archive.on('error', (err: any) => {
      console.error('[DownloadDocsZip Error]:', err);
      if (!res.headersSent) {
        res.status(500).send('Error generating zip archive');
      }
    });

    archive.pipe(res);

    let addedCount = 0;
    for (const doc of documents) {
      if (!doc.fileUrl) continue;

      const ext = path.extname(doc.fileName || doc.fileUrl) || '.pdf';
      const docLabel = (doc.docName || doc.docTypeId || 'Document')
        .replace(/[^a-zA-Z0-9_\- ]/g, '')
        .trim()
        .replace(/\s+/g, '_');
      const originalBase = path.basename(doc.fileName || doc.fileUrl, ext).replace(/[^a-zA-Z0-9_\- ]/g, '_');
      const entryName = `${docLabel}_${originalBase}${ext}`;

      let fileBuffer: Buffer | null = null;

      // 1. Fetch remote HTTP/HTTPS URL (e.g. Cloudinary, MinIO, CDN)
      if (doc.fileUrl.startsWith('http://') || doc.fileUrl.startsWith('https://')) {
        try {
          const fetched = await uploadService.fetchDocumentBytes(doc.fileUrl);
          if (fetched?.buffer && fetched.buffer.length > 0) {
            fileBuffer = fetched.buffer;
          }
        } catch {
          try {
            const resp = await fetch(doc.fileUrl);
            if (resp.ok) {
              const ab = await resp.arrayBuffer();
              if (ab.byteLength > 0) fileBuffer = Buffer.from(ab);
            }
          } catch (_) {}
        }
      } else {
        // 2. Fetch from local filesystem
        const relativePath = doc.fileUrl.startsWith('/') ? doc.fileUrl.slice(1) : doc.fileUrl;
        const candidates = [
          path.join(process.cwd(), relativePath),
          path.join(process.cwd(), 'backend', relativePath),
          path.join(__dirname, '../../../../', relativePath),
          path.join(__dirname, '../../../', relativePath),
          path.join('/app', relativePath),
          path.join('/app/uploads', path.basename(relativePath)),
          path.join(process.cwd(), 'uploads', 'crm', 'client-docs', path.basename(relativePath)),
          path.join(process.cwd(), 'backend', 'uploads', 'crm', 'client-docs', path.basename(relativePath)),
        ];

        for (const cand of candidates) {
          if (fs.existsSync(cand)) {
            try {
              fileBuffer = fs.readFileSync(cand);
              break;
            } catch (_) {}
          }
        }

        // 3. Fallback: fetch from live domain if local container disk missed it
        if (!fileBuffer) {
          const remoteCandidates = [
            `https://crm.nbdeveloper.co.in${doc.fileUrl}`,
            `https://crm.nbdeveloper.co.in/api${doc.fileUrl}`,
          ];
          for (const remoteUrl of remoteCandidates) {
            try {
              const resp = await fetch(remoteUrl);
              if (resp.ok) {
                const ab = await resp.arrayBuffer();
                if (ab.byteLength > 0) {
                  fileBuffer = Buffer.from(ab);
                  break;
                }
              }
            } catch (_) {}
          }
        }
      }

      if (fileBuffer && fileBuffer.length > 0) {
        archive.append(fileBuffer, { name: entryName });
        addedCount++;
      }
    }

    if (addedCount === 0) {
      archive.append(
        'The requested application files could not be located on storage. Please contact the administrator or re-upload the documents.',
        { name: 'README.txt' }
      );
    }

    await archive.finalize();
  },

  async wipeRealEstatePreSalesData() {
    const reLeads = await prisma.crmLead.findMany({
      where: {
        scope: { not: 'NB_FINSERVE' },
      },
      select: { id: true },
    });

    const leadIds = reLeads.map((l) => l.id);
    if (leadIds.length === 0) {
      return { count: 0, message: 'No Real Estate leads found to delete.' };
    }

    await prisma.crmFollowUp.deleteMany({ where: { leadId: { in: leadIds } } }).catch(() => {});
    await prisma.crmCallLog.updateMany({
      where: { leadId: { in: leadIds } },
      data: { leadId: null },
    }).catch(() => {});

    const deleteRes = await prisma.crmLead.deleteMany({
      where: { id: { in: leadIds } },
    });

    return {
      count: deleteRes.count,
      message: `Successfully wiped ${deleteRes.count} Real Estate Pre-Sales leads and associated records.`,
    };
  },
};

