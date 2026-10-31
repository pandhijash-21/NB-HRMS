import { env } from '../../config/env';
import {
  HubPartner,
  HubTrashRecord,
  HubApiResponse,
  CreateHubPartnerDto,
  UpdateHubPartnerDto,
} from './hub.types';

function asStringList(raw: unknown): string[] {
  if (raw == null) return [];
  if (Array.isArray(raw)) {
    return raw.map((e) => String(e).trim()).filter(Boolean);
  }
  if (typeof raw === 'string') {
    return raw
      .split(/[,;|]/)
      .map((e) => e.trim())
      .filter(Boolean);
  }
  return [];
}

export class HubApiService {
  private readonly baseUrl: string;
  private readonly timeoutMs: number;

  constructor(baseUrl?: string, timeoutMs = 10000) {
    const raw =
      baseUrl ||
      env.NB_HUB_API_URL ||
      process.env.NB_HUB_API_URL ||
      'https://crm.nbdeveloper.co.in/hub-api/api';
    this.baseUrl = raw.trim().replace(/\/+$/, '');
    this.timeoutMs = timeoutMs;
  }

  getBaseUrl(): string {
    return this.baseUrl;
  }

  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<HubApiResponse<T>> {
    const url = `${this.baseUrl}${endpoint.startsWith('/') ? '' : '/'}${endpoint}`;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      const response = await fetch(url, {
        ...options,
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          ...(options.headers || {}),
        },
      });

      const body = await response.json().catch(() => null);

      if (!response.ok) {
        const errorMsg =
          body?.message || body?.error || `Hub API responded with HTTP status ${response.status}`;
        throw new Error(errorMsg);
      }

