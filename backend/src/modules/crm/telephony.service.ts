/**
 * CRM telephony orchestration over 9ance Cloud Telephony.
 * Replaces Elision / Greeter Click2Call.
 */

import { Request, Response } from 'express';
import { prisma } from '../../config/prisma';
import {
  DEFAULT_NINEANCE_BASE,
  NineanceApiError,
  NineanceClient,
  NineanceTokens,
} from './nineance.client';
import { whatsappService } from './whatsapp.service';

export type TelecallerNineanceConfig = {
  agent_id?: string;
  agent_number?: string;
  agent_email?: string;
  did_id?: string;
};

type StoredNineanceSettings = {
  base_url: string;
  email: string;
  password: string;
  api_key: string;
  api_secret: string;
  provider_key: string;
  display_name: string;
  access_token: string;
  refresh_token: string;
  webhook_token: string;
  webhook_url: string;
  default_did_id: string;
  connected: boolean;
};

function prefixKey(scope: string, key: string) {
  return scope === 'NB_FINSERVE' ? `finserve_${key}` : key;
}

function digitsOnly(v: string): string {
  return String(v || '').replace(/[^0-9]/g, '');
}

function last10(v: string): string {
  const d = digitsOnly(v);
  return d.length > 10 ? d.slice(-10) : d;
}

function normalizePhone10(v: string): string {
  let d = digitsOnly(v);
  if (d.length > 10 && d.startsWith('91')) d = d.slice(2);
  return d;
}

