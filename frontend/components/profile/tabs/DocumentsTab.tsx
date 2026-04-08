"use client";

import { useState } from "react";
import { Card, CardContent } from "@/components/ui/card";
import { FileUploadInput } from "@/components/shared/FileUploadInput";
import { useUpload } from "@/lib/hooks/useUpload";
import { useEmployee } from "@/lib/hooks/useEmployee";
import api from "@/lib/axios";

interface DocumentsTabProps {
  employeeId: string;
  isAdmin?: boolean;
}

export function DocumentsTab({ employeeId, isAdmin }: DocumentsTabProps) {
  const { upload, uploading } = useUpload(employeeId);
  const { employee, refetch } = useEmployee(employeeId);
  const [activeUpload, setActiveUpload] = useState<string | null>(null);

  const handleUpload = async (
    type: "photo" | "signature" | "aadhaarCard" | "panCard" | "offerLetter" | "experienceLetter",
    file: File
  ) => {
    setActiveUpload(type);
    try {
      await upload(type, file);
      refetch();
    } finally {
      setActiveUpload(null);
    }
  };

  const handleRemove = async (type: "photo" | "signature") => {
    if (!isAdmin) return;
    setActiveUpload(type);
    try {
      await api.patch(`employees/${employeeId}`, type === "photo" ? { photoUrl: null } : { signatureUrl: null });
      refetch();
    } finally {
      setActiveUpload(null);
    }
  };

  const docs = [
    { key: "photo" as const, label: "Profile Photo", url: employee?.photoUrl, accept: "image/*" },
    { key: "signature" as const, label: "Signature", url: employee?.signatureUrl, accept: "image/*" },
    { key: "aadhaarCard" as const, label: "Aadhaar Card", url: null, accept: "image/*,.pdf" },
    { key: "panCard" as const, label: "PAN Card", url: null, accept: "image/*,.pdf" },
    { key: "offerLetter" as const, label: "Offer Letter", url: null, accept: ".pdf,image/*" },
    { key: "experienceLetter" as const, label: "Experience Letter", url: null, accept: ".pdf,image/*" },
  ];

  return (
    <Card>
      <CardContent className="pt-5 space-y-5">
        <h3 className="text-sm font-semibold text-slate-700">Documents & Photos</h3>

        {!isAdmin && (
          <div className="p-3 bg-amber-50 border border-amber-200 rounded-lg text-xs text-amber-700">
            Documents can only be uploaded by HR / Admin.
          </div>
        )}

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {docs.map((doc) => (
            <FileUploadInput
              key={doc.key}
              label={doc.label}
              accept={doc.accept}
              currentUrl={doc.url}
              onRemove={
                isAdmin && (doc.key === "photo" || doc.key === "signature")
                  ? () => handleRemove(doc.key)
                  : undefined
              }
              uploading={uploading && activeUpload === doc.key}
              disabled={!isAdmin}
              onUpload={(file) => handleUpload(doc.key, file)}
            />
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
