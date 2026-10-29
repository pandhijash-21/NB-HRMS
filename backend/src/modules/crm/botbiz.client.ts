/**
 * BotBiz WhatsApp API Client
 *
 * Implements documented BotBiz endpoints:
 * 1. Send free-form text message:
 *    POST https://dash.botbiz.io/api/v1/whatsapp/send (x-www-form-urlencoded)
 *    Parameters: apiToken, phone_number_id, phone_number, message
 *
 * 2. Fetch connected templates:
 *    POST https://dash.botbiz.io/api/v1/whatsapp/get/template/list (x-www-form-urlencoded)
 *    Parameters: apiToken, phone_number_id
 *
 * 3. Check template approval status:
 *    POST https://dash.botbiz.io/api/v1/whatsapp/template/status (application/json)
 *    Headers: Authorization: Bearer <apiToken>
 *    JSON Body: { "phone_number_id": "...", "template_id": "..." }
 *
 * 4. Template sending isolation:
 *    BotBiz generates ready-to-use template endpoints per approved template in its UI.
 *    Universal endpoint does not exist. Client supports configured template endpoint
 *    or returns actionable instructions without inventing fictional schemas.
 */

export interface BotbizClientConfig {
  apiBase: string; // Default: 'https://dash.botbiz.io/api/v1'
  apiToken: string;
  phoneNumberId: string;
  timeoutMs?: number; // Default: 15000ms
}

export interface BotbizSendTextParams {
  phoneNumber: string; // Country code + digits, e.g. 919876543210
  message: string;
  mediaUrl?: string; // Optional media attachment
}

export interface BotbizSendResponse {
  success: boolean;
  status: string; // '1' = documented success, '0' = failure
  waMessageId?: string;
  message: string;
  rawResponse?: any;
  httpStatus?: number;
  error?: string;
}

export interface BotbizTemplate {
  id: string;
  name: string;
  language: string;
  category?: string;
  status: 'APPROVED' | 'PENDING' | 'REJECTED' | 'PAUSED' | 'DISABLED' | 'UNKNOWN';
  rawStatus?: string;
  components?: any[];
  variableCount?: number;
  headerFormat?: 'document' | 'image' | 'video' | 'text' | 'location' | 'none' | string;
  headerExampleUrl?: string;
  /** Sample header text from Meta examples (TEXT headers). */
  headerExampleText?: string;
  bodyText?: string;
  /**
   * Placeholder names/indexes expected by the template body
   * (e.g. `name`, `1`, `date`) — NOT Meta example sample values.
   */
  bodyExampleVariables?: string[];
  raw?: any;
}

/** BotBiz documents status "1" as success. Null/empty wa_message_id must NOT count as success. */
export function isBotbizSendSuccess(resJson: any, httpOk: boolean): boolean {
  if (!httpOk || !resJson || typeof resJson !== 'object') return false;

  const status = resJson.status;
  if (status === '0' || status === 0 || status === 'error' || status === 'failed' || status === false) {
    return false;
  }

  if (status === '1' || status === 1 || status === 'success' || status === true) {
    return true;
  }

  const waId = resJson.wa_message_id ?? resJson.message_id ?? resJson.wamid;
  if (waId != null && String(waId).trim() !== '' && String(waId).toLowerCase() !== 'null') {
    return true;
  }

  return false;
}

function extractBodyVariableNames(bodyText?: string, exampleBodyRow?: any[]): string[] {
  const names: string[] = [];
  if (bodyText) {
    const matches = bodyText.match(/\{\{([a-zA-Z0-9_-]+)\}\}/g);
    if (matches) {
      for (const m of matches) {
        const name = m.replace(/[{}]/g, '').trim();
        if (name && !names.includes(name)) names.push(name);
      }
    }
  }

  // Meta example.body_text is sample VALUES, not names. Only use positional indexes
  // when the body has no named/numbered placeholders we could parse.
  if (names.length === 0 && Array.isArray(exampleBodyRow) && exampleBodyRow.length > 0) {
    for (let i = 0; i < exampleBodyRow.length; i++) {
      names.push(String(i + 1));
    }
  }

  return names;
}

function normalizeHeaderFormat(raw: any): string | undefined {
  if (raw == null) return undefined;
  const s = String(raw).trim().toLowerCase();
  if (!s) return undefined;
  if (s.includes('document') || s === 'pdf' || s === 'file') return 'document';
  if (s.includes('image') || s === 'img' || s === 'photo') return 'image';
  if (s.includes('video')) return 'video';
  if (s.includes('text')) return 'text';
  if (s.includes('location')) return 'location';
  if (s === 'none' || s === 'null') return 'none';
  return s;
}

