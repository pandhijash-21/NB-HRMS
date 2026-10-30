/**
 * 9ance Cloud Telephony API client
 * Base: https://crmapi.9ance.com
 * Auth: Bearer JWT (access ~1h, refresh ~7d)
 */

const DEFAULT_BASE = 'https://crmapi.9ance.com';

export interface NineanceTokens {
  access: string;
  refresh: string;
}

export interface NineanceRequestOptions {
  method?: string;
  body?: any;
  query?: Record<string, string | number | boolean | undefined | null>;
  formData?: FormData;
  rawBody?: BodyInit;
  contentType?: string;
  accessToken?: string;
  /** Skip auth header (login / refresh) */
  noAuth?: boolean;
  timeoutMs?: number;
}

export class NineanceApiError extends Error {
  status: number;
  detail?: string;
  providerError?: string;
  raw?: any;

  constructor(status: number, message: string, raw?: any) {
    super(message);
    this.name = 'NineanceApiError';
    this.status = status;
    this.detail = raw?.detail || message;
    this.providerError = raw?.provider_error;
    this.raw = raw;
  }
}

export class NineanceClient {
  baseUrl: string;
  accessToken = '';
  refreshToken = '';
  private refreshHandler: (() => Promise<NineanceTokens | null>) | null = null;

  constructor(baseUrl: string = DEFAULT_BASE) {
    this.baseUrl = (baseUrl || DEFAULT_BASE).replace(/\/+$/, '');
  }

  setBaseUrl(url: string) {
    this.baseUrl = (url || DEFAULT_BASE).replace(/\/+$/, '');
  }

  setTokens(tokens: Partial<NineanceTokens>) {
    if (tokens.access) this.accessToken = tokens.access;
    if (tokens.refresh) this.refreshToken = tokens.refresh;
  }

  /** Called when a 401 is received so the service can refresh from stored credentials */
  onNeedRefresh(handler: () => Promise<NineanceTokens | null>) {
    this.refreshHandler = handler;
  }

  private buildUrl(path: string, query?: NineanceRequestOptions['query']): string {
    const p = path.startsWith('/') ? path : `/${path}`;
    const withSlash = p.endsWith('/') ? p : `${p}/`;
    const url = new URL(`${this.baseUrl}${withSlash}`);
    if (query) {
      for (const [k, v] of Object.entries(query)) {
        if (v === undefined || v === null || v === '') continue;
        url.searchParams.set(k, String(v));
      }
    }
    return url.toString();
  }

  async request<T = any>(path: string, opts: NineanceRequestOptions = {}, retried = false): Promise<T> {
    const method = (opts.method || 'GET').toUpperCase();
    const headers: Record<string, string> = {};
    const token = opts.accessToken || this.accessToken;
    if (!opts.noAuth && token) {
      headers.Authorization = `Bearer ${token}`;
    }

    let body: BodyInit | undefined;
    if (opts.formData) {
      body = opts.formData as any;
    } else if (opts.rawBody) {
      body = opts.rawBody;
      if (opts.contentType) headers['Content-Type'] = opts.contentType;
    } else if (opts.body !== undefined) {
      headers['Content-Type'] = 'application/json';
      body = JSON.stringify(opts.body);
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), opts.timeoutMs ?? 30000);

