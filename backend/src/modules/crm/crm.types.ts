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
  assignedTelecallerIds?: number[];
  assignmentMode?: 'ROUND_ROBIN' | 'SPECIFIC';
}

export interface UpdateCampaignDto {
  projectId?: string | null;
  name?: string;
  adId?: string;
  description?: string;
  startDate?: string;
  isActive?: boolean;
  assignedTelecallerIds?: number[];
  assignmentMode?: 'ROUND_ROBIN' | 'SPECIFIC';
}

export interface TransferLeadDto {
  targetTelecallerId: number;
  remarks?: string;
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
  status?: 'NOT_STARTED' | 'ASSIGNED' | 'CNR' | 'SCHEDULED_VISIT' | 'NOT_INTERESTED' | 'SITE_VISIT_DONE' | 'FOLLOW_UP' | 'INTERESTED';
  customFields?: Record<string, any>;
  assignedToId?: number | null;
  telecallerId?: number | null;
  leadSource?: string;
  channelPartnerName?: string;
  channelPartnerPhone?: string;
  referenceType?: string;
  referenceName?: string;
}

export interface UpdateLeadDto {
  phone?: string;
  name?: string;
  status?: string;
  customFields?: Record<string, any>;
  assignedToId?: number | null;
  telecallerId?: number | null;
  leadSource?: string;
  channelPartnerName?: string;
  channelPartnerPhone?: string;
  referenceType?: string;
  referenceName?: string;
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
  excel_assigned_telecaller_ids?: string | number[];
  webhook_assigned_telecaller_ids?: string | number[];
  max_telecaller_active_workload?: number | string;
  telecaller_max_workload_map?: string | Record<string, number>;
  untouched_lead_timeout_minutes?: number | string;
  idle_timeout_minutes?: number | string;
  quotation_general_remarks?: string;
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

export interface FinserveApplicationField {
  key: string;
  label: string;
  section: 'PERSONAL' | 'COMPANY' | 'REFERENCE' | 'CUSTOM';
  type: 'text' | 'number' | 'phone' | 'email' | 'select' | 'textarea';
  options?: string[];
  required: boolean;
  enabled: boolean;
}

export interface FinserveDocumentItem {
  id: string;
  docTypeId: string;
  docName: string;
  fileUrl: string;
  fileName: string;
  fileSize?: number;
  uploadedAt: string;
  uploadedBy?: string;
  status?: 'PENDING' | 'VERIFIED' | 'REJECTED';
}

export interface UpdateLeadApplicationDetailsDto {
  loanType?: string;
  applicationDetails?: Record<string, any>;
  status?: string;
}

export interface BankApplicationItem {
  id: string;
  bankName: string;
  appliedAt?: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  rejectionRemarks?: string;
  roi?: string; // Rate of interest %
  approvedAmount?: string;
  tenureMonths?: string;
  isFinalSelected?: boolean;
}

export interface FinalBankDetails {
  bankId?: string;
  bankName: string;
  roi?: string;
  applicationId?: string;
  loanAgreementNumber?: string;
  finalizedAt?: string;
  finalizedBy?: string;
}

export interface BankQueryItem {
  id: string;
  stage?: string;
  query: string; // What query
  required: string; // What is required
  status: 'OPEN' | 'RESOLVED';
  raisedAt: string;
  raisedBy?: string;
  resolvedAt?: string;
  resolvedBy?: string;
  resolutionNotes?: string;
}

export interface TentativeDateEntry {
  date: string; // YYYY-MM-DD
  setAt: string;
  setBy?: string;
  status: 'PENDING' | 'DISBURSED' | 'DELAYED';
  delayReason?: string;
}

export interface DisbursementDetails {
  tentativeDates: TentativeDateEntry[];
  currentTentativeDate?: string;
  isDisbursed?: boolean;
  disbursedAt?: string;
  disbursedAmount?: string;
  remarks?: string;
  flowClosed?: boolean;
}

export interface UpdateFinservePipelineDto {
  forwardedForProcessing?: {
    forwardedToId: number;
    forwardedToName: string;
    forwardedAt: string;
    forwardedBy?: string;
    remarks?: string;
  };
  bankApplications?: BankApplicationItem[];
  finalBank?: FinalBankDetails;
  disbursementDetails?: DisbursementDetails;
  loanStage?: string;
  status?: string;
}
