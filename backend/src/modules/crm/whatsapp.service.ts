import { prisma } from '../../config/prisma';
import {
  BotBizApiClient,
  BotbizTemplate,
  BotbizTemplateStatusResponse,
} from './botbiz.client';
import {
  BOTBIZ_LEGACY_TOWER_PDF,
  CLOUDINARY_LEGACY_TOWER_PDF,
  CLOUDINARY_NB_FINSERVE_PDF,
  CLOUDINARY_DEFAULT_IMAGE,
} from './default-brochure';

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
    messageType: 'TEMPLATE',
    templateName: 'cal',
    messageTemplate: 'Template: cal',
    mediaUrl: '',
    includeCalendarLink: true,
    locationUrl: 'https://maps.google.com/?q=Legacy+Tower',
  },
  {
    id: 'trigger_site_visit_rescheduled',
    event: 'SITE_VISIT_RESCHEDULED',
    name: 'Site Visit Rescheduled Notice',
    enabled: true,
    messageType: 'TEMPLATE',
    templateName: 'cal',
    messageTemplate: 'Template: cal',
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
    messageType: 'TEMPLATE',
    templateName: 'visit_done',
    messageTemplate: 'Template: visit_done',
    mediaUrl: 'https://nbdeveloper.co.in/brochures/legacy-tower.pdf',
    includeCalendarLink: false,
    locationUrl: '',
  },
  {
    id: 'trigger_site_visit_reminder',
    event: 'SITE_VISIT_REMINDER',
    name: 'Site Visit Day Reminder',
    enabled: true,
    messageType: 'TEMPLATE',
    templateName: 'visit_reminder',
    messageTemplate: 'Template: visit_reminder',
    mediaUrl: '',
    includeCalendarLink: false,
    locationUrl: 'https://maps.google.com/?q=Legacy+Tower',
  },
  {
    id: 'trigger_lead_created',
    event: 'LEAD_CREATED',
    name: 'New Lead Welcome (Inquiry Acknowledgment)',
    enabled: true,
    messageType: 'TEMPLATE',
    templateName: 'newlead',
    messageTemplate: 'Template: newlead',
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
   * Suggested BotBiz template names per CRM event (admin can override in Settings).
   */
  private suggestedTemplateNameForEvent(event: string): string | undefined {
    const e = String(event || '').toUpperCase();
    const map: Record<string, string> = {
      SITE_VISIT_REMINDER: 'visit_reminder',
      SITE_VISIT_SCHEDULED: 'cal',
      SCHEDULED_VISIT: 'cal',
      VISIT_SCHEDULED: 'cal',
      SITE_VISIT_RESCHEDULED: 'cal',
      LEAD_CREATED: 'newlead',
      SITE_VISIT_DONE: 'visit_done',
      VISIT_DONE: 'visit_done',
    };
    return map[e];
  }

  /**
   * Bind each trigger to a synced Meta template by id or name.
   * Keeps admin choice dynamic — never hard-locks a template id.
   */
  bindTriggersToTemplates(
    triggers: CrmWhatsappTrigger[],
    templates: BotbizTemplate[],
  ): { triggers: CrmWhatsappTrigger[]; changed: boolean } {
    if (!Array.isArray(triggers) || triggers.length === 0) {
      return { triggers: triggers || [], changed: false };
    }
    let changed = false;
    const next = triggers.map((t) => {
      const byId = t.templateId
        ? templates.find(
            (x) =>
              x.id === t.templateId ||
              String(x.raw?.id) === t.templateId ||
              String(x.raw?.template_id) === t.templateId ||
              x.name?.toLowerCase() === String(t.templateId).toLowerCase(),
          )
        : undefined;
      if (byId) {
        if (t.templateName !== byId.name || t.messageType !== 'TEMPLATE') {
          changed = true;
          return {
            ...t,
            templateId: byId.id,
            templateName: byId.name,
            messageType: 'TEMPLATE' as WhatsappMessageType,
          };
        }
        return t;
      }

      const wantName = (
        t.templateName ||
        this.suggestedTemplateNameForEvent(t.event) ||
        ''
      )
        .trim()
        .toLowerCase();
      if (!wantName) return t;

      const byName = templates.find((x) => x.name?.toLowerCase() === wantName);
      if (!byName) return t;

      changed = true;
      return {
        ...t,
        templateId: byName.id,
        templateName: byName.name,
        messageType: 'TEMPLATE' as WhatsappMessageType,
        messageTemplate: t.messageTemplate?.startsWith('Template:')
          ? `Template: ${byName.name}`
          : t.messageTemplate || `Template: ${byName.name}`,
      };
    });
    return { triggers: next, changed };
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

    const keysToFetch = [
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
    ];
    if (isFinserve) {
      keysToFetch.push(
        'whatsapp_enabled',
        'whatsapp_provider',
        'whatsapp_api_base',
        'whatsapp_api_url',
        'whatsapp_api_key',
        'whatsapp_sender_id',
        'whatsapp_default_calendar_link',
        'whatsapp_calendar_link',
        'whatsapp_default_brochure_url',
        'whatsapp_default_brochure_name',
        'whatsapp_default_location_url',
        'whatsapp_default_project_name',
      );
    }

    const settings = await prisma.crmSetting.findMany({
      where: {
        key: { in: keysToFetch },
      },
    });

    const defaultMap: Record<string, string> = {};
    const finserveMap: Record<string, string> = {};

    for (const s of settings) {
      if (s.value !== undefined && s.value !== null) {
        if (s.key.startsWith('finserve_')) {
          finserveMap[s.key.substring('finserve_'.length)] = s.value;
        } else {
          defaultMap[s.key] = s.value;
        }
      }
    }

    const map = isFinserve ? { ...defaultMap, ...finserveMap } : defaultMap;

    // Merge DB values with Environment Variables (with fallback to main credentials)
    const envApiBase = process.env.BOTBIZ_API_BASE;
    const envApiToken =
      (isFinserve ? process.env.FINSERVE_BOTBIZ_API_TOKEN : undefined) ||
      process.env.BOTBIZ_API_TOKEN ||
      '';
    const envPhoneId =
      (isFinserve ? process.env.FINSERVE_BOTBIZ_PHONE_NUMBER_ID : undefined) ||
      process.env.BOTBIZ_PHONE_NUMBER_ID ||
      '';

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
          // Repair older saved TEXT triggers that never had a Meta template mapped:
          // keep admin overrides (templateId / templateName) but fill suggested names.
          const repaired = parsed.map((t: CrmWhatsappTrigger) => {
            const def = defaultList.find((d) => d.event === t.event);
            const suggested =
              (t.templateName && String(t.templateName).trim()) ||
              def?.templateName ||
              this.suggestedTemplateNameForEvent(t.event);
            if (!suggested) return t;
            if (t.templateId || (t.messageType === 'TEMPLATE' && t.templateName)) {
              return t;
            }
            return {
              ...t,
              messageType: 'TEMPLATE' as WhatsappMessageType,
              templateName: suggested,
              messageTemplate:
                t.messageTemplate?.startsWith('Template:') || !t.messageTemplate
                  ? `Template: ${suggested}`
                  : t.messageTemplate,
            };
          });
          triggers = [...repaired, ...missingDefaults];
        }
      } catch (err) {
        console.error(`[CRM WhatsApp - ${scope}] Failed to parse triggers JSON:`, err);
      }
    }

    // Resolve each trigger's Meta template dynamically from the synced BotBiz list.
    try {
      const cached = await this.getCachedTemplates(scope);
      if (cached.templates.length > 0) {
        triggers = this.bindTriggersToTemplates(triggers, cached.templates).triggers;
      }
    } catch (_) {}

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
        map.whatsapp_default_brochure_url ||
        (isFinserve ? CLOUDINARY_NB_FINSERVE_PDF : BOTBIZ_LEGACY_TOWER_PDF),
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
    // Sanitize header URLs before persisting to cache:
    // - Replace Wasabi S3 URLs (slow, >50MB) with reliable local brochure URL
    // - Replace Meta 4:: handles (not public HTTP) with Cloudinary fallback image
    const sanitized = this.sanitizeTemplateHeaderUrls(res.templates, isFinserve);
    await prisma.crmSetting.upsert({
      where: { key },
      update: {
        value: JSON.stringify({
          syncedAt: new Date().toISOString(),
          templates: sanitized,
        }),
      },
      create: {
        key,
        value: JSON.stringify({
          syncedAt: new Date().toISOString(),
          templates: sanitized,
        }),
        description: `Cached Meta WhatsApp templates for ${isFinserve ? 'NB Finserve' : 'NB Developer'} synced from BotBiz`,
      },
    });

    // After sync: auto-map unmapped triggers (by name / event suggestion) and persist.
    try {
      const bound = this.bindTriggersToTemplates(raw.triggers, sanitized);
      if (bound.changed) {
        await prisma.crmSetting.upsert({
          where: { key: `${prefix}whatsapp_triggers` },
          update: { value: JSON.stringify(bound.triggers) },
          create: {
            key: `${prefix}whatsapp_triggers`,
            value: JSON.stringify(bound.triggers),
            description: `WhatsApp event triggers for ${isFinserve ? 'NB Finserve' : 'NB Developer'}`,
          },
        });
      }
    } catch (err) {
      console.warn(`[CRM WhatsApp - ${scope}] Trigger auto-bind after sync failed:`, err);
    }

    return {
      success: true,
      count: sanitized.length,
      templates: sanitized,
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
    if (!row?.value) {
      if (isFinserve) {
        return this.getCachedTemplates('NB_DEVELOPER');
      }
      return { templates: [] };
    }

    try {
      const parsed = JSON.parse(row.value);
      const list: BotbizTemplate[] = parsed.templates || [];
      if (list.length === 0 && isFinserve) {
        return this.getCachedTemplates('NB_DEVELOPER');
      }
      return {
        syncedAt: parsed.syncedAt,
        templates: this.sanitizeTemplateHeaderUrls(list, isFinserve),
      };
    } catch {
      if (isFinserve) {
        return this.getCachedTemplates('NB_DEVELOPER');
      }
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
   * Sanitize template header URLs:
   * - Wasabi S3 URLs (large, slow) => local brochure URL
   * - Meta 4:: handles (non-HTTP) => Cloudinary image or local PDF
   */
  private sanitizeTemplateHeaderUrls(templates: BotbizTemplate[], isFinserve: boolean): BotbizTemplate[] {
    const localPdf = isFinserve
      ? CLOUDINARY_NB_FINSERVE_PDF
      : BOTBIZ_LEGACY_TOWER_PDF;
    return templates.map((t) => {
      const url = t.headerExampleUrl;
      if (!url) return t;
      // Replace Meta internal handles (4:: prefix) — these are not public HTTP URLs
      if (url.startsWith('4::')) {
        return { ...t, headerExampleUrl: CLOUDINARY_DEFAULT_IMAGE };
      }
      // Keep valid HTTP/HTTPS URLs (including Wasabi S3 — BotBiz fetches these server-side)
      return t;
    });
  }

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
  }): Promise<{
    success: boolean;
    data?: any;
    error?: string;
    skipped?: boolean;
    message?: string;
  }> {
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

    // Deduplication check: prevent duplicate dispatch within 30 seconds for automated background events
    const isManual = params.event === 'MANUAL_DISPATCH' || params.event === 'MANUAL' || params.event === 'TEST';
    const dedupKey = `${scope}:${params.event || 'MSG'}:${normalizedPhone}:${params.leadId || ''}`;
    const lastSent = this.recentDispatches.get(dedupKey);
    const now = Date.now();
    if (!isManual && lastSent && now - lastSent < 30000) {
      console.log(`[CRM WhatsApp - ${scope}] Suppressing duplicate automated dispatch to ${normalizedPhone} (${dedupKey})`);
      // Not a delivery success — caller must not treat this as "message sent to WhatsApp".
      return {
        success: true,
        skipped: true,
        data: {
          deduplicated: true,
          skipped: true,
          message: 'Duplicate automated dispatch suppressed (already sent within 30s)',
        },
        message: 'Duplicate automated dispatch suppressed (already sent within 30s)',
      };
    }
    this.recentDispatches.set(dedupKey, now);

    this.botbizClient.updateCredentials(
      raw.apiKey,
      raw.senderId,
      raw.apiBase,
    );

    // 1. Template Message Dispatch (Meta Approved Template)
    // Allow templateName-only (e.g. visit_reminder) — resolve BotBiz id from cache.
    if (params.messageType === 'TEMPLATE' && (params.templateId || params.templateName)) {
      const cached = await this.getCachedTemplates(scope);
      const matchTmpl = (list: typeof cached.templates) =>
        list.find(
          (t) =>
            (params.templateId &&
              (t.id === params.templateId ||
                t.name?.toLowerCase() === params.templateId?.toLowerCase() ||
                String(t.raw?.id) === params.templateId ||
                String(t.raw?.template_id) === params.templateId)) ||
            (params.templateName &&
              t.name?.toLowerCase() === params.templateName.toLowerCase()),
        );
      let tmpl = matchTmpl(cached.templates);

      // Auto-refresh cache if template not found
      if (!tmpl) {
        try {
          const syncRes = await this.syncTemplates(scope);
          tmpl = matchTmpl(syncRes.templates);
        } catch (_) {}
      }

      if (!params.templateId && tmpl?.id) {
        params.templateId = tmpl.id;
      }
      if (!params.templateId) {
        const errMsg = `WhatsApp template "${params.templateName || 'unknown'}" not found. Sync templates from BotBiz first.`;
        await this.addLog({
          phone: normalizedPhone,
          event: params.event || 'MANUAL',
          leadId: params.leadId,
          message: messageText,
          messageType: 'TEMPLATE',
          status: 'FAILED',
          error: errMsg,
        }, scope);
        return { success: false, error: errMsg };
      }

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

      const isNewlead =
        params.templateId === '1443065537184471' ||
        params.templateId === '463170' ||
        params.templateName?.toLowerCase() === 'newlead' ||
        tmpl?.name?.toLowerCase() === 'newlead';

      // Use internal BotBiz ID (BotBiz API requires internal template ID like 463170, not Meta template ID)
      const botbizInternalId = tmpl?.raw?.id
        ? String(tmpl.raw.id)
        : (isNewlead ? '463170' : params.templateId);

      let headerMediaUrl = params.headerMediaUrl || params.mediaUrl;
      // Strip any raw Meta handles (e.g. 4::...), slow Wasabi S3 URLs, or non-HTTP values
      if (
        headerMediaUrl &&
        (headerMediaUrl.startsWith('4::') ||
          (!headerMediaUrl.startsWith('http://') && !headerMediaUrl.startsWith('https://')))
      ) {
        headerMediaUrl = undefined;
      }
      if (!headerMediaUrl && tmpl?.headerExampleUrl && (tmpl.headerExampleUrl.startsWith('http://') || tmpl.headerExampleUrl.startsWith('https://'))) {
        headerMediaUrl = tmpl.headerExampleUrl;
      }

      // Check if template requires a media header (DOCUMENT, IMAGE, VIDEO)
      const tmplHeaderType = (tmpl?.headerFormat || tmpl?.raw?.header_type || tmpl?.raw?.header_subtype || '').toString().toUpperCase();
      const isFinserve = scope === 'NB_FINSERVE';
      const isImage = tmplHeaderType.includes('IMAGE') || tmpl?.headerFormat?.toLowerCase() === 'image';
      const isDocument = isNewlead || tmplHeaderType.includes('DOCUMENT') || tmpl?.headerFormat?.toLowerCase() === 'document';
      const isTextHeader = tmplHeaderType.includes('TEXT') || tmpl?.headerFormat?.toLowerCase() === 'text';
      const needsMediaHeader = isImage || isDocument || tmplHeaderType.includes('VIDEO') || tmplHeaderType.includes('MEDIA');

      // Auto-correct MIME mismatch: don't send a PDF to an image header, or an image to a document header
      if (isImage && headerMediaUrl && (headerMediaUrl.toLowerCase().endsWith('.pdf') || headerMediaUrl.toLowerCase().includes('.pdf'))) {
        headerMediaUrl = CLOUDINARY_DEFAULT_IMAGE;
      }
      if (isDocument && (
        !headerMediaUrl ||
        /\.(jpe?g|png|webp)($|\?)/i.test(headerMediaUrl)
      )) {
        // For newlead (document header): use the original Wasabi S3 PDF — BotBiz fetches it server-side
        headerMediaUrl = isNewlead
          ? 'https://bot-data.s3.ap-southeast-1.wasabisys.com/flowbuilder/306044/306044/whatsapp-440327/flowbuilder-306044-1792663002.pdf'
          : (isFinserve ? CLOUDINARY_NB_FINSERVE_PDF : BOTBIZ_LEGACY_TOWER_PDF);
      }

      if (!headerMediaUrl && needsMediaHeader) {
        if (isImage) {
          headerMediaUrl = CLOUDINARY_DEFAULT_IMAGE;
        } else if (raw.defaultBrochureUrl && (raw.defaultBrochureUrl.startsWith('http://') || raw.defaultBrochureUrl.startsWith('https://'))) {
          headerMediaUrl = raw.defaultBrochureUrl;
        } else {
          headerMediaUrl = isFinserve ? CLOUDINARY_NB_FINSERVE_PDF : BOTBIZ_LEGACY_TOWER_PDF;
        }
      }

      // Prefer placeholder names from body text. Site-visit templates need name+date+time.
      const allowedVars = tmpl
        ? (tmpl.bodyExampleVariables && tmpl.bodyExampleVariables.length > 0
            ? tmpl.bodyExampleVariables
            : (tmpl.variableCount === 0 || !tmpl.bodyText?.includes('{{')
                ? []
                : ['name', 'date', 'time']))
        : (isNewlead ? ['name'] : ['name', 'date', 'time']);

      const resolvedVariables = { ...(params.variables || {}) };
      if (isNewlead && (!resolvedVariables.name || String(resolvedVariables.name).trim() === '')) {
        resolvedVariables.name = resolvedVariables.customerName || resolvedVariables.client_name || 'Valued Client';
      }

      // Fill missing placeholder values with strict aliases only.
      // Do NOT use includes('name') / includes('time') — that mapped projectName→name and
      // could leave the wrong value on the name slot for BotBiz.
      if (allowedVars && allowedVars.length > 0) {
        const pickVar = (...keys: string[]) => {
          for (const k of keys) {
            const v = resolvedVariables[k];
            if (v != null && String(v).trim() !== '') return String(v).trim();
          }
          return undefined;
        };
        for (const key of allowedVars) {
          if (resolvedVariables[key] != null && String(resolvedVariables[key]).trim() !== '') continue;
          const lower = String(key).toLowerCase();
          if (
            lower === '1' ||
            lower === 'name' ||
            lower === 'customername' ||
            lower === 'customer_name' ||
            lower === 'client_name' ||
            lower === 'clientname'
          ) {
            resolvedVariables[key] =
              pickVar('name', 'customerName', 'client_name', 'customer_name', '1') || 'Valued Client';
          } else if ( lower === 'pname' ) {
            resolvedVariables[key] = pickVar('pname', 'projectName', 'project', 'project_name') || '';
          } else if (
            lower === '2' ||
            lower === 'date' ||
            lower === 'visit_date' ||
            lower === 'sitevisitdate' ||
            lower === 'site_visit_date'
          ) {
            resolvedVariables[key] = pickVar('date', 'visit_date', 'siteVisitDate', '2') || '';
          } else if (
            lower === '3' ||
            lower === 'time' ||
            lower === 'visit_time' ||
            lower === 'sitevisittime' ||
            lower === 'site_visit_time'
          ) {
            resolvedVariables[key] = pickVar('time', 'visit_time', 'siteVisitTime', '3') || '';
          } else if (lower === 'project' || lower === 'projectname' || lower === 'project_name') {
            resolvedVariables[key] = pickVar('projectName', 'project', 'pname', 'project_name') || '';
          } else if (lower === 'phone' || lower === 'number') {
            resolvedVariables[key] = pickVar('phone', 'number') || normalizedPhone;
          } else if (resolvedVariables[lower] != null) {
            resolvedVariables[key] = String(resolvedVariables[lower]);
          }
        }
      }

      // If BotBiz/Meta template only declares `name`, force that value from the lead —
      // never allow an empty name to fall through to another field.
      const isPersonNameKey = (k: string) => {
        const lower = String(k).toLowerCase();
        return (
          lower === 'name' ||
          lower === '1' ||
          lower === 'customername' ||
          lower === 'customer_name' ||
          lower === 'client_name' ||
          lower === 'clientname'
        );
      };
      const nameOnly =
        Array.isArray(allowedVars) &&
        allowedVars.length > 0 &&
        allowedVars.every((k) => isPersonNameKey(String(k)));
      // Always sanitize the person name — reject clock / project values in the greeting.
      {
        const looksLikeClock = (s: string) =>
          /^\d{1,2}:\d{2}(\s*[AaPp][Mm])?$/.test(String(s).trim());
        const looksLikeProject = (s: string) => {
          const n = String(s || '')
            .trim()
            .toLowerCase()
            .replace(/\s+/g, ' ');
          if (!n) return false;
          const projectCmp = String(
            resolvedVariables.projectName ||
              resolvedVariables.project ||
              resolvedVariables.pname ||
              '',
          )
            .trim()
            .toLowerCase();
          const known = new Set([
            'legacy tower',
            'nb legacy tower',
            'nb finserve',
            'nb infra',
            'nb infra projects',
            'nb infra projects ltd',
          ]);
          return n === projectCmp || known.has(n);
        };
        const safePerson = (...vals: Array<string | undefined>) => {
          for (const v of vals) {
            if (!v) continue;
            const s = String(v).trim();
            if (!s || looksLikeClock(s) || looksLikeProject(s)) continue;
            return s;
          }
          return 'Valued Client';
        };
        const leadName = safePerson(
          resolvedVariables.name,
          resolvedVariables.customerName,
          resolvedVariables.client_name,
          resolvedVariables.Client_Name,
        );
        resolvedVariables.name = leadName;
        resolvedVariables.customerName = leadName;
        resolvedVariables.client_name = leadName;
        resolvedVariables.Client_Name = leadName;
        if (nameOnly) {
          for (const k of allowedVars!) {
            resolvedVariables[k] = leadName;
          }
        }
      }

      // TEXT header — never auto-fill with project name (BotBiz leaked that into
      // body {{1}} as "Dear Legacy Tower"). Only forward an explicit safe header.
      let headerText = params.headerText?.trim() || undefined;
      if (headerText) {
        const ht = headerText.toLowerCase().replace(/\s+/g, ' ');
        const projectCmp = String(
          resolvedVariables.projectName || resolvedVariables.project || '',
        )
          .trim()
          .toLowerCase();
        const known = new Set([
          'legacy tower',
          'nb legacy tower',
          'nb finserve',
          'nb infra',
          'nb infra projects',
          'nb infra projects ltd',
        ]);
        if (ht === projectCmp || known.has(ht) || /^\d{1,2}:\d{2}/.test(headerText.trim())) {
          headerText = undefined;
        }
      }
      if (isTextHeader && !headerText) {
        const candidate =
          resolvedVariables.header_text ||
          resolvedVariables.headerText ||
          resolvedVariables.header_variable ||
          undefined;
        if (candidate && String(candidate).trim()) {
          const ct = String(candidate).trim().toLowerCase().replace(/\s+/g, ' ');
          const projectCmp = String(
            resolvedVariables.projectName || resolvedVariables.project || '',
          )
            .trim()
            .toLowerCase();
          const known = new Set([
            'legacy tower',
            'nb legacy tower',
            'nb finserve',
            'nb infra',
            'nb infra projects',
            'nb infra projects ltd',
          ]);
          if (ct !== projectCmp && !known.has(ct)) {
            headerText = String(candidate).trim();
          }
        }
      }

      const sendRes = await this.botbizClient.sendTemplateMessage({
        phoneNumber: normalizedPhone,
        templateId: botbizInternalId,
        templateName: params.templateName || tmpl?.name || (isNewlead ? 'newlead' : 'CRM_NOTIFICATION'),
        templateEndpointUrl: params.templateEndpoint,
        templateHeaderMediaUrl: headerMediaUrl,
        templateHeaderText: headerText,
        variables: resolvedVariables,
        allowedVariableNames: allowedVars,
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
  ): Promise<{ success: boolean; skipped?: boolean; error?: string; data?: any; message?: string }> {
    try {
      const scope = context?.scope || (lead as any)?.scope || 'NB_DEVELOPER';
      const isFinserve = scope === 'NB_FINSERVE';
      const raw = await this.getRawConfig(scope);
      if (!raw.enabled) {
        return { success: false, skipped: true, error: 'WhatsApp automation is disabled' };
      }

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
        return { success: false, skipped: true, error: `No enabled WhatsApp trigger for ${normalizedEvent}` };
      }

      const phone =
        lead.phone ||
        (lead.customFields &&
          (lead.customFields.phone || lead.customFields.Phone)) ||
        '';
      if (!phone) {
        return { success: false, error: 'Lead has no phone number for WhatsApp dispatch' };
      }

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

      // Format Date & Time (BotBiz slots prefer dd/MM/yyyy + hh:mm a)
      let formattedDate = 'Upcoming Date';
      let botbizDate = formattedDate;
      let rawDateStr = '';
      let formattedTime = context?.visitTime || '';
      if (context?.visitDate) {
        const d = new Date(context.visitDate);
        if (!isNaN(d.getTime())) {
          formattedDate = d.toLocaleDateString('en-IN', {
            weekday: 'short',
            day: 'numeric',
            month: 'short',
            year: 'numeric',
            timeZone: 'Asia/Kolkata',
          });
          botbizDate = d.toLocaleDateString('en-GB', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
            timeZone: 'Asia/Kolkata',
          });
          rawDateStr = d.toISOString();
          if (!formattedTime) {
            formattedTime = d.toLocaleTimeString('en-IN', {
              hour: '2-digit',
              minute: '2-digit',
              hour12: true,
              timeZone: 'Asia/Kolkata',
            });
          }
        }
      }
      if (!formattedTime) formattedTime = '11:00 AM';
      // Normalize "11:00" → "11:00 AM" when caller passed 24h HH:mm
      if (/^\d{1,2}:\d{2}$/.test(String(formattedTime).trim())) {
        const [hh, mm] = String(formattedTime).trim().split(':').map(Number);
        const probe = new Date();
        probe.setHours(hh, mm, 0, 0);
        formattedTime = probe.toLocaleTimeString('en-IN', {
          hour: '2-digit',
          minute: '2-digit',
          hour12: true,
        });
      }

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
        visit_date: botbizDate,
        date: botbizDate,
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

      const sendRes = await this.sendDirect({
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
      return {
        success: !!sendRes?.success,
        skipped: !!(sendRes as any)?.skipped,
        error: (sendRes as any)?.error,
        data: (sendRes as any)?.data,
        message: (sendRes as any)?.message,
      };
    } catch (err: any) {
      console.error(`[CRM WhatsApp - ${event} Error]:`, err);
      return {
        success: false,
        error: err?.message || `WhatsApp trigger ${event} failed`,
      };
    }
  }
}

export const whatsappService = new WhatsappService();
