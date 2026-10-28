import { env } from '../../config/env';
import {
  HubPartner,
  HubTrashRecord,
  HubApiResponse,
  CreateHubPartnerDto,
  UpdateHubPartnerDto,
} from './hub.types';

export class HubApiService {
  private readonly baseUrl: string;
  private readonly timeoutMs: number;

  constructor(baseUrl?: string, timeoutMs = 10000) {
    const raw = baseUrl || env.NB_HUB_API_URL || process.env.NB_HUB_API_URL || 'https://crm.nbdeveloper.co.in/hub-api/api';
    this.baseUrl = raw.trim().replace(/\/+$/, '');
    this.timeoutMs = timeoutMs;
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
          'Accept': 'application/json',
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
   * Fetch all active NB Hub onboarding partners.
   */
  async getAllPartners(): Promise<HubPartner[]> {
    const res = await this.request<HubPartner[]>('/admin/onboarding', {
      method: 'GET',
    });
    return res.data || [];
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
      }
    );
    return res.user || res.data || null;
  }

  /**
   * Create a new partner / onboarding record in NB Hub.
   */
  async createPartner(payload: Partial<HubPartner> | CreateHubPartnerDto): Promise<HubPartner> {
    const res = await this.request<HubPartner>('/admin/onboarding', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    if (!res.data && res.user) return res.user;
    if (!res.data) throw new Error(res.message || 'Failed to create partner in NB Hub');
    return res.data;
  }

  /**
   * Update an existing partner in NB Hub.
   */
  async updatePartner(id: string, payload: Partial<HubPartner> | UpdateHubPartnerDto): Promise<HubPartner> {
    const res = await this.request<HubPartner>(`/admin/onboarding/${encodeURIComponent(id)}`, {
      method: 'PUT',
      body: JSON.stringify(payload),
    });
    if (!res.data && res.user) return res.user;
    if (!res.data) throw new Error(res.message || 'Failed to update partner in NB Hub');
    return res.data;
  }

  /**
   * Move a partner record to trash in NB Hub.
   */
  async deletePartner(id: string): Promise<boolean> {
    const res = await this.request<{ success: boolean; message?: string }>(
      `/admin/onboarding/${encodeURIComponent(id)}`,
      {
        method: 'DELETE',
      }
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