export interface BotbizTemplateStatusResponse {
  success: boolean;
  templateId: string;
  status: 'APPROVED' | 'PENDING' | 'REJECTED' | 'PAUSED' | 'DISABLED' | 'UNKNOWN';
  rawStatus?: string;
  message?: string;
  raw?: any;
}

export class BotBizApiClient {
  private config: BotbizClientConfig;

  constructor(config?: Partial<BotbizClientConfig>) {
    this.config = {
      apiBase: (
        config?.apiBase ||
        process.env.BOTBIZ_API_BASE ||
        'https://dash.botbiz.io/api/v1'
      ).replace(/\/+$/, ''),
      apiToken: config?.apiToken || process.env.BOTBIZ_API_TOKEN || '',
      phoneNumberId:
        config?.phoneNumberId || process.env.BOTBIZ_PHONE_NUMBER_ID || '',
      timeoutMs: config?.timeoutMs || 90000,
    };
  }

  /**
   * Update active credentials dynamically
   */
  updateCredentials(apiToken?: string, phoneNumberId?: string, apiBase?: string) {
    if (apiToken !== undefined) this.config.apiToken = apiToken;
    if (phoneNumberId !== undefined) this.config.phoneNumberId = phoneNumberId;
    if (apiBase !== undefined)
      this.config.apiBase = apiBase.replace(/\/+$/, '');
  }

  /**
   * Check if minimum credentials (Token & Phone Number ID) are configured
   */
  isConfigured(): boolean {
    return Boolean(
      this.config.apiToken &&
        this.config.apiToken.trim().length > 0 &&
        this.config.phoneNumberId &&
        this.config.phoneNumberId.trim().length > 0,
    );
  }

  /**
   * Get safe masked view of active configuration
   */
  getMaskedConfig() {
    const token = this.config.apiToken || '';
    const masked =
      token.length > 6
        ? `${'•'.repeat(Math.max(8, token.length - 4))}${token.slice(-4)}`
        : token.length > 0
          ? '••••••••'
          : '';

    return {
      apiBase: this.config.apiBase,
      phoneNumberId: this.config.phoneNumberId,
      isConfigured: this.isConfigured(),
      hasToken: Boolean(token),
      maskedToken: masked,
    };
  }

  /**
   * Helper: Normalize phone numbers to digits only with country code
   * (e.g. 10-digit Indian numbers get 91 prepended)
   */
  static normalizePhoneNumber(phone: string): string {
    const digits = (phone || '').replace(/[^0-9]/g, '');
    if (digits.length === 10) {
      return `91${digits}`; // Standard Indian mobile number prefix
    }
    return digits;
  }

