"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import api from "@/lib/axios";

export type LetterTemplate = {
  id: string;
  key: string;
  name: string;
  description?: string | null;
  templateHtml: string;
  logoUrl?: string | null;
  placeholders?: string[] | null;
  isActive: boolean;
};

export type LetterDocument = {
  id: string;
  employeeId: number;
  templateId: string;
  status: "DRAFT" | "FINAL";
  contentHtml: string;
  template?: LetterTemplate | null;
  createdAt?: string;
  updatedAt?: string;
};

function getErrorMessage(error: unknown, fallback: string) {
  if (typeof error === "object" && error && "response" in error) {
    const response = (error as { response?: { data?: { error?: string } } }).response;
    if (response?.data?.error) return response.data.error;
  }
  return fallback;
}

export function useLetterTemplates() {
  return useQuery({
    queryKey: ["letters", "templates"],
    queryFn: async () => {
      const { data } = await api.get("letters/templates");
      return data.data as LetterTemplate[];
    },
  });
}

export function useEmployeeLetterDocuments(employeeId?: number | string | null) {
  return useQuery({
    queryKey: ["letters", "employee", employeeId, "documents"],
    queryFn: async () => {
      const { data } = await api.get(`letters/employees/${employeeId}/documents`);
      return data.data as LetterDocument[];
    },
    enabled: !!employeeId,
  });
}

export function useUpsertLetterTemplate() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: {
      id?: string;
      key: string;
      name: string;
      description?: string | null;
      templateHtml: string;
      logoUrl?: string | null;
      placeholders?: string[];
    }) => {
      const { data } = await api.post("letters/templates", payload);
      return data.data as LetterTemplate;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["letters", "templates"] });
      toast.success("Letter template saved");
    },
    onError: (error: unknown) => {
      toast.error(getErrorMessage(error, "Failed to save letter template"));
    },
  });
}

export function useCreateLetterDraft() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: { employeeId: number | string; templateId: string }) => {
      const { data } = await api.post(
        `letters/employees/${payload.employeeId}/templates/${payload.templateId}/draft`,
      );
      return data.data as LetterDocument;
    },
    onSuccess: (_doc, vars) => {
      queryClient.invalidateQueries({
        queryKey: ["letters", "employee", vars.employeeId, "documents"],
      });
    },
    onError: (error: unknown) => {
      toast.error(getErrorMessage(error, "Failed to create letter draft"));
    },
  });
}

export function useUpdateLetterDraft() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: {
      documentId: string;
      contentHtml: string;
      employeeId?: number | string;
    }) => {
      const { data } = await api.patch(`letters/documents/${payload.documentId}`, {
        contentHtml: payload.contentHtml,
      });
      return { doc: data.data as LetterDocument, employeeId: payload.employeeId };
    },
    onSuccess: ({ employeeId }) => {
      if (employeeId) {
        queryClient.invalidateQueries({
          queryKey: ["letters", "employee", employeeId, "documents"],
        });
      }
    },
    onError: (error: unknown) => {
      toast.error(getErrorMessage(error, "Failed to update letter draft"));
    },
  });
}

export function useFinalizeLetterDraft() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: { draftId: string; employeeId?: number | string }) => {
      const { data } = await api.post(`letters/documents/${payload.draftId}/finalize`);
      return { doc: data.data as LetterDocument, employeeId: payload.employeeId };
    },
    onSuccess: ({ employeeId }) => {
      if (employeeId) {
        queryClient.invalidateQueries({
          queryKey: ["letters", "employee", employeeId, "documents"],
        });
      }
      toast.success("Letter generated and stored");
    },
    onError: (error: unknown) => {
      toast.error(getErrorMessage(error, "Failed to finalize letter"));
    },
  });
}

export function useDeleteLetterDocument() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: { documentId: string; employeeId?: number | string }) => {
      // Prefer POST delete — some environments drop DELETE verbs.
      const { data } = await api.post(`letters/documents/${payload.documentId}/delete`);
      return { result: data.data as { id: string; deleted: boolean }, employeeId: payload.employeeId };
    },
    onSuccess: ({ employeeId }) => {
      queryClient.invalidateQueries({ queryKey: ["letters", "employee"] });
      if (employeeId) {
        queryClient.invalidateQueries({
          queryKey: ["letters", "employee", employeeId, "documents"],
        });
      }
      toast.success("Letter deleted");
    },
    onError: (error: unknown) => {
      toast.error(getErrorMessage(error, "Failed to delete letter"));
    },
  });
}

export function useCreateCustomLetterDraft() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (payload: { employeeId: number | string; title?: string }) => {
      const { data } = await api.post(`letters/employees/${payload.employeeId}/custom-draft`, {
        title: payload.title ?? "Custom Letter",
      });
      return data.data as LetterDocument;
    },
    onSuccess: (_doc, vars) => {
      queryClient.invalidateQueries({
        queryKey: ["letters", "employee", vars.employeeId, "documents"],
      });
    },
    onError: (error: unknown) => {
      toast.error(getErrorMessage(error, "Failed to create custom letter"));
    },
  });
}

/** Opens a print window so the user can Save as PDF. */
export function downloadLetterPdf(title: string, html: string) {
  const w = window.open("", "_blank", "noopener,noreferrer,width=900,height=1100");
  if (!w) {
    toast.error("Please allow pop-ups to download the PDF");
    return;
  }
  const safeTitle = title.replace(/</g, "&lt;").replace(/>/g, "&gt;");
  w.document.open();
  w.document.write(`<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>${safeTitle}</title>
  <style>
    @page { margin: 18mm; size: A4; }
    body {
      margin: 0;
      font-family: Arial, Helvetica, sans-serif;
      color: #111;
      background: #fff;
    }
    .sheet { padding: 8mm; }
    img { max-width: 100%; }
  </style>
</head>
<body>
  <div class="sheet">${html}</div>
  <script>
    window.onload = function () {
      setTimeout(function () { window.print(); }, 250);
    };
  </script>
</body>
</html>`);
  w.document.close();
}

