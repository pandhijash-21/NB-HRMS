"use client";

import React from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Clock, Globe, Shield, User, Laptop } from "lucide-react";
import type { AuditLogEntry } from "@/lib/hooks/useAuditLogs";

interface AuditDetailDialogProps {
  log: AuditLogEntry | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function AuditDetailDialog({ log, open, onOpenChange }: AuditDetailDialogProps) {
  if (!log) return null;

  const dateStr = new Date(log.changedAt).toLocaleString("en-US", {
    weekday: "short",
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-xl max-h-[85vh] overflow-y-auto">
        <DialogHeader className="border-b pb-3">
          <div className="flex items-center justify-between pr-4">
            <DialogTitle className="text-base font-bold text-slate-800 flex items-center gap-2">
              <Shield className="w-5 h-5 text-indigo-600" />
              Audit Log Event Details
            </DialogTitle>
            <Badge variant="outline" className="font-mono text-[10px] text-slate-500 uppercase">
              {log.id.slice(0, 8)}
            </Badge>
          </div>
        </DialogHeader>

        <div className="space-y-4 pt-2 text-sm">
          {/* Target Employee */}
          {log.targetEmployee && (
            <div className="bg-slate-50 border border-slate-200/80 rounded-lg p-3">
              <div className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">
                Target Employee
              </div>
              <div className="flex items-center gap-3">
                <Avatar className="w-10 h-10 border border-slate-200">
                  {log.targetEmployee.avatarUrl && (
                    <AvatarImage src={log.targetEmployee.avatarUrl} alt={log.targetEmployee.fullName} />
                  )}
                  <AvatarFallback className="bg-indigo-100 text-indigo-700 font-bold text-xs">
                    {log.targetEmployee.fullName.slice(0, 2).toUpperCase()}
                  </AvatarFallback>
                </Avatar>
                <div>
                  <div className="font-bold text-slate-800 text-sm">
                    {log.targetEmployee.fullName}
                  </div>
                  <div className="text-xs text-slate-500 flex items-center gap-2">
                    {log.targetEmployee.employeeCode && (
                      <span className="font-mono">{log.targetEmployee.employeeCode}</span>
                    )}
                    {log.targetEmployee.designation && <span>• {log.targetEmployee.designation}</span>}
                    {log.targetEmployee.department && <span>• {log.targetEmployee.department}</span>}
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Module & Field */}
          <div className="grid grid-cols-2 gap-3">
            <div className="bg-slate-50 border border-slate-200/80 rounded-lg p-3">
              <div className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-1">
                Section / Module
              </div>
              <div className="font-semibold text-slate-800">{log.tableLabel}</div>
              <div className="text-[11px] font-mono text-slate-400 mt-0.5">{log.tableName}</div>
            </div>

            <div className="bg-slate-50 border border-slate-200/80 rounded-lg p-3">
              <div className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-1">
                Field Changed
              </div>
              <div className="font-semibold text-slate-800">{log.fieldLabel}</div>
              <div className="text-[11px] font-mono text-slate-400 mt-0.5">{log.fieldName}</div>
            </div>
          </div>

          {/* Value Diff */}
          <div className="border border-slate-200 rounded-lg overflow-hidden">
            <div className="bg-slate-100/80 px-3 py-1.5 border-b border-slate-200 text-xs font-bold text-slate-600 uppercase tracking-wider">
              Change Diff Inspection
            </div>
            <div className="p-3 grid grid-cols-1 md:grid-cols-2 gap-3">
              <div>
                <span className="text-xs font-bold text-rose-600 block mb-1">Previous Value:</span>
                <div className="p-2.5 rounded bg-rose-50/50 border border-rose-200/60 font-mono text-xs text-slate-700 whitespace-pre-wrap break-all min-h-[48px]">
                  {log.oldValue !== null && log.oldValue !== undefined && log.oldValue !== "" ? (
                    log.oldValue
                  ) : (
                    <span className="text-slate-400 italic">(none / empty)</span>
                  )}
                </div>
              </div>

              <div>
                <span className="text-xs font-bold text-emerald-600 block mb-1">Updated Value:</span>
                <div className="p-2.5 rounded bg-emerald-50/50 border border-emerald-200/60 font-mono text-xs text-slate-800 font-medium whitespace-pre-wrap break-all min-h-[48px]">
                  {log.newValue !== null && log.newValue !== undefined && log.newValue !== "" ? (
                    log.newValue
                  ) : (
                    <span className="text-slate-400 italic">(cleared / null)</span>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Changer Info & Context */}
          <div className="border border-slate-200 rounded-lg p-3 space-y-2.5">
            <div className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Actor & Context
            </div>

            <div className="grid grid-cols-2 gap-2 text-xs">
              <div className="flex items-center gap-2">
                <User className="w-4 h-4 text-slate-400 shrink-0" />
                <div>
                  <span className="font-bold text-slate-800">{log.changedByName}</span>
                  {log.changedByRole && (
                    <Badge variant="outline" className="ml-2 text-[9px] uppercase font-bold py-0">
                      {log.changedByRole}
                    </Badge>
                  )}
                  {log.isSelfChange && (
                    <Badge className="ml-1 text-[9px] bg-sky-100 text-sky-800 border-sky-300 py-0">
                      Self
                    </Badge>
                  )}
                </div>
              </div>

              <div className="flex items-center gap-2">
                <Clock className="w-4 h-4 text-slate-400 shrink-0" />
                <span className="text-slate-600">{dateStr}</span>
              </div>

              {log.ipAddress && (
                <div className="flex items-center gap-2">
                  <Globe className="w-4 h-4 text-slate-400 shrink-0" />
                  <span className="font-mono text-slate-600">{log.ipAddress}</span>
                </div>
              )}

              {log.userAgent && (
                <div className="flex items-center gap-2 col-span-2">
                  <Laptop className="w-4 h-4 text-slate-400 shrink-0" />
                  <span className="text-slate-500 truncate text-[11px]" title={log.userAgent}>
                    {log.userAgent}
                  </span>
                </div>
              )}
            </div>

            {log.changeReason && (
              <div className="mt-2 pt-2 border-t border-slate-100">
                <span className="text-xs font-bold text-slate-500">Reason: </span>
                <span className="text-xs text-slate-700 italic">{log.changeReason}</span>
              </div>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
