"use client";

import { useState } from "react";
import api from "@/lib/axios";

type UploadType =
  | "photo"
  | "signature"
  | "aadhaarCard"
  | "panCard"
  | "offerLetter"
  | "experienceLetter"
  | "marksheet";

export function useUpload(employeeId: string) {
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const upload = async (type: UploadType, file: File, extraData?: Record<string, string>) => {
    setUploading(true);
    setError(null);
    setProgress(0);
    const formData = new FormData();
    formData.append("file", file);
    if (extraData) {
      Object.entries(extraData).forEach(([k, v]) => formData.append(k, v));
    }
    try {
      const res = await api.post(
        `/personal-education/employees/${employeeId}/upload/${type}`,
        formData,
        {
          headers: { "Content-Type": "multipart/form-data" },
          onUploadProgress: (e) => {
            if (e.total) setProgress(Math.round((e.loaded * 100) / e.total));
          },
        }
      );
      return res.data.data as { url: string };
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : "Upload failed";
      setError(msg);
      throw e;
    } finally {
      setUploading(false);
    }
  };

  return { upload, uploading, progress, error };
}
