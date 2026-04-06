import { gql } from "@apollo/client/core";

export const GET_EXPERIENCES = gql`
  query GetExperiences($employeeId: Int!) {
    employee_experience(
      where: { employeeId: { _eq: $employeeId } }
      order_by: { fromDate: desc }
    ) {
      id
      type
      designation
      organizationName
      fromDate
      toDate
      jobDescription
      lastSalary
      experienceLetterUrl
      lastPaycheckUrl
      recommendationLetters
      createdAt
      updatedAt
    }
  }
`;

export const UPSERT_EXPERIENCE = gql`
  mutation UpsertExperience(
    $employeeId: Int!
    $objects: [employee_experience_insert_input!]!
  ) {
    insert_employee_experience(
      objects: $objects
      on_conflict: {
        constraint: employee_experience_pkey
        update_columns: [
          type
          designation
          organizationName
          fromDate
          toDate
          jobDescription
          lastSalary
          experienceLetterUrl
          lastPaycheckUrl
          recommendationLetters
        ]
      }
    ) {
      returning {
        id
        type
        designation
      }
    }
  }
`;

export const DELETE_EXPERIENCE = gql`
  mutation DeleteExperience($id: uuid!) {
    delete_employee_experience_by_pk(id: $id) {
      id
    }
  }
`;
