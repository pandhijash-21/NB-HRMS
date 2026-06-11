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

export interface EmployeeNameItem {
  type: "EMPLOYEE" | "POSITION";
  id: number | string;
  userId: string;
  fullName: string;
  employeeCode: string | null;
}

export function useEmployeeNames() {
  return useQuery({
    queryKey: ["employees", "names"],
    queryFn: async () => {
      const { data } = await api.get(`employees/names`);
      return data.data as EmployeeNameItem[];
    },
    staleTime: 60_000,
  });
}

export function useAdminEmployee(id: string | number) {
  return useQuery({
    queryKey: ["admin", "employees", id],
    queryFn: async () => {
      const { data } = await api.get(`employees/${id}`);
      return data.data;
    },
    enabled: !!id,
  });
}

export type EmployeeAssignment = {
  id: string;
  employeeId: number;
  effectiveFrom: string; // YYYY-MM-DD
  effectiveTo: string | null; // YYYY-MM-DD
  organization: string | null;
  subOrganization: string | null;
  department: string | null;
  designation: string;
  shift: string | null;
  appointmentType: string | null;
  reason: string | null;
  changedBy: string;
  createdAt: string;
};

export function useAdminEmployeeAssignments(employeeId: string | number) {
  return useQuery({
    queryKey: ["admin", "employees", employeeId, "assignments"],
    queryFn: async () => {
      const { data } = await api.get(`employees/${employeeId}/assignments`);
      return data.data as EmployeeAssignment[];
    },
    enabled: !!employeeId,
  });
}

export function useInstituteTransfer(employeeId: string | number) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: { newSubOrganization: string | null; effectiveFrom: string; reason?: string | null }) => {
      const { data } = await api.post(`employees/${employeeId}/institute-transfer`, payload);
      return data.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "employees", employeeId] });
      queryClient.invalidateQueries({ queryKey: ["admin", "employees", employeeId, "assignments"] });
      queryClient.invalidateQueries({ queryKey: ["admin", "employees"] });
      toast.success("Institute transfer recorded");
    },
    onError: (error: any) => {
      toast.error(error.response?.data?.message || "Institute transfer failed");
    },
  });
}

export function useDesignationUpgrade(employeeId: string | number) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: { newDesignation: string; effectiveFrom: string; reason?: string | null }) => {
      const { data } = await api.post(`employees/${employeeId}/designation-upgrade`, payload);
      return data.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "employees", employeeId] });
      queryClient.invalidateQueries({ queryKey: ["admin", "employees", employeeId, "assignments"] });
      queryClient.invalidateQueries({ queryKey: ["admin", "employees"] });
      toast.success("Designation upgrade recorded");
    },
    onError: (error: any) => {
      toast.error(error.response?.data?.message || "Designation upgrade failed");
    },
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
