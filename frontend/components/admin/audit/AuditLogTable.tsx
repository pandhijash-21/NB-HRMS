"use client";

import React, { useState } from "react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Eye, Clock, ShieldAlert, ChevronLeft, ChevronRight, User, MousePointerClick, Compass, Zap, FileEdit } from "lucide-react";
import { AuditDiffBadge } from "./AuditDiffBadge";
import { AuditDetailDialog } from "./AuditDetailDialog";
import type { AuditLogEntry, PaginationMeta } from "@/lib/hooks/useAuditLogs";

interface AuditLogTableProps {
  logs: AuditLogEntry[];
  pagination: PaginationMeta;
  loading: boolean;
  onPageChange: (newPage: number) => void;
  hideEmployeeCol?: boolean;
}

export function AuditLogTable({
  logs,
  pagination,
  loading,
  onPageChange,
  hideEmployeeCol = false,
}: AuditLogTableProps) {
  const [selectedLog, setSelectedLog] = useState<AuditLogEntry | null>(null);

  const formatRelativeTime = (isoDate: string) => {
    try {
      const diffMs = Date.now() - new Date(isoDate).getTime();
      const diffMin = Math.floor(diffMs / 60000);
      if (diffMin < 1) return "Just now";
      if (diffMin < 60) return `${diffMin}m ago`;
      const diffHours = Math.floor(diffMin / 60);
      if (diffHours < 24) return `${diffHours}h ago`;
      const diffDays = Math.floor(diffHours / 24);
      if (diffDays < 7) return `${diffDays}d ago`;
      return new Date(isoDate).toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
        year: "numeric",
      });
    } catch {
      return isoDate;
    }
  };

  return (
    <div className="space-y-3">
      <div className="border border-slate-200/90 rounded-lg overflow-hidden bg-white shadow-sm">
        <div className="overflow-x-auto">
          <Table>
            <TableHeader className="bg-slate-50/80">
              <TableRow className="border-b border-slate-200/80 text-xs text-slate-600 font-bold tracking-wider uppercase">
                <TableHead className="w-[170px]">Timestamp</TableHead>
                {!hideEmployeeCol && <TableHead className="w-[200px]">Target Employee</TableHead>}
                <TableHead className="w-[180px]">Module / Field</TableHead>
                <TableHead className="min-w-[280px]">Change Diff</TableHead>
                <TableHead className="w-[170px]">Changed By</TableHead>
                <TableHead className="w-[60px] text-right">View</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading ? (
                Array.from({ length: 6 }).map((_, i) => (
                  <TableRow key={i} className="animate-pulse">
                    <TableCell colSpan={hideEmployeeCol ? 5 : 6} className="py-4">
                      <div className="h-4 bg-slate-100 rounded w-full" />
                    </TableCell>
                  </TableRow>
                ))
              ) : logs.length === 0 ? (
                <TableRow>
                  <TableCell
                    colSpan={hideEmployeeCol ? 5 : 6}
                    className="py-12 text-center text-slate-500"
                  >
                    <div className="flex flex-col items-center justify-center max-w-sm mx-auto">
                      <ShieldAlert className="w-10 h-10 text-slate-300 mb-2 stroke-[1.5]" />
                      <p className="font-semibold text-slate-700 text-sm">No audit logs found</p>
                      <p className="text-xs text-slate-400 mt-1">
                        Try adjusting your filters, date range, or selected employee.
                      </p>
                    </div>
                  </TableCell>
                </TableRow>
              ) : (
                logs.map((log) => {
                  const emp = log.targetEmployee;
                  return (
                    <TableRow
                      key={log.id}
                      className="hover:bg-slate-50/80 transition-colors text-xs border-b border-slate-100"
                    >
                      {/* Timestamp */}
                      <TableCell className="align-top py-3">
                        <div className="font-semibold text-slate-800">
                          {formatRelativeTime(log.changedAt)}
                        </div>
                        <div className="text-[10px] text-slate-400 font-mono mt-0.5" title={log.changedAt}>
                          {new Date(log.changedAt).toLocaleTimeString([], {
                            hour: "2-digit",
                            minute: "2-digit",
                          })}
                        </div>
                      </TableCell>

                      {/* Target Employee */}
                      {!hideEmployeeCol && (
                        <TableCell className="align-top py-3">
                          {emp ? (
                            <div className="flex items-center gap-2">
                              <Avatar className="w-7 h-7 shrink-0 border border-slate-200">
                                {emp.avatarUrl && <AvatarImage src={emp.avatarUrl} alt={emp.fullName} />}
                                <AvatarFallback className="bg-indigo-50 text-indigo-700 font-bold text-[10px]">
                                  {emp.fullName.slice(0, 2).toUpperCase()}
                                </AvatarFallback>
                              </Avatar>
                              <div className="min-w-0">
                                <div className="font-bold text-slate-800 truncate" title={emp.fullName}>
                                  {emp.fullName}
                                </div>
                                <div className="text-[10px] text-slate-400 font-mono truncate">
                                  {emp.employeeCode || `ID #${emp.id}`}
                                </div>
                              </div>
                            </div>
                          ) : (
                            <span className="text-slate-400 italic">Global / System</span>
                          )}
                        </TableCell>
                      )}

                      {/* Module & Field */}
                      <TableCell className="align-top py-3">
                        {log.category === "CLICK" || log.tableName === "USER_CLICK" ? (
                          <>
                            <Badge
                              variant="secondary"
                              className="text-[10px] font-semibold py-0 px-1.5 bg-cyan-50 text-cyan-700 border border-cyan-200 mb-1 flex items-center gap-1 w-fit"
                            >
                              <MousePointerClick className="w-3 h-3" />
                              User Click
                            </Badge>
                            <div className="font-bold text-slate-800 truncate" title={log.fieldName}>
                              {log.fieldName}
                            </div>
                          </>
                        ) : log.category === "VIEW" || log.tableName === "PAGE_VIEW" ? (
                          <>
                            <Badge
                              variant="secondary"
                              className="text-[10px] font-semibold py-0 px-1.5 bg-purple-50 text-purple-700 border border-purple-200 mb-1 flex items-center gap-1 w-fit"
                            >
                              <Compass className="w-3 h-3" />
                              Page View
                            </Badge>
                            <div className="font-bold text-slate-800 truncate" title={log.recordId}>
                              {log.recordId}
                            </div>
                          </>
                        ) : log.category === "ACTION" || log.tableName === "SYSTEM_ACTION" ? (
                          <>
                            <Badge
                              variant="secondary"
                              className="text-[10px] font-semibold py-0 px-1.5 bg-amber-50 text-amber-700 border border-amber-200 mb-1 flex items-center gap-1 w-fit"
                            >
                              <Zap className="w-3 h-3" />
                              System Action
                            </Badge>
                            <div className="font-bold text-slate-800 truncate" title={log.fieldName}>
                              {log.fieldName}
                            </div>
                          </>
                        ) : (
                          <>
                            <Badge
                              variant="secondary"
                              className="text-[10px] font-semibold py-0 px-1.5 bg-slate-100 text-slate-700 border border-slate-200 mb-1"
                            >
                              {log.tableLabel}
                            </Badge>
                            <div className="font-bold text-slate-800 truncate" title={log.fieldLabel}>
                              {log.fieldLabel}
                            </div>
                          </>
                        )}
                      </TableCell>

                      {/* Diff / Details */}
                      <TableCell className="align-top py-3">
                        {log.category === "CLICK" || log.tableName === "USER_CLICK" ? (
                          <div className="text-xs text-slate-600">
                            <span className="font-medium text-slate-400">Screen: </span>
                            <span className="font-mono bg-slate-100 px-1.5 py-0.5 rounded text-slate-700 border border-slate-200">
                              {log.recordId}
                            </span>
                          </div>
                        ) : log.category === "VIEW" || log.tableName === "PAGE_VIEW" ? (
                          <div className="text-xs text-slate-500 italic">
                            Navigation transition
                          </div>
                        ) : log.category === "ACTION" || log.tableName === "SYSTEM_ACTION" ? (
                          <div className="text-xs text-slate-700">
                            <span className="font-medium text-slate-400">Target: </span>
                            <span className="font-mono">{log.recordId}</span>
                            {log.newValue && (
                              <Badge variant="outline" className="ml-2 text-[10px] bg-emerald-50 text-emerald-700 border-emerald-200">
                                {log.newValue}
                              </Badge>
                            )}
                          </div>
                        ) : (
                          <>
                            <AuditDiffBadge oldValue={log.oldValue} newValue={log.newValue} />
                            {log.changeReason && (
                              <div className="text-[10px] text-slate-400 italic mt-1 truncate" title={log.changeReason}>
                                Reason: {log.changeReason}
                              </div>
                            )}
                          </>
                        )}
                      </TableCell>

                      {/* Changed By */}
                      <TableCell className="align-top py-3">
                        <div className="font-semibold text-slate-800 flex items-center gap-1 truncate" title={log.changedByName}>
                          <User className="w-3 h-3 text-slate-400 shrink-0" />
                          <span className="truncate">{log.changedByName}</span>
                        </div>
                        <div className="flex items-center gap-1 mt-0.5">
                          {log.changedByRole && (
                            <Badge variant="outline" className="text-[9px] uppercase font-bold py-0 px-1">
                              {log.changedByRole}
                            </Badge>
                          )}
                          {log.isSelfChange && (
                            <Badge className="text-[9px] bg-sky-100 text-sky-800 border-sky-300 py-0 px-1">
                              Self
                            </Badge>
                          )}
                        </div>
                      </TableCell>

                      {/* Action */}
                      <TableCell className="align-top py-3 text-right">
                        <Button
                          variant="ghost"
                          size="sm"
                          className="h-7 w-7 p-0 text-slate-500 hover:text-indigo-600 hover:bg-indigo-50"
                          onClick={() => setSelectedLog(log)}
                          title="Inspect details"
                        >
                          <Eye className="w-3.5 h-3.5" />
                        </Button>
                      </TableCell>
                    </TableRow>
                  );
                })
              )}
            </TableBody>
          </Table>
        </div>

        {/* Pagination Bar */}
        <div className="flex items-center justify-between px-4 py-2.5 border-t border-slate-200 bg-slate-50/50 text-xs text-slate-500">
          <div>
            Showing{" "}
            <span className="font-semibold text-slate-700">
              {logs.length > 0 ? (pagination.page - 1) * pagination.limit + 1 : 0}
            </span>{" "}
            to{" "}
            <span className="font-semibold text-slate-700">
              {Math.min(pagination.page * pagination.limit, pagination.total)}
            </span>{" "}
            of <span className="font-semibold text-slate-700">{pagination.total}</span> entries
          </div>

          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              disabled={pagination.page <= 1 || loading}
              onClick={() => onPageChange(pagination.page - 1)}
              className="h-7 text-xs px-2.5"
            >
              <ChevronLeft className="w-3.5 h-3.5 mr-1" />
              Previous
            </Button>
            <span className="text-xs font-semibold px-2">
              Page {pagination.page} of {Math.max(1, pagination.totalPages)}
            </span>
            <Button
              variant="outline"
              size="sm"
              disabled={pagination.page >= pagination.totalPages || loading}
              onClick={() => onPageChange(pagination.page + 1)}
              className="h-7 text-xs px-2.5"
            >
              Next
              <ChevronRight className="w-3.5 h-3.5 ml-1" />
            </Button>
          </div>
        </div>
      </div>

      <AuditDetailDialog
        log={selectedLog}
        open={Boolean(selectedLog)}
        onOpenChange={(open) => !open && setSelectedLog(null)}
      />
    </div>
  );
}
