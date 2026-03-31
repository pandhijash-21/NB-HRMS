import { gql } from "@apollo/client/core";

export const GET_EMPLOYEE_ADDRESSES = gql`
  query GetEmployeeAddresses($employeeId: Int!) {
    employee_address(
      where: { employeeId: { _eq: $employeeId } }
      order_by: { type: asc }
    ) {
      id
      type
      addressLine1
      addressLine2
      city
      district
      state
      pincode
      country
      updatedAt
    }
  }
`;

export const UPSERT_EMPLOYEE_ADDRESS = gql`
  mutation UpsertEmployeeAddress(
    $objects: [employee_address_insert_input!]!
  ) {
    insert_employee_address(
      objects: $objects
      on_conflict: {
        constraint: employee_address_employee_id_type_key
        update_columns: [
          addressLine1
          addressLine2
          city
          district
          state
          pincode
          country
        ]
      }
    ) {
      returning {
        id
        type
      }
    }
  }
`;