  /**
   * Documented Endpoint A: Send free-form text message
   * POST https://dash.botbiz.io/api/v1/whatsapp/send
   * Form parameters: apiToken, phone_number_id, phone_number, message
   */
  async sendTextMessage(
    params: BotbizSendTextParams,
  ): Promise<BotbizSendResponse> {
    const normalizedPhone = BotBizApiClient.normalizePhoneNumber(
      params.phoneNumber,
    );

    if (!normalizedPhone || normalizedPhone.length < 10) {
      return {
        success: false,
        status: '0',
        message: 'Invalid phone number format. Must be at least 10 digits.',
        error: 'Invalid phone number format',
      };
    }

    if (!this.config.apiToken) {
      return {
        success: false,
        status: '0',
        message:
          'BotBiz API Token is not configured. Please add it in CRM WhatsApp Settings.',
        error: 'Missing BOTBIZ_API_TOKEN',
      };
    }

    if (!this.config.phoneNumberId) {
      return {
        success: false,
        status: '0',
        message:
          'BotBiz Phone Number ID is not configured. Please add it in CRM WhatsApp Settings.',
        error: 'Missing BOTBIZ_PHONE_NUMBER_ID',
      };
    }

    const endpoint = `${this.config.apiBase}/whatsapp/send`;

    // Construct form-urlencoded payload per documentation
    const formParams = new URLSearchParams();
    formParams.append('apiToken', this.config.apiToken);
    formParams.append('phone_number_id', this.config.phoneNumberId);
    formParams.append('phone_number', normalizedPhone);
    formParams.append('message', params.message);

    if (params.mediaUrl) {
      formParams.append('media_url', params.mediaUrl);
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.config.timeoutMs);

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formParams.toString(),
        signal: controller.signal,
      });

      clearTimeout(timer);

      const rawText = await response.text();
      let resJson: any = {};
      try {
        resJson = JSON.parse(rawText);
      } catch {
        resJson = { raw: rawText };
      }

      // BotBiz documentation specifies status: "1" as success indicator.
      // Do NOT treat wa_message_id: null / missing as success (common false-positive).
      const isSuccess = isBotbizSendSuccess(resJson, response.ok);

      // Never invent synthetic wa ids — logs must show real BotBiz/Meta ids only.
      const waMessageIdRaw =
        resJson.wa_message_id || resJson.message_id || resJson.wamid || null;
      const waMessageId =
        waMessageIdRaw != null && String(waMessageIdRaw).trim() !== '' && String(waMessageIdRaw).toLowerCase() !== 'null'
          ? String(waMessageIdRaw)
          : undefined;

      let errorMessage: string | undefined;
      if (!isSuccess) {
        if (response.status === 403) {
          errorMessage =
            'BotBiz API 403 Access Denied: Token lacks permission or is invalid.';
        } else if (response.status === 401) {
          errorMessage = 'BotBiz API 401 Unauthorized: Invalid API Token.';
        } else if (response.status === 429) {
          errorMessage =
            'BotBiz API 429 Rate Limit: Too many requests or subscriber limit reached.';
        } else {
          errorMessage =
            resJson.message ||
            resJson.error ||
            `HTTP ${response.status}: ${rawText.slice(0, 200)}`;
        }
      }

      return {
        success: isSuccess,
        status: isSuccess ? '1' : '0',
        waMessageId,
        message:
          resJson.message ||
          (isSuccess ? 'Message sent successfully.' : errorMessage || 'Send failed'),
        rawResponse: resJson,
        httpStatus: response.status,
        error: errorMessage,
      };
    } catch (err: any) {
      clearTimeout(timer);
      const isTimeout = err.name === 'AbortError';
      const errMsg = isTimeout
        ? `Request timed out after ${this.config.timeoutMs}ms while contacting BotBiz API`
        : err.message || 'Network connection error';

      return {
        success: false,
        status: '0',
        message: errMsg,
        error: errMsg,
      };
    }
  }

  /**
   * Documented Endpoint B: Fetch connected WhatsApp account's templates
   * POST https://dash.botbiz.io/api/v1/whatsapp/get/template/list
   * Form parameters: apiToken, phone_number_id
   */
  async getTemplateList(): Promise<{
    success: boolean;
    templates: BotbizTemplate[];
    error?: string;
    raw?: any;
    httpStatus?: number;
  }> {
    if (!this.config.apiToken || !this.config.phoneNumberId) {
      return {
        success: false,
        templates: [],
        error:
          'BotBiz credentials incomplete. Both API Token and Phone Number ID are required to fetch templates.',
      };
    }

    const endpoint = `${this.config.apiBase}/whatsapp/get/template/list`;
    const formParams = new URLSearchParams();
    formParams.append('apiToken', this.config.apiToken);
    formParams.append('phone_number_id', this.config.phoneNumberId);

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.config.timeoutMs);

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: formParams.toString(),
        signal: controller.signal,
      });

      clearTimeout(timer);

      const rawText = await response.text();
      let resJson: any = {};
      try {
        resJson = JSON.parse(rawText);
      } catch {
        resJson = { raw: rawText };
      }

      if (!response.ok) {
        let errDesc = `HTTP ${response.status}`;
        if (response.status === 403) {
          errDesc =
            '403 Access Denied: BotBiz API Token permission restricted or invalid.';
        } else if (response.status === 401) {
          errDesc = '401 Unauthorized: Invalid API Token.';
        }
        return {
          success: false,
          templates: [],
          httpStatus: response.status,
          error: `${errDesc} - ${resJson.message || rawText.slice(0, 150)}`,
          raw: resJson,
        };
      }

      // Normalize template data from response first — some BotBiz payloads omit status: "1"
      // but still return a usable template array (message/data/templates).
      let rawList: any[] = [];
      if (Array.isArray(resJson)) {
        rawList = resJson;
      } else if (Array.isArray(resJson.message)) {
        rawList = resJson.message;
      } else if (Array.isArray(resJson.data)) {
        rawList = resJson.data;
      } else if (Array.isArray(resJson.templates)) {
        rawList = resJson.templates;
      } else if (Array.isArray(resJson.template_list)) {
        rawList = resJson.template_list;
      } else if (resJson.data && typeof resJson.data === 'object') {
        rawList = Object.values(resJson.data);
      }

      // Explicit account/token failure — only when there is no usable template list.
      const explicitlyFailed =
        resJson.status === '0' ||
        resJson.status === 0 ||
        resJson.status === 'error' ||
        resJson.status === 'failed';
      if (explicitlyFailed && rawList.length === 0) {
        return {
          success: false,
          templates: [],
          httpStatus: response.status,
          error:
            typeof resJson.message === 'string'
              ? resJson.message
              : 'BotBiz returned status: 0 (Account or token verification failed)',
          raw: resJson,
        };
      }

      if (rawList.length === 0 && typeof resJson.message === 'string' && resJson.status !== '1' && resJson.status !== 1) {
        return {
          success: false,
          templates: [],
          httpStatus: response.status,
          error: resJson.message || 'No templates returned from BotBiz',
          raw: resJson,
        };
      }

      const normalized: BotbizTemplate[] = rawList.map((item: any, idx: number) => {
        const id =
          item.template_id ||
          item.id ||
          item.templateId ||
          `tmpl_${item.template_name || item.name || idx}`;
        const name = item.template_name || item.name || `template_${idx}`;
        const language =
          item.locale || item.language || item.lang || item.language_code || 'en_US';
        const category = item.template_category || item.category || 'MARKETING';

        // Normalize status
        const rawStatus = (
          item.status ||
          item.approval_status ||
          'UNKNOWN'
        ).toString();
        let status: BotbizTemplate['status'] = 'UNKNOWN';
        const upperStatus = rawStatus.toUpperCase();

        if (upperStatus === 'APPROVED' || upperStatus === '1') {
          status = 'APPROVED';
        } else if (
          upperStatus === 'PENDING' ||
          upperStatus === 'IN_REVIEW' ||
          upperStatus === '0'
        ) {
          status = 'PENDING';
        } else if (upperStatus === 'REJECTED') {
          status = 'REJECTED';
        } else if (upperStatus === 'PAUSED') {
          status = 'PAUSED';
        } else if (upperStatus === 'DISABLED') {
          status = 'DISABLED';
        }

        let components: any[] = [];
        try {
          if (Array.isArray(item.components)) {
            components = item.components;
          } else if (typeof item.template_json === 'string' && item.template_json.trim()) {
            const parsed = JSON.parse(item.template_json);
            components = Array.isArray(parsed?.components) ? parsed.components : (Array.isArray(parsed) ? parsed : []);
          } else if (item.template_json && typeof item.template_json === 'object') {
            components = Array.isArray(item.template_json.components) ? item.template_json.components : [];
          }
        } catch {
          components = [];
        }

        const headerComp = Array.isArray(components)
          ? components.find((c: any) => String(c.type || '').toUpperCase() === 'HEADER')
          : undefined;

        const headerFormat =
          normalizeHeaderFormat(headerComp?.format) ||
          normalizeHeaderFormat(item.header_format) ||
          normalizeHeaderFormat(item.header_type) ||
          normalizeHeaderFormat(item.header_subtype) ||
          normalizeHeaderFormat(item.headerFormat);

        let headerExampleUrl: string | undefined = undefined;
        const candidateUrls = [
          headerComp?.example?.header_url?.[0],
          headerComp?.example?.header_handle?.[0],
          item.header_url,
          item.header_example_url,
          item.headerExampleUrl,
          item.media_url,
          item.example_header_url,
        ];
        for (const candidate of candidateUrls) {
          if (candidate == null) continue;
          const u = String(candidate).trim();
          if (u.startsWith('http://') || u.startsWith('https://')) {
            headerExampleUrl = u;
            break;
          }
        }

        let headerExampleText: string | undefined = undefined;
        if (headerFormat === 'text') {
          const textCandidates = [
            headerComp?.example?.header_text?.[0],
            headerComp?.example?.header_text,
            headerComp?.text,
            item.header_text,
            item.headerExampleText,
          ];
          for (const candidate of textCandidates) {
            if (candidate == null) continue;
            const t = Array.isArray(candidate) ? String(candidate[0] ?? '').trim() : String(candidate).trim();
            if (t && !t.startsWith('http://') && !t.startsWith('https://') && !t.startsWith('4::')) {
              headerExampleText = t;
              break;
            }
          }
        }

        const bodyComp = Array.isArray(components)
          ? components.find((c: any) => String(c.type || '').toUpperCase() === 'BODY')
          : undefined;
        const bodyText =
          (bodyComp?.text ? String(bodyComp.text) : undefined) ||
          (item.body_text ? String(item.body_text) : undefined) ||
          (item.bodyText ? String(item.bodyText) : undefined);

        const exampleBodyRow = Array.isArray(bodyComp?.example?.body_text?.[0])
          ? bodyComp.example.body_text[0]
          : undefined;
        const bodyExampleVariables = extractBodyVariableNames(bodyText, exampleBodyRow);

        return {
          id: String(id),
          name: String(name),
          language: String(language),
          category: String(category),
          status,
          rawStatus,
          components,
          headerFormat,
          headerExampleUrl,
          headerExampleText,
          bodyText,
          bodyExampleVariables,
          variableCount: bodyExampleVariables.length > 0
            ? bodyExampleVariables.length
            : (Array.isArray(components) ? JSON.stringify(components).split('{{').length - 1 : undefined),
          raw: item,
        };
      });

      return {
        success: true,
        templates: normalized,
        raw: resJson,
        httpStatus: response.status,
      };
    } catch (err: any) {
      clearTimeout(timer);
      const isTimeout = err.name === 'AbortError';
      const errMsg = isTimeout
        ? `Timeout while fetching BotBiz templates (${this.config.timeoutMs}ms)`
        : err.message || 'Network error fetching templates';

      return {
        success: false,
        templates: [],
        error: errMsg,
      };
    }
  }

  /**
   * Documented Endpoint C: Check template approval status
   * POST https://dash.botbiz.io/api/v1/whatsapp/template/status
   * Headers:
   *   Content-Type: application/json
   *   Authorization: Bearer <apiToken>
   * JSON Body:
   *   { "phone_number_id": "...", "template_id": "..." }
   */
  async getTemplateStatus(
    templateId: string,
  ): Promise<BotbizTemplateStatusResponse> {
    if (!this.config.apiToken || !this.config.phoneNumberId) {
      return {
        success: false,
        templateId,
        status: 'UNKNOWN',
        message: 'Credentials missing (API Token & Phone Number ID)',
      };
    }

    const endpoint = `${this.config.apiBase}/whatsapp/template/status`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.config.timeoutMs);

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.config.apiToken}`,
        },
        body: JSON.stringify({
          phone_number_id: this.config.phoneNumberId,
          template_id: templateId,
        }),
        signal: controller.signal,
      });

      clearTimeout(timer);

      const rawText = await response.text();
      let resJson: any = {};
      try {
        resJson = JSON.parse(rawText);
      } catch {
        resJson = { raw: rawText };
      }

      if (!response.ok) {
        return {
          success: false,
          templateId,
          status: 'UNKNOWN',
          rawStatus: `HTTP ${response.status}`,
          message:
            resJson.message || `HTTP ${response.status}: ${rawText.slice(0, 100)}`,
          raw: resJson,
        };
      }

      const rawStatus = (
        resJson.status ||
        resJson.template_status ||
        resJson.approval_status ||
        'UNKNOWN'
      ).toString();

      const upper = rawStatus.toUpperCase();
      let normalizedStatus: BotbizTemplateStatusResponse['status'] = 'UNKNOWN';

      if (upper === 'APPROVED' || upper === '1') {
        normalizedStatus = 'APPROVED';
      } else if (upper === 'PENDING' || upper === 'IN_REVIEW' || upper === '0') {
        normalizedStatus = 'PENDING';
      } else if (upper === 'REJECTED') {
        normalizedStatus = 'REJECTED';
      } else if (upper === 'PAUSED') {
        normalizedStatus = 'PAUSED';
      } else if (upper === 'DISABLED') {
        normalizedStatus = 'DISABLED';
      }

      return {
        success: true,
        templateId,
        status: normalizedStatus,
        rawStatus,
        message: resJson.message || `Status is ${normalizedStatus}`,
        raw: resJson,
      };
    } catch (err: any) {
      clearTimeout(timer);
      return {
        success: false,
        templateId,
        status: 'UNKNOWN',
        message: err.message || 'Status check request failed',
      };
    }
  }

  /**
   * Section 3.D: Template Sending Isolation
   *
   * BotBiz requires generating a specific endpoint per approved template
   * in the BotBiz developer UI ("Generate API End-point: Send Template Message").
   * Universal template send URL is NOT specified in documentation.
   *
   * This method executes the send if a specific template endpoint is configured,
   * otherwise returns a clear, actionable instruction without inventing endpoints.
   */
  async sendTemplateMessage(params: {
    phoneNumber: string;
    templateId: string;
    templateName?: string;
    templateEndpointUrl?: string;
    templateHeaderMediaUrl?: string;
    templateHeaderText?: string;
    variables?: Record<string, string>;
    allowedVariableNames?: string[];
  }): Promise<BotbizSendResponse> {
    const normalizedPhone = BotBizApiClient.normalizePhoneNumber(
      params.phoneNumber,
    );

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.config.timeoutMs);

    try {
      // 1. Determine target base URL and initialize parameters
      let targetBase = `${this.config.apiBase}/whatsapp/send/template`;
      const formParams = new URLSearchParams();

      // If user pasted a BotBiz-generated template endpoint URL, extract its preset query parameters
      if (params.templateEndpointUrl && params.templateEndpointUrl.trim().length > 0) {
        try {
          const parsed = new URL(params.templateEndpointUrl.trim());
          targetBase = `${parsed.origin}${parsed.pathname}`;
          parsed.searchParams.forEach((val, key) => {
            formParams.set(key, val);
          });
        } catch {
          // not a full URL, treat as endpoint path
        }
      }

      // Map known Meta template IDs or names to internal BotBiz IDs to prevent "Message template not found."
      const BOTBIZ_INTERNAL_IDS: Record<string, string> = {
        '1443065537184471': '463170', // newlead
        '2903556339977365': '417854', // call
        '1364454835831892': '417875', // cal
        '2039206550319800': '418618', // fivebhk
        '902523552910603': '418619',  // fourbhk
        '1056714737048878': '418620', // fourfive
        '2126132515445498': '448639', // modem
        'newlead': '463170',
        'call': '417854',
        'cal': '417875',
        'fivebhk': '418618',
        'fourbhk': '418619',
        'fourfive': '418620',
        'modem': '448639',
      };

      const resolvedTemplateId =
        BOTBIZ_INTERNAL_IDS[params.templateId] ||
        (params.templateName ? BOTBIZ_INTERNAL_IDS[params.templateName.toLowerCase()] : undefined) ||
        params.templateId;

      // 2. Set credentials and recipient
      formParams.set('apiToken', this.config.apiToken);
      formParams.set('phone_number_id', this.config.phoneNumberId);
      formParams.set('phone_number', normalizedPhone);
      if (resolvedTemplateId) {
        formParams.set('template_id', resolvedTemplateId);
      }
      if (params.templateName) {
        formParams.set('template_name', params.templateName);
      }

      // 3. Header Management (Media URL: DOCUMENT/PDF/IMAGE/VIDEO or Header Text Variable)
      let headerMediaUrl =
        params.templateHeaderMediaUrl ||
        formParams.get('template_header_media_url') ||
        params.variables?.header_media_url ||
        params.variables?.headerMediaUrl;

      // Filter out only truly invalid values: Meta internal handles (4::...) or non-HTTP strings
      if (
        headerMediaUrl &&
        (headerMediaUrl.startsWith('4::') ||
          (!headerMediaUrl.startsWith('http://') && !headerMediaUrl.startsWith('https://')))
      ) {
        headerMediaUrl = undefined;
        formParams.delete('template_header_media_url');
        formParams.delete('header_media_url');
        formParams.delete('templateHeaderMediaUrl');
      }

      // Default brochure URL for newlead if no header media URL was provided
      if (
        (!headerMediaUrl || headerMediaUrl.trim().length === 0) &&
        (resolvedTemplateId === '463170' || params.templateName?.toLowerCase() === 'newlead')
      ) {
        // Use the original official Wasabi S3 brochure — BotBiz fetches this server-side without local timeout
        headerMediaUrl = 'https://bot-data.s3.ap-southeast-1.wasabisys.com/flowbuilder/306044/306044/whatsapp-440327/flowbuilder-306044-1792663002.pdf';
      }

      if (headerMediaUrl && String(headerMediaUrl).trim().length > 0) {
        const cleanMediaUrl = String(headerMediaUrl).trim();
        formParams.set('template_header_media_url', cleanMediaUrl);
        formParams.set('header_media_url', cleanMediaUrl);
        formParams.set('templateHeaderMediaUrl', cleanMediaUrl);
      }

      // Header text is applied later (after clearing preset URL vars) only when
      // params.templateHeaderText is explicitly provided by the caller.

      // 4. Variables — strict slots:
      //   name  → templateVariable-name-1 / {{1}}
      //   date  → templateVariable-date-1 / {{2}}
      //   time  → templateVariable-time-1 / {{3}}
      // Never put time into the name/{{1}} keys (that caused "Dear 12:32 PM").
      // Always send date/time when present (blocking them caused "Date: - / Time: -").
      const vars = params.variables || {};
      const pick = (...keys: string[]): string | undefined => {
        for (const k of keys) {
          const v = vars[k];
          if (v != null && String(v).trim() !== '') return String(v).trim();
        }
        return undefined;
      };
      const looksLikeClock = (s: string) =>
        /^\d{1,2}:\d{2}(\s*[AaPp][Mm])?$/.test(String(s).trim());
      const isProjectKey = (key: string) => {
        const k = key.toLowerCase();
        return (
          k === 'pname' ||
          k === 'project' ||
          k === 'projectname' ||
          k === 'project_name'
        );
      };

      const dateVal = pick('date', 'visit_date', 'siteVisitDate', '2');
      const timeVal = pick('time', 'visit_time', 'siteVisitTime', '3');
      const projectVal = pick('pname', 'projectName', 'project', 'project_name');

      // Exact project labels only — do NOT use includes() (CRM client names can mention the project).
      const looksLikeProject = (s: string) => {
        const n = String(s || '')
          .trim()
          .toLowerCase()
          .replace(/\s+/g, ' ');
        if (!n) return false;
        const known = new Set([
          'legacy tower',
          'nb legacy tower',
          'nb finserve',
          'nb infra',
          'nb infra projects',
          'nb infra projects ltd',
        ]);
        if (known.has(n)) return true;
        if (projectVal && n === String(projectVal).trim().toLowerCase()) return true;
        return false;
      };

      // Greeting {{name}} = CRM person only (Pre-Sales Client Name), never project/clock.
      const pickPerson = (...keys: string[]) => {
        for (const k of keys) {
          const v = vars[k];
          if (v == null) continue;
          const s = String(v).trim();
          if (!s || looksLikeClock(s) || looksLikeProject(s)) continue;
          return s;
        }
        return undefined;
      };
      const personName =
        pickPerson('name', 'customerName', 'client_name', 'customer_name', 'Client_Name') ||
        'Valued Client';

      const allowed = (params.allowedVariableNames || [])
        .map((k) => String(k || '').trim())
        .filter(Boolean);
      const explicitNoBodyVars =
        Array.isArray(params.allowedVariableNames) && allowed.length === 0;
      const allowedWantsProject =
        allowed.length > 0 && allowed.some((k) => isProjectKey(k));

      // Drop any preset variable keys copied from a BotBiz endpoint URL.
      for (const key of [...formParams.keys()]) {
        const lk = key.toLowerCase();
        if (
          lk.startsWith('templatevariable') ||
          lk.startsWith('template_variable') ||
          lk.startsWith('template_header_variable') ||
          lk.startsWith('templateheadervariable') ||
          lk === 'template_header_text'
        ) {
          formParams.delete(key);
        }
      }

      // Never send project/clock as header — BotBiz can leak it into body {{1}}
      // ("Dear Legacy Tower"). Skip unsafe header values entirely.
      if (params.templateHeaderText && String(params.templateHeaderText).trim()) {
        const cleanHeaderText = String(params.templateHeaderText).trim();
        if (
          !looksLikeClock(cleanHeaderText) &&
          !looksLikeProject(cleanHeaderText) &&
          !(projectVal && cleanHeaderText.toLowerCase() === projectVal.toLowerCase())
        ) {
          formParams.set('template_header_variable-1', cleanHeaderText);
          formParams.set('template_header_variable', cleanHeaderText);
          formParams.set('templateHeaderVariable-1', cleanHeaderText);
        }
      }

      if (!explicitNoBodyVars) {
        // {{1}} / name — person only
        formParams.set('templateVariable-name-1', personName);
        formParams.set('templateVariable-name', personName);
        formParams.set('templateVariable-1', personName);
        formParams.set('templateVariable-1-1', personName);

        // {{2}} / date
        if (dateVal && !looksLikeClock(dateVal)) {
          formParams.set('templateVariable-date-1', dateVal);
          formParams.set('templateVariable-date', dateVal);
          formParams.set('templateVariable-2', dateVal);
          formParams.set('templateVariable-2-1', dateVal);
        }

        // {{3}} / time — own keys only, never {{1}} or name
        if (timeVal) {
          formParams.set('templateVariable-time-1', timeVal);
          formParams.set('templateVariable-time', timeVal);
          formParams.set('templateVariable-3', timeVal);
          formParams.set('templateVariable-3-1', timeVal);
        }

        // Project only when template explicitly allows it.
        if (allowedWantsProject && projectVal && !looksLikeClock(projectVal)) {
          formParams.set('templateVariable-pname-1', projectVal);
          formParams.set('templateVariable-project-1', projectVal);
        }

        // Any other allowed keys (excluding name/date/time/project) — do not touch slots 1–3.
        for (const rawKey of allowed) {
          const k = rawKey.toLowerCase();
          if (
            k === 'name' ||
            k === '1' ||
            k === 'date' ||
            k === '2' ||
            k === 'time' ||
            k === '3' ||
            k === 'customername' ||
            k === 'client_name' ||
            k === 'customer_name' ||
            isProjectKey(k)
          ) {
            continue;
          }
          const v = pick(rawKey, rawKey.toLowerCase());
          if (!v || looksLikeClock(v) || looksLikeProject(v)) continue;
          formParams.set(`templateVariable-${rawKey}-1`, v);
        }

        // Re-assert name/{{1}} last so nothing else can own that slot.
        formParams.set('templateVariable-name-1', personName);
        formParams.set('templateVariable-name', personName);
        formParams.set('templateVariable-1', personName);
        formParams.set('templateVariable-1-1', personName);
      }

      console.log(
        `[BotBiz sendTemplate] template=${params.templateName || params.templateId} name=${personName} date=${dateVal || '-'} time=${timeVal || '-'} keys=${[...formParams.keys()].filter((k) => /variable/i.test(k)).join(',')}`,
      );

      // BotBiz supports POST x-www-form-urlencoded (preferred) and GET fallback
      const getUrl = targetBase.includes('?')
        ? `${targetBase}&${formParams.toString()}`
        : `${targetBase}?${formParams.toString()}`;

      let response: Response;
      try {
        response = await fetch(targetBase, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            Accept: 'application/json',
          },
          body: formParams.toString(),
          signal: controller.signal,
        });

        if (response.status === 405) {
          // If POST not allowed on endpoint, fallback to GET with query string
          response = await fetch(getUrl, {
            method: 'GET',
            headers: { Accept: 'application/json' },
            signal: controller.signal,
          });
        }
      } catch {
        // Network fallback to GET
        response = await fetch(getUrl, {
          method: 'GET',
          headers: { Accept: 'application/json' },
          signal: controller.signal,
        });
      }

      clearTimeout(timer);

      const rawText = await response.text();
      let resJson: any = {};
      try {
        resJson = JSON.parse(rawText);
      } catch {
        resJson = { raw: rawText };
      }

      const isSuccess = isBotbizSendSuccess(resJson, response.ok);
      const waMessageIdRaw =
        resJson.wa_message_id || resJson.message_id || resJson.wamid || null;
      const waMessageId =
        waMessageIdRaw != null && String(waMessageIdRaw).trim() !== '' && String(waMessageIdRaw).toLowerCase() !== 'null'
          ? String(waMessageIdRaw)
          : undefined;

      return {
        success: isSuccess,
        status: isSuccess ? '1' : '0',
        waMessageId,
        message: resJson.message || (isSuccess ? 'Template message sent' : 'Template dispatch failed'),
        rawResponse: resJson,
        httpStatus: response.status,
        error: isSuccess
          ? undefined
          : resJson.message || resJson.error || `HTTP ${response.status}: BotBiz did not confirm delivery`,
      };
    } catch (err: any) {
      clearTimeout(timer);
      return {
        success: false,
        status: '0',
        message: err.message || 'Template message network error',
        error: err.message,
      };
    }
  }

  /**
   * Safe Connection Test:
   * Performs an authorized test against BotBiz API to verify credentials.
   * Does NOT send any real message to customers.
   */
  async testConnection(): Promise<{
    connected: boolean;
    statusCode?: number;
    message: string;
    details?: any;
  }> {
    if (!this.config.apiToken || !this.config.phoneNumberId) {
      return {
        connected: false,
        message:
          'Credentials not configured: BotBiz API Token and Phone Number ID are required.',
      };
    }

    try {
      const res = await this.getTemplateList();
      if (res.success) {
        return {
          connected: true,
          statusCode: res.httpStatus || 200,
          message: `BotBiz connection verified! Successfully retrieved ${res.templates.length} templates.`,
          details: { templateCount: res.templates.length },
        };
      }

      if (res.httpStatus === 403) {
        return {
          connected: false,
          statusCode: 403,
          message:
            '403 Access Denied: BotBiz rejected the request. Please verify that your API Token has WhatsApp API permissions in your BotBiz account.',
          details: res.error,
        };
      }

      if (res.httpStatus === 401) {
        return {
          connected: false,
          statusCode: 401,
          message: '401 Unauthorized: The BotBiz API Token is invalid or expired.',
          details: res.error,
        };
      }

      return {
        connected: false,
        statusCode: res.httpStatus,
        message: `Connection test failed: ${res.error || 'Unknown error'}`,
        details: res.error,
      };
    } catch (err: any) {
      return {
        connected: false,
        message: `Connection error: ${err.message}`,
        details: err.message,
      };
    }
  }
}
