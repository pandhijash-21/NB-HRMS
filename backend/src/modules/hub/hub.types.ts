export interface HubPartner {
  id: string;
  role: 'CP' | 'AP' | string;
  email: string;
  username: string;
  phone?: string;
  company_or_firm_name?: string;
  contact_person_name?: string;
  company_logo?: string;
  professional_stream?: string;
  constitution?: string;
  icai_membership_no?: string;
  cop_no?: string;
  pan?: string;
  gstin?: string;
  rera_no?: string;
  date_of_incorporation?: string;
  address?: string;
  city?: string;
  pincode?: string;
  website?: string;
  nature_of_business?: string[];
  areas_of_practice?: string[];
  declaration_accepted?: boolean;
  status: 'ACTIVE' | 'INACTIVE' | string;
  permission_level: string;
  created_at: string;
  updated_at: string;
}

export interface HubTrashRecord {
  id: string;
  original_id?: string;
  record_type?: string;
  data?: any;
  deleted_at?: string;
  deleted_by?: string;
  [key: string]: any;
}

export interface HubApiResponse<T> {
  success: boolean;
  count?: number;
  data?: T;
  user?: T;
  error?: string;
  message?: string;
  source?: string;
}

export interface CreateHubPartnerDto {
  role: 'CP' | 'AP' | string;
  email: string;
  username: string;
  phone?: string;
  company_or_firm_name?: string;
  contact_person_name?: string;
  company_logo?: string;
  professional_stream?: string;
  constitution?: string;
  icai_membership_no?: string;
  cop_no?: string;
  pan?: string;
  gstin?: string;
  rera_no?: string;
  date_of_incorporation?: string;
  address?: string;
  city?: string;
  pincode?: string;
  website?: string;
  nature_of_business?: string[];
  areas_of_practice?: string[];
  declaration_accepted?: boolean;
  status?: 'ACTIVE' | 'INACTIVE' | string;
  permission_level?: string;
  [key: string]: any;
}

export interface UpdateHubPartnerDto extends Partial<CreateHubPartnerDto> {}
