import { gql } from "@apollo/client/core";

export const GET_FAMILY_MEMBERS = gql`
  query GetFamilyMembers($employeeId: Int!) {
    employee_family(
      where: {
        employeeId: { _eq: $employeeId }
        deletedAt: { _is_null: true }
      }
      order_by: { relation: asc }
    ) {
      id
      name
      relation
      dateOfBirth
      dependent
      employed
      employerName
      aadhaarNoMasked
      updatedAt
    }
  }
`;

export const DELETE_FAMILY_MEMBER = gql`
  mutation DeleteFamilyMember($id: uuid!, $now: timestamptz!) {
    update_employee_family_by_pk(
      pk_columns: { id: $id }
      _set: { deletedAt: $now }
    ) {
      id
    }
  }
`;
