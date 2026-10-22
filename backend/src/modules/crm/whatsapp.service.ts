import { prisma } from '../../config/prisma';
import {
  BotBizApiClient,
  BotbizTemplate,
  BotbizTemplateStatusResponse,
} from './botbiz.client';

export type WhatsappMessageType = 'TEXT' | 'TEMPLATE';

export interface CrmWhatsappTrigger {
  id: string;
  event: string; // e.g. 'SITE_VISIT_SCHEDULED' | 'SITE_VISIT_RESCHEDULED' | 'SITE_VISIT_CANCELLED' | 'SITE_VISIT_DONE' | 'LEAD_CREATED' | 'LEAD_ASSIGNED' | 'FOLLOW_UP_DUE' | 'BOOKING_CONFIRMED' | 'PAYMENT_RECEIVED' | 'AFTER_CALL'
  name: string;
  enabled: boolean;
  messageType: WhatsappMessageType; // 'TEXT' or 'TEMPLATE'
  templateId?: string; // BotBiz Meta Template ID if messageType is 'TEMPLATE'
  templateName?: string; // BotBiz Meta Template Name
  templateEndpoint?: string; // Administrator configured BotBiz generated template endpoint
  headerMediaUrl?: string; // Header document/image/video URL if template has media header
  headerType?: 'NONE' | 'DOCUMENT' | 'IMAGE' | 'VIDEO' | 'TEXT' | string;
  language?: string; // e.g. 'en_US'
  messageTemplate: string; // Body text for free-form or template preview
  mediaUrl?: string; // Optional image or document URL
  includeCalendarLink?: boolean;
  locationUrl?: string; // Google Maps location pin
}

export type ConnectionStatusType =
  | 'NOT_CONFIGURED'
  | 'CONFIGURED_UNVERIFIED'
  | 'CONNECTED_VERIFIED';

export interface CrmWhatsappConfig {
  enabled: boolean;
  provider: 'botbiz' | 'generic' | 'ultramsg' | 'wati' | 'meta' | 'custom';
  apiBase: string; // BotBiz API Base: https://dash.botbiz.io/api/v1
  apiUrl: string; // Legacy field retained for compatibility
  apiKey: string; // Masked on return for security
  hasApiKey: boolean;
  senderId: string; // BotBiz WhatsApp Phone Number ID
  defaultCalendarLink: string; // Calendar/Appointment scheduling URL (Google Calendar / Calendly)
  defaultBrochureUrl?: string;
  defaultBrochureName?: string;
  defaultLocationUrl: string;
  defaultProjectName: string;
  connectionStatus: ConnectionStatusType;
  lastVerifiedAt?: string;
  lastVerificationResult?: string;
  triggers: CrmWhatsappTrigger[];
}

export interface CrmWhatsappLogItem {
  id: string;
  phone: string;
  event: string;
  leadId?: string;
  message: string;
  messageType?: WhatsappMessageType;
  templateId?: string;
  waMessageId?: string;
  mediaUrl?: string;
  status: 'SENT' | 'FAILED' | 'DISABLED';
  error?: string;
  httpStatus?: number;
  retryCount?: number;
  timestamp: string;
}

