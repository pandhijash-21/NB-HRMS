import { CrmLeadStatus } from '@prisma/client';
import { prisma } from '../../config/prisma';
import * as crypto from 'crypto';
import * as xlsx from 'xlsx';
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
  async getProjects() {
    return prisma.crmProject.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        campaigns: {
          where: { isActive: true },
          select: {
            id: true,
            name: true,
            code: true,
            adId: true,
            webhookToken: true,
            startDate: true,
            isActive: true,
            _count: { select: { leads: { where: { isDeleted: false } } } },
          },
        },
        _count: {
          select: { campaigns: { where: { isActive: true } } },
        },
      },
    });
  },

  async createProject(dto: CreateProjectDto) {
    const code = (dto.code && dto.code.trim())
      ? dto.code.trim().toUpperCase().replace(/[^A-Z0-9_]/g, '_')
      : dto.name.trim().toUpperCase().replace(/[^A-Z0-9_]/g, '_') + '_' + Date.now().toString().slice(-4);

    return prisma.crmProject.create({
      data: {
        name: dto.name.trim(),
        code,
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
  async ensureDefaultCampaign(module = 'PRE_SALES') {
    let campaign = await prisma.crmCampaign.findFirst({
      where: { module, code: 'DEFAULT' },
    });

    if (!campaign) {
      const webhookToken = crypto.randomBytes(12).toString('hex');
      campaign = await prisma.crmCampaign.create({
        data: {
          name: 'Default Campaign',
          code: 'DEFAULT',
          description: 'Primary Pre-Sales Campaign',
          webhookToken,
          module,
          isActive: true,
        },
      });
    } else if (!campaign.webhookToken) {
      const webhookToken = crypto.randomBytes(12).toString('hex');
      campaign = await prisma.crmCampaign.update({
        where: { id: campaign.id },
        data: { webhookToken },
      });
    }

    // Attach any orphan columns/leads with null campaignId to this default campaign
    await prisma.crmColumnConfig.updateMany({
      where: { module, campaignId: null },
      data: { campaignId: campaign.id },
    });

    await prisma.crmLead.updateMany({
      where: { campaignId: null },
      data: { campaignId: campaign.id },
    });

    // Check if columns exist for this campaign
    const columnCount = await prisma.crmColumnConfig.count({
      where: { module, campaignId: campaign.id },
    });

    if (columnCount === 0 && module === 'PRE_SALES') {
      for (const col of DEFAULT_PRE_SALES_COLUMNS) {
        await prisma.crmColumnConfig.create({
          data: {
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
      }
    }

    return campaign;
  },

  async getCampaigns(module = 'PRE_SALES', projectId?: string) {
    if (!projectId) {
      await this.ensureDefaultCampaign(module);
    }
    const where: any = { module, isActive: true };
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
            columns: { where: { isActive: true } },
            leads: { where: { isDeleted: false } },
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

  async createCampaign(dto: CreateCampaignDto) {
    const module = dto.module || 'PRE_SALES';
    const defaultCamp = await this.ensureDefaultCampaign(module);

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
        isActive: true,
      },
      include: {
        project: { select: { id: true, name: true } },
      },
    });

    // Clone columns from source campaign (or default campaign)
    const sourceCampaignId = dto.copyFromCampaignId || defaultCamp.id;
    const sourceColumns = await prisma.crmColumnConfig.findMany({
      where: { campaignId: sourceCampaignId, isActive: true },
      orderBy: { displayOrder: 'asc' },
    });

    if (sourceColumns.length > 0) {
      for (const col of sourceColumns) {
        await prisma.crmColumnConfig.create({
          data: {
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
      },
    });
    const existingKeys = new Set(existingColumns.map((c) => c.columnKey));

    let displayOrder = existingColumns.length;
    for (const key of Object.keys(normalizedPayload)) {
      if (!existingKeys.has(key)) {
        const label = key.replace(/_/g, ' ');
        await prisma.crmColumnConfig.create({
          data: {
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

    const lead = await prisma.crmLead.create({
      data: {
        campaignId: campaign.id,
        phone: rawPhone || '0000000000',
        name,
        status: 'NOT_STARTED',
        customFields: normalizedPayload,
      },
    });

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
  async ensureDefaultColumns(module = 'PRE_SALES') {
    await this.ensureDefaultCampaign(module);
  },

  async getColumns(module = 'PRE_SALES', campaignId?: string) {
    const defaultCamp = await this.ensureDefaultCampaign(module);
    const targetCampaignId = campaignId || defaultCamp.id;

    // Check if columns exist for this campaign, if not clone default
    const count = await prisma.crmColumnConfig.count({
      where: { module, campaignId: targetCampaignId, isActive: true },
    });

    if (count === 0) {
      for (const col of DEFAULT_PRE_SALES_COLUMNS) {
        await prisma.crmColumnConfig.create({
          data: {
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
      }
    }

    return prisma.crmColumnConfig.findMany({
      where: { module, campaignId: targetCampaignId, isActive: true },
      orderBy: { displayOrder: 'asc' },
    });
  },

  async createColumn(dto: CreateColumnDto) {
    const module = dto.module || 'PRE_SALES';
    const defaultCamp = await this.ensureDefaultCampaign(module);
    const campaignId = dto.campaignId || defaultCamp.id;

    const key = dto.columnKey
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9_]/g, '_');

    // Determine max order
    const last = await prisma.crmColumnConfig.findFirst({
      where: { module, campaignId },
      orderBy: { displayOrder: 'desc' },
    });
    const nextOrder = dto.displayOrder ?? (last ? last.displayOrder + 1 : 1);

    return prisma.crmColumnConfig.upsert({
      where: { module_campaignId_columnKey: { module, campaignId, columnKey: key } },
      update: {
        label: dto.label,
        dataType: dto.dataType || 'TEXT',
        options: dto.options || [],
        isRequired: dto.isRequired ?? false,
        isActive: true,
        displayOrder: nextOrder,
      },
      create: {
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
    page?: number;
    limit?: number;
  }) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.min(100, query.limit || 50);
    const skip = (page - 1) * limit;

    const where: any = {
      isDeleted: false,
    };

    if (query.campaignId && query.campaignId !== 'ALL') {
      where.campaignId = query.campaignId;
    } else if (query.projectId && query.projectId !== 'ALL') {
      where.campaign = { projectId: query.projectId };
    }

    if (query.status && query.status !== 'ALL') {
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
      where.OR = [
        { name: { contains: s, mode: 'insensitive' } },
        { phone: { contains: s, mode: 'insensitive' } },
      ];
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
            orderBy: { scheduledDate: 'desc' },
            take: 1,
          },
        },
      }),
    ]);

    return {
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
      items,
    };
  },

  async createLead(dto: CreateLeadDto, createdById?: string, telecallerId?: number) {
    const custom = (dto.customFields && typeof dto.customFields === 'object') ? dto.customFields : {};
    const phone = (dto.phone || custom.phone || custom.Phone || custom.Phone_Number || custom.phone_number || '').toString().trim();
    const name = (dto.name || custom.client_name || custom.Client_Name || custom.full_name || custom.Full_Name || custom.Name || custom.name || 'Unnamed Lead').toString().trim();
    const defaultCamp = await this.ensureDefaultCampaign('PRE_SALES');
    const campaignId = dto.campaignId || defaultCamp.id;

    return prisma.crmLead.create({
      data: {
        campaignId,
        phone: phone || '0000000000',
        name,
        status: (dto.status as CrmLeadStatus) || CrmLeadStatus.NOT_STARTED,
        customFields: custom,
        assignedToId: dto.assignedToId,
        telecallerId: telecallerId || dto.telecallerId,
        createdById,
      },
      include: {
        campaign: { select: { id: true, name: true, code: true, projectId: true } },
        assignedTo: {
          include: { generalInfo: { select: { fullName: true } } },
        },
      },
    });
  },

  async importExcelLeads(
    fileBuffer: Buffer,
    createdById?: string,
    telecallerId?: number,
    campaignId?: string,
  ) {
    const workbook = xlsx.read(fileBuffer, { type: 'buffer' });
    const firstSheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[firstSheetName];
    const rows: Array<Record<string, any>> = xlsx.utils.sheet_to_json(worksheet, { defval: '' });

    if (!rows || rows.length === 0) {
      return { count: 0, message: 'No rows found in Excel sheet' };
    }

    const defaultCamp = await this.ensureDefaultCampaign('PRE_SALES');
    const targetCampaignId = campaignId || defaultCamp.id;

    // Fetch column configs to map header aliases for THIS campaign
    const cols = await this.getColumns('PRE_SALES', targetCampaignId);
    const colMap: Record<string, string> = {};
    for (const c of cols) {
      colMap[c.label.toLowerCase().trim()] = c.columnKey;
      colMap[c.columnKey.toLowerCase().trim()] = c.columnKey;
    }

    let insertedCount = 0;
    const leadsToInsert: any[] = [];

    for (const row of rows) {
      const customFields: Record<string, any> = {};
      let phone = '';
      let name = '';

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
        customFields[mappedKey] = strVal;
      }

      if (!phone && customFields.phone) phone = String(customFields.phone);
      if (!name && customFields.client_name) name = String(customFields.client_name);

      if (phone || name) {
        leadsToInsert.push({
          campaignId: targetCampaignId,
          phone: phone || 'N/A',
          name: name || 'Unnamed Lead',
          status: CrmLeadStatus.NOT_STARTED,
          customFields,
          telecallerId,
          createdById,
        });
      }
    }

    if (leadsToInsert.length > 0) {
      for (const lead of leadsToInsert) {
        await prisma.crmLead.create({ data: lead });
        insertedCount++;
      }
    }

    return {
      count: insertedCount,
      totalRows: rows.length,
      message: `Successfully imported ${insertedCount} leads from Excel`,
    };
  },

  async updateLeadStatus(
    leadId: string,
    status: 'NOT_STARTED' | 'FOLLOW_UP' | 'INTERESTED' | 'NOT_INTERESTED',
    payload: {
      scheduledDate?: string;
      scheduledTime?: string;
      remarks?: string;
      assignedToId?: number;
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

    if (existing.assignedToId && !isSuperAdmin && !isAssignedSalesRep) {
      throw new Error('This lead is assigned to a sales representative. Telecallers have view-only access.');
    }

    const updateData: any = {
      status: status as CrmLeadStatus,
    };

    if (status === 'NOT_INTERESTED') {
      updateData.notInterestedAt = new Date();
    } else {
      updateData.notInterestedAt = null;
    }

    let safeAssignedId = existing.assignedToId;
    if (payload.assignedToId && payload.assignedToId > 0) {
      const emp = await prisma.employee.findUnique({ where: { id: payload.assignedToId } });
      if (emp) safeAssignedId = emp.id;
    }

    if (status === 'INTERESTED' && safeAssignedId) {
      updateData.assignedToId = safeAssignedId;
    }

    // Schedule or reschedule single active follow-up if date and time provided
    if (payload.scheduledDate && payload.scheduledTime) {
      const scheduledDateTime = new Date(payload.scheduledDate);
      const existingPending = await prisma.crmFollowUp.findFirst({
        where: { leadId, status: 'PENDING' },
        orderBy: { createdAt: 'desc' },
      });

      if (existingPending) {
        await prisma.crmFollowUp.update({
          where: { id: existingPending.id },
          data: {
            scheduledDate: scheduledDateTime,
            scheduledTime: payload.scheduledTime,
            remarks: payload.remarks || (status === 'INTERESTED' ? 'Interested client sales meeting scheduled' : 'Follow-up scheduled'),
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
            remarks: payload.remarks || (status === 'INTERESTED' ? 'Interested client sales meeting scheduled' : 'Follow-up scheduled'),
            assignedToId: safeAssignedId,
            createdById: userContext?.userId,
          },
        });
      }
    }

    return prisma.crmLead.update({
      where: { id: leadId },
      data: updateData,
      include: {
        assignedTo: {
          include: { generalInfo: { select: { fullName: true } } },
        },
        followUps: {
          orderBy: { scheduledDate: 'desc' },
          take: 1,
        },
      },
    });
  },

  async updateLead(
    leadId: string,
    dto: UpdateLeadDto,
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

    if (existing.assignedToId && !isSuperAdmin && !isAssignedSalesRep) {
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

    return prisma.crmLead.update({
      where: { id: leadId },
      data: {
        ...(dto.name && { name: dto.name }),
        ...(dto.phone && { phone: dto.phone }),
        ...(dto.status && { status: dto.status as CrmLeadStatus }),
        ...(dto.customFields && {
          customFields: {
            ...((existing.customFields as Record<string, any>) || {}),
            ...dto.customFields,
          },
        }),
        ...(safeAssignedToId !== undefined && { assignedToId: safeAssignedToId }),
      },
      include: {
        assignedTo: {
          include: { generalInfo: { select: { fullName: true } } },
        },
      },
    });
  },

  async moveToBin(
    leadId: string,
    userContext?: { userId?: string; employeeId?: number; role?: string },
  ) {
    const existing = await prisma.crmLead.findUnique({ where: { id: leadId } });
    if (!existing) throw new Error('Lead not found');

    const isSuperAdmin = ['ADMIN', 'SUPER_ADMIN', 'SYSTEM_ADMIN'].includes(userContext?.role?.toUpperCase() || '');
    const isAssignedSalesRep = userContext?.employeeId != null && userContext?.employeeId === existing.assignedToId;

    if (existing.assignedToId && !isSuperAdmin && !isAssignedSalesRep) {
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

  async getBinLeads(module = 'PRE_SALES') {
    // Return leads marked as isDeleted: true OR marked as NOT_INTERESTED
    const retentionSetting = await prisma.crmSetting.findUnique({
      where: { key: 'not_interested_retention_days' },
    });
    const retentionDays = parseInt(retentionSetting?.value || '30', 10);
    const thresholdDate = new Date();
    thresholdDate.setDate(thresholdDate.getDate() - retentionDays);

    return prisma.crmLead.findMany({
      where: {
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
  }) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    // Strictly ensure follow-ups are only returned for ACTIVE (non-deleted / non-binned) leads
    const where: any = {
      lead: {
        isDeleted: false,
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
  // Settings & Elision Telephony
  // ---------------------------------------------------------------------------
  async getSettings() {
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
    };
    for (const s of settings) {
      if (s.value !== undefined && s.value !== null) {
        map[s.key] = s.value;
      }
    }
    return map;
  },

  async updateSettings(dto: UpdateCrmSettingsDto, updatedBy?: string) {
    const entries = Object.entries(dto);
    for (const [key, value] of entries) {
      if (value !== undefined) {
        await prisma.crmSetting.upsert({
          where: { key },
          update: { value: String(value), updatedBy },
          create: { key, value: String(value), updatedBy },
        });
      }
    }
    return this.getSettings();
  },

  async clickToCall(leadId: string, agentPhoneOrId?: string, userContext?: any) {
    const lead = await prisma.crmLead.findUnique({ where: { id: leadId } });
    if (!lead) throw new Error('Lead not found');

    const settings = await this.getSettings();
    const apiUrl = settings.elision_api_url || 'https://greeter.co.in/api/click2call';
    const userId = settings.elision_user_id || '634550';
    const routeNumber = settings.elision_route_number || '98';
    const did = settings.elision_did || '9484700070';

    // Normalize customer phone number (strip spaces/dashes)
    let customerNumber = lead.phone.replace(/[^0-9]/g, '');
    if (customerNumber.length > 10 && customerNumber.startsWith('91')) {
      customerNumber = customerNumber.substring(2);
    }

    // Resolve Agent Mobile Number
    let agentNumber: string | null | undefined = agentPhoneOrId;
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
      payload.Audio_URL ||
      payload.audio_url ||
      payload.recording ||
      payload.record_url ||
      payload.recording_file ||
      payload.record_file ||
      payload.AudioUrl ||
      payload.RecordingUrl ||
      payload.filename ||
      payload.file_url ||
      payload.recording_path ||
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

    return {
      status: 'success',
      message: 'Call log saved successfully',
      logId: callLog.id,
      leadMatched: leadId !== null,
    };
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

  // ---------------------------------------------------------------------------
  // KPI Metrics for Dashboard
  // ---------------------------------------------------------------------------
  async getKpiMetrics(projectId?: string, campaignId?: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const leadWhere: Record<string, unknown> = { isDeleted: false };
    if (campaignId && campaignId !== 'ALL') {
      leadWhere.campaignId = campaignId;
    } else if (projectId && projectId !== 'ALL') {
      leadWhere.campaign = { projectId };
    }

    const followUpWhere: Record<string, unknown> = {
      scheduledDate: { gte: today, lt: tomorrow },
      status: 'PENDING',
      lead: { ...leadWhere },
    };

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
          ...(campaignId && campaignId !== 'ALL'
            ? { campaignId }
            : projectId && projectId !== 'ALL'
              ? { campaign: { projectId } }
              : {}),
        },
      }),
      prisma.crmLead.count({
        where: { ...leadWhere, status: CrmLeadStatus.NOT_STARTED },
      }),
      prisma.crmLead.count({
        where: { ...leadWhere, status: CrmLeadStatus.FOLLOW_UP },
      }),
      prisma.crmCallLog.count(),
      prisma.crmCallLog.count({
        where: {
          callStatus: { in: ['ANSWERED', 'ANSWER', 'COMPLETED', 'SUCCESS'] },
        },
      }),
      prisma.crmCallLog.count({
        where: {
          callStatus: { in: ['MISSED', 'NOANSWER', 'BUSY', 'FAILED', 'CANCELLED'] },
        },
      }),
      prisma.crmCallLog.aggregate({
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
    };
  },

  // ---------------------------------------------------------------------------
  // Sales Users & Employees from HRMS
  // ---------------------------------------------------------------------------
  async getSalesUsers() {
    const employees = await prisma.employee.findMany({
      where: { status: 'ACTIVE' },
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

    return employees.map((emp) => ({
      employeeId: emp.id,
      userId: emp.userId,
      fullName: emp.generalInfo?.fullName || emp.user?.username || `Employee #${emp.id}`,
      designation: emp.generalInfo?.designation || 'Sales Executive',
      department: emp.generalInfo?.department || 'Sales & Marketing',
      role: emp.user?.role?.name || 'SALES',
    }));
  },
};

