"use client";

import { useState, useEffect } from "react";
import { FileUploadInput } from "./FileUploadInput";
import { useUpload } from "@/lib/hooks/useUpload";

interface SemMarksheetGridProps {
  employeeId: string;
  qualificationId?: string;
  semCount?: number;
  existingUrls?: string[];
  onUpdate?: (urls: string[]) => void;
}

export function SemMarksheetGrid({
  employeeId,
  qualificationId,
  semCount = 8,
  existingUrls = [],
  onUpdate,
}: SemMarksheetGridProps) {
  const [urls, setUrls] = useState<string[]>(() =>
    Array.from({ length: semCount }, (_, i) => existingUrls[i] ?? "")
  );
  const { upload, uploading } = useUpload(employeeId);

  useEffect(() => {
    setUrls((prev) =>
      Array.from({ length: semCount }, (_, i) => existingUrls[i] ?? prev[i] ?? "")
    );
  }, [existingUrls, semCount]);

  const handleUpload = async (semIndex: number, file: File) => {
    const extra: Record<string, string> = { sem: String(semIndex + 1) };
    if (qualificationId) extra.qualId = qualificationId;
    const url = await upload("marksheet", file, extra);
    const newUrls = [...urls];
    newUrls[semIndex] = url;
    setUrls(newUrls);
    onUpdate?.(newUrls);
  };

  return (
    <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
      {Array.from({ length: semCount }).map((_, i) => (
        <FileUploadInput
          key={i}
          label={`Sem ${i + 1}`}
          accept="image/*,.pdf"
          currentUrl={urls[i]}
          onUpload={(file) => handleUpload(i, file)}
          uploading={uploading}
        />
      ))}
    </div>
  );
}