const DEFAULT_TRIGGERS: CrmWhatsappTrigger[] = [
  {
    id: 'trigger_site_visit_scheduled',
    event: 'SITE_VISIT_SCHEDULED',
    name: 'Site Visit Confirmed & Calendar Reminder',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Dear {{customerName}},\n\nYour site visit for *{{projectName}}* has been confirmed! 🎉\n\n📅 *Date:* {{siteVisitDate}}\n⏰ *Time:* {{siteVisitTime}}\n📍 *Location Pin:* {{locationUrl}}\n\nTap below to automatically add this visit to your Google Calendar:\n👉 {{calendarLink}}\n\nOur property advisor {{salespersonName}} will be waiting to assist you. See you soon!',
    mediaUrl: '',
    includeCalendarLink: true,
    locationUrl: 'https://maps.google.com/?q=Legacy+Tower',
  },
  {
    id: 'trigger_site_visit_rescheduled',
    event: 'SITE_VISIT_RESCHEDULED',
    name: 'Site Visit Rescheduled Notice',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Hello {{customerName}},\n\nYour site visit for *{{projectName}}* has been rescheduled to:\n\n📅 *New Date:* {{siteVisitDate}}\n⏰ *New Time:* {{siteVisitTime}}\n📍 *Location:* {{locationUrl}}\n\nAdd updated reminder to your calendar:\n👉 {{calendarLink}}\n\nFor any questions, feel free to reply directly to this message.',
    mediaUrl: '',
    includeCalendarLink: true,
    locationUrl: 'https://maps.google.com/?q=Legacy+Tower',
  },
  {
    id: 'trigger_site_visit_cancelled',
    event: 'SITE_VISIT_CANCELLED',
    name: 'Site Visit Cancellation Acknowledgement',
    enabled: false,
    messageType: 'TEXT',
    messageTemplate:
      'Dear {{customerName}},\n\nYour site visit scheduled for *{{projectName}}* has been cancelled as requested.\n\nWhenever you would like to reschedule or explore other properties, please let us know. We would love to host you!',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_site_visit_done',
    event: 'SITE_VISIT_DONE',
    name: 'Post Site Visit Follow-up & Feedback',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Dear {{customerName}},\n\nThank you for visiting *{{projectName}}* today! ✨ We hope you loved experiencing the project.\n\nAttached is our full project deck with floor layouts and pricing details: {{brochureUrl}}\n\nOur property advisor {{salespersonName}} will connect with you to answer any questions.',
    mediaUrl: 'https://nbdeveloper.co.in/brochures/legacy-tower.pdf',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_lead_created',
    event: 'LEAD_CREATED',
    name: 'New Lead Welcome (Inquiry Acknowledgment)',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Hello {{customerName}},\n\nThank you for your interest in *{{projectName}}*! 🏢\n\nWe have received your inquiry. Attached is the exclusive brochure with floor plans, amenities, and connectivity.\n\nBrochure: {{brochureUrl}}\n\nOur team will be in touch with you shortly!',
    mediaUrl: 'https://nbdeveloper.co.in/brochures/legacy-tower.pdf',
    includeCalendarLink: false,
    locationUrl: 'https://maps.google.com/?q=Legacy+Tower',
  },
  {
    id: 'trigger_lead_assigned',
    event: 'LEAD_ASSIGNED',
    name: 'Property Advisor Assigned Notification',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Dear {{customerName}},\n\nYour dedicated property advisor for *{{projectName}}* is *{{salespersonName}}* (Contact: {{salespersonPhone}}).\n\nThey will assist you with customized unit availability, pricing schemes, and private site previews.',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_follow_up_due',
    event: 'FOLLOW_UP_DUE',
    name: 'Customer Follow-Up Due',
    enabled: false,
    messageType: 'TEXT',
    messageTemplate:
      'Hello {{customerName}},\n\nFollowing up regarding your inquiry for *{{projectName}}*. Please let us know if you need any additional details or when would be a convenient time for a quick call.',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_booking_confirmed',
    event: 'BOOKING_CONFIRMED',
    name: 'Unit Booking Confirmed Congratulation',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Heartiest Congratulations, {{customerName}}! 🎊\n\nYour booking at *{{projectName}}* has been confirmed. Welcome to the NB Developer family!\n\nOur relationship manager will coordinate the official agreement and documentation shortly.',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_payment_received',
    event: 'PAYMENT_RECEIVED',
    name: 'Payment Receipt Acknowledgement',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Dear {{customerName}},\n\nWe have successfully received your payment of *₹{{paymentAmount}}* for *{{projectName}}*.\n\nAn official payment receipt has been generated. Thank you for your prompt payment!',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_after_call',
    event: 'AFTER_CALL',
    name: 'Post-Call Greeting & Relationship',
    enabled: false,
    messageType: 'TEXT',
    messageTemplate:
      'Dear {{customerName}},\n\nThank you for speaking with our *{{projectName}}* team today! 🙏\n\nIf you need any more details or have questions, please reach out to us directly on this WhatsApp.\n\nHave a wonderful day ahead!',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
];

const DEFAULT_FINSERVE_TRIGGERS: CrmWhatsappTrigger[] = [
  {
    id: 'trigger_finserve_lead_created',
    event: 'LEAD_CREATED',
    name: 'New Loan Inquiry Acknowledgment',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Hello {{customerName}},\n\nThank you for reaching out to *NB Finserve*! 💼\n\nWe have received your loan inquiry. Our financial advisor will connect with you shortly to assist you with the best loan options, competitive interest rates, and quick processing.\n\nWarm regards,\nNB Finserve Team',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_finserve_lead_assigned',
    event: 'LEAD_ASSIGNED',
    name: 'Financial Advisor Assigned Notification',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Dear {{customerName}},\n\nYour dedicated Financial Advisor at *NB Finserve* is *{{salespersonName}}* (Contact: {{salespersonPhone}}).\n\nThey will guide you through your {{loanType}} options and assist with eligibility and documentation.',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_finserve_follow_up_due',
    event: 'FOLLOW_UP_DUE',
    name: 'Consultation / Follow-Up Due Reminder',
    enabled: false,
    messageType: 'TEXT',
    messageTemplate:
      'Hello {{customerName}},\n\nFollowing up regarding your loan inquiry with *NB Finserve*. Please let us know if you have any questions or when would be a convenient time for a quick call.\n\nBest regards,\nNB Finserve Team',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_finserve_cnr',
    event: 'CNR',
    name: 'Customer Not Reachable (CNR) Notice',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Dear {{customerName}},\n\nWe tried reaching you from *NB Finserve* regarding your loan inquiry, but could not connect.\n\nPlease let us know a suitable time to call you back, or message us here directly.\n\nThank you,\nNB Finserve Team',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_finserve_visit_scheduled',
    event: 'VISIT_SCHEDULED',
    name: 'Consultation / Verification Meeting Scheduled',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Dear {{customerName}},\n\nYour consultation meeting with *NB Finserve* has been scheduled! 📅\n\n📅 Date: {{siteVisitDate}}\n⏰ Time: {{siteVisitTime}}\n👤 Advisor: {{salespersonName}}\n\nPlease keep your basic KYC documents handy for faster processing.',
    mediaUrl: '',
    includeCalendarLink: true,
    locationUrl: '',
  },
  {
    id: 'trigger_finserve_visit_done',
    event: 'VISIT_DONE',
    name: 'Post-Consultation Meeting Acknowledgment',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Dear {{customerName}},\n\nThank you for meeting with our *NB Finserve* team today! 🙏\n\nWe have recorded your loan requirements and our credit team is actively reviewing your profile. For any assistance, reply directly on this WhatsApp.',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_finserve_docs_requested',
    event: 'DOCS_REQUESTED',
    name: 'Loan Documents Checklist Request',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Dear {{customerName}},\n\nTo proceed with your *NB Finserve* loan application, please share the required documents (PAN Card, Aadhaar Card, Bank Statements, Salary Slips / ITR).\n\nUpload securely or share them directly with your advisor {{salespersonName}}.',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_finserve_loan_sanctioned',
    event: 'LOAN_SANCTIONED',
    name: 'Loan Sanctioned / Approved Congratulation',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Congratulations {{customerName}}! 🎉\n\nYour loan with *NB Finserve* has been approved/sanctioned! 💰\n\nOur team is coordinating the final agreement and disbursement process. Thank you for choosing NB Finserve!',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_finserve_loan_disbursed',
    event: 'LOAN_DISBURSED',
    name: 'Loan Disbursed Notification',
    enabled: true,
    messageType: 'TEXT',
    messageTemplate:
      'Dear {{customerName}},\n\nWe are pleased to inform you that your loan amount has been successfully disbursed! 🎊\n\nWelcome to the NB Finserve family. For any service queries, we are always here to assist.',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_finserve_not_interested',
    event: 'NOT_INTERESTED',
    name: 'Inquiry Closed Acknowledgment',
    enabled: false,
    messageType: 'TEXT',
    messageTemplate:
      'Dear {{customerName}},\n\nWe have noted that you are not looking to proceed with your loan inquiry at this time.\n\nWhenever you require financial services in the future, *NB Finserve* will be glad to assist you. Have a great day ahead!',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_finserve_after_call',
    event: 'AFTER_CALL',
    name: 'Post-Call Greeting & Relationship',
    enabled: false,
    messageType: 'TEXT',
    messageTemplate:
      'Dear {{customerName}},\n\nThank you for speaking with our *NB Finserve* team today! 🙏\n\nIf you need any more details or have questions, please reach out to us directly on this WhatsApp.\n\nHave a wonderful day ahead!',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: '',
  },
];

export class WhatsappService {
  private botbizClient: BotBizApiClient;
  // In-memory idempotency deduplication cache: `${event}:${phone}` -> timestamp
  private recentDispatches = new Map<string, number>();

  constructor() {
    this.botbizClient = new BotBizApiClient();
  }

  /**
   * Helper: Build Google Calendar Event Link
   */
  static buildGoogleCalendarUrl(params: {
    title: string;
    details: string;
    location: string;
    dateStr?: string;
    timeStr?: string;
  }): string {
    try {
      const now = new Date();
      let start = new Date(now.getTime() + 24 * 60 * 60 * 1000); // default tomorrow
      if (params.dateStr) {
        const parsed = new Date(params.dateStr);
        if (!isNaN(parsed.getTime())) {
          start = parsed;
        }
      }

      if (params.timeStr) {
        const timeMatch = params.timeStr.match(/(\d{1,2}):(\d{2})\s*(AM|PM)?/i);
        if (timeMatch) {
          let hours = parseInt(timeMatch[1], 10);
          const mins = parseInt(timeMatch[2], 10);
          const ampm = timeMatch[3]?.toUpperCase();
          if (ampm === 'PM' && hours < 12) hours += 12;
          if (ampm === 'AM' && hours === 12) hours = 0;
          start.setHours(hours, mins, 0, 0);
        }
      }

      const end = new Date(start.getTime() + 60 * 60 * 1000); // 1 hour duration

      const formatIsoUtc = (d: Date) => {
        return d.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
      };

      const datesParam = `${formatIsoUtc(start)}/${formatIsoUtc(end)}`;
      const url = new URL('https://calendar.google.com/calendar/render');
      url.searchParams.set('action', 'TEMPLATE');
      url.searchParams.set('text', params.title || 'Site Visit - Legacy Tower');
      url.searchParams.set('dates', datesParam);
      url.searchParams.set('details', params.details || 'Site Visit at Legacy Tower');
      if (params.location) {
        url.searchParams.set('location', params.location);
      }
      return url.toString();
    } catch {
      return 'https://calendar.google.com';
    }
  }

  /**
   * Safe token mask: never expose secret token over API or logs
   */
  private maskToken(token: string): string {
    if (!token) return '';
    const trimmed = token.trim();
    if (trimmed.length <= 4) return '••••••••';
    return `${'•'.repeat(Math.max(8, trimmed.length - 4))}${trimmed.slice(-4)}`;
  }

  /**
   * Internal helper: read raw unmasked configuration
   */
  async getRawConfig(scope: string = 'NB_DEVELOPER'): Promise<{
    enabled: boolean;
    provider: 'botbiz' | 'generic' | 'ultramsg' | 'wati' | 'meta' | 'custom';
    apiBase: string;
    apiKey: string;
    senderId: string;
    defaultCalendarLink: string;
    defaultBrochureUrl: string;
    defaultBrochureName: string;
    defaultLocationUrl: string;
    defaultProjectName: string;
    lastVerifiedAt?: string;
    lastVerificationResult?: string;
    triggers: CrmWhatsappTrigger[];
  }> {
    const isFinserve = scope === 'NB_FINSERVE';
    const prefix = isFinserve ? 'finserve_' : '';

    const settings = await prisma.crmSetting.findMany({
      where: {
        key: {
          in: [
            `${prefix}whatsapp_enabled`,
            `${prefix}whatsapp_provider`,
            `${prefix}whatsapp_api_base`,
            `${prefix}whatsapp_api_url`,
            `${prefix}whatsapp_api_key`,
            `${prefix}whatsapp_sender_id`,
            `${prefix}whatsapp_default_calendar_link`,
            `${prefix}whatsapp_calendar_link`,
            `${prefix}whatsapp_default_brochure_url`,
            `${prefix}whatsapp_default_brochure_name`,
            `${prefix}whatsapp_default_location_url`,
            `${prefix}whatsapp_default_project_name`,
            `${prefix}whatsapp_triggers`,
            `${prefix}whatsapp_last_verified_at`,
            `${prefix}whatsapp_last_verification_result`,
          ],
        },
      },
    });

    const map: Record<string, string> = {};
    for (const s of settings) {
      if (s.value !== undefined && s.value !== null) {
        const rawKey = isFinserve && s.key.startsWith('finserve_')
          ? s.key.substring('finserve_'.length)
          : s.key;
        map[rawKey] = s.value;
      }
    }

    // Merge DB values with Environment Variables
    const envApiBase = process.env.BOTBIZ_API_BASE;
    const envApiToken = isFinserve
      ? (process.env.FINSERVE_BOTBIZ_API_TOKEN || '')
      : (process.env.BOTBIZ_API_TOKEN || '');
    const envPhoneId = isFinserve
      ? (process.env.FINSERVE_BOTBIZ_PHONE_NUMBER_ID || '')
      : (process.env.BOTBIZ_PHONE_NUMBER_ID || '');

    const apiBase =
      map.whatsapp_api_base ||
      envApiBase ||
      'https://dash.botbiz.io/api/v1';

    const apiKey = map.whatsapp_api_key || envApiToken || '';
    const senderId = map.whatsapp_sender_id || envPhoneId || '';

    const defaultList = isFinserve ? DEFAULT_FINSERVE_TRIGGERS : DEFAULT_TRIGGERS;
    let triggers = defaultList;
    if (map.whatsapp_triggers) {
      try {
        const parsed = JSON.parse(map.whatsapp_triggers);
        if (Array.isArray(parsed) && parsed.length > 0) {
          // Merge any newly introduced default triggers with saved triggers
          const existingEventIds = new Set(parsed.map((t: any) => t.event));
          const missingDefaults = defaultList.filter(
            (dt) => !existingEventIds.has(dt.event),
          );
          triggers = [...parsed, ...missingDefaults];
        }
      } catch (err) {
        console.error(`[CRM WhatsApp - ${scope}] Failed to parse triggers JSON:`, err);
      }
    }

    return {
      enabled: map.whatsapp_enabled !== 'false',
      provider: (map.whatsapp_provider as any) || 'botbiz',
      apiBase,
      apiKey,
      senderId,
      defaultCalendarLink:
        map.whatsapp_default_calendar_link ||
        map.whatsapp_calendar_link ||
        '',
      defaultBrochureUrl:
        map.whatsapp_default_brochure_url || '',
      defaultBrochureName:
        map.whatsapp_default_brochure_name ||
        (isFinserve ? 'NB_Finserve_Loan_Guide.pdf' : 'Legacy_Tower_Brochure.pdf'),
      defaultLocationUrl:
        map.whatsapp_default_location_url ||
        (isFinserve ? '' : 'https://maps.google.com/?q=Legacy+Tower'),
      defaultProjectName:
        map.whatsapp_default_project_name || (isFinserve ? 'NB Finserve' : 'Legacy Tower'),
      lastVerifiedAt: map.whatsapp_last_verified_at,
      lastVerificationResult: map.whatsapp_last_verification_result,
      triggers,
    };
  }

  /**
   * Retrieve current WhatsApp Configuration for CRM Admin (MASKED Token)
   */
  async getConfig(scope: string = 'NB_DEVELOPER'): Promise<CrmWhatsappConfig> {
    const raw = await this.getRawConfig(scope);

    // Determine connection status
    let connectionStatus: ConnectionStatusType = 'NOT_CONFIGURED';
    const hasCreds = Boolean(raw.apiKey.trim() && raw.senderId.trim());

    if (!hasCreds) {
      connectionStatus = 'NOT_CONFIGURED';
    } else if (raw.lastVerificationResult === 'SUCCESS') {
      connectionStatus = 'CONNECTED_VERIFIED';
    } else {
      connectionStatus = 'CONFIGURED_UNVERIFIED';
    }

    return {
      enabled: raw.enabled,
      provider: raw.provider,
      apiBase: raw.apiBase,
      apiUrl: `${raw.apiBase}/whatsapp/send`,
      apiKey: this.maskToken(raw.apiKey),
      hasApiKey: Boolean(raw.apiKey.trim()),
      senderId: raw.senderId,
      defaultCalendarLink: raw.defaultCalendarLink,
      defaultBrochureUrl: raw.defaultBrochureUrl,
      defaultBrochureName: raw.defaultBrochureName,
      defaultLocationUrl: raw.defaultLocationUrl,
      defaultProjectName: raw.defaultProjectName,
      connectionStatus,
      lastVerifiedAt: raw.lastVerifiedAt,
      lastVerificationResult: raw.lastVerificationResult,
      triggers: raw.triggers,
    };
  }

  /**
   * Update WhatsApp Configuration (Safe unmask protection)
   */
  async updateConfig(
    dto: Partial<CrmWhatsappConfig>,
    updatedBy?: string,
    scope: string = 'NB_DEVELOPER',
  ): Promise<CrmWhatsappConfig> {
    const isFinserve = scope === 'NB_FINSERVE';
    const prefix = isFinserve ? 'finserve_' : '';
    const entries: Array<[string, string]> = [];

    if (dto.enabled !== undefined)
      entries.push([`${prefix}whatsapp_enabled`, String(dto.enabled)]);
    if (dto.provider !== undefined)
      entries.push([`${prefix}whatsapp_provider`, String(dto.provider)]);
    if (dto.apiBase !== undefined)
      entries.push([`${prefix}whatsapp_api_base`, String(dto.apiBase).trim()]);
    if (dto.apiUrl !== undefined && !dto.apiBase)
      entries.push([`${prefix}whatsapp_api_base`, String(dto.apiUrl).replace(/\/whatsapp\/send.*$/, '').trim()]);

    // Secure handling: only update API key if non-empty and NOT a masked bullet string
    if (dto.apiKey !== undefined) {
      const cleanKey = String(dto.apiKey).trim();
      const isMaskedOnly = /^[\*\•\s]+$/.test(cleanKey);
      if (cleanKey && !isMaskedOnly) {
        entries.push([`${prefix}whatsapp_api_key`, cleanKey]);
        // Invalidate verified status when key changes
        entries.push([`${prefix}whatsapp_last_verification_result`, 'UNVERIFIED']);
      }
    }

    if (dto.senderId !== undefined) {
      entries.push([`${prefix}whatsapp_sender_id`, String(dto.senderId).trim()]);
    }
    if ((dto as any).defaultCalendarLink !== undefined) {
      entries.push([
        `${prefix}whatsapp_default_calendar_link`,
        String((dto as any).defaultCalendarLink).trim(),
      ]);
    }
    if (dto.defaultBrochureUrl !== undefined)
      entries.push([
        `${prefix}whatsapp_default_brochure_url`,
        String(dto.defaultBrochureUrl).trim(),
      ]);
    if (dto.defaultBrochureName !== undefined)
      entries.push([
        `${prefix}whatsapp_default_brochure_name`,
        String(dto.defaultBrochureName).trim(),
      ]);
    if (dto.defaultLocationUrl !== undefined)
      entries.push([
        `${prefix}whatsapp_default_location_url`,
        String(dto.defaultLocationUrl).trim(),
      ]);
    if (dto.defaultProjectName !== undefined)
      entries.push([
        `${prefix}whatsapp_default_project_name`,
        String(dto.defaultProjectName).trim(),
      ]);
    if (dto.triggers !== undefined) {
      entries.push([`${prefix}whatsapp_triggers`, JSON.stringify(dto.triggers)]);
    }

    for (const [key, value] of entries) {
      await prisma.crmSetting.upsert({
        where: { key },
        update: { value, updatedBy },
        create: { key, value, updatedBy },
      });
    }

    return this.getConfig(scope);
  }

  /**
   * Test BotBiz API Connection (Safe test without customer messaging)
   */
  async testConnection(scope: string = 'NB_DEVELOPER'): Promise<{
    success: boolean;
    connectionStatus: ConnectionStatusType;
    message: string;
    details?: any;
  }> {
    const isFinserve = scope === 'NB_FINSERVE';
    const prefix = isFinserve ? 'finserve_' : '';
    const raw = await this.getRawConfig(scope);

    if (!raw.apiKey.trim() || !raw.senderId.trim()) {
      return {
        success: false,
        connectionStatus: 'NOT_CONFIGURED',
        message:
          `BotBiz credentials for ${isFinserve ? 'NB Finserve' : 'NB Developer'} are not configured. Please supply your API Token and WhatsApp Phone Number ID.`,
      };
    }

    this.botbizClient.updateCredentials(
      raw.apiKey,
      raw.senderId,
      raw.apiBase,
    );

    const testRes = await this.botbizClient.testConnection();

    const timestamp = new Date().toISOString();
    const resultStatus = testRes.connected ? 'SUCCESS' : 'FAILED';

    await prisma.crmSetting.upsert({
      where: { key: `${prefix}whatsapp_last_verified_at` },
      update: { value: timestamp },
      create: { key: `${prefix}whatsapp_last_verified_at`, value: timestamp },
    });
    await prisma.crmSetting.upsert({
      where: { key: `${prefix}whatsapp_last_verification_result` },
      update: { value: resultStatus },
      create: { key: `${prefix}whatsapp_last_verification_result`, value: resultStatus },
    });

    return {
      success: testRes.connected,
      connectionStatus: testRes.connected
        ? 'CONNECTED_VERIFIED'
        : 'CONFIGURED_UNVERIFIED',
      message: testRes.message,
      details: testRes.details,
    };
  }

  /**
   * Sync Templates from BotBiz (Documented endpoint POST /whatsapp/get/template/list)
   */
  async syncTemplates(scope: string = 'NB_DEVELOPER'): Promise<{
    success: boolean;
    count: number;
    templates: BotbizTemplate[];
    error?: string;
  }> {
    const isFinserve = scope === 'NB_FINSERVE';
    const prefix = isFinserve ? 'finserve_' : '';
    const raw = await this.getRawConfig(scope);
    this.botbizClient.updateCredentials(
      raw.apiKey,
      raw.senderId,
      raw.apiBase,
    );

    const res = await this.botbizClient.getTemplateList();
    if (!res.success) {
      return {
        success: false,
        count: 0,
        templates: [],
        error: res.error || 'Failed to fetch templates from BotBiz API',
      };
    }

    const key = `${prefix}whatsapp_botbiz_templates`;
    await prisma.crmSetting.upsert({
      where: { key },
      update: {
        value: JSON.stringify({
          syncedAt: new Date().toISOString(),
          templates: res.templates,
        }),
      },
      create: {
        key,
        value: JSON.stringify({
          syncedAt: new Date().toISOString(),
          templates: res.templates,
        }),
        description: `Cached Meta WhatsApp templates for ${isFinserve ? 'NB Finserve' : 'NB Developer'} synced from BotBiz`,
      },
    });

    return {
      success: true,
      count: res.templates.length,
      templates: res.templates,
    };
  }

  /**
   * Retrieve cached templates
   */
  async getCachedTemplates(scope: string = 'NB_DEVELOPER'): Promise<{
    syncedAt?: string;
    templates: BotbizTemplate[];
  }> {
    const isFinserve = scope === 'NB_FINSERVE';
    const prefix = isFinserve ? 'finserve_' : '';
    const key = `${prefix}whatsapp_botbiz_templates`;
    const row = await prisma.crmSetting.findUnique({
      where: { key },
    });
    if (!row?.value) return { templates: [] };

    try {
      const parsed = JSON.parse(row.value);
      return {
        syncedAt: parsed.syncedAt,
        templates: parsed.templates || [],
      };
    } catch {
      return { templates: [] };
    }
  }

  /**
   * Check individual template approval status (POST /whatsapp/template/status)
   */
  async checkTemplateStatus(
    templateId: string,
    scope: string = 'NB_DEVELOPER',
  ): Promise<BotbizTemplateStatusResponse> {
    const isFinserve = scope === 'NB_FINSERVE';
    const prefix = isFinserve ? 'finserve_' : '';
    const raw = await this.getRawConfig(scope);
    this.botbizClient.updateCredentials(
      raw.apiKey,
      raw.senderId,
      raw.apiBase,
    );

    const statusRes = await this.botbizClient.getTemplateStatus(templateId);

    // Update in cached list if exists
    try {
      const cached = await this.getCachedTemplates(scope);
      const updatedList = cached.templates.map((t) => {
        if (t.id === templateId) {
          return { ...t, status: statusRes.status, rawStatus: statusRes.rawStatus };
        }
        return t;
      });
      const key = `${prefix}whatsapp_botbiz_templates`;
      await prisma.crmSetting.upsert({
        where: { key },
        update: {
          value: JSON.stringify({
            syncedAt: cached.syncedAt || new Date().toISOString(),
            templates: updatedList,
          }),
        },
        create: {
          key,
          value: JSON.stringify({
            syncedAt: new Date().toISOString(),
            templates: updatedList,
          }),
        },
      });
    } catch {}

    return statusRes;
  }

  /**
   * Dynamic Variable Resolver
   * Maps customerName, projectName, loanType, siteVisitDate, siteVisitTime, salespersonName, etc.
   * Ensures no unresolved {{placeholder}} remains.
   */
  renderTemplate(template: string, vars: Record<string, string>, scope: string = 'NB_DEVELOPER'): string {
    const isFinserve = scope === 'NB_FINSERVE';
    let rendered = template;

    // Normalize keys: both camelCase and snake_case supported
    const lookup: Record<string, string> = {};
    for (const [k, v] of Object.entries(vars)) {
      lookup[k.toLowerCase()] = v;
      lookup[k.toLowerCase().replace(/_/g, '')] = v;
    }

    // Replace all {{ tag }} instances
    rendered = rendered.replace(/\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/g, (match, tag) => {
      const normalizedTag = tag.toLowerCase();
      const strippedTag = normalizedTag.replace(/_/g, '');

      if (lookup[normalizedTag] !== undefined && lookup[normalizedTag] !== '') {
        return lookup[normalizedTag];
      }
      if (lookup[strippedTag] !== undefined && lookup[strippedTag] !== '') {
        return lookup[strippedTag];
      }

      // Contextual fallbacks so client never sees unresolved syntax
      if (normalizedTag.includes('customer') || normalizedTag.includes('client') || normalizedTag === 'name') {
        return 'Valued Customer';
      }
      if (normalizedTag.includes('loan')) {
        return 'Loan';
      }
      if (normalizedTag.includes('project') || normalizedTag.includes('entity') || normalizedTag.includes('brand')) {
        return isFinserve ? 'NB Finserve' : 'Legacy Tower';
      }
      if (normalizedTag.includes('date')) {
        return 'the scheduled date';
      }
      if (normalizedTag.includes('time')) {
        return 'the scheduled time';
      }
      if (normalizedTag.includes('salesperson') || normalizedTag.includes('agent') || normalizedTag.includes('advisor')) {
        return isFinserve ? 'our financial advisor' : 'our property advisor';
      }

      return ''; // Clean replacement rather than broken template tag
    });

    return rendered;
  }

  /**
   * Format / Normalize Phone Number
   */
  normalizePhoneNumber(phone: string): string {
    return BotBizApiClient.normalizePhoneNumber(phone);
  }

  /**
   * Add message log item (Keeps up to 150 items)
   */
  async addLog(item: Omit<CrmWhatsappLogItem, 'id' | 'timestamp'>, scope: string = 'NB_DEVELOPER') {
    const isFinserve = scope === 'NB_FINSERVE';
    const prefix = isFinserve ? 'finserve_' : '';
    const key = `${prefix}whatsapp_recent_logs`;

    try {
      const row = await prisma.crmSetting.findUnique({
        where: { key },
      });
      let logs: CrmWhatsappLogItem[] = [];
      if (row?.value) {
        try {
          logs = JSON.parse(row.value);
        } catch {}
      }

      const newLog: CrmWhatsappLogItem = {
        id: 'log_' + Date.now() + '_' + Math.random().toString(36).slice(2, 7),
        ...item,
        timestamp: new Date().toISOString(),
      };

      logs.unshift(newLog);
      if (logs.length > 150) {
        logs = logs.slice(0, 150);
      }

      await prisma.crmSetting.upsert({
        where: { key },
        update: { value: JSON.stringify(logs) },
        create: {
          key,
          value: JSON.stringify(logs),
          description: `Recent dispatched CRM WhatsApp notifications for ${isFinserve ? 'NB Finserve' : 'NB Developer'}`,
        },
      });
    } catch (err) {
      console.error(`[CRM WhatsApp - ${scope}] Failed to save dispatch log:`, err);
    }
  }

  /**
   * Get recent dispatch logs
   */
  async getLogs(limit = 50, scope: string = 'NB_DEVELOPER'): Promise<CrmWhatsappLogItem[]> {
    const isFinserve = scope === 'NB_FINSERVE';
    const prefix = isFinserve ? 'finserve_' : '';
    const key = `${prefix}whatsapp_recent_logs`;

    try {
      const row = await prisma.crmSetting.findUnique({
        where: { key },
      });
      if (!row?.value) return [];
      const parsed = JSON.parse(row.value);
      return Array.isArray(parsed) ? parsed.slice(0, limit) : [];
    } catch {
      return [];
    }
  }

  /**
   * Retry a previously failed message dispatch
   */
  async retryLog(logId: string, scope: string = 'NB_DEVELOPER'): Promise<{ success: boolean; message: string }> {
    const logs = await this.getLogs(150, scope);
    const target = logs.find((l) => l.id === logId);
    if (!target) {
      throw new Error(`Log record ${logId} not found`);
    }

    const res = await this.sendDirect({
      phone: target.phone,
      message: target.message,
      mediaUrl: target.mediaUrl,
      event: target.event,
      leadId: target.leadId,
      messageType: target.messageType,
      templateId: target.templateId,
      scope,
    });

    return {
      success: res.success,
      message: res.success
        ? 'Message retried successfully!'
        : `Retry failed: ${res.error}`,
    };
  }

  /**
   * Send WhatsApp Message via BotBiz or fallback provider
   */
  async sendDirect(params: {
    phone: string;
    message?: string;
    mediaUrl?: string;
    headerMediaUrl?: string;
    headerText?: string;
    event?: string;
    leadId?: string;
    messageType?: WhatsappMessageType;
    templateId?: string;
    templateName?: string;
    templateEndpoint?: string;
    variables?: Record<string, string>;
    scope?: string;
  }): Promise<{ success: boolean; data?: any; error?: string }> {
    const scope = params.scope || 'NB_DEVELOPER';
    const raw = await this.getRawConfig(scope);
    const normalizedPhone = this.normalizePhoneNumber(params.phone);

    const messageText = params.message || (params.templateName ? `Template: ${params.templateName}` : (params.templateId ? `Template: ${params.templateId}` : 'WhatsApp Notification'));

    if (!normalizedPhone || normalizedPhone.length < 10) {
      const errMsg = 'Invalid or missing recipient phone number';
      await this.addLog({
        phone: params.phone,
        event: params.event || 'MANUAL',
        leadId: params.leadId,
        message: messageText,
        mediaUrl: params.mediaUrl,
        status: 'FAILED',
        error: errMsg,
      }, scope);
      return { success: false, error: errMsg };
    }

    if (!raw.enabled) {
      await this.addLog({
        phone: normalizedPhone,
        event: params.event || 'MANUAL',
        leadId: params.leadId,
        message: messageText,
        mediaUrl: params.mediaUrl,
        status: 'DISABLED',
        error: `WhatsApp automation is currently disabled in ${scope === 'NB_FINSERVE' ? 'NB Finserve' : 'NB Developer'} settings`,
      }, scope);
      return { success: false, error: 'WhatsApp automation is disabled' };
    }

    // Deduplication check: prevent duplicate dispatch within 30 seconds
    const dedupKey = `${scope}:${params.event || 'MSG'}:${normalizedPhone}:${params.leadId || ''}`;
    const lastSent = this.recentDispatches.get(dedupKey);
    const now = Date.now();
    if (lastSent && now - lastSent < 30000) {
      console.log(`[CRM WhatsApp - ${scope}] Suppressing duplicate dispatch to ${normalizedPhone} (${dedupKey})`);
      return {
        success: true,
        data: { deduplicated: true, message: 'Duplicate dispatch suppressed' },
      };
    }
    this.recentDispatches.set(dedupKey, now);

    this.botbizClient.updateCredentials(
      raw.apiKey,
      raw.senderId,
      raw.apiBase,
    );

    // 1. Template Message Dispatch (Meta Approved Template)
    if (params.messageType === 'TEMPLATE' && params.templateId) {
      // Validate template approval status
      const cached = await this.getCachedTemplates(scope);
      const tmpl = cached.templates.find(
        (t) =>
          t.id === params.templateId ||
          t.name === params.templateName ||
          String(t.raw?.id) === params.templateId,
      );

      if (tmpl && tmpl.status !== 'APPROVED') {
        const errMsg = `Template "${tmpl.name}" is currently ${tmpl.status}. Only APPROVED templates can be dispatched outside customer-care window.`;
        await this.addLog({
          phone: normalizedPhone,
          event: params.event || 'MANUAL',
          leadId: params.leadId,
          message: messageText,
          messageType: 'TEMPLATE',
          templateId: params.templateId,
          status: 'FAILED',
          error: errMsg,
        }, scope);
        return { success: false, error: errMsg };
      }

      // Use internal BotBiz ID if present (BotBiz API requires internal template ID)
      const botbizInternalId = tmpl?.raw?.id ? String(tmpl.raw.id) : params.templateId;

      const headerMediaUrl =
        params.headerMediaUrl ||
        params.mediaUrl ||
        tmpl?.headerExampleUrl;

      const sendRes = await this.botbizClient.sendTemplateMessage({
        phoneNumber: normalizedPhone,
        templateId: botbizInternalId,
        templateName: params.templateName || tmpl?.name || 'CRM_NOTIFICATION',
        templateEndpointUrl: params.templateEndpoint,
        templateHeaderMediaUrl: headerMediaUrl,
        templateHeaderText: params.headerText,
        variables: params.variables,
      });

      await this.addLog({
        phone: normalizedPhone,
        event: params.event || 'MANUAL',
        leadId: params.leadId,
        message: messageText,
        messageType: 'TEMPLATE',
        templateId: params.templateId,
        waMessageId: sendRes.waMessageId,
        status: sendRes.success ? 'SENT' : 'FAILED',
        error: sendRes.error,
        httpStatus: sendRes.httpStatus,
      }, scope);

      return {
        success: sendRes.success,
        data: sendRes.rawResponse,
        error: sendRes.error,
      };
    }

    // 2. Free-Form Text Message Dispatch (Documented POST /whatsapp/send)
    const sendRes = await this.botbizClient.sendTextMessage({
      phoneNumber: normalizedPhone,
      message: messageText,
      mediaUrl: params.mediaUrl,
    });

    await this.addLog({
      phone: normalizedPhone,
      event: params.event || 'MANUAL',
      leadId: params.leadId,
      message: messageText,
      messageType: 'TEXT',
      mediaUrl: params.mediaUrl,
      waMessageId: sendRes.waMessageId,
      status: sendRes.success ? 'SENT' : 'FAILED',
      error: sendRes.error,
      httpStatus: sendRes.httpStatus,
    }, scope);

    return {
      success: sendRes.success,
      data: sendRes.rawResponse,
      error: sendRes.error,
    };
  }

  /**
   * Dispatch trigger event for a CRM lead (LEAD_CREATED, SITE_VISIT_SCHEDULED, etc.)
   * Safe asynchronous non-blocking execution.
   */
  async triggerEvent(
    event: string,
    lead: {
      id?: string;
      name?: string | null;
      phone?: string | null;
      customFields?: any;
      assignedTo?: any;
      scope?: string;
    },
    context?: {
      projectName?: string;
      visitDate?: string | Date;
      visitTime?: string;
      callDuration?: number;
      remarks?: string;
      agentName?: string;
      agentPhone?: string;
      paymentAmount?: string | number;
      loanType?: string;
      scope?: string;
    },
  ) {
    try {
      const scope = context?.scope || (lead as any)?.scope || 'NB_DEVELOPER';
      const isFinserve = scope === 'NB_FINSERVE';
      const raw = await this.getRawConfig(scope);
      if (!raw.enabled) return;

      const normalizedEvent = event.toUpperCase();
      const trigger = raw.triggers.find(
        (t) =>
          (t.event.toUpperCase() === normalizedEvent ||
            (normalizedEvent === 'SITE_VISIT_SCHEDULED' && t.event.toUpperCase() === 'VISIT_SCHEDULED') ||
            (normalizedEvent === 'SITE_VISIT_DONE' && t.event.toUpperCase() === 'VISIT_DONE') ||
            (normalizedEvent === 'VISIT_SCHEDULED' && t.event.toUpperCase() === 'SITE_VISIT_SCHEDULED') ||
            (normalizedEvent === 'VISIT_DONE' && t.event.toUpperCase() === 'SITE_VISIT_DONE')) &&
          t.enabled,
      );
      if (!trigger) {
        return; // Trigger not active or configured
      }

      const phone =
        lead.phone ||
        (lead.customFields &&
          (lead.customFields.phone || lead.customFields.Phone)) ||
        '';
      if (!phone) return;

      const customerName =
        lead.name ||
        (lead.customFields &&
          (lead.customFields.client_name ||
            lead.customFields.Client_Name ||
            lead.customFields.Name ||
            lead.customFields.customerName)) ||
        'Valued Customer';

      const projectName =
        context?.projectName || raw.defaultProjectName || (isFinserve ? 'NB Finserve' : 'Legacy Tower');
      const locationUrl =
        trigger.locationUrl ||
        raw.defaultLocationUrl ||
        (isFinserve ? '' : 'https://maps.google.com/?q=Legacy+Tower');
      const brochureUrl =
        trigger.mediaUrl || raw.defaultBrochureUrl || '';

      // Format Date & Time
      let formattedDate = 'Upcoming Date';
      let rawDateStr = '';
      if (context?.visitDate) {
        const d = new Date(context.visitDate);
        if (!isNaN(d.getTime())) {
          formattedDate = d.toLocaleDateString('en-IN', {
            weekday: 'short',
            day: 'numeric',
            month: 'short',
            year: 'numeric',
          });
          rawDateStr = d.toISOString();
        }
      }

      const formattedTime = context?.visitTime || '11:00 AM';

      // Generate Calendar Link
      let calendarLink = '';
      if (trigger.includeCalendarLink) {
        calendarLink = WhatsappService.buildGoogleCalendarUrl({
          title: isFinserve ? `Consultation Meeting - ${projectName}` : `Site Visit - ${projectName}`,
          details: `Confirmed ${isFinserve ? 'Consultation' : 'Site Visit'} with ${projectName}. Date: ${formattedDate}, Time: ${formattedTime}.\n${locationUrl ? `Location: ${locationUrl}` : ''}`,
          location: locationUrl,
          dateStr: rawDateStr,
          timeStr: formattedTime,
        });
      }

      const agentName =
        context?.agentName ||
        lead.assignedTo?.generalInfo?.fullName ||
        (isFinserve ? 'Financial Advisor' : 'Property Advisor');
      const agentPhone =
        context?.agentPhone ||
        lead.assignedTo?.generalInfo?.mobileNumber ||
        'Support Team';
      const loanType =
        context?.loanType ||
        (lead.customFields && (lead.customFields.loan_type || lead.customFields.Loan_Type)) ||
        'Loan';

      const variables: Record<string, string> = {
        customerName,
        client_name: customerName,
        name: customerName,
        phone,
        projectName,
        project_name: projectName,
        project: projectName,
        loanType,
        loantype: loanType,
        loan_type: loanType,
        siteVisitDate: formattedDate,
        visit_date: formattedDate,
        date: formattedDate,
        siteVisitTime: formattedTime,
        visit_time: formattedTime,
        time: formattedTime,
        salespersonName: agentName,
        agent_name: agentName,
        salespersonPhone: agentPhone,
        agent_phone: agentPhone,
        paymentAmount: String(context?.paymentAmount || '0'),
        amount: String(context?.paymentAmount || '0'),
        locationUrl,
        map_pin: locationUrl,
        calendarLink,
        brochureUrl,
      };

      const finalMessage = this.renderTemplate(
        trigger.messageTemplate,
        variables,
        scope,
      );

      console.log(
        `[CRM WhatsApp - ${scope}] Triggering "${trigger.name}" (${trigger.event}) for lead ${lead.id || 'N/A'} (${phone})`,
      );

      await this.sendDirect({
        phone,
        message: finalMessage,
        mediaUrl: trigger.mediaUrl,
        headerMediaUrl: trigger.headerMediaUrl || trigger.mediaUrl,
        event,
        leadId: lead.id,
        messageType: trigger.messageType,
        templateId: trigger.templateId,
        templateName: trigger.templateName,
        templateEndpoint: trigger.templateEndpoint,
        variables,
        scope,
      });
    } catch (err) {
      console.error(`[CRM WhatsApp - ${event} Error]:`, err);
    }
  }
}

export const whatsappService = new WhatsappService();
