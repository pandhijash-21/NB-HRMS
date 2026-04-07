import { gql } from "@apollo/client/core";

export const GET_EXPERIENCES = gql`
  query GetExperiences($employeeId: Int!) {
    employee_experience(
      where: { employee_id: { _eq: $employeeId } }
      order_by: { from_date: desc }
    ) {
      id
      type
      designation
      organizationName: organization_name
      fromDate: from_date
      toDate: to_date
      jobDescription: job_description
      lastSalary: last_salary
      experienceLetterUrl: experience_letter_url
      lastPaycheckUrl: last_paycheck_url
      recommendationLetters: recommendation_letters
      createdAt: created_at
      updatedAt: updated_at
    }
  }
`;

export const UPSERT_EXPERIENCE = gql`
  mutation UpsertExperience(
    $objects: [employee_experience_insert_input!]!
  ) {
    insert_employee_experience(
      objects: $objects
      on_conflict: {
        constraint: employee_experience_pkey
        update_columns: [
          type
          designation
          organization_name
          from_date
          to_date
          job_description
          last_salary
          experience_letter_url
          last_paycheck_url
          recommendation_letters
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
