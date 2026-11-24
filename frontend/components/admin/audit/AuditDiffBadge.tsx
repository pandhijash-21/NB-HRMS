"use client";

import React from "react";
import { ArrowRight, Minus, Plus } from "lucide-react";

interface AuditDiffBadgeProps {
  oldValue: string | null;
  newValue: string | null;
  maxLen?: number;
}

export function AuditDiffBadge({ oldValue, newValue, maxLen = 35 }: AuditDiffBadgeProps) {
  const isOldEmpty = oldValue === null || oldValue === undefined || oldValue.trim() === "";
  const isNewEmpty = newValue === null || newValue === undefined || newValue.trim() === "";

  const truncate = (val: string | null) => {
    if (!val) return "";
    return val.length > maxLen ? `${val.substring(0, maxLen)}...` : val;
  };

  if (isOldEmpty && isNewEmpty) {
    return <span className="text-xs text-slate-400 italic">No value change recorded</span>;
  }

  // Value added
  if (isOldEmpty && !isNewEmpty) {
    return (
      <div className="flex items-center gap-1.5 text-xs">
        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded font-mono font-medium bg-emerald-50 text-emerald-700 border border-emerald-200/60 max-w-[280px] truncate" title={newValue ?? undefined}>
          <Plus className="w-3 h-3 text-emerald-600 shrink-0" />
          {truncate(newValue)}
        </span>
      </div>
    );
  }

  // Value removed
  if (!isOldEmpty && isNewEmpty) {
    return (
      <div className="flex items-center gap-1.5 text-xs">
        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded font-mono font-medium bg-rose-50 text-rose-700 border border-rose-200/60 line-through max-w-[280px] truncate" title={oldValue ?? undefined}>
          <Minus className="w-3 h-3 text-rose-600 shrink-0" />
          {truncate(oldValue)}
        </span>
      </div>
    );
  }

  // Value modified
  return (
    <div className="flex items-center gap-1.5 text-xs flex-wrap">
      <span className="px-2 py-0.5 rounded font-mono text-slate-500 bg-slate-100 line-through border border-slate-200 max-w-[180px] truncate" title={oldValue ?? undefined}>
        {truncate(oldValue)}
      </span>
      <ArrowRight className="w-3.5 h-3.5 text-slate-400 shrink-0" />
      <span className="px-2 py-0.5 rounded font-mono font-semibold bg-emerald-50 text-emerald-800 border border-emerald-300/80 max-w-[180px] truncate" title={newValue ?? undefined}>
        {truncate(newValue)}
      </span>
    </div>
  );
}