function asList(data: any): any[] {
  let list: any[] = [];
  if (Array.isArray(data)) list = data;
  else if (Array.isArray(data?.results)) list = data.results;
  else if (Array.isArray(data?.data)) list = data.data;
  else if (Array.isArray(data?.agents)) list = data.agents;
  else if (Array.isArray(data?.dids)) list = data.dids;
  else if (Array.isArray(data?.calls)) list = data.calls;

  // Dedupe by id (9ance sync can return / accumulate duplicates)
  const seen = new Set<string>();
  const out: any[] = [];
  for (const item of list) {
    const id = item?.id != null ? String(item.id) : '';
    const key = id || `${item?.name || ''}|${item?.phone || item?.number || ''}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(item);
  }
  return out;
}

class TelephonyService {
  private clients = new Map<string, NineanceClient>();

  private getClient(scope: string): NineanceClient {
    const key = scope || 'NB_DEVELOPER';
    let c = this.clients.get(key);
    if (!c) {
      c = new NineanceClient();
      c.onNeedRefresh(async () => {
        try {
          return await this.refreshTokens(key);
        } catch {
          return null;
        }
      });
      this.clients.set(key, c);
    }
    return c;
  }

  private async upsertSetting(key: string, value: string, updatedBy?: string) {
    await prisma.crmSetting.upsert({
      where: { key },
      update: { value, updatedBy },
      create: { key, value, updatedBy },
    });
  }

  private async readSetting(key: string): Promise<string> {
    const row = await prisma.crmSetting.findUnique({ where: { key } });
    return row?.value ?? '';
  }

  async getNineanceSettings(scope: string = 'NB_DEVELOPER'): Promise<StoredNineanceSettings> {
    const p = (k: string) => prefixKey(scope, k);
    const [
      base_url,
      email,
      password,
      api_key,
      api_secret,
      provider_key,
      display_name,
      access_token,
      refresh_token,
      webhook_token,
      webhook_url,
      default_did_id,
      connected,
    ] = await Promise.all([
      this.readSetting(p('nineance_base_url')),
      this.readSetting(p('nineance_email')),
      this.readSetting(p('nineance_password')),
      this.readSetting(p('nineance_api_key')),
      this.readSetting(p('nineance_api_secret')),
      this.readSetting(p('nineance_provider_key')),
      this.readSetting(p('nineance_display_name')),
      this.readSetting(p('nineance_access_token')),
      this.readSetting(p('nineance_refresh_token')),
      this.readSetting(p('nineance_webhook_token')),
      this.readSetting(p('nineance_webhook_url')),
      this.readSetting(p('nineance_default_did_id')),
      this.readSetting(p('nineance_connected')),
    ]);

    return {
      base_url: base_url || DEFAULT_NINEANCE_BASE,
      email,
      password,
      api_key,
      api_secret,
      provider_key: (provider_key || 'indiavoice').toLowerCase(),
      display_name: display_name || (scope === 'NB_FINSERVE' ? 'NB Finserve Dialer' : 'NB Developer Dialer'),
      access_token,
      refresh_token,
      webhook_token,
      webhook_url,
      default_did_id,
      connected: connected === 'true',
    };
  }

  /** Public settings shape for CRM getSettings (password masked). */
  async getPublicNineanceFields(scope: string = 'NB_DEVELOPER') {
    const s = await this.getNineanceSettings(scope);
    return {
      nineance_base_url: s.base_url,
      nineance_email: s.email,
      nineance_password: s.password ? '••••••••' : '',
      nineance_has_password: Boolean(s.password),
      nineance_api_key: s.api_key ? `${'•'.repeat(Math.max(4, s.api_key.length - 4))}${s.api_key.slice(-4)}` : '',
      nineance_has_api_key: Boolean(s.api_key),
      nineance_api_secret: s.api_secret ? '••••••••' : '',
      nineance_has_api_secret: Boolean(s.api_secret),
      nineance_provider_key: s.provider_key,
      nineance_display_name: s.display_name,
      nineance_webhook_token: s.webhook_token,
      nineance_webhook_url: s.webhook_url,
      nineance_default_did_id: s.default_did_id,
      nineance_connected: s.connected,
      // Legacy keys kept empty so old UI does not show Greeter defaults
      elision_api_url: '',
      elision_user_id: '',
      elision_did: '',
      elision_route_number: '',
      elision_default_agent_number: '',
      elision_api_key: '',
      elision_campaign_id: '',
      elision_agent_id: '',
    };
  }

  async saveNineanceCredentials(
    dto: Record<string, any>,
    updatedBy?: string,
    scope: string = 'NB_DEVELOPER',
  ) {
    const p = (k: string) => prefixKey(scope, k);
    const current = await this.getNineanceSettings(scope);
    const write = async (key: string, val: string | undefined, skipMasked = false) => {
      if (val === undefined) return;
      const trimmed = String(val).trim();
      if (skipMasked && (/^[\*\•]+$/.test(trimmed) || trimmed === '••••••••')) return;
      await this.upsertSetting(p(key), trimmed, updatedBy);
    };

    await write('nineance_base_url', dto.nineance_base_url ?? dto.base_url);
    await write('nineance_email', dto.nineance_email ?? dto.email);
    await write('nineance_password', dto.nineance_password ?? dto.password, true);
    await write('nineance_api_key', dto.nineance_api_key ?? dto.api_key, true);
    await write('nineance_api_secret', dto.nineance_api_secret ?? dto.api_secret, true);
    const providerRaw = dto.nineance_provider_key ?? dto.provider_key;
    if (providerRaw !== undefined) {
      await write('nineance_provider_key', String(providerRaw).trim().toLowerCase());
    }
    await write('nineance_display_name', dto.nineance_display_name ?? dto.display_name);
    if (dto.nineance_default_did_id !== undefined) {
      await write('nineance_default_did_id', dto.nineance_default_did_id);
    }

    // Preserve password if masked placeholder sent
    if ((dto.nineance_password || dto.password) && current.password) {
      const raw = String(dto.nineance_password || dto.password || '').trim();
      if (/^[\*\•]+$/.test(raw) || raw === '••••••••') {
        // keep existing
      }
    }
    return this.getPublicNineanceFields(scope);
  }

  private async persistTokens(scope: string, tokens: NineanceTokens, updatedBy?: string) {
    const p = (k: string) => prefixKey(scope, k);
    if (tokens.access) await this.upsertSetting(p('nineance_access_token'), tokens.access, updatedBy);
    if (tokens.refresh) await this.upsertSetting(p('nineance_refresh_token'), tokens.refresh, updatedBy);
  }

  async refreshTokens(scope: string): Promise<NineanceTokens | null> {
    const s = await this.getNineanceSettings(scope);
    const client = this.getClient(scope);
    client.setBaseUrl(s.base_url);
    if (s.refresh_token) {
      try {
        const tokens = await client.refreshAccessToken(s.refresh_token);
        await this.persistTokens(scope, tokens);
        return tokens;
      } catch {
        // fall through to login
      }
    }
    if (s.email && s.password) {
      const tokens = await client.login(s.email, s.password);
      await this.persistTokens(scope, tokens);
      return tokens;
    }
    return null;
  }

  async ensureAuthenticated(scope: string = 'NB_DEVELOPER'): Promise<NineanceClient> {
    const s = await this.getNineanceSettings(scope);
    const client = this.getClient(scope);
    client.setBaseUrl(s.base_url);
    if (s.access_token) {
      client.setTokens({ access: s.access_token, refresh: s.refresh_token });
      return client;
    }
    const tokens = await this.refreshTokens(scope);
    if (!tokens?.access) {
      throw new Error('9ance is not connected. Save email/password and click Activate.');
    }
    client.setTokens(tokens);
    return client;
  }

  async testConnection(scope: string = 'NB_DEVELOPER') {
    const s = await this.getNineanceSettings(scope);
    if (!s.email || !s.password) {
      throw new Error('Save 9ance email and password first');
    }
    const client = this.getClient(scope);
    client.setBaseUrl(s.base_url);
    const login = await client.login(s.email, s.password);
    await this.persistTokens(scope, login);
    try {
      const test = await client.testConfig();
      return {
        success: true,
        message: test?.success === false ? 'Logged in, but telephony config test failed' : 'Connected to 9ance',
        configTest: test,
        tenant: login.tenant,
      };
    } catch (err: any) {
      // Login worked; config may not exist yet
      return {
        success: true,
        message: 'Logged in to 9ance (activate to create telephony config)',
        warning: err?.message,
        tenant: login.tenant,
      };
    }
  }

  private formatNineanceError(err: any, step: string): Error {
    if (err instanceof NineanceApiError) {
      const bits = [`9ance ${step} failed (${err.status})`, err.detail || err.message];
      if (err.providerError) bits.push(`provider: ${err.providerError}`);
      return new Error(bits.filter(Boolean).join(' — '));
    }
    return new Error(err?.message || `9ance ${step} failed`);
  }

  async activate(scope: string = 'NB_DEVELOPER', updatedBy?: string) {
    const s = await this.getNineanceSettings(scope);
    if (!s.email || !s.password) {
      throw new Error(
        'Missing login email/password. Fill Email + Password (portal login), then Save or Activate again.',
      );
    }
    if (!s.api_key || !s.api_secret) {
      throw new Error(
        'Missing API Username/Password. Put API Username in API key and API password in API secret, then Activate again.',
      );
    }

    const client = this.getClient(scope);
    client.setBaseUrl(s.base_url);

    let login: NineanceTokens & { user?: any; tenant?: any };
    try {
      login = await client.login(s.email, s.password);
    } catch (err: any) {
      throw this.formatNineanceError(
        err,
        'login',
      );
    }
    await this.persistTokens(scope, login, updatedBy);

    let config: any;
    try {
      config = await client.createConfig({
        provider_key: s.provider_key || 'indiavoice',
        display_name: s.display_name,
        credentials: { api_key: s.api_key, api_secret: s.api_secret },
        settings: {},
      });
    } catch (err: any) {
      if (err instanceof NineanceApiError && err.status === 409) {
        try {
          config = await client.updateConfig({
            provider_key: s.provider_key || 'indiavoice',
            display_name: s.display_name,
            credentials: { api_key: s.api_key, api_secret: s.api_secret },
          });
        } catch (updErr: any) {
          throw this.formatNineanceError(updErr, 'config update');
        }
      } else {
        // try get existing
        try {
          config = await client.getConfig();
        } catch {
          throw this.formatNineanceError(err, 'config create');
        }
      }
    }

    const webhookToken = String(config?.webhook_token || config?.webhookToken || s.webhook_token || '');
    const webhookUrl = String(config?.webhook_url || config?.webhookUrl || s.webhook_url || '');
    const p = (k: string) => prefixKey(scope, k);
    if (webhookToken) await this.upsertSetting(p('nineance_webhook_token'), webhookToken, updatedBy);
    if (webhookUrl) await this.upsertSetting(p('nineance_webhook_url'), webhookUrl, updatedBy);
    await this.upsertSetting(p('nineance_connected'), 'true', updatedBy);

    let agentsSync: any = null;
    let didsSync: any = null;
    try {
      agentsSync = await client.syncAgents();
    } catch (e: any) {
      agentsSync = { error: e?.message };
    }
    try {
      didsSync = await client.syncDids();
    } catch (e: any) {
      didsSync = { error: e?.message };
    }

    try {
      await client.testConfig();
    } catch (_) {}

    return {
      success: true,
      message: '9ance Cloud Telephony activated',
      webhook_token: webhookToken,
      webhook_url: webhookUrl,
      agentsSync,
      didsSync,
      config,
    };
  }

  // ── Telecaller map ────────────────────────────────────────────────────────

  async _readTelecallerConfigMap(scope: string = 'NB_DEVELOPER'): Promise<
    Record<string, TelecallerNineanceConfig>
  > {
    const key = prefixKey(scope, 'nineance_telecaller_configs');
    const legacyKey = prefixKey(scope, 'elision_telecaller_configs');
    let row = await prisma.crmSetting.findUnique({ where: { key } });
    if (!row?.value) {
      row = await prisma.crmSetting.findUnique({ where: { key: legacyKey } });
    }
    if (!row?.value) return {};
    try {
      const parsed = JSON.parse(row.value);
      return parsed && typeof parsed === 'object' ? parsed : {};
    } catch {
      return {};
    }
  }

  async _writeTelecallerConfigMap(
    map: Record<string, TelecallerNineanceConfig>,
    updatedBy?: string,
    scope: string = 'NB_DEVELOPER',
  ) {
    const key = prefixKey(scope, 'nineance_telecaller_configs');
    await prisma.crmSetting.upsert({
      where: { key },
      update: { value: JSON.stringify(map), updatedBy },
      create: {
        key,
        value: JSON.stringify(map),
        description: `Per-telecaller 9ance agent mapping for ${scope === 'NB_FINSERVE' ? 'NB Finserve' : 'NB Developer'}`,
        updatedBy,
      },
    });
  }

  async listTelecallerTelephony(scope: string = 'NB_DEVELOPER') {
    const configs = await this._readTelecallerConfigMap(scope);
    const settings = await this.getNineanceSettings(scope);

    const telecallers = await prisma.employee.findMany({
      where: {
        status: 'ACTIVE',
        OR: [
          { generalInfo: { designation: { equals: 'Telecaller', mode: 'insensitive' } } },
          {
            generalInfo: {
              designationRef: { name: { equals: 'Telecaller', mode: 'insensitive' } },
            },
          },
        ],
      },
      select: {
        id: true,
        userId: true,
        generalInfo: {
          select: { fullName: true, employeeCode: true, designation: true },
        },
      },
      orderBy: { generalInfo: { fullName: 'asc' } },
    });

    return {
      defaults: {
        did_id: settings.default_did_id,
        connected: settings.connected,
      },
      telecallers: telecallers.map((e) => {
        const cfg = configs[String(e.id)] ?? {};
        return {
          employeeId: e.id,
          userId: e.userId,
          name: e.generalInfo?.fullName ?? `Employee #${e.id}`,
          employeeCode: e.generalInfo?.employeeCode ?? null,
          designation: e.generalInfo?.designation ?? 'Telecaller',
          configured: Boolean(cfg.agent_id || cfg.agent_number || cfg.agent_email),
          config: {
            agent_id: cfg.agent_id || '',
            agent_number: cfg.agent_number || '',
            agent_email: cfg.agent_email || '',
            did_id: cfg.did_id || settings.default_did_id || '',
          },
        };
      }),
    };
  }

  async upsertTelecallerTelephony(
    employeeId: number,
    body: Record<string, unknown>,
    updatedBy?: string,
    scope: string = 'NB_DEVELOPER',
  ) {
    if (!Number.isFinite(employeeId) || employeeId <= 0) throw new Error('Invalid employee id');
    const emp = await prisma.employee.findUnique({
      where: { id: employeeId },
      include: {
        generalInfo: {
          select: { designation: true, designationRef: { select: { name: true } } },
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
    const prev = map[String(employeeId)] || {};
    map[String(employeeId)] = {
      agent_id:
        body.agent_id != null ? String(body.agent_id).trim() : prev.agent_id,
      agent_number:
        body.agent_number != null
          ? normalizePhone10(String(body.agent_number))
          : prev.agent_number,
      agent_email:
        body.agent_email != null ? String(body.agent_email).trim() : prev.agent_email,
      did_id: body.did_id != null ? String(body.did_id).trim() : prev.did_id,
    };
    await this._writeTelecallerConfigMap(map, updatedBy, scope);
    const list = await this.listTelecallerTelephony(scope);
    return list.telecallers.find((t) => t.employeeId === employeeId) ?? null;
  }

  // ── Agents / DIDs ─────────────────────────────────────────────────────────

  async listAgents(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    const data = await client.listAgents();
    return { agents: asList(data), raw: data };
  }

  async syncAgents(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    const result = await client.syncAgents();
    const listed = await client.listAgents();
    return { ...result, agents: asList(listed) };
  }

  async assignAgent(
    agentId: string,
    payload: { user_id?: string | null; employee_id?: number },
    scope: string = 'NB_DEVELOPER',
    updatedBy?: string,
  ) {
    const client = await this.ensureAuthenticated(scope);
    let userId = payload.user_id ?? null;
    if (payload.employee_id != null) {
      const emp = await prisma.employee.findUnique({
        where: { id: Number(payload.employee_id) },
        select: { userId: true },
      });
      // 9ance expects their CRM user UUID — we store mapping locally and pass null to unmap remote if needed
      if (emp?.userId) {
        // Keep local map; remote assign only if caller sent explicit 9ance user_id
      }
      const map = await this._readTelecallerConfigMap(scope);
      const agents = asList(await client.listAgents());
      const agent = agents.find((a: any) => a.id === agentId);
      map[String(payload.employee_id)] = {
        ...(map[String(payload.employee_id)] || {}),
        agent_id: agentId,
        agent_number: agent?.phone ? normalizePhone10(String(agent.phone)) : map[String(payload.employee_id)]?.agent_number,
        agent_email: agent?.email || map[String(payload.employee_id)]?.agent_email,
      };
      await this._writeTelecallerConfigMap(map, updatedBy, scope);
    }
    if (userId !== undefined && payload.user_id !== undefined) {
      await client.assignAgent(agentId, userId);
    }
    return { success: true, agent_id: agentId, employee_id: payload.employee_id, user_id: userId };
  }

  async setAgentStatus(
    agentId: string,
    status: string,
    breakType?: string,
    scope: string = 'NB_DEVELOPER',
  ) {
    const client = await this.ensureAuthenticated(scope);
    return client.setAgentStatus(agentId, status, breakType);
  }

  async listDids(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    const data = await client.listDids();
    return { dids: asList(data), raw: data };
  }

  async syncDids(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    const result = await client.syncDids();
    const listed = await client.listDids();
    return { ...result, dids: asList(listed) };
  }

  async setDefaultDid(didId: string, scope: string = 'NB_DEVELOPER', updatedBy?: string) {
    const client = await this.ensureAuthenticated(scope);
    const result = await client.setDefaultDid(didId);
    await this.upsertSetting(prefixKey(scope, 'nineance_default_did_id'), didId, updatedBy);
    return result;
  }

  // ── Click to call ─────────────────────────────────────────────────────────

  async clickToCall(leadId: string, agentPhoneOrId?: string, userContext?: any) {
    const lead = await prisma.crmLead.findUnique({ where: { id: leadId } });
    if (!lead) throw new Error('Lead not found');

    const scope = lead.scope || 'NB_DEVELOPER';
    const settings = await this.getNineanceSettings(scope);
    if (!settings.connected && !settings.access_token && !(settings.email && settings.password)) {
      throw new Error('9ance Cloud Telephony is not configured. Open CRM Settings → Telephony.');
    }

    const telecallerMap = await this._readTelecallerConfigMap(scope);
    const empId = userContext?.employeeId != null ? Number(userContext.employeeId) : null;
    const personal =
      empId != null && Number.isFinite(empId) ? telecallerMap[String(empId)] : undefined;

    let customerNumber = normalizePhone10(lead.phone || '');
    if (!customerNumber) throw new Error('Lead has no phone number');

    let agentId = personal?.agent_id || '';
    let agentNumber = personal?.agent_number || '';
    let agentEmail = personal?.agent_email || '';
    const didId = personal?.did_id || settings.default_did_id || undefined;

    // Explicit agent override from UI (phone or 9ance agent uuid)
    if (agentPhoneOrId) {
      const raw = String(agentPhoneOrId).trim();
      if (raw.includes('-') || raw.length > 20) {
        agentId = raw;
      } else if (raw.includes('@')) {
        agentEmail = raw;
      } else {
        agentNumber = normalizePhone10(raw);
      }
    }

    if (!agentNumber && userContext?.employeeId && !agentId) {
      try {
        const emp = await prisma.employee.findUnique({
          where: { id: userContext.employeeId },
          include: { addresses: true },
        });
        const addr = emp?.addresses?.find((a: any) => a.mobileNo || a.phoneNo);
        if (addr) agentNumber = normalizePhone10(addr.mobileNo || addr.phoneNo || '');
      } catch (_) {}
    }

    if (!agentId && !agentNumber && !agentEmail) {
      throw new Error(
        'No 9ance agent mapped for this user. Map an agent under CRM Settings → Telephony → Agents.',
      );
    }

    await prisma.crmLead.update({
      where: { id: leadId },
      data: { lastCallAt: new Date() },
    });

    const client = await this.ensureAuthenticated(scope);
    const payload: any = {
      customer_number: customerNumber,
      lead_id: leadId,
    };
    if (agentId) payload.agent_id = agentId;
    else if (agentNumber) payload.agent_number = agentNumber;
    else if (agentEmail) payload.agent_email = agentEmail;
    if (didId) payload.did_id = didId;

    try {
      const responseData = await client.clickToCall(payload);
      const callId = responseData?.call_id || responseData?.provider_call_id || null;

      await prisma.crmCallLog.create({
        data: {
          leadId: lead.id,
          customerNumber,
          agentNumber: agentNumber || agentId || null,
          did: didId || null,
          callStatus: responseData?.success === false ? 'FAILED' : 'INITIATED',
          callTime: new Date(),
          callId: callId ? String(callId) : null,
          rawPayload: responseData as any,
        },
      });

      return {
        success: responseData?.success !== false,
        message:
          responseData?.message ||
          `Call initiated to ${customerNumber}${agentNumber ? ` via agent ${agentNumber}` : ''}.`,
        customerNumber,
        agentNumber: agentNumber || agentId,
        did: didId,
        callId,
        data: responseData,
      };
    } catch (err: any) {
      await prisma.crmCallLog.create({
        data: {
          leadId: lead.id,
          customerNumber,
          agentNumber: agentNumber || agentId || null,
          did: didId || null,
          callStatus: 'CONNECTION_ERROR',
          callTime: new Date(),
          rawPayload: { error: err?.message, detail: err?.detail || err?.providerError },
        },
      });
      return {
        success: false,
        error: err?.message || 'Failed to connect to 9ance Cloud Telephony',
      };
    }
  }

  // ── Webhook ───────────────────────────────────────────────────────────────

  async handleTelephonyWebhook(payload: any) {
    const eventType = String(
      payload.event || payload.event_type || payload.type || payload.call_event || '',
    ).toLowerCase();

    const rawCustomer = String(
      payload.customer_number ||
        payload.from_number ||
        payload.to_number ||
        payload.phone ||
        payload.cli ||
        payload.caller ||
        payload.Customer_No ||
        payload.customer_no ||
        payload.mobile ||
        payload.src ||
        payload.dst ||
        '',
    );

    // Prefer the non-DID party as customer for inbound
    let customerDigits = normalizePhone10(rawCustomer);
    const didDigits = digitsOnly(
      String(payload.did_number || payload.did || payload.DID || payload.virtual_number || ''),
    );
    if (
      payload.direction === 'inbound' &&
      payload.from_number &&
      normalizePhone10(String(payload.from_number))
    ) {
      customerDigits = normalizePhone10(String(payload.from_number));
    } else if (
      payload.direction === 'outbound' &&
      payload.to_number &&
      normalizePhone10(String(payload.to_number))
    ) {
      customerDigits = normalizePhone10(String(payload.to_number));
    }

    const rawAgent = String(
      payload.agent_number ||
        payload.agent_phone ||
        payload.agen_number ||
        payload.agent ||
        payload.extension ||
        payload.agent_id ||
        '',
    );
    const agentDigits = normalizePhone10(rawAgent) || String(payload.agent || '').trim();

    if (!customerDigits && !payload.call_id && !payload.provider_call_id && !payload.id) {
      return { status: 'ignored', message: 'No valid customer phone or call id in payload' };
    }

    const rawStatus = String(
      payload.call_status ||
        payload.status ||
        payload.call_result ||
        payload.disposition ||
        payload.Status ||
        'COMPLETED',
    ).trim();

    let callStatus = rawStatus.toUpperCase().replace(/\s+/g, '_');
    if (
      ['ANSWER', 'ANSWERED', 'COMPLETED', 'SUCCESS', 'CONNECTED', 'ANSWERED_CALL'].includes(callStatus)
    ) {
      callStatus = 'ANSWERED';
    } else if (
      ['NOANSWER', 'NO_ANSWER', 'MISSED', 'UNANSWERED', 'CANCEL', 'CUSTOMER_MISSED'].includes(callStatus)
    ) {
      callStatus = 'MISSED';
    } else if (['BUSY', 'LINE_BUSY', 'USER_BUSY'].includes(callStatus)) {
      callStatus = 'BUSY';
    } else if (eventType.includes('initat') || eventType === 'call_initiated' || eventType === 'live_call') {
      if (callStatus === 'COMPLETED') callStatus = 'RINGING';
    }

    const duration =
      parseInt(
        String(
          payload.talk_duration_secs ||
            payload.duration_secs ||
            payload.duration ||
            payload.AnsDur ||
            payload.talk_time ||
            payload.billsec ||
            0,
        ),
        10,
      ) || 0;

    let recordingUrl =
      payload.recording_url ||
      payload.recording ||
      payload.Recording_Path ||
      payload.audio_url ||
      null;
    if (recordingUrl && typeof recordingUrl === 'string') {
      recordingUrl = recordingUrl.trim();
    }

    const did =
      payload.did_number ||
      payload.did ||
      payload.DID ||
      payload.virtual_number ||
      (didDigits || null);
    const callId =
      payload.call_id ||
      payload.id ||
      payload.provider_call_id ||
      payload.unique_id ||
      payload.Call_ID ||
      null;

    const callTimeRaw =
      payload.started_at ||
      payload.call_time ||
      payload.ended_at ||
      payload.timestamp ||
      payload.Call_Time;
    const callTime = callTimeRaw ? new Date(callTimeRaw) : new Date();

    let leadId: string | null = payload.lead || payload.lead_id || null;
    if (leadId) {
      const exists = await prisma.crmLead.findUnique({
        where: { id: String(leadId) },
        select: { id: true },
      });
      if (!exists) leadId = null;
    }

    if (!leadId && customerDigits.length >= 10) {
      const matchedLead = await prisma.crmLead.findFirst({
        where: { phone: { contains: last10(customerDigits) } },
      });
      if (matchedLead) {
        leadId = matchedLead.id;
        await prisma.crmLead.update({
          where: { id: matchedLead.id },
          data: { lastCallAt: callTime },
        });
      } else if (
        payload.direction === 'inbound' ||
        eventType.includes('inbound') ||
        String(payload.source || '').toUpperCase().includes('IVR')
      ) {
        try {
          const newLead = await prisma.crmLead.create({
            data: {
              phone: customerDigits,
              name: `Inbound (${customerDigits})`,
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

    // Upsert by callId first
    let callLog = null as any;
    if (callId) {
      callLog = await prisma.crmCallLog.findFirst({
        where: { callId: String(callId) },
        orderBy: { createdAt: 'desc' },
      });
    }
    if (!callLog && customerDigits.length >= 10) {
      const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
      callLog = await prisma.crmCallLog.findFirst({
        where: {
          customerNumber: { contains: last10(customerDigits) },
          callStatus: { in: ['INITIATED', 'RINGING'] },
          createdAt: { gte: thirtyMinutesAgo },
        },
        orderBy: { createdAt: 'desc' },
      });
    }

    if (callLog) {
      callLog = await prisma.crmCallLog.update({
        where: { id: callLog.id },
        data: {
          leadId: leadId || callLog.leadId,
          callStatus,
          duration: duration || callLog.duration,
          recordingUrl: recordingUrl || callLog.recordingUrl,
          callTime,
          did: did ? String(did) : callLog.did,
          agentNumber: agentDigits || callLog.agentNumber,
          callId: callId ? String(callId) : callLog.callId,
          rawPayload: payload,
        },
      });
    } else {
      callLog = await prisma.crmCallLog.create({
        data: {
          leadId,
          customerNumber: customerDigits || 'unknown',
          agentNumber: agentDigits || null,
          did: did ? String(did) : null,
          callStatus,
          duration,
          recordingUrl,
          callTime,
          callId: callId ? String(callId) : null,
          rawPayload: payload,
        },
      });
    }

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
      event: eventType || undefined,
    };
  }

  async syncCallsFromNineance(scope: string = 'NB_DEVELOPER', query: Record<string, any> = {}) {
    const client = await this.ensureAuthenticated(scope);
    const data = await client.listCalls({ sync: 1, page_size: query.page_size || 50, ...query });
    const calls = asList(data);
    let upserted = 0;
    for (const c of calls) {
      const callId = String(c.id || c.provider_call_id || '');
      if (!callId) continue;
      const customer =
        c.direction === 'inbound'
          ? normalizePhone10(c.from_number || '')
          : normalizePhone10(c.to_number || '');
      let leadId: string | null = c.lead || null;
      if (!leadId && customer.length >= 10) {
        const matched = await prisma.crmLead.findFirst({
          where: { phone: { contains: last10(customer) } },
          select: { id: true },
        });
        leadId = matched?.id || null;
      }
      const statusRaw = String(c.status || c.call_result || 'COMPLETED').toUpperCase();
      let callStatus = statusRaw.replace(/\s+/g, '_');
      if (['ANSWERED', 'COMPLETED'].includes(callStatus) || statusRaw.includes('ANSWER')) {
        callStatus = callStatus === 'NO_ANSWER' ? 'MISSED' : 'ANSWERED';
      }
      if (callStatus === 'NO_ANSWER') callStatus = 'MISSED';

      const existing = await prisma.crmCallLog.findFirst({ where: { callId } });
      const row = {
        leadId,
        customerNumber: customer || 'unknown',
        agentNumber: c.agent_name || c.agent || null,
        did: c.did_number || null,
        callStatus,
        duration: Number(c.talk_duration_secs || c.duration_secs || 0) || 0,
        recordingUrl: c.recording_url || null,
        callTime: c.started_at ? new Date(c.started_at) : new Date(),
        callId,
        rawPayload: c,
      };
      if (existing) {
        await prisma.crmCallLog.update({ where: { id: existing.id }, data: row });
      } else {
        await prisma.crmCallLog.create({ data: row });
      }
      upserted += 1;
    }
    return { success: true, upserted, total: calls.length, raw: data };
  }

  async streamCallAudio(logId: string, req: Request, res: Response) {
    const log = await prisma.crmCallLog.findUnique({
      where: { id: logId },
      select: { id: true, recordingUrl: true, callId: true, leadId: true },
    });
    if (!log) return res.status(404).send('Recording not found');

    let scope = 'NB_DEVELOPER';
    if (log.leadId) {
      const lead = await prisma.crmLead.findUnique({
        where: { id: log.leadId },
        select: { scope: true },
      });
      if (lead?.scope) scope = lead.scope;
    }

    // Prefer 9ance authenticated recording proxy
    if (log.callId) {
      try {
        const client = await this.ensureAuthenticated(scope);
        const upstreamRes = await client.fetchRecordingResponse(
          String(log.callId),
          req.headers.range as string | undefined,
        );
        if (upstreamRes.ok || upstreamRes.status === 206) {
          const contentType = upstreamRes.headers.get('content-type') || 'audio/mpeg';
          if (!contentType.includes('text/html')) {
            res.status(upstreamRes.status);
            res.setHeader('Content-Type', contentType);
            res.setHeader('Accept-Ranges', 'bytes');
            res.setHeader('Access-Control-Allow-Origin', '*');
            const cl = upstreamRes.headers.get('content-length');
            if (cl) res.setHeader('Content-Length', cl);
            const cr = upstreamRes.headers.get('content-range');
            if (cr) res.setHeader('Content-Range', cr);
            if (upstreamRes.body) {
              const { Readable } = await import('stream');
              // @ts-ignore
              Readable.fromWeb(upstreamRes.body).pipe(res);
              return;
            }
          }
        }
      } catch (err: any) {
        console.warn('[9ance recording proxy]', err?.message);
      }
    }

    if (!log.recordingUrl) return res.status(404).send('Recording not found');

    let audioUrl = log.recordingUrl.trim();
    try {
      const headers: Record<string, string> = {
        'User-Agent': 'NB-CRM-Audio-Streamer/1.0',
      };
      if (req.headers.range) headers.Range = req.headers.range as string;
      // Attach bearer if URL is on 9ance host
      if (audioUrl.includes('9ance.com')) {
        try {
          const client = await this.ensureAuthenticated(scope);
          if (client.accessToken) headers.Authorization = `Bearer ${client.accessToken}`;
        } catch (_) {}
      }
      const upstreamRes = await fetch(audioUrl, { method: 'GET', headers });
      const contentType = upstreamRes.headers.get('content-type') || 'audio/mpeg';
      if (contentType.includes('text/html')) {
        return res.status(404).send('Audio recording file not found');
      }
      res.status(upstreamRes.status);
      res.setHeader('Content-Type', contentType);
      res.setHeader('Accept-Ranges', 'bytes');
      res.setHeader('Access-Control-Allow-Origin', '*');
      const cl = upstreamRes.headers.get('content-length');
      if (cl) res.setHeader('Content-Length', cl);
      const cr = upstreamRes.headers.get('content-range');
      if (cr) res.setHeader('Content-Range', cr);
      if (upstreamRes.body) {
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
  }

  async getDialerConfig(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    try {
      return await client.getDialerConfig();
    } catch {
      return await client.getSoftphoneConfig();
    }
  }

  async getWsToken(scope: string = 'NB_DEVELOPER') {
    const s = await this.getNineanceSettings(scope);
    const client = await this.ensureAuthenticated(scope);
    return {
      access: client.accessToken || s.access_token,
      ws_url: `wss://${new URL(s.base_url || DEFAULT_NINEANCE_BASE).host}/ws/telephony/calls/`,
      base_url: s.base_url || DEFAULT_NINEANCE_BASE,
    };
  }

  async dispositionCall(
    callId: string,
    payload: { disposition: string; notes?: string; follow_up_at?: string },
    scope: string = 'NB_DEVELOPER',
  ) {
    const client = await this.ensureAuthenticated(scope);
    return client.dispositionCall(callId, payload);
  }

  async listLiveCalls(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.listLiveCalls();
  }

  async matchPhone(phone: string, scope: string = 'NB_DEVELOPER') {
    // Prefer local CRM match; also try 9ance
    const local = await prisma.crmLead.findFirst({
      where: { phone: { contains: last10(phone) } },
      select: { id: true, name: true, phone: true, status: true },
    });
    let remote: any = null;
    try {
      const client = await this.ensureAuthenticated(scope);
      remote = await client.matchPhone(normalizePhone10(phone));
    } catch (_) {}
    return { local, remote };
  }

  // Campaigns / analytics thin proxies
  async listCampaigns(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.listCampaigns();
  }

  async createCampaign(payload: Record<string, any>, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.createCampaignJson(payload);
  }

  async startCampaign(id: string, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.startCampaign(id);
  }

  async stopCampaign(id: string, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.stopCampaign(id);
  }

  async campaignReport(id: string, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.campaignReport(id);
  }

  async previewDialList(payload: Record<string, any>, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.previewDialList(payload);
  }

  async listDispositions(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.listDispositions();
  }

  async providerDashboard(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.providerDashboard();
  }

  async agentAnalytics(scope: string = 'NB_DEVELOPER', date?: string) {
    const client = await this.ensureAuthenticated(scope);
    return client.agentAnalytics(date);
  }
}

export const telephonyService = new TelephonyService();
