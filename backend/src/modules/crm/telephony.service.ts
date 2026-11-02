/**
 * CRM telephony orchestration over 9ance Cloud Telephony.
 * Replaces Elision / Greeter Click2Call.
 */

import { Request, Response as ExpressResponse } from 'express';
import { prisma } from '../../config/prisma';
import {
  DEFAULT_NINEANCE_BASE,
  NineanceApiError,
  NineanceClient,
  NineanceTokens,
} from './nineance.client';
import { whatsappService } from './whatsapp.service';

/** Fetch API Response (avoid clash with Express Response) */
type FetchResponse = globalThis.Response;

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
  // Always collapse to last 10 digits (handles 0-prefix and 91-prefix).
  return last10(v);
}

/** Dial number for CTC: keep full international digits when present; else last 10. */
function dialNumberFromLeadPhone(phone: string): string {
  const raw = String(phone || '').trim();
  const d = digitsOnly(raw);
  if (!d) return '';
  if (raw.startsWith('+') || d.length > 10) return d;
  return last10(d);
}

/** User-confirmed dial override — digits only, no forced last-10 truncation. */
function dialNumberOverride(v: string): string {
  return digitsOnly(String(v || '').trim());
}

function didNumberOf(item: any): string {
  const raw =
    item?.default_did_number ??
    item?.effective_did ??
    item?.default_did ??
    item?.did_number ??
    '';
  if (raw && typeof raw === 'object') {
    return String(raw.number || raw.did || raw.value || '').trim();
  }
  return String(raw || '').trim();
}

function agentDedupeKey(item: any): string {
  // Phone first — 9ance often returns duplicate agent rows (different UUID /
  // provider_agent_id) for the same real number after create+sync.
  const phone = normalizePhone10(String(item?.phone || item?.sip_username || ''));
  if (phone.length >= 10) return `ph:${phone}`;
  const providerId = item?.provider_agent_id != null ? String(item.provider_agent_id).trim() : '';
  if (providerId) return `p:${providerId}`;
  const id = item?.id != null ? String(item.id) : '';
  if (id) return `id:${id}`;
  const name = String(item?.name || '').trim().toLowerCase();
  return `n:${name}|${phone}`;
}

function normalizeAgentRecord(item: any): any {
  if (!item || typeof item !== 'object') return item;
  const didNum = didNumberOf(item);
  return {
    ...item,
    id: item.id != null ? String(item.id) : item.id,
    provider_agent_id:
      item.provider_agent_id != null ? String(item.provider_agent_id) : item.provider_agent_id,
    default_did_number: didNum || (typeof item.default_did_number === 'string' ? item.default_did_number : ''),
    effective_did: didNum || (typeof item.effective_did === 'string' ? item.effective_did : ''),
  };
}

function preferAgent(a: any, b: any): any {
  const score = (x: any) => {
    let s = 0;
    if (x?.user || x?.user_id || x?.user_name) s += 8;
    if (x?.is_active === true) s += 4;
    if (x?.sip_password_set === true) s += 2;
    if (x?.phone) s += 1;
    const t = Date.parse(String(x?.updated_at || x?.last_synced_at || '')) || 0;
    return s * 1e15 + t;
  };
  return score(a) >= score(b) ? a : b;
}

