"use client";

import { useState } from "react";
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
  semCount = 8,
  existingUrls = [],
  onUpdate,
}: SemMarksheetGridProps) {
  const [urls, setUrls] = useState<string[]>(existingUrls);
  const { upload, uploading } = useUpload(employeeId);

  const handleUpload = async (semIndex: number, file: File) => {
    const result = await upload("marksheet", file, {
      semIndex: String(semIndex + 1),
    });
    const newUrls = [...urls];
    newUrls[semIndex] = result.url;
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
