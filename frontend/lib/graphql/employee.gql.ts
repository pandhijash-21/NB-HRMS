import { gql } from "@apollo/client/core";

export const GET_EMPLOYEE = gql`
  query GetEmployee($id: uuid!) {
    employee_by_pk(id: $id) {
      id
      employeeCode
      fullName
      email
      phone
      photoUrl
      signatureUrl
      status
      designation
      department
      functionalDepartment
      organization
      subOrganization
      employeeCategory
      appointmentType
      shift
      joiningDate
      originalJoiningDate
      incrementMonth
      firstReporting
      secondReporting
      createdAt
      updatedAt
    }
  }
`;

export const GET_EMPLOYEE_LIST = gql`
  query GetEmployeeList($limit: Int, $offset: Int, $search: String) {
    employee(
      limit: $limit
      offset: $offset
      where: {
        deletedAt: { _is_null: true }
        _or: [
          { fullName: { _ilike: $search } }
          { employeeCode: { _ilike: $search } }
          { email: { _ilike: $search } }
        ]
      }
      order_by: { fullName: asc }
    ) {
      id
      employeeCode
      fullName
      email
      phone
      photoUrl
      designation
      department
      status
      joiningDate
      employeeCategory
    }
    employee_aggregate(
      where: {
        deletedAt: { _is_null: true }
        _or: [
          { fullName: { _ilike: $search } }
          { employeeCode: { _ilike: $search } }
          { email: { _ilike: $search } }
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
  mutation UpdateEmployeeGeneral($id: uuid!, $set: employee_set_input!) {
    update_employee_by_pk(pk_columns: { id: $id }, _set: $set) {
      id
      fullName
      designation
      department
      joiningDate
      updatedAt
    }
  }
`;