function asList(data: any): any[] {
  let list: any[] = [];
  if (Array.isArray(data)) list = data;
  else if (Array.isArray(data?.results)) list = data.results;
  else if (Array.isArray(data?.data)) list = data.data;
  else if (Array.isArray(data?.agents)) list = data.agents;
  else if (Array.isArray(data?.dids)) list = data.dids;
  else if (Array.isArray(data?.calls)) list = data.calls;

  // 9ance often returns the same person twice (sync + create) with different UUIDs.
  // Collapse by phone → provider_agent_id → id.
  const byKey = new Map<string, any>();
  for (const raw of list) {
    if (!raw || typeof raw !== 'object') continue;
    const item = normalizeAgentRecord(raw);
    const key = agentDedupeKey(item);
    const prev = byKey.get(key);
    byKey.set(key, prev ? preferAgent(prev, item) : item);
  }
  return Array.from(byKey.values());
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

  /** Agent numbers / ids mapped to an employee for call-log ownership checks. */
  async getEmployeeAgentIdentifiers(
    employeeId: number,
    scope: string = 'NB_DEVELOPER',
  ): Promise<{ agentNumbers: string[]; agentIds: string[] }> {
    const agentNumbers = new Set<string>();
    const agentIds = new Set<string>();
    if (!Number.isFinite(employeeId) || employeeId <= 0) {
      return { agentNumbers: [], agentIds: [] };
    }

    const map = await this._readTelecallerConfigMap(scope);
    const cfg = map[String(employeeId)] || {};
    if (cfg.agent_number) {
      const n = normalizePhone10(String(cfg.agent_number));
      if (n) agentNumbers.add(n);
      if (n.length >= 10) agentNumbers.add(last10(n));
    }
    if (cfg.agent_id) agentIds.add(String(cfg.agent_id).trim());

    try {
      const emp = await prisma.employee.findUnique({
        where: { id: employeeId },
        include: { addresses: true },
      });
      const addr = emp?.addresses?.find((a: any) => a.mobileNo || a.phoneNo);
      if (addr) {
        const n = normalizePhone10(addr.mobileNo || addr.phoneNo || '');
        if (n) {
          agentNumbers.add(n);
          if (n.length >= 10) agentNumbers.add(last10(n));
        }
      }
    } catch (_) {}

    return {
      agentNumbers: [...agentNumbers].filter(Boolean),
      agentIds: [...agentIds].filter(Boolean),
    };
  }

  async listTelecallerTelephony(scope: string = 'NB_DEVELOPER') {
    const configs = await this._readTelecallerConfigMap(scope);
    const settings = await this.getNineanceSettings(scope);

    // Include telecallers + anyone already mapped (sales/admin/etc can own an agent).
    const mappedIds = Object.entries(configs)
      .filter(([, cfg]) => Boolean(cfg?.agent_id || cfg?.agent_number || cfg?.agent_email))
      .map(([id]) => Number(id))
      .filter((id) => Number.isFinite(id) && id > 0);

    const employees = await prisma.employee.findMany({
      where: {
        status: 'ACTIVE',
        OR: [
          { generalInfo: { designation: { contains: 'telecall', mode: 'insensitive' } } },
          {
            generalInfo: {
              designationRef: { name: { contains: 'telecall', mode: 'insensitive' } },
            },
          },
          { user: { role: { name: { contains: 'telecall', mode: 'insensitive' } } } },
          ...(mappedIds.length ? [{ id: { in: mappedIds } }] : []),
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
      telecallers: employees.map((e) => {
        const cfg = configs[String(e.id)] ?? {};
        return {
          employeeId: e.id,
          userId: e.userId,
          name: e.generalInfo?.fullName ?? `Employee #${e.id}`,
          employeeCode: e.generalInfo?.employeeCode ?? null,
          designation: e.generalInfo?.designation ?? null,
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
      select: {
        id: true,
        generalInfo: { select: { fullName: true, employeeCode: true, designation: true } },
        userId: true,
      },
    });
    if (!emp) throw new Error('Employee not found');

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
    const cfg = map[String(employeeId)];
    return {
      employeeId: emp.id,
      userId: emp.userId,
      name: emp.generalInfo?.fullName ?? `Employee #${emp.id}`,
      employeeCode: emp.generalInfo?.employeeCode ?? null,
      designation: emp.generalInfo?.designation ?? null,
      configured: Boolean(cfg.agent_id || cfg.agent_number || cfg.agent_email),
      config: {
        agent_id: cfg.agent_id || '',
        agent_number: cfg.agent_number || '',
        agent_email: cfg.agent_email || '',
        did_id: cfg.did_id || '',
      },
    };
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

  async clickToCall(
    leadId: string,
    agentPhoneOrId?: string,
    userContext?: any,
    customerNumberOverride?: string,
  ) {
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

    let customerNumber = customerNumberOverride?.trim()
      ? dialNumberOverride(customerNumberOverride)
      : dialNumberFromLeadPhone(lead.phone || '');
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
      // 9ance often places the call even when our HTTP layer fails (timeout, truncated
      // body, non-2xx with call_id). Prefer INITIATED so webhooks / sync can correct
      // status+duration instead of sticking on CONNECTION_ERROR.
      const detail = err?.detail || err?.providerError || err?.body || err?.response || {};
      const detailObj = detail && typeof detail === 'object' ? detail : {};
      const recoveredCallId =
        detailObj.call_id ||
        detailObj.provider_call_id ||
        detailObj.id ||
        detailObj.Call_ID ||
        null;
      const msg = String(err?.message || '').toLowerCase();
      const likelyDialed =
        !!recoveredCallId ||
        /timeout|timed out|network|econnreset|econnrefused|fetch failed|aborted|socket/.test(msg) ||
        (typeof err?.status === 'number' && err.status >= 500);
      const callStatus = likelyDialed ? 'INITIATED' : 'CONNECTION_ERROR';
      await prisma.crmCallLog.create({
        data: {
          leadId: lead.id,
          customerNumber,
          agentNumber: agentNumber || agentId || null,
          did: didId || null,
          callStatus,
          callTime: new Date(),
          callId: recoveredCallId ? String(recoveredCallId) : null,
          rawPayload: {
            error: err?.message,
            detail: detailObj,
            status: err?.status,
            likelyDialed,
          },
        },
      });
      return {
        success: likelyDialed,
        error: likelyDialed
          ? undefined
          : err?.message || 'Failed to connect to 9ance Cloud Telephony',
        message: likelyDialed
          ? `Call started (provider may have dialed) despite API warning: ${err?.message || 'unknown'}`
          : undefined,
        callId: recoveredCallId ? String(recoveredCallId) : undefined,
        customerNumber,
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
      // Also match CONNECTION_ERROR / FAILED — click-to-call may have thrown after
      // 9ance already dialed; webhook must still be able to correct status/duration.
      callLog = await prisma.crmCallLog.findFirst({
        where: {
          customerNumber: { contains: last10(customerDigits) },
          callStatus: {
            in: ['INITIATED', 'RINGING', 'CONNECTION_ERROR', 'FAILED', 'LIVE', 'IN_PROGRESS'],
          },
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
    const data = await client.listCalls({
      sync: 1,
      page_size: query.page_size || 100,
      ...query,
    });
    const calls = asList(data);
    let upserted = 0;
    let healed = 0;
    let skipped = 0;
    const errors: string[] = [];

    const resolveLeadId = async (
      candidate: string | null | undefined,
      customerPhone: string,
    ): Promise<string | null> => {
      // 9ance `lead` is often their own id — only keep if it exists in our CRM
      if (candidate) {
        const id = String(candidate).trim();
        if (id) {
          const found = await prisma.crmLead.findUnique({
            where: { id },
            select: { id: true },
          });
          if (found) return found.id;
        }
      }
      if (customerPhone.length >= 10) {
        const matched = await prisma.crmLead.findFirst({
          where: { phone: { contains: last10(customerPhone) } },
          select: { id: true },
        });
        if (matched) return matched.id;
      }
      return null;
    };

    for (const c of calls) {
      try {
        const callId = String(c.id || c.provider_call_id || '');
        if (!callId) continue;
        const customer =
          c.direction === 'inbound'
            ? normalizePhone10(c.from_number || '')
            : normalizePhone10(c.to_number || '');

        const statusRaw = String(c.status || c.call_result || 'COMPLETED').toUpperCase();
        let callStatus = statusRaw.replace(/\s+/g, '_');
        if (['ANSWERED', 'COMPLETED'].includes(callStatus) || statusRaw.includes('ANSWER')) {
          callStatus = callStatus === 'NO_ANSWER' ? 'MISSED' : 'ANSWERED';
        }
        if (callStatus === 'NO_ANSWER') callStatus = 'MISSED';

        const callTime = c.started_at ? new Date(c.started_at) : new Date();
        const duration = Number(c.talk_duration_secs || c.duration_secs || 0) || 0;

        let existing = await prisma.crmCallLog.findFirst({ where: { callId } });
        let didHeal = false;
        // Heal sticky click-to-call CONNECTION_ERROR / FAILED rows that never got a callId
        if (!existing && customer.length >= 10) {
          const windowStart = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000);
          const callTimeStart = new Date(callTime.getTime() - 2 * 60 * 60 * 1000);
          const callTimeEnd = new Date(callTime.getTime() + 2 * 60 * 60 * 1000);
          const candidates = await prisma.crmCallLog.findMany({
            where: {
              customerNumber: { contains: last10(customer) },
              callStatus: { in: ['CONNECTION_ERROR', 'FAILED', 'INITIATED', 'RINGING'] },
              createdAt: { gte: windowStart },
              OR: [{ callId: null }, { callId: '' }],
              callTime: { gte: callTimeStart, lte: callTimeEnd },
            },
            orderBy: { createdAt: 'desc' },
            take: 10,
          });
          if (candidates.length === 0) {
            const loose = await prisma.crmCallLog.findMany({
              where: {
                customerNumber: { contains: last10(customer) },
                callStatus: { in: ['CONNECTION_ERROR', 'FAILED'] },
                createdAt: { gte: windowStart },
                OR: [{ callId: null }, { callId: '' }],
              },
              orderBy: { createdAt: 'desc' },
              take: 5,
            });
            existing = loose[0] || null;
          } else {
            existing = candidates.sort((a, b) => {
              const aT = a.callTime ? a.callTime.getTime() : a.createdAt.getTime();
              const bT = b.callTime ? b.callTime.getTime() : b.createdAt.getTime();
              return Math.abs(aT - callTime.getTime()) - Math.abs(bT - callTime.getTime());
            })[0];
          }
          if (existing) didHeal = true;
        }

        const leadId = await resolveLeadId(
          c.lead || c.lead_id || existing?.leadId || null,
          customer,
        );

        const row = {
          leadId,
          customerNumber: customer || existing?.customerNumber || 'unknown',
          agentNumber: c.agent_name || c.agent || existing?.agentNumber || null,
          did: c.did_number || existing?.did || null,
          callStatus,
          duration,
          recordingUrl: c.recording_url || existing?.recordingUrl || null,
          callTime,
          callId,
          rawPayload: c,
        };
        if (existing) {
          await prisma.crmCallLog.update({ where: { id: existing.id }, data: row });
          if (didHeal) healed += 1;
        } else {
          await prisma.crmCallLog.create({ data: row });
        }
        upserted += 1;
      } catch (err: any) {
        skipped += 1;
        const msg = err?.message || String(err);
        if (errors.length < 5) errors.push(msg);
        console.warn('[9ance sync skip]', msg);
      }
    }
    return {
      success: true,
      upserted,
      healed,
      skipped,
      total: calls.length,
      errors: errors.length ? errors : undefined,
      raw: data,
    };
  }

  /** Best-effort: pull 9ance history to fix sticky CONNECTION_ERROR rows (throttled). */
  private _lastHealAtByScope = new Map<string, number>();
  async maybeHealStaleCallErrors(scope: string = 'NB_DEVELOPER') {
    const now = Date.now();
    const last = this._lastHealAtByScope.get(scope) || 0;
    if (now - last < 90_000) return { skipped: true };
    this._lastHealAtByScope.set(scope, now);

    const windowStart = new Date(now - 14 * 24 * 60 * 60 * 1000);
    const sticky = await prisma.crmCallLog.count({
      where: {
        callStatus: { in: ['CONNECTION_ERROR', 'FAILED'] },
        createdAt: { gte: windowStart },
        OR: [{ callId: null }, { callId: '' }],
      },
    });
    if (sticky === 0) return { skipped: true, sticky: 0 };
    try {
      return await this.syncCallsFromNineance(scope, { page_size: 100 });
    } catch (err: any) {
      console.warn('[telephony heal]', err?.message);
      return { skipped: false, error: err?.message };
    }
  }

  private async _pipeUpstreamAudio(
    upstreamRes: FetchResponse,
    res: ExpressResponse,
  ): Promise<boolean> {
    if (!(upstreamRes.ok || upstreamRes.status === 206)) return false;
    const contentType = upstreamRes.headers.get('content-type') || 'audio/mpeg';
    // Reject HTML login pages and JSON error bodies
    if (
      contentType.includes('text/html') ||
      contentType.includes('application/json') ||
      contentType.includes('text/plain')
    ) {
      return false;
    }
    res.status(upstreamRes.status);
    res.setHeader('Content-Type', contentType.includes('audio') ? contentType : 'audio/mpeg');
    res.setHeader('Accept-Ranges', 'bytes');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 'private, max-age=60');
    const cl = upstreamRes.headers.get('content-length');
    if (cl) res.setHeader('Content-Length', cl);
    const cr = upstreamRes.headers.get('content-range');
    if (cr) res.setHeader('Content-Range', cr);
    if (upstreamRes.body) {
      const { Readable } = await import('stream');
      // @ts-ignore
      Readable.fromWeb(upstreamRes.body).pipe(res);
      return true;
    }
    return false;
  }

  async streamCallAudio(logId: string, req: Request, res: ExpressResponse) {
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
    const scopesToTry = Array.from(new Set([scope, 'NB_DEVELOPER', 'NB_FINSERVE']));
    const range = req.headers.range as string | undefined;
    const proxyErrors: string[] = [];

    // 1) Authenticated 9ance recording by callId (with token refresh)
    if (log.callId) {
      for (const tryScope of scopesToTry) {
        try {
          const client = await this.ensureAuthenticated(tryScope);
          const upstreamRes = await client.fetchRecordingResponse(String(log.callId), range);
          if (await this._pipeUpstreamAudio(upstreamRes, res)) return;
          proxyErrors.push(`${tryScope} callId→${upstreamRes.status}`);
        } catch (err: any) {
          proxyErrors.push(`${tryScope} callId→${err?.message || err}`);
        }
      }
    }

    // 2) Fallback: stored recordingUrl with Bearer if hosted on 9ance
    if (log.recordingUrl) {
      let audioUrl = log.recordingUrl.trim();
      // Relative 9ance API paths → absolute
      if (audioUrl.startsWith('/')) {
        audioUrl = `https://crmapi.9ance.com${audioUrl}`;
      }
      for (const tryScope of scopesToTry) {
        try {
          const headers: Record<string, string> = {
            'User-Agent': 'NB-CRM-Audio-Streamer/1.0',
            Accept: 'audio/*,application/octet-stream,*/*',
          };
          if (range) headers.Range = range;
          if (audioUrl.includes('9ance.com')) {
            const client = await this.ensureAuthenticated(tryScope);
            if (client.accessToken) headers.Authorization = `Bearer ${client.accessToken}`;
          }
          let upstreamRes = await fetch(audioUrl, { method: 'GET', headers });
          if (upstreamRes.status === 401 && audioUrl.includes('9ance.com')) {
            const refreshed = await this.refreshTokens(tryScope).catch(() => null);
            if (refreshed?.access) {
              headers.Authorization = `Bearer ${refreshed.access}`;
              upstreamRes = await fetch(audioUrl, { method: 'GET', headers });
            }
          }
          if (await this._pipeUpstreamAudio(upstreamRes, res)) return;
          proxyErrors.push(`${tryScope} url→${upstreamRes.status}`);
        } catch (err: any) {
          proxyErrors.push(`${tryScope} url→${err?.message || err}`);
        }
      }
    }

    console.warn('[9ance recording proxy failed]', logId, proxyErrors.join(' | '));
    if (!res.headersSent) {
      return res.status(404).json({
        status: 'error',
        message:
          'Recording not available from 9ance yet (auth or file missing). Re-sync the call or try again shortly.',
        details: proxyErrors,
      });
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

  async createDisposition(
    payload: { label: string; value: string; color?: string },
    scope: string = 'NB_DEVELOPER',
  ) {
    const client = await this.ensureAuthenticated(scope);
    return client.createDisposition(payload);
  }

  async updateDisposition(id: string, payload: Record<string, any>, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.updateDisposition(id, payload);
  }

  async deleteDisposition(id: string, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.deleteDisposition(id);
  }

  async providerDashboard(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.providerDashboard();
  }

  async agentAnalytics(scope: string = 'NB_DEVELOPER', date?: string) {
    const client = await this.ensureAuthenticated(scope);
    return client.agentAnalytics(date);
  }

  async myAnalytics(scope: string = 'NB_DEVELOPER', date?: string) {
    const client = await this.ensureAuthenticated(scope);
    return client.myAnalytics(date);
  }

  async createAgent(
    payload: { name: string; phone: string; access?: string; sip_password?: string },
    scope: string = 'NB_DEVELOPER',
  ) {
    const client = await this.ensureAuthenticated(scope);
    const phone = normalizePhone10(payload.phone);
    if (!payload.name?.trim() || !phone) {
      throw new Error('Agent name and 10-digit phone are required');
    }
    return client.createAgent({
      name: payload.name.trim(),
      phone,
      access: payload.access || '2',
      sip_password: payload.sip_password,
    });
  }

  async deleteAgent(id: string, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    const rawId = String(id || '').trim();
    if (!rawId) throw new Error('Agent id is required');

    // Resolve aliases — 9ance sometimes rejects UUID with "invalid member id"
    // and expects provider_agent_id (telephony member id) instead.
    let providerId = '';
    let uuid = rawId;
    try {
      const agents = asList(await client.listAgents());
      const match = agents.find(
        (a: any) =>
          String(a?.id || '') === rawId ||
          String(a?.provider_agent_id || '') === rawId,
      );
      if (match) {
        uuid = String(match.id || rawId);
        providerId = String(match.provider_agent_id || '');
      }
    } catch (_) {
      /* still try delete with given id */
    }

    const candidates = Array.from(new Set([uuid, providerId, rawId].filter(Boolean)));
    let lastErr: any;
    for (const candidate of candidates) {
      try {
        return await client.deleteAgent(candidate);
      } catch (err: any) {
        lastErr = err;
        const msg = String(err?.message || err?.detail || '').toLowerCase();
        const alreadyGone =
          err?.status === 404 ||
          msg.includes('not found') ||
          msg.includes('does not exist');
        if (alreadyGone) return { deleted: true, already_gone: true };
        const tryNext =
          msg.includes('member') ||
          msg.includes('invalid') ||
          msg.includes('uuid') ||
          err?.status === 400;
        if (!tryNext) break;
      }
    }
    throw lastErr || new Error('Failed to delete agent');
  }

  async bulkAssignAgents(
    assignments: Array<{ agent_id: string; user_id: string | null }>,
    scope: string = 'NB_DEVELOPER',
  ) {
    const client = await this.ensureAuthenticated(scope);
    return client.bulkAssignAgents(assignments);
  }

  async getMyAgent(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.getMyAgent();
  }

  async getMyAgentStatus(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.getMyAgentStatus();
  }

  async setMyAgentStatus(status: string, breakType?: string, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.setMyAgentStatus(status, breakType);
  }

  async listProviderConfigs(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.listProviderConfigs();
  }

  async createProviderConfig(payload: Record<string, any>, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.createProviderConfig(payload);
  }

  async updateProviderConfig(id: string, payload: Record<string, any>, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.updateProviderConfig(id, payload);
  }

  async deleteProviderConfig(id: string, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.deleteProviderConfig(id);
  }

  async enableProviderConfig(id: string, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.enableProviderConfig(id);
  }

  async listCallGroups(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.listCallGroups();
  }

  async createCallGroup(
    payload: { group_name: string; members: string[]; ring_type?: string },
    scope: string = 'NB_DEVELOPER',
  ) {
    const client = await this.ensureAuthenticated(scope);
    return client.createCallGroup(payload);
  }

  async transcriptionCapability(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.transcriptionCapability();
  }

  async getTranscriptionSettings(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.getTranscriptionSettings();
  }

  async updateTranscriptionSettings(payload: Record<string, any>, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.updateTranscriptionSettings(payload);
  }

  async getNineanceConfig(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.getConfig();
  }

  async updateNineanceConfig(payload: Record<string, any>, scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.updateConfig(payload);
  }

  async deleteNineanceConfig(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.deleteConfig();
  }

  async getSoftphoneConfig(scope: string = 'NB_DEVELOPER') {
    const client = await this.ensureAuthenticated(scope);
    return client.getSoftphoneConfig();
  }

  async listAuthProducts() {
    const client = new NineanceClient((await this.getNineanceSettings()).base_url);
    return client.listProducts();
  }

  async getWebhookUrls(scope: string = 'NB_DEVELOPER') {
    const s = await this.getNineanceSettings(scope);
    const client = this.getClient(scope);
    client.setBaseUrl(s.base_url);
    const token = s.webhook_token;
    return {
      webhook_token: token,
      webhook_url: token ? client.buildWebhookUrl(token, false) : s.webhook_url,
      live_calls_webhook_url: token ? client.buildWebhookUrl(token, true) : '',
      crm_receiver_url: 'https://crm.nbdeveloper.co.in/api/crm/telephony/webhook',
    };
  }
}

export const telephonyService = new TelephonyService();
