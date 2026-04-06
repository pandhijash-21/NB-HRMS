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
  | "marksheet"
  | "certificate"
  | "passport"
  | "aadhaarFamily"
  | "lastPaycheck"
  | "recommendation";

function formatTypeForApi(type: UploadType): string {
  const typeMap: Record<UploadType, string> = {
    photo: "photo",
    signature: "signature",
    aadhaarCard: "aadhaar-card",
    panCard: "pan-card",
    offerLetter: "offer-letter",
    experienceLetter: "experience-letter",
    marksheet: "marksheet",
    certificate: "certificate",
    passport: "passport",
    aadhaarFamily: "aadhaar-family",
    lastPaycheck: "last-paycheck",
    recommendation: "recommendation",
  };
  return typeMap[type] || type.replace(/([A-Z])/g, '-$1').toLowerCase();
}

export function useUpload(employeeId: string) {
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const upload = async (type: UploadType, file: File, extraData?: Record<string, string>): Promise<string> => {
    setUploading(true);
    setError(null);
    setProgress(0);
    const formData = new FormData();
    formData.append("file", file);
    formData.append("employeeId", employeeId);
    if (extraData) {
      Object.entries(extraData).forEach(([k, v]) => formData.append(k, v));
    }
    try {
      const res = await api.post(
        `upload/${formatTypeForApi(type)}`,
        formData,
        {
          headers: { "Content-Type": "multipart/form-data" },
          onUploadProgress: (e) => {
            if (e.total) setProgress(Math.round((e.loaded * 100) / e.total));
          },
        }
      );
      // Return the URL from the response
      return res.data.data?.url || res.data.data;
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