    try {
      const res = await fetch(this.buildUrl(path, opts.query), {
        method,
        headers,
        body,
        signal: controller.signal,
      });

      const text = await res.text();
      let json: any = null;
      if (text) {
        try {
          json = JSON.parse(text);
        } catch {
          json = { detail: text };
        }
      }

      if (res.status === 401 && !opts.noAuth && !retried && this.refreshHandler) {
        const refreshed = await this.refreshHandler();
        if (refreshed?.access) {
          this.setTokens(refreshed);
          return this.request<T>(path, { ...opts, accessToken: refreshed.access }, true);
        }
      }

      if (!res.ok) {
        const msg =
          (typeof json?.detail === 'string' && json.detail) ||
          (typeof json?.message === 'string' && json.message) ||
          `9ance API ${res.status}`;
        throw new NineanceApiError(res.status, msg, json);
      }

      return (json ?? {}) as T;
    } finally {
      clearTimeout(timeout);
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  async login(email: string, password: string): Promise<NineanceTokens & { user?: any; tenant?: any }> {
    const data = await this.request<any>('/api/auth/login/', {
      method: 'POST',
      noAuth: true,
      body: { email, password },
    });
    const tokens = { access: String(data.access || ''), refresh: String(data.refresh || '') };
    this.setTokens(tokens);
    return { ...tokens, user: data.user, tenant: data.tenant };
  }

  async refreshAccessToken(refresh?: string): Promise<NineanceTokens> {
    const data = await this.request<any>('/api/auth/token/refresh/', {
      method: 'POST',
      noAuth: true,
      body: { refresh: refresh || this.refreshToken },
    });
    const tokens = {
      access: String(data.access || ''),
      refresh: String(data.refresh || this.refreshToken || ''),
    };
    this.setTokens(tokens);
    return tokens;
  }

  // ── Config ────────────────────────────────────────────────────────────────

  async createConfig(payload: {
    provider_key: string;
    display_name: string;
    credentials: { api_key: string; api_secret: string };
    settings?: Record<string, any>;
  }) {
    return this.request('/api/telephony/config/', { method: 'POST', body: payload });
  }

  async getConfig() {
    return this.request('/api/telephony/config/', { method: 'GET' });
  }

  async updateConfig(payload: Record<string, any>) {
    return this.request('/api/telephony/config/', { method: 'PUT', body: payload });
  }

  async deleteConfig() {
    return this.request('/api/telephony/config/', { method: 'DELETE' });
  }

  async testConfig() {
    return this.request<{ success?: boolean }>('/api/telephony/config/test/', { method: 'POST' });
  }

  // ── Agents ────────────────────────────────────────────────────────────────

  async listAgents() {
    return this.request<any>('/api/telephony/agents/', { method: 'GET' });
  }

  async syncAgents() {
    return this.request<{ synced?: number; created?: number }>('/api/telephony/agents/sync/', {
      method: 'POST',
    });
  }

  async createAgent(payload: {
    name: string;
    phone: string;
    access?: string;
    sip_password?: string;
  }) {
    return this.request('/api/telephony/agents/', { method: 'POST', body: payload });
  }

  async deleteAgent(id: string) {
    return this.request(`/api/telephony/agents/${id}/`, { method: 'DELETE' });
  }

  async assignAgent(id: string, userId: string | null) {
    return this.request(`/api/telephony/agents/${id}/assign/`, {
      method: 'POST',
      body: { user_id: userId },
    });
  }

  async bulkAssignAgents(assignments: Array<{ agent_id: string; user_id: string | null }>) {
    return this.request('/api/telephony/agents/bulk-assign/', {
      method: 'POST',
      body: { assignments },
    });
  }

  async setAgentStatus(id: string, status: string, breakType?: string) {
    const body: any = { status };
    if (breakType) body.break_type = breakType;
    return this.request(`/api/telephony/agents/${id}/status/`, { method: 'POST', body });
  }

  async getMyAgent() {
    return this.request('/api/telephony/agents/me/', { method: 'GET' });
  }

  async getMyAgentStatus() {
    return this.request('/api/telephony/agents/me/status/', { method: 'GET' });
  }

  async setMyAgentStatus(status: string, breakType?: string) {
    const body: any = { status };
    if (breakType) body.break_type = breakType;
    return this.request('/api/telephony/agents/me/status/', { method: 'POST', body });
  }

  // ── DIDs ──────────────────────────────────────────────────────────────────

  async listDids() {
    return this.request<any>('/api/telephony/dids/', { method: 'GET' });
  }

  async syncDids() {
    return this.request('/api/telephony/dids/sync/', { method: 'POST' });
  }

  async setDefaultDid(id: string) {
    return this.request(`/api/telephony/dids/${id}/set-default/`, { method: 'POST' });
  }

  // ── Calls ─────────────────────────────────────────────────────────────────

  async clickToCall(payload: {
    customer_number: string;
    agent_id?: string;
    agent_number?: string;
    agent_email?: string;
    lead_id?: string;
    contact_id?: string;
    customer_id?: string;
    did_id?: string;
    wait_seconds?: number;
  }) {
    return this.request<{
      success?: boolean;
      call_id?: string;
      provider_call_id?: string;
      message?: string;
    }>('/api/telephony/calls/click-to-call/', { method: 'POST', body: payload });
  }

  async listCalls(query: Record<string, any> = {}) {
    return this.request<any>('/api/telephony/calls/', { method: 'GET', query });
  }

  async getCallRecording(callId: string, download = false) {
    return this.request(`/api/telephony/calls/${callId}/recording/`, {
      method: 'GET',
      query: download ? { download: 1 } : undefined,
    });
  }

  /** Stream recording bytes with auth */
  async fetchRecordingResponse(callId: string, rangeHeader?: string): Promise<Response> {
    const url = this.buildUrl(`/api/telephony/calls/${callId}/recording/`);
    const headers: Record<string, string> = {};
    if (this.accessToken) headers.Authorization = `Bearer ${this.accessToken}`;
    if (rangeHeader) headers.Range = rangeHeader;
    return fetch(url, { method: 'GET', headers });
  }

  async dispositionCall(
    callId: string,
    payload: { disposition: string; notes?: string; follow_up_at?: string },
  ) {
    return this.request(`/api/telephony/calls/${callId}/disposition/`, {
      method: 'POST',
      body: payload,
    });
  }

  async listLiveCalls() {
    return this.request('/api/telephony/calls/live/', { method: 'GET' });
  }

  async matchPhone(phone: string) {
    return this.request('/api/telephony/calls/match/', {
      method: 'GET',
      query: { phone },
    });
  }

  async getDialerConfig() {
    return this.request('/api/telephony/dialer/config/', { method: 'GET' });
  }

  async getSoftphoneConfig() {
    return this.request('/api/telephony/agents/me/softphone-config/', { method: 'GET' });
  }

  // ── Campaigns ─────────────────────────────────────────────────────────────

  async listCampaigns() {
    return this.request('/api/telephony/campaigns/', { method: 'GET' });
  }

  async createCampaignJson(payload: Record<string, any>) {
    return this.request('/api/telephony/campaigns/', { method: 'POST', body: payload });
  }

  async startCampaign(id: string) {
    return this.request(`/api/telephony/campaigns/${id}/start/`, { method: 'POST' });
  }

  async stopCampaign(id: string) {
    return this.request(`/api/telephony/campaigns/${id}/stop/`, { method: 'POST' });
  }

  async campaignReport(id: string) {
    return this.request(`/api/telephony/campaigns/${id}/report/`, { method: 'GET' });
  }

  async previewDialList(payload: Record<string, any>) {
    return this.request('/api/telephony/campaigns/preview-dial-list/', {
      method: 'POST',
      body: payload,
    });
  }

  // ── Dispositions / groups / analytics ─────────────────────────────────────

  async listDispositions() {
    return this.request('/api/telephony/dispositions/', { method: 'GET' });
  }

  async createDisposition(payload: { label: string; value: string; color?: string }) {
    return this.request('/api/telephony/dispositions/', { method: 'POST', body: payload });
  }

  async listCallGroups() {
    return this.request('/api/telephony/call-groups/', { method: 'GET' });
  }

  async createCallGroup(payload: {
    group_name: string;
    members: string[];
    ring_type?: string;
  }) {
    return this.request('/api/telephony/call-groups/', { method: 'POST', body: payload });
  }

  async providerDashboard() {
    return this.request('/api/telephony/provider-dashboard/', { method: 'GET' });
  }

  async agentAnalytics(date?: string) {
    return this.request('/api/telephony/analytics/agents/', {
      method: 'GET',
      query: date ? { date } : undefined,
    });
  }

  async myAnalytics(date?: string) {
    return this.request('/api/telephony/analytics/me/', {
      method: 'GET',
      query: date ? { date } : undefined,
    });
  }
}

export const DEFAULT_NINEANCE_BASE = DEFAULT_BASE;
