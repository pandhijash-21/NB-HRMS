import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/axios";
import { toast } from "sonner";

export interface AdminEmployeeListParams {
  page?: number;
  limit?: number;
  search?: string;
  status?: string;
}

export function useAdminEmployeeList(params: AdminEmployeeListParams) {
  const { page = 0, limit = 20, search, status } = params;
  const offset = page * limit;

  return useQuery({
    queryKey: ["admin", "employees", { limit, offset, search, status }],
    queryFn: async () => {
      const { data } = await api.get(`employees`, {
        params: { limit, offset, search, status }
      });
      return data.data as { items: any[]; total: number };
    },
  });
}

export function useCreateEmployee() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: any) => {
      const { data } = await api.post(`employees/full`, payload);
      return data.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "employees"] });
      toast.success("Employee record created successfully");
    },
    onError: (error: any) => {
      const message = error.response?.data?.message || "Failed to create employee";
      toast.error(message);
    }
  });
}

export function useDeleteEmployee() {
    const queryClient = useQueryClient();
  
    return useMutation({
      mutationFn: async (id: number) => {
        const { data } = await api.delete(`employees/${id}`);
        return data.data;
      },
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: ["admin", "employees"] });
        toast.success("Employee deactivated successfully");
      },
      onError: (error: any) => {
        const message = error.response?.data?.message || "Failed to delete employee";
        toast.error(message);
      }
    });
  }
