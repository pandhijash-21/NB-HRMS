import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import api from '@/lib/axios';
import { toast } from 'sonner';

export type ChangeRequest = {
  id: string;
  employeeId: number;
  module: string;
  oldData: Record<string, any>;
  newData: Record<string, any>;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  requestedAt: string;
  reviewedAt?: string;
  reviewedBy?: string;
  employee?: {
    id: number;
    generalInfo?: { fullName: string; employeeCode: string; designation: string };
  };
};

/** Check if a pending change request exists for a given module */
export function usePendingRequest(module: string) {
  return useQuery<ChangeRequest | null>({
    queryKey: ['change-request', 'pending', module],
    queryFn: async () => {
      try {
        const { data } = await api.get(`/approvals/pending?module=${module}`);
        return data.data ?? null;
      } catch (err: any) {
        // 401/403 = not logged in or no employee linked — return null silently
        if (err?.response?.status === 401 || err?.response?.status === 403) return null;
        return null;
      }
    },
    enabled: !!module,
  });
}

/** Submit a change request (employee-side) */
export function useRequestChange() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ module, newData }: { module: string; newData: Record<string, any> }) => {
      const { data } = await api.post('/approvals', { module, newData });
      if (!data.success) throw new Error(data.error ?? 'Request failed');
      return data.data;
    },
    onSuccess: (_d, vars) => {
      queryClient.invalidateQueries({ queryKey: ['change-request', 'pending', vars.module] });
      toast.success('Change request submitted. HR will review it shortly.');
    },
    onError: (err: any) => {
      const msg = err?.response?.data?.error ?? err?.message ?? 'Failed to submit request';
      toast.error(`Could not submit request: ${msg}`);
    },
  });
}

/** Admin: list all change requests */
export function useAllChangeRequests(status?: 'PENDING' | 'APPROVED' | 'REJECTED') {
  return useQuery<ChangeRequest[]>({
    queryKey: ['change-requests', status],
    queryFn: async () => {
      const url = status ? `/approvals?status=${status}` : '/approvals';
      const { data } = await api.get(url);
      return data.data ?? [];
    },
  });
}

/** Admin: approve or reject */
export function useReviewRequest() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, action }: { id: string; action: 'approve' | 'reject' }) => {
      const { data } = await api.post(`/approvals/${id}/${action}`);
      return data.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['change-requests'] });
    },
  });
}
