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
  bodyText?: string;
  bodyExampleVariables?: string[];
  raw?: any;
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
      timeoutMs: config?.timeoutMs || 15000,
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

      // BotBiz documentation specifies status: "1" as success indicator
      const isSuccess =
        response.ok &&
        (resJson.status === '1' ||
          resJson.status === 1 ||
          resJson.status === 'success' ||
          resJson.wa_message_id !== undefined);

      const waMessageId =
        resJson.wa_message_id ||
        resJson.message_id ||
        resJson.id ||
        (isSuccess ? `botbiz_${Date.now()}` : undefined);

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

      // BotBiz returns HTTP 200 with status: "0" when business ID, token, or account fails
      if (
        resJson.status === '0' ||
        resJson.status === 0 ||
        resJson.status === 'error' ||
        (typeof resJson.message === 'string' && resJson.status !== '1' && resJson.status !== 1 && !Array.isArray(resJson))
      ) {
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

      // Normalize template data from response
      // BotBiz returns templates in resJson.message or resJson.data or directly as array
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

        const components = item.components || (item.template_json ? JSON.parse(item.template_json).components : []);
        const headerComp = Array.isArray(components)
          ? components.find((c: any) => c.type?.toUpperCase() === 'HEADER')
          : undefined;
        const headerFormat = headerComp?.format ? String(headerComp.format).toLowerCase() : undefined;
        let headerExampleUrl: string | undefined = undefined;
        if (headerComp?.example?.header_url && headerComp.example.header_url[0]) {
          const u = String(headerComp.example.header_url[0]).trim();
          if (u.startsWith('http://') || u.startsWith('https://')) {
            headerExampleUrl = u;
          }
        } else if (headerComp?.example?.header_handle && headerComp.example.header_handle[0]) {
          const h = String(headerComp.example.header_handle[0]).trim();
          if (h.startsWith('http://') || h.startsWith('https://')) {
            headerExampleUrl = h;
          }
        }
        const bodyComp = Array.isArray(components)
          ? components.find((c: any) => c.type?.toUpperCase() === 'BODY')
          : undefined;
        const bodyText = bodyComp?.text ? String(bodyComp.text) : undefined;
        let bodyExampleVariables: string[] = [];
        if (bodyComp?.example?.body_text && Array.isArray(bodyComp.example.body_text[0])) {
          bodyExampleVariables = bodyComp.example.body_text[0].map(String);
        } else if (bodyText) {
          const matches = bodyText.match(/\{\{([a-zA-Z0-9_-]+)\}\}/g);
          if (matches) {
            matches.forEach((m: string) => {
              const name = m.replace(/[\{\}]/g, '').trim();
              if (!bodyExampleVariables.includes(name)) {
                bodyExampleVariables.push(name);
              }
            });
          }
        }

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

      // 2. Set credentials and recipient
      formParams.set('apiToken', this.config.apiToken);
      formParams.set('phone_number_id', this.config.phoneNumberId);
      formParams.set('phone_number', normalizedPhone);
      if (params.templateId) {
        formParams.set('template_id', params.templateId);
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

      // Filter out Meta handles like 4::... or non-HTTP values
      if (headerMediaUrl && (headerMediaUrl.startsWith('4::') || (!headerMediaUrl.startsWith('http://') && !headerMediaUrl.startsWith('https://')))) {
        headerMediaUrl = undefined;
        formParams.delete('template_header_media_url');
        formParams.delete('header_media_url');
        formParams.delete('templateHeaderMediaUrl');
      }

      if (headerMediaUrl && String(headerMediaUrl).trim().length > 0) {
        const cleanMediaUrl = String(headerMediaUrl).trim();
        formParams.set('template_header_media_url', cleanMediaUrl);
        formParams.set('header_media_url', cleanMediaUrl);
        formParams.set('templateHeaderMediaUrl', cleanMediaUrl);
      }

      const headerText =
        params.templateHeaderText ||
        formParams.get('template_header_variable-1') ||
        params.variables?.header_variable ||
        params.variables?.headerVariable ||
        params.variables?.header_text ||
        params.variables?.headerText;
      if (headerText && String(headerText).trim().length > 0) {
        const cleanHeaderText = String(headerText).trim();
        formParams.set('template_header_variable-1', cleanHeaderText);
        formParams.set('template_header_variable', cleanHeaderText);
        formParams.set('templateHeaderVariable-1', cleanHeaderText);
        formParams.set('template_header_text', cleanHeaderText);
      }

      // 4. Variables Management (e.g. templateVariable-name-1=Jash, templateVariable-date-1=..., templateVariable-time-1=...)
      if (params.variables) {
        for (const [key, rawVal] of Object.entries(params.variables)) {
          if (rawVal !== undefined && rawVal !== null) {
            const val = String(rawVal);
            const cleanKey = key.trim();
            formParams.set(`templateVariable-${cleanKey}-1`, val);
            formParams.set(`templateVariable-${cleanKey}`, val);
          }
        }

        // Standard positional aliases to guarantee compatibility with numbered templates {{1}}, {{2}}, {{3}}, {{4}}
        if (params.variables.name) {
          formParams.set('templateVariable-name-1', params.variables.name);
          formParams.set('templateVariable-1-1', params.variables.name);
          formParams.set('templateVariable-1', params.variables.name);
        }
        if (params.variables.date) {
          formParams.set('templateVariable-date-1', params.variables.date);
          formParams.set('templateVariable-2-1', params.variables.date);
          formParams.set('templateVariable-2', params.variables.date);
        }
        if (params.variables.time) {
          formParams.set('templateVariable-time-1', params.variables.time);
          formParams.set('templateVariable-3-1', params.variables.time);
          formParams.set('templateVariable-3', params.variables.time);
        }
        const calendarLink =
          params.variables.calendar_link ||
          params.variables.calendarLink ||
          params.variables.link;
        if (calendarLink) {
          formParams.set('templateVariable-calendar_link-1', calendarLink);
          formParams.set('templateVariable-calendar-1', calendarLink);
          formParams.set('templateVariable-link-1', calendarLink);
          formParams.set('templateVariable-4-1', calendarLink);
          formParams.set('templateVariable-4', calendarLink);
        }
        if (params.variables.phone || params.variables.number) {
          const ph = params.variables.phone || params.variables.number;
          formParams.set('templateVariable-phone-1', ph);
          formParams.set('templateVariable-number-1', ph);
        }
      }

      // Construct target full URL with query string
      const fullUrl = `${targetBase}?${formParams.toString()}`;

      // BotBiz supports GET and POST x-www-form-urlencoded
      let response: Response;
      try {
        response = await fetch(fullUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
          body: formParams.toString(),
          signal: controller.signal,
        });

        if (response.status === 405) {
          // If POST not allowed on endpoint, fallback to GET with query string
          response = await fetch(fullUrl, {
            method: 'GET',
            headers: { 'Accept': 'application/json' },
            signal: controller.signal,
          });
        }
      } catch {
        // Network fallback to GET
        response = await fetch(fullUrl, {
          method: 'GET',
          headers: { 'Accept': 'application/json' },
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

      const isSuccess =
        response.ok &&
        (resJson.status === '1' ||
          resJson.status === 1 ||
          resJson.status === 'success' ||
          resJson.wa_message_id !== undefined);

      return {
        success: isSuccess,
        status: isSuccess ? '1' : '0',
        waMessageId: resJson.wa_message_id || resJson.id,
        message: resJson.message || (isSuccess ? 'Template message sent' : 'Template dispatch failed'),
        rawResponse: resJson,
        httpStatus: response.status,
        error: isSuccess ? undefined : resJson.message || `HTTP ${response.status}`,
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
