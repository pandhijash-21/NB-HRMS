import { gql } from "@apollo/client/core";

export const GET_AUDIT_LOGS = gql`
  query GetAuditLogs($employeeId: uuid!, $limit: Int, $offset: Int) {
    audit_log(
      where: { employeeId: { _eq: $employeeId } }
      order_by: { createdAt: desc }
      limit: $limit
      offset: $offset
    ) {
      id
      tableName
      operation
      fieldName
      oldValueMasked
      newValueMasked
      changedById
      changedByName
      createdAt
    }
    audit_log_aggregate(where: { employeeId: { _eq: $employeeId } }) {
      aggregate {
        count
      }
    }
  }
`;
