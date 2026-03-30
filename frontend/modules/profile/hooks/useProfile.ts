"use client";

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/axios";
import { GeneralInfo, PersonalInfo, Address, FamilyMember, AcademicQualification, OtherInfo } from "../types";

// Base Profile Query
export function useEmployeeBase(id: string | number) {
  return useQuery({
    queryKey: ["employee", id],
    queryFn: async () => {
      const { data } = await api.get(`employees/${id}`);
      return data.data;
    },
    enabled: !!id,
  });
}

// General Info
export function useGeneralInfo(id: string | number) {
  return useQuery<GeneralInfo>({
    queryKey: ["employee", id, "general"],
    queryFn: async () => {
      const { data } = await api.get(`employees/${id}/general`);
      return data.data;
    },
    enabled: !!id,
  });
}

export function useUpdateGeneralInfo(id: string | number) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: Partial<GeneralInfo>) => {
      const { data } = await api.patch(`employees/${id}/general`, payload);
      return data.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["employee", id, "general"] });
    },
  });
}

// Personal Info
export function usePersonalInfo(id: string | number) {
  return useQuery<PersonalInfo>({
    queryKey: ["employee", id, "personal"],
    queryFn: async () => {
      const { data } = await api.get(`employees/${id}/personal`);
      return data.data;
    },
    enabled: !!id,
  });
}

export function useUpdatePersonalInfo(id: string | number) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: Partial<PersonalInfo>) => {
      const { data } = await api.patch(`employees/${id}/personal`, payload);
      return data.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["employee", id, "personal"] });
    },
  });
}

// Addresses
export function useAddresses(id: string | number) {
  return useQuery<Address[]>({
    queryKey: ["employee", id, "addresses"],
    queryFn: async () => {
      const { data } = await api.get(`employees/${id}/addresses`);
      return data.data;
    },
    enabled: !!id,
  });
}

export function useUpsertAddress(id: string | number) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: Partial<Address>) => {
      const { data } = await api.post(`employees/${id}/addresses`, payload);
      return data.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["employee", id, "addresses"] });
    },
  });
}

// Other Info
export function useOtherInfo(id: string | number) {
  return useQuery<OtherInfo>({
    queryKey: ["employee", id, "other"],
    queryFn: async () => {
      const { data } = await api.get(`employees/${id}/other`);
      return data.data;
    },
    enabled: !!id,
  });
}

export function useUpdateOtherInfo(id: string | number) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: Partial<OtherInfo>) => {
      const { data } = await api.patch(`employees/${id}/other`, payload);
      return data.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["employee", id, "other"] });
    },
  });
}

// Family
export function useFamilyMembers(id: string | number) {
  return useQuery<FamilyMember[]>({
    queryKey: ["employee", id, "family"],
    queryFn: async () => {
      const { data } = await api.get(`employees/${id}/family`);
      return data.data;
    },
    enabled: !!id,
  });
}

export function useFamilyActions(id: string | number) {
  const queryClient = useQueryClient();
  
  const addMutation = useMutation({
    mutationFn: async (payload: Partial<FamilyMember>) => {
      const { data } = await api.post(`employees/${id}/family`, payload);
      return data.data;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["employee", id, "family"] }),
  });

  const deleteMutation = useMutation({
    mutationFn: async (memberId: number) => {
      const { data } = await api.delete(`employees/${id}/family/${memberId}`);
      return data.data;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["employee", id, "family"] }),
  });

  return { addMutation, deleteMutation };
}

// Academic
export function useAcademicQualifications(id: string | number) {
  return useQuery<AcademicQualification[]>({
    queryKey: ["employee", id, "academic"],
    queryFn: async () => {
      const { data } = await api.get(`employees/${id}/academic`);
      return data.data;
    },
    enabled: !!id,
  });
}

export function useAcademicActions(id: string | number) {
  const queryClient = useQueryClient();
  
  const addMutation = useMutation({
    mutationFn: async (payload: Partial<AcademicQualification>) => {
      const { data } = await api.post(`employees/${id}/academic`, payload);
      return data.data;
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["employee", id, "academic"] }),
  });

  return { addMutation };
}
