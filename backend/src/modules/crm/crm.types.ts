export interface CreateProjectDto {
  name: string;
  code?: string;
  description?: string;
  location?: string;
  startDate?: string;
}

export interface UpdateProjectDto {
  name?: string;
  description?: string;
  location?: string;
  startDate?: string;
  isActive?: boolean;
}

export interface CreateCampaignDto {
  projectId?: string | null;
  name: string;
  code?: string;
  adId?: string;
  description?: string;
  startDate?: string;
  module?: string;
  copyFromCampaignId?: string;
}

export interface UpdateCampaignDto {
  projectId?: string | null;
  name?: string;
  adId?: string;
  description?: string;
  startDate?: string;
  isActive?: boolean;
}

export interface MergeColumnsDto {
  campaignId?: string | null;
  module?: string;
  sourceKey: string;
  targetKey: string;
  targetLabel?: string;
}

export interface CreateColumnDto {
  module?: string;
  campaignId?: string | null;
  columnKey: string;
  label: string;
  dataType?: 'TEXT' | 'NUMBER' | 'DATE' | 'SELECT' | 'PHONE' | 'EMAIL';
  options?: string[];
  isRequired?: boolean;
  isSystem?: boolean;
  isVisibleInTable?: boolean;
  displayOrder?: number;
  isActive?: boolean;
}

export interface UpdateColumnDto {
  label?: string;
  dataType?: 'TEXT' | 'NUMBER' | 'DATE' | 'SELECT' | 'PHONE' | 'EMAIL';
  options?: string[];
  isRequired?: boolean;
  isVisibleInTable?: boolean;
  displayOrder?: number;
  isActive?: boolean;
}

export interface CreateLeadDto {
  campaignId?: string | null;
  phone: string;
  name?: string;
  status?: 'NOT_STARTED' | 'FOLLOW_UP' | 'INTERESTED' | 'NOT_INTERESTED';
  customFields?: Record<string, any>;
  assignedToId?: number | null;
  telecallerId?: number | null;
}

export interface UpdateLeadDto {
  phone?: string;
  name?: string;
  status?: 'NOT_STARTED' | 'FOLLOW_UP' | 'INTERESTED' | 'NOT_INTERESTED';
  customFields?: Record<string, any>;
  assignedToId?: number | null;
  telecallerId?: number | null;
}

export interface ScheduleFollowUpDto {
  leadId: string;
  scheduledDate: string; // YYYY-MM-DD or ISO
  scheduledTime: string; // HH:mm
  remarks?: string;
  assignedToId?: number | null;
}

export interface UpdateCrmSettingsDto {
  elision_api_url?: string;
  elision_user_id?: string;
  elision_did?: string;
  elision_route_number?: string;
  elision_default_agent_number?: string;
  elision_api_key?: string;
  elision_campaign_id?: string;
  elision_agent_id?: string;
  not_interested_retention_days?: string;
  bin_retention_days?: string;
  [key: string]: any;
}

export interface TelephonyWebhookDto {
  customer_number?: string;
  agent_number?: string;
  agen_number?: string;
  call_status?: string;
  status?: string;
  duration?: number | string;
  recording_url?: string;
  call_time?: string;
  did?: string;
  call_id?: string;
  [key: string]: any;
}
