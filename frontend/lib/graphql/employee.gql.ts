import { gql } from "@apollo/client/core";

export const GET_EMPLOYEE = gql`
  query GetEmployee($id: Int!) {
    employees(where: {id: {_eq: $id}}) {
      id
      status
      photoUrl: photo_url
      signatureUrl: signature_url
      updatedAt: updated_at
      employee_general_infos {
        fullName: full_name
        employeeCategory: employee_category
        designation
        department
        functionalDepartment: functional_department
        organization
        subOrganization: sub_organization
        appointmentType: appointment_type
        shift
        joiningDate: joining_date
        originalJoiningDate: original_joining_date
        incrementMonth: increment_month
        firstApproverUserId: first_approver_user_id
        secondApproverUserId: second_approver_user_id
        thirdApproverUserId: third_approver_user_id
      }
      employee_personal_infos {
        birthDate: birth_date
        birthPlace: birth_place
        homeTown: home_town
        nationality
        motherTongue: mother_tongue
        nomineeName: nominee_name
        nomineeRelation: nominee_relation
        bloodGroup: blood_group
        gender
        maritalStatus: marital_status
        panNo: pan_no
        aadhaarNo: aadhaar_no
        passportNo: passport_no
        passportIssuePlace: passport_issue_place
        passportIssueDate: passport_issue_date
        passportExpiryDate: passport_expiry_date
        castCategory: cast_category
        subCaste: sub_caste
        customFields: custom_fields
      }
      employee_salary_infos {
        payCommission: pay_commission
        payGrade: pay_grade
        basicSalary: basic_salary
        agp
        grossSalary: gross_salary
      }
      employee_bank_infos {
        bankName: bank_name
        bankAccountNo: bank_account_no
        bankBranchCode: bank_branch_code
        ifscCode: ifsc_code
      }
      employee_other_infos {
        skillSet: skill_set
        strength
        weakness
        hobbies
        isHandicapped: is_handicapped
        heightInFeet: height_in_feet
        weightInKg: weight_in_kg
      }
      employee_addresses(where: {address_type: {_eq: "LOCAL"}}) {
        flatBlockNo: flat_block_no
        buildingSociety: building_society
        area
        city
        zipPostalCode: zip_postal_code
        state
        country
        personalEmail: personal_email
        instituteEmail: institute_email
        mobileNo: mobile_no
      }
    }
  }
`;

export const GET_EMPLOYEE_LIST = gql`
  query GetEmployeeList($limit: Int, $offset: Int, $where: employees_bool_exp) {
    employees(
      limit: $limit
      offset: $offset
      where: $where
      order_by: { id: asc }
    ) {
      id
      status
      photo_url
      employee_general_infos {
        full_name
        designation
        department
        joining_date
        employee_category
      }
      employee_addresses(where: { address_type: { _eq: "LOCAL" } }) {
        personal_email
        institute_email
        mobile_no
      }
    }
    employees_aggregate(where: $where) {
      aggregate {
        count
      }
    }
    active_aggregate: employees_aggregate(
      where: {
        _and: [
          { status: { _eq: "ACTIVE" } },
          $where
        ]
      }
    ) {
      aggregate {
        count
      }
    }
  }
`;

export const UPDATE_EMPLOYEE_GENERAL = gql`
  mutation UpdateEmployeeGeneral($employeeId: Int!, $set: employee_general_info_set_input!) {
    update_employee_general_info(where: { employee_id: { _eq: $employeeId } }, _set: $set) {
      returning {
        id
        full_name
      }
    }
  }
`;

export const UPDATE_EMPLOYEE_MEDIA = gql`
  mutation UpdateEmployeeMedia($id: Int!, $set: employees_set_input!) {
    update_employees(where: { id: { _eq: $id } }, _set: $set) {
      returning {
        id
        photo_url
        signature_url
      }
    }
  }
`;

export const UPDATE_EMPLOYEE_OTHER = gql`
  mutation UpdateEmployeeOther($employeeId: Int!, $set: employee_other_info_set_input!) {
    update_employee_other_info(where: { employee_id: { _eq: $employeeId } }, _set: $set) {
      returning {
        id
      }
    }
  }
`;

export const UPDATE_EMPLOYEE_PERSONAL = gql`
  mutation UpdateEmployeePersonal($employeeId: Int!, $set: employee_personal_info_set_input!) {
    update_employee_personal_info(where: { employee_id: { _eq: $employeeId } }, _set: $set) {
      returning {
        id
      }
    }
  }
`;

export const UPDATE_EMPLOYEE_SALARY = gql`
  mutation UpdateEmployeeSalary($employeeId: Int!, $set: employee_salary_info_set_input!) {
    update_employee_salary_info(where: { employee_id: { _eq: $employeeId } }, _set: $set) {
      returning {
        id
      }
    }
  }
`;

export const UPDATE_EMPLOYEE_BANK = gql`
  mutation UpdateEmployeeBank($employeeId: Int!, $set: employee_bank_info_set_input!) {
    update_employee_bank_info(where: { employee_id: { _eq: $employeeId } }, _set: $set) {
      returning {
        id
      }
    }
  }
`;
