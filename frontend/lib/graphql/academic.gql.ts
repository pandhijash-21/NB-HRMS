import { gql } from "@apollo/client/core";

export const GET_ACADEMIC_QUALIFICATIONS = gql`
  query GetAcademicQualifications($employeeId: Int!) {
    employee_academic_qualification(
      where: { employeeId: { _eq: $employeeId } }
      order_by: { passingYear: desc }
    ) {
      id
      level
      degreeName
      stream
      institution
      board
      passingYear
      percentage
      cgpa
      semMarksheetUrls
      certificateUrl
      updatedAt
    }
  }
`;

export const UPSERT_ACADEMIC_QUALIFICATION = gql`
  mutation UpsertAcademicQualification(
    $objects: [employee_academic_qualification_insert_input!]!
  ) {
    insert_employee_academic_qualification(
      objects: $objects
      on_conflict: {
        constraint: employee_academic_qualification_pkey
        update_columns: [
          degreeName
          stream
          institution
          board
          passingYear
          percentage
          cgpa
          semMarksheetUrls
          certificateUrl
        ]
      }
    ) {
      returning {
        id
        level
        degreeName
      }
    }
  }
`;

export const DELETE_ACADEMIC_QUALIFICATION = gql`
  mutation DeleteAcademicQualification($id: uuid!) {
    delete_employee_academic_qualification_by_pk(id: $id) {
      id
    }
  }
`;
