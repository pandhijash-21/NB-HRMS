"use client";

import { useQuery, useMutation } from "@apollo/client/react";
import { GET_EMPLOYEE_ADDRESSES, UPSERT_EMPLOYEE_ADDRESS } from "@/lib/graphql";

export function useAddress(employeeId: string) {
  const { data, loading, error, refetch } = useQuery(GET_EMPLOYEE_ADDRESSES, {
    variables: { employeeId },
    skip: !employeeId,
  });

  const [upsert, { loading: saving }] = useMutation(UPSERT_EMPLOYEE_ADDRESS);

  const localAddress = data?.employee_address?.find(
    (a: { type: string }) => a.type === "LOCAL"
  ) ?? null;
  const permanentAddress = data?.employee_address?.find(
    (a: { type: string }) => a.type === "PERMANENT"
  ) ?? null;

  const saveAddresses = async (
    local: Record<string, unknown>,
    permanent: Record<string, unknown>
  ) => {
    await upsert({
      variables: {
        objects: [
          { ...local, employeeId, type: "LOCAL" },
          { ...permanent, employeeId, type: "PERMANENT" },
        ],
      },
    });
    refetch();
  };

  return {
    localAddress,
    permanentAddress,
    loading,
    saving,
    error,
    refetch,
    saveAddresses,
  };
}
