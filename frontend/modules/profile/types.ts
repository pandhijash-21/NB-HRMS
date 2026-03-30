export type EmployeeStatus = 'ACTIVE' | 'INACTIVE' | 'ON_LEAVE' | 'RESIGNED' | 'RETIRED' | 'TERMINATED';
export type EmployeeCategory = 'TEACHING' | 'NON_TEACHING' | 'CONTRACT' | 'VISITING';
export type AppointmentType = 'FULL_TIME_REGULAR' | 'FULL_TIME_CONTRACT' | 'PART_TIME' | 'VISITING' | 'DEPUTATION';

export interface GeneralInfo {
  id: number;
  fullName: string;
  originalJoiningDate: string;
  joiningDate: string;
  incrementMonth?: string | null;
  organization: string;
  subOrganization?: string | null;
  department: string;
  functionalDepartment?: string | null;
  firstReporting?: string | null;
  secondReporting?: string | null;
  employeeCategory: EmployeeCategory;
  designation: string;
  shift?: string | null;
  appointmentType?: AppointmentType | null;
}

export interface PersonalInfo {
  id: number;
  birthDate: string;
  birthPlace?: string | null;
  homeTown?: string | null;
  gender: 'MALE' | 'FEMALE' | 'OTHER';
  maritalStatus: 'SINGLE' | 'MARRIED' | 'DIVORCED' | 'WIDOWED';
  nationality?: string | null;
  bloodGroup?: "A_POS" | "A_NEG" | "B_POS" | "B_NEG" | "O_POS" | "O_NEG" | "AB_POS" | "AB_NEG" | null;
  religion?: string | null;
  caste?: string | null;
  subCaste?: string | null;
  aadhaarNo?: string | null;
  panNo?: string | null;
  passportNo?: string | null;
  height?: number | null;
  weight?: number | null;
  identificationMark?: string | null;
}

export interface OtherInfo {
  id: number;
  skills?: string | null;
  hobbies?: string | null;
  languages?: string | null;
  extraCurricular?: string | null;
  height?: number | null;
  weight?: number | null;
  identificationMark?: string | null;
}

export interface Address {
  id: number;
  addressType: 'LOCAL' | 'PERMANENT';
  flatBlockNo?: string | null;
  buildingSociety?: string | null;
  area?: string | null;
  city?: string | null;
  state?: string | null;
  country?: string | null;
  zipPostalCode?: string | null;
  phoneNo?: string | null;
  mobileNo?: string | null;
  personalEmail?: string | null;
  instituteEmail?: string | null;
}

export interface FamilyMember {
  id: number;
  name: string;
  relationship: string;
  birthDate?: string | null;
  occupation?: string | null;
  isDependent: boolean;
  contactNo?: string | null;
}

export interface AcademicQualification {
  id: number;
  degreeName: string;
  universityBoard: string;
  institutionName: string;
  passingYear: number;
  percentageCgpa: number;
  specialization?: string | null;
  marksheetUrl?: string | null;
  certificateUrl?: string | null;
}
