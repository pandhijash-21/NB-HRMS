"use client";

import { useQuery, useMutation as useQueryMutation } from "@tanstack/react-query";
import api from "@/lib/axios";
import { toast } from "sonner";

export type Address = {
  addressType?: "LOCAL" | "PERMANENT";
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
};

async function fetchAddress(
  employeeId: number,
  type: "LOCAL" | "PERMANENT"
): Promise<Address | null> {
  try {
    const { data } = await api.get(`employees/${employeeId}/address/${type}`);
    return data.data ?? null;
  } catch (err: any) {
    // 404 = no address record yet — totally normal
    if (err?.response?.status === 404) return null;
    return null; // fail silently on other errors
  }
}

async function saveAddress(
  employeeId: number,
  type: "LOCAL" | "PERMANENT",
  payload: Record<string, unknown>,
  exists: boolean
) {
  if (exists) {
    // Record exists → PATCH
    const { data } = await api.patch(
      `employees/${employeeId}/address/${type}`,
      payload
    );
    return data;
  } else {
    // Record doesn't exist → POST (creates)
    const { data } = await api.post(`employees/${employeeId}/address`, {
      ...payload,
      addressType: type,
    });
    return data;
  }
}

export function useAddress(employeeId: string) {
  const numericId = parseInt(employeeId, 10);
  const valid = Number.isFinite(numericId) && numericId > 0;

  const {
    data: localAddress,
    isLoading: localLoading,
    refetch: refetchLocal,
  } = useQuery<Address | null>({
    queryKey: ["address", numericId, "LOCAL"],
    queryFn: () => fetchAddress(numericId, "LOCAL"),
    enabled: valid,
  });

  const {
    data: permanentAddress,
    isLoading: permanentLoading,
    refetch: refetchPermanent,
  } = useQuery<Address | null>({
    queryKey: ["address", numericId, "PERMANENT"],
    queryFn: () => fetchAddress(numericId, "PERMANENT"),
    enabled: valid,
  });

  const { mutateAsync: doSave, isPending: saving } = useQueryMutation({
    mutationFn: async ({
      local,
      permanent,
    }: {
      local: Record<string, unknown>;
      permanent: Record<string, unknown>;
    }) => {
      await Promise.all([
        saveAddress(numericId, "LOCAL", local, !!localAddress),
        saveAddress(numericId, "PERMANENT", permanent, !!permanentAddress),
      ]);
    },
    onSuccess: () => {
      toast.success("Address saved successfully.");
      refetchLocal();
      refetchPermanent();
    },
    onError: (err: any) => {
      const msg =
        err?.response?.data?.error ?? err?.message ?? "Failed to save address";
      toast.error(`Address save failed: ${msg}`);
    },
  });

  const saveAddresses = (
    local: Record<string, unknown>,
    permanent: Record<string, unknown>
  ) => {
    if (!valid) {
      toast.error("Invalid employee ID — cannot save address.");
      return Promise.resolve();
    }
    return doSave({ local, permanent });
  };

  return {
    localAddress: localAddress ?? null,
    permanentAddress: permanentAddress ?? null,
    loading: localLoading || permanentLoading,
    saving,
    saveAddresses,
  };
}
