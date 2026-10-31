import { Request, Response } from 'express';
import { hubApiService } from './hub.service';
import { ok, fail } from '../../utils/response';

export const hubController = {
  /**
   * GET /api/crm/partners/health — connectivity probe to NB Hub REST API.
   */
  async health(req: Request, res: Response) {
    try {
      const result = await hubApiService.healthCheck();
      if (!result.ok) {
        return res.status(502).json(fail(result.message || 'NB Hub API unreachable'));
      }
      res.json(ok(result));
    } catch (err: any) {
      console.error('[HubController.health]', err);
      res.status(502).json(fail(err.message || 'NB Hub API unreachable'));
    }
  },

  /**
   * GET /api/crm/partners or /crm/api/hub/partners
   * List all partners from NB Hub with optional search, role, or status filter.
   */
  async getPartners(req: Request, res: Response) {
    try {
      let partners = await hubApiService.getAllPartners();

      const roleFilter = typeof req.query.role === 'string' ? req.query.role.trim().toUpperCase() : null;
      const statusFilter = typeof req.query.status === 'string' ? req.query.status.trim().toUpperCase() : null;
      const searchQuery = typeof req.query.search === 'string' ? req.query.search.trim().toLowerCase() : null;

      if (roleFilter && roleFilter !== 'ALL') {
        partners = partners.filter((p) => (p.role || '').toUpperCase() === roleFilter);
      }

      if (statusFilter && statusFilter !== 'ALL') {
        partners = partners.filter((p) => (p.status || '').toUpperCase() === statusFilter);
      }

      if (searchQuery) {
        partners = partners.filter((p) => {
          const name = (p.company_or_firm_name || '').toLowerCase();
          const contact = (p.contact_person_name || '').toLowerCase();
          const email = (p.email || '').toLowerCase();
          const phone = (p.phone || '').toLowerCase();
          const city = (p.city || '').toLowerCase();
          const username = (p.username || '').toLowerCase();
          const pan = (p.pan || '').toLowerCase();
          const rera = (p.rera_no || '').toLowerCase();
          const gst = (p.gstin || '').toLowerCase();
          return (
            name.includes(searchQuery) ||
            contact.includes(searchQuery) ||
            email.includes(searchQuery) ||
            phone.includes(searchQuery) ||
            city.includes(searchQuery) ||
            username.includes(searchQuery) ||
            pan.includes(searchQuery) ||
            rera.includes(searchQuery) ||
            gst.includes(searchQuery)
          );
        });
      }

      res.json(ok(partners));
    } catch (err: any) {
      console.error('[HubController.getPartners]', err);
      res.status(500).json(fail(err.message || 'Failed to fetch partners from NB Hub'));
    }
  },

  /**
   * GET /api/crm/partners/:identifier
   * Get specific partner profile by email or username.
   */
  async getPartnerByIdentifier(req: Request, res: Response) {
    try {
      const rawId = req.params.identifier || req.query.identifier || '';
      const identifier = (Array.isArray(rawId) ? rawId[0] : rawId).toString().trim();
      if (!identifier) {
        return res.status(400).json(fail('Missing identifier (email or username)'));
      }

      const partner = await hubApiService.getPartnerByEmailOrUsername(identifier);
      if (!partner) {
        return res.status(404).json(fail('Partner profile not found'));
      }

      res.json(ok(partner));
    } catch (err: any) {
      console.error('[HubController.getPartnerByIdentifier]', err);
      res.status(500).json(fail(err.message || 'Failed to fetch partner profile from NB Hub'));
    }
  },

  /**
   * POST /api/crm/partners
   * Onboard / create a new partner in NB Hub.
   */
  async createPartner(req: Request, res: Response) {
    try {
      const { email, username, password } = req.body || {};
      if (!email || !username) {
        return res.status(400).json(fail('Email and username are required'));
      }
      if (!password || String(password).trim().length < 4) {
        return res.status(400).json(fail('Password is required (min 4 characters) when creating a partner'));
      }

      const created = await hubApiService.createPartner(req.body);
      res.status(201).json(ok(created));
    } catch (err: any) {
      console.error('[HubController.createPartner]', err);
      res.status(500).json(fail(err.message || 'Failed to create partner in NB Hub'));
    }
  },

  /**
   * PUT /api/crm/partners/:id
   * Update partner details in NB Hub.
   */
  async updatePartner(req: Request, res: Response) {
    try {
      const rawId = req.params.id;
      const id = (Array.isArray(rawId) ? rawId[0] : rawId || '').toString().trim();
      if (!id) {
        return res.status(400).json(fail('Partner ID is required'));
      }

      const updated = await hubApiService.updatePartner(id, req.body);
      res.json(ok(updated));
    } catch (err: any) {
      console.error('[HubController.updatePartner]', err);
      res.status(500).json(fail(err.message || 'Failed to update partner in NB Hub'));
    }
  },

  /**
   * DELETE /api/crm/partners/:id
   * Move partner record to trash in NB Hub.
   */
  async deletePartner(req: Request, res: Response) {
    try {
      const rawId = req.params.id;
      const id = (Array.isArray(rawId) ? rawId[0] : rawId || '').toString().trim();
      if (!id) {
        return res.status(400).json(fail('Partner ID is required'));
      }

      const success = await hubApiService.deletePartner(id);
      res.json(ok({ success, message: 'Partner record moved to trash' }));
    } catch (err: any) {
      console.error('[HubController.deletePartner]', err);
      res.status(500).json(fail(err.message || 'Failed to move partner to trash in NB Hub'));
    }
  },

  /**
   * GET /api/crm/partners/trash/records
   * Get all archived / trash records.
   */
  async getTrash(req: Request, res: Response) {
    try {
      const trash = await hubApiService.getTrashRecords();
      res.json(ok(trash));
    } catch (err: any) {
      console.error('[HubController.getTrash]', err);
      res.status(500).json(fail(err.message || 'Failed to fetch trash records from NB Hub'));
    }
  },
};
