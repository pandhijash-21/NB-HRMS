"use client";

import { useCallback, useState, type ReactNode, type WheelEvent } from "react";
import { X } from "lucide-react";
import { cn } from "@/lib/utils";

export function PhotoLightbox({
  src,
  alt,
  children,
  className,
}: {
  src?: string | null;
  alt?: string;
  children: ReactNode;
  className?: string;
}) {
  const [open, setOpen] = useState(false);
  const [scale, setScale] = useState(1);
  const url = (src ?? "").trim();
  const canOpen = url.length > 0;

  const close = useCallback(() => {
    setOpen(false);
    setScale(1);
  }, []);

  const onWheel = (e: WheelEvent) => {
    e.preventDefault();
    setScale((s) => Math.min(5, Math.max(1, s + (e.deltaY < 0 ? 0.18 : -0.18))));
  };

  return (
    <>
      <span
        className={cn(canOpen ? "cursor-zoom-in inline-flex" : "inline-flex", className)}
        onClick={(e) => {
          if (!canOpen) return;
          e.stopPropagation();
          setOpen(true);
        }}
        onKeyDown={(e) => {
          if (canOpen && (e.key === "Enter" || e.key === " ")) {
            e.preventDefault();
            setOpen(true);
          }
        }}
        role={canOpen ? "button" : undefined}
        tabIndex={canOpen ? 0 : undefined}
      >
        {children}
      </span>
      {open && canOpen ? (
        <div className="fixed inset-0 z-[80] bg-black/85 flex flex-col">
          <div className="flex items-center gap-3 px-4 py-3 text-white shrink-0">
            <button
              type="button"
              className="rounded-full p-2 hover:bg-white/10"
              onClick={close}
              aria-label="Close photo"
            >
              <X className="size-5" />
            </button>
            <p className="font-semibold truncate flex-1">{alt || "Photo"}</p>
            <span className="text-xs text-white/70 hidden sm:inline">Scroll to zoom</span>
          </div>
          <div
            className="flex-1 overflow-auto grid place-items-center p-6 cursor-zoom-in"
            onClick={close}
            onWheel={onWheel}
          >
            <img
              src={url}
              alt={alt || ""}
              onClick={(e) => e.stopPropagation()}
              onDoubleClick={() => setScale((s) => (s > 1.2 ? 1 : 2.4))}
              className="max-w-[min(92vw,1100px)] max-h-[82vh] object-contain select-none"
              style={{ transform: `scale(${scale})`, transformOrigin: "center center" }}
            />
          </div>
        </div>
      ) : null}
    </>
  );
}
