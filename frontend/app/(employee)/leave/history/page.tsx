"use client";

import { useState } from "react";
import { useMyLeaveApplications, useCancelLeave } from "@/lib/hooks/useLeave";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import { CalendarDays, XCircle, ChevronLeft, ChevronRight } from "lucide-react";
import { formatDate } from "@/lib/utils";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";

const STATUS_STYLES: Record<string, string> = {
  PENDING:   "bg-amber-100 text-amber-700 border-amber-200",
  APPROVED:  "bg-emerald-100 text-emerald-700 border-emerald-200",
  REJECTED:  "bg-rose-100 text-rose-600 border-rose-200",
  CANCELLED: "bg-slate-100 text-slate-500 border-slate-200",
};

const PAGE_SIZE = 10;
const CY = new Date().getFullYear();
const YEARS = Array.from({ length: 5 }, (_, i) => CY - i);

export default function LeaveHistoryPage() {
  const [status, setStatus] = useState<string>("ALL");
  const [year, setYear] = useState<number>(CY);
  const [page, setPage] = useState(0);

  const { data, isLoading } = useMyLeaveApplications({
    status: status === "ALL" ? undefined : status,
    year,
    page,
    limit: PAGE_SIZE,
  });

  const { mutate: cancel } = useCancelLeave();
  const totalPages = data ? Math.ceil(data.total / PAGE_SIZE) : 0;

  return (
    <div className="space-y-6 animate-in fade-in duration-500">
      <div>
        <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Leave History</h1>
        <p className="text-sm text-slate-500 mt-1">All your leave applications</p>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <Select value={String(year)} onValueChange={(v) => { setYear(Number(v)); setPage(0); }}>
          <SelectTrigger className="w-28">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {YEARS.map((y) => (
              <SelectItem key={y} value={String(y)}>{y}</SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Select value={status} onValueChange={(v) => { setStatus(v); setPage(0); }}>
          <SelectTrigger className="w-36">
            <SelectValue placeholder="Status" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="ALL">All Status</SelectItem>
            <SelectItem value="PENDING">Pending</SelectItem>
            <SelectItem value="APPROVED">Approved</SelectItem>
            <SelectItem value="REJECTED">Rejected</SelectItem>
            <SelectItem value="CANCELLED">Cancelled</SelectItem>
          </SelectContent>
        </Select>
      </div>

      {/* Table */}
      {isLoading ? (
        <div className="space-y-3">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton key={i} className="h-20 rounded-xl" />
          ))}
        </div>
      ) : !data?.items.length ? (
        <div className="text-center py-16 text-slate-400">
          <CalendarDays className="w-10 h-10 mx-auto mb-3 opacity-30" />
          <p>No applications found</p>
        </div>
      ) : (
        <div className="space-y-3">
          {data.items.map((a) => (
            <Card key={a.id} className="border-none shadow-sm hover:shadow-md transition-all">
              <CardContent className="py-4 px-5">
                <div className="flex items-start justify-between gap-4">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-semibold text-slate-800">{a.leaveType.name}</span>
                      <Badge className={`text-[11px] border ${STATUS_STYLES[a.status] ?? ""}`}>
                        {a.status}
                      </Badge>
                      {a.isHalfDay && (
                        <Badge variant="outline" className="text-[11px]">Half Day</Badge>
                      )}
                    </div>
                    <p className="text-sm text-slate-500 mt-1">
                      {formatDate(a.fromDate)} – {formatDate(a.toDate)} &middot; {a.totalDays} day{a.totalDays !== 1 ? "s" : ""}
                    </p>
                    <p className="text-xs text-slate-400 mt-0.5">
                      {a.applicationNo} &middot; Applied {formatDate(a.appliedAt)}
                    </p>
                    {a.reason && (
                      <p className="text-xs text-slate-500 mt-1 line-clamp-1 italic">"{a.reason}"</p>
                    )}
                    {/* Approval step summary */}
                    {a.approvalSteps?.length > 0 && (
                      <div className="flex items-center gap-2 mt-2 flex-wrap">
                        {a.approvalSteps.map((s) => (
                          <span
                            key={s.id}
                            className={`text-[10px] px-2 py-0.5 rounded-full border font-medium ${
                              s.action === "APPROVED" || s.action === "RECOMMENDED"
                                ? "bg-emerald-50 border-emerald-200 text-emerald-700"
                                : s.action === "REJECTED"
                                  ? "bg-rose-50 border-rose-200 text-rose-600"
                                  : s.isSuperseded
                                    ? "bg-slate-50 border-slate-200 text-slate-400 line-through"
                                    : "bg-amber-50 border-amber-200 text-amber-700"
                            }`}
                          >
                            {s.approverRole}: {s.action ?? "Pending"}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                  {a.status === "PENDING" && (
                    <AlertDialog>
                      <AlertDialogTrigger asChild>
                        <Button variant="ghost" size="icon" className="text-rose-400 hover:text-rose-600 shrink-0">
                          <XCircle className="w-4 h-4" />
                        </Button>
                      </AlertDialogTrigger>
                      <AlertDialogContent>
                        <AlertDialogHeader>
                          <AlertDialogTitle>Cancel this application?</AlertDialogTitle>
                          <AlertDialogDescription>
                            This will cancel your {a.leaveType.name} application and restore your balance.
                          </AlertDialogDescription>
                        </AlertDialogHeader>
                        <AlertDialogFooter>
                          <AlertDialogCancel>Keep</AlertDialogCancel>
                          <AlertDialogAction
                            className="bg-rose-600"
                            onClick={() => cancel(a.id)}
                          >
                            Cancel Application
                          </AlertDialogAction>
                        </AlertDialogFooter>
                      </AlertDialogContent>
                    </AlertDialog>
                  )}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between pt-2">
          <Button variant="ghost" size="sm" disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
            <ChevronLeft className="w-4 h-4 mr-1" /> Previous
          </Button>
          <span className="text-xs text-slate-500">
            Page {page + 1} of {totalPages}
          </span>
          <Button variant="ghost" size="sm" disabled={page >= totalPages - 1} onClick={() => setPage((p) => p + 1)}>
            Next <ChevronRight className="w-4 h-4 ml-1" />
          </Button>
        </div>
      )}
    </div>
  );
}
