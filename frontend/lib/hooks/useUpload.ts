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
  return typeMap[type] || type.replace(/([A-Z])/g, "-$1").toLowerCase();
}

/** Backend returns `ok({ url, ...record })` — normalize to a single HTTPS URL string. */
function extractUploadUrl(payload: unknown): string {
  if (typeof payload === "string" && /^https?:\/\//i.test(payload)) {
    return payload;
  }
  if (!payload || typeof payload !== "object") {
    throw new Error("Invalid upload response");
  }
  const o = payload as Record<string, unknown>;
  if (typeof o.url === "string") return o.url;
  if (typeof o.photoUrl === "string") return o.photoUrl;
  if (typeof o.signatureUrl === "string") return o.signatureUrl;
  if (typeof o.certificateUrl === "string") return o.certificateUrl;
  if (typeof o.secure_url === "string") return o.secure_url;
  const q = o.qualification;
  if (q && typeof q === "object") {
    const qo = q as Record<string, unknown>;
    if (typeof qo.certificateUrl === "string") return qo.certificateUrl;
    for (let i = 1; i <= 8; i++) {
      const k = `sem${i}MarksheetUrl`;
      if (typeof qo[k] === "string") return qo[k] as string;
    }
  }
  throw new Error("Upload response did not include a URL");
}

export function useUpload(employeeId: string) {
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const upload = async (
    type: UploadType,
    file: File,
    extraData?: Record<string, string>
  ): Promise<string> => {
    setUploading(true);
    setError(null);
    setProgress(0);
    const formData = new FormData();
    formData.append("file", file);
    formData.append("employeeId", employeeId);
    if (extraData) {
      Object.entries(extraData).forEach(([k, v]) => {
        if (v !== undefined && v !== null) formData.append(k, String(v));
      });
    }
    try {
      const res = await api.post(`upload/${formatTypeForApi(type)}`, formData, {
        headers: { "Content-Type": "multipart/form-data" },
        onUploadProgress: (e) => {
          if (e.total) setProgress(Math.round((e.loaded * 100) / e.total));
        },
      });
      const raw = res.data?.data;
      return extractUploadUrl(raw);
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