      return body as HubApiResponse<T>;
    } catch (err: any) {
      if (err.name === 'AbortError') {
        throw new Error(`NB Hub API timed out after ${this.timeoutMs / 1000}s on ${endpoint}`);
      }
      console.error(`[HubApiService Error] Failed on ${endpoint}:`, err.message || err);
      throw err;
    } finally {
      clearTimeout(timeout);
    }
  }

  /**
   * Lightweight connectivity check against Hub onboarding list.
   */
  async healthCheck(): Promise<{ ok: boolean; baseUrl: string; count?: number; message?: string }> {
    try {
      const partners = await this.getAllPartners();
      return { ok: true, baseUrl: this.baseUrl, count: partners.length };
    } catch (err: any) {
      return {
        ok: false,
        baseUrl: this.baseUrl,
        message: err?.message || 'Hub API unreachable',
      };
    }
  }

  /**
   * Fetch all active NB Hub onboarding partners.
   */
  async getAllPartners(): Promise<HubPartner[]> {
    const res = await this.request<HubPartner[]>('/admin/onboarding', {
      method: 'GET',
    });
    return (res.data || []).map((p) => this.normalizePartnerResponse(p));
  }

  /**
   * Fetch a specific partner/user profile by username or email.
   */
  async getPartnerByEmailOrUsername(identifier: string): Promise<HubPartner | null> {
    if (!identifier) return null;
    const res = await this.request<HubPartner>(
      `/user/profile?identifier=${encodeURIComponent(identifier)}`,
      {
        method: 'GET',
      },
    );
    const raw = res.user || res.data || null;
    return raw ? this.normalizePartnerResponse(raw) : null;
  }

  /** Map Hub response into a consistent snake_case + dual-alias shape for CRM clients. */
  private normalizePartnerResponse(raw: any): HubPartner {
    const p = raw && typeof raw === 'object' ? raw : {};
    const nature = asStringList(p.nature_of_business ?? p.natureOfBusiness);
    const areas = asStringList(p.areas_of_practice ?? p.areasOfPractice);
    return {
      ...p,
      id: String(p.id ?? ''),
      role: String(p.role ?? 'CP').toUpperCase(),
      email: String(p.email ?? ''),
      username: String(p.username ?? ''),
      phone: p.phone != null ? String(p.phone) : undefined,
      company_or_firm_name:
        p.company_or_firm_name ?? p.companyOrFirmName ?? p.firmName ?? p.companyName ?? undefined,
      contact_person_name:
        p.contact_person_name ?? p.contactPersonName ?? p.name ?? p.fullName ?? undefined,
      company_logo: p.company_logo ?? p.companyLogo ?? undefined,
      professional_stream: p.professional_stream ?? p.professionalStream ?? undefined,
      constitution: p.constitution ?? undefined,
      icai_membership_no: p.icai_membership_no ?? p.icaiMembershipNo ?? undefined,
      cop_no: p.cop_no ?? p.copNo ?? undefined,
      pan: p.pan ?? undefined,
      gstin: p.gstin ?? undefined,
      rera_no: p.rera_no ?? p.reraNo ?? undefined,
      date_of_incorporation: p.date_of_incorporation ?? p.dateOfIncorporation ?? undefined,
      address: p.address ?? undefined,
      city: p.city ?? undefined,
      pincode: p.pincode ?? undefined,
      website: p.website ?? undefined,
      nature_of_business: nature,
      areas_of_practice: areas,
      declaration_accepted:
        p.declaration_accepted === true ||
        p.declarationAccepted === true ||
        p.declaration_accepted === 1,
      status: String(p.status ?? 'ACTIVE').toUpperCase(),
      permission_level: String(p.permission_level ?? p.permissionLevel ?? 'READ_ONLY'),
      created_at: String(p.created_at ?? p.createdAt ?? ''),
      updated_at: String(p.updated_at ?? p.updatedAt ?? ''),
    };
  }

  private normalizePartnerPayload(payload: any) {
    const p = { ...(payload || {}) };
    const firm = p.companyOrFirmName || p.company_or_firm_name || p.firmName || '';
    const contact = p.contactPersonName || p.contact_person_name || p.name || '';
    const email = (p.email || '').toString().trim().toLowerCase();
    const username = (p.username || '').toString().trim();
    const password = (p.password || '').toString();
    const logo = (p.company_logo || p.companyLogo || '').toString().trim();
    const nature = asStringList(p.nature_of_business ?? p.natureOfBusiness);
    const areas = asStringList(p.areas_of_practice ?? p.areasOfPractice);
    const doi = (p.date_of_incorporation || p.dateOfIncorporation || '').toString().trim();
    const permission = (p.permissionLevel || p.permission_level || 'READ_ONLY').toString();

    const out: Record<string, any> = {
      ...p,
      email,
      username,
      companyOrFirmName: firm,
      company_or_firm_name: firm,
      contactPersonName: contact,
      contact_person_name: contact,
      name: contact || firm,
      role: (p.role || 'CP').toString().toUpperCase(),
      status: (p.status || 'ACTIVE').toString().toUpperCase(),
      permissionLevel: permission,
      permission_level: permission,
      declarationAccepted: p.declarationAccepted !== false && p.declaration_accepted !== false,
      declaration_accepted: p.declarationAccepted !== false && p.declaration_accepted !== false,
      professional_stream: p.professional_stream || p.professionalStream || '',
      professionalStream: p.professional_stream || p.professionalStream || '',
      constitution: p.constitution || '',
      icai_membership_no: p.icai_membership_no || p.icaiMembershipNo || '',
      icaiMembershipNo: p.icai_membership_no || p.icaiMembershipNo || '',
      cop_no: p.cop_no || p.copNo || '',
      copNo: p.cop_no || p.copNo || '',
      pan: (p.pan || '').toString().toUpperCase(),
      gstin: (p.gstin || '').toString().toUpperCase(),
      rera_no: p.rera_no || p.reraNo || '',
      reraNo: p.rera_no || p.reraNo || '',
      date_of_incorporation: doi,
      dateOfIncorporation: doi,
      address: p.address || '',
      city: p.city || '',
      pincode: p.pincode || '',
      website: p.website || '',
      phone: p.phone || '',
      nature_of_business: nature,
      natureOfBusiness: nature,
      areas_of_practice: areas,
      areasOfPractice: areas,
    };

    if (logo) {
      out.company_logo = logo;
      out.companyLogo = logo;
    }

    // Password is write-only; omit when blank so edits do not clear Hub credentials.
    if (password.trim()) {
      out.password = password.trim();
    } else {
      delete out.password;
    }

    return out;
  }

  /**
   * Create a new partner / onboarding record in NB Hub.
   */
  async createPartner(payload: Partial<HubPartner> | CreateHubPartnerDto): Promise<HubPartner> {
    const normalized = this.normalizePartnerPayload(payload);
    const res = await this.request<HubPartner>('/admin/onboarding', {
      method: 'POST',
      body: JSON.stringify(normalized),
    });
    if (!res.data && res.user) return this.normalizePartnerResponse(res.user);
    if (!res.data) throw new Error(res.message || 'Failed to create partner in NB Hub');
    return this.normalizePartnerResponse(res.data);
  }

  /**
   * Update an existing partner in NB Hub.
   */
  async updatePartner(id: string, payload: Partial<HubPartner> | UpdateHubPartnerDto): Promise<HubPartner> {
    const normalized = this.normalizePartnerPayload(payload);
    const res = await this.request<HubPartner>(`/admin/onboarding/${encodeURIComponent(id)}`, {
      method: 'PUT',
      body: JSON.stringify(normalized),
    });
    if (!res.data && res.user) return this.normalizePartnerResponse(res.user);
    if (!res.data) throw new Error(res.message || 'Failed to update partner in NB Hub');
    return this.normalizePartnerResponse(res.data);
  }

  /**
   * Move a partner record to trash in NB Hub.
   */
  async deletePartner(id: string): Promise<boolean> {
    const res = await this.request<{ success: boolean; message?: string }>(
      `/admin/onboarding/${encodeURIComponent(id)}`,
      {
        method: 'DELETE',
      },
    );
    return res.success === true;
  }

  /**
   * Fetch all trash / archived records from NB Hub.
   */
  async getTrashRecords(): Promise<HubTrashRecord[]> {
    const res = await this.request<HubTrashRecord[]>('/admin/trash', {
      method: 'GET',
    });
    return res.data || [];
  }
}

export const hubApiService = new HubApiService();
