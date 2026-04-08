"use client";

import { useRef, useState } from "react";
import { cn } from "@/lib/utils";

interface FileUploadInputProps {
  label: string;
  accept?: string;
  currentUrl?: string | null;
  onUpload: (file: File) => Promise<void>;
  onRemove?: () => void;
  uploading?: boolean;
  disabled?: boolean;
  className?: string;
}

export function FileUploadInput({
  label,
  accept = "image/*,.pdf",
  currentUrl,
  onUpload,
  onRemove,
  uploading,
  disabled,
  className,
}: FileUploadInputProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [dragOver, setDragOver] = useState(false);

  const handleFile = async (file: File) => {
    await onUpload(file);
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) handleFile(file);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    const file = e.dataTransfer.files?.[0];
    if (file) handleFile(file);
  };

  const isImage =
    currentUrl &&
    /\.(jpg|jpeg|png|gif|webp)(\?.*)?$/i.test(currentUrl);

  return (
    <div className={cn("space-y-2", className)}>
      <p className="text-xs font-medium text-slate-600">{label}</p>

      {currentUrl && isImage && (
        <div className="relative w-20 h-20 rounded-lg overflow-hidden border border-slate-200 mb-2">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={currentUrl}
            alt={label}
            className="w-full h-full object-cover"
          />
          {onRemove && !disabled && (
            <button
              type="button"
              onClick={onRemove}
              className="absolute top-1 left-1 rounded bg-black/55 text-white text-[10px] px-1.5 py-0.5 hover:bg-black/70"
              aria-label={`Remove ${label}`}
            >
              Remove
            </button>
          )}
        </div>
      )}
      {currentUrl && !isImage && (
        <div className="flex items-center gap-3">
          <a
            href={currentUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-xs text-[#1d3459] underline"
          >
            View current file
          </a>
          {onRemove && !disabled && (
            <button
              type="button"
              onClick={onRemove}
              className="text-xs text-rose-600 underline"
            >
              Remove
            </button>
          )}
        </div>
      )}

      <div
        className={cn(
          "border-2 border-dashed rounded-lg p-4 text-center cursor-pointer transition-colors",
          dragOver
            ? "border-[#d9b557] bg-amber-50"
            : "border-slate-200 hover:border-[#1d3459] hover:bg-slate-50",
          (uploading || disabled) && "opacity-50 pointer-events-none"
        )}
        onClick={() => inputRef.current?.click()}
        onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
        onDragLeave={() => setDragOver(false)}
        onDrop={handleDrop}
      >
        {uploading ? (
          <p className="text-xs text-slate-500 animate-pulse">Uploading…</p>
        ) : (
          <>
            <svg className="mx-auto mb-1 w-6 h-6 text-slate-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
              <polyline points="16 16 12 12 8 16" />
              <line x1="12" y1="12" x2="12" y2="21" />
              <path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3" />
            </svg>
            <p className="text-xs text-slate-500">
              Click or drag to upload
            </p>
          </>
        )}
      </div>

      <input
        ref={inputRef}
        type="file"
        accept={accept}
        aria-label={label}
        className="hidden"
        onChange={handleChange}
        disabled={uploading || disabled}
      />
    </div>
  );
}
