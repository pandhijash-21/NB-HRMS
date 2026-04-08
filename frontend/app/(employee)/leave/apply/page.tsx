"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import type { Resolver } from "react-hook-form";
import { useLeaveTypes, useApplyLeave, useMyLeaveBalances } from "@/lib/hooks/useLeave";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { Switch } from "@/components/ui/switch";
import { ArrowLeft, CalendarDays } from "lucide-react";
import Link from "next/link";

const schema = z.object({
  leaveTypeId: z.string().min(1, "Please select a leave type"),
  fromDate: z.string().min(1, "From date is required"),
  toDate: z.string().min(1, "To date is required"),
  isHalfDay: z.boolean().default(false),
  halfDaySession: z.enum(["MORNING", "AFTERNOON"]).optional().nullable(),
  reason: z.string().min(5, "Reason must be at least 5 characters"),
  documentUrl: z.string().optional().nullable(),
});

type FormData = z.infer<typeof schema>;

export default function ApplyLeavePage() {
  const router = useRouter();
  const { data: allTypes = [], isLoading: typesLoading } = useLeaveTypes();
  const { data: balances = [] } = useMyLeaveBalances(new Date().getFullYear());

  // SL and EL can only be applied by admin on behalf — hide from self-apply
  const types = allTypes.filter((t) => t.isActive && t.employeeCanApply);
  const { mutateAsync: apply, isPending } = useApplyLeave();

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    formState: { errors },
  } = useForm<FormData>({
    resolver: zodResolver(schema) as Resolver<FormData>,
    defaultValues: { isHalfDay: false, halfDaySession: null },
  });

  const isHalfDay = watch("isHalfDay");
  const selectedTypeId = watch("leaveTypeId");
  const selectedType = types.find((t) => t.id === selectedTypeId);
  const balance = balances.find((b) => b.leaveTypeId === selectedTypeId);

  const onSubmit = async (data: FormData) => {
    await apply({
      leaveTypeId: data.leaveTypeId,
      fromDate: data.fromDate,
      toDate: data.toDate,
      isHalfDay: data.isHalfDay,
      halfDaySession: data.isHalfDay ? data.halfDaySession : null,
      reason: data.reason,
      documentUrl: data.documentUrl || null,
    });
    router.push("/leave");
  };

  return (
    <div className="max-w-2xl mx-auto space-y-6 animate-in fade-in duration-500">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/leave"><ArrowLeft className="w-4 h-4" /></Link>
        </Button>
        <div>
          <h1 className="text-xl font-bold text-slate-900">Apply for Leave</h1>
          <p className="text-xs text-slate-500">Fill in the details below and submit for approval</p>
        </div>
      </div>

      <Card className="border-none shadow-sm">
        <CardHeader>
          <CardTitle className="text-base flex items-center gap-2">
            <CalendarDays className="w-4 h-4 text-slate-400" /> Application Details
          </CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
            {/* Leave Type */}
            <div className="space-y-1.5">
              <Label>Leave Type</Label>
              {typesLoading ? (
                <div className="h-10 bg-slate-100 rounded-md animate-pulse" />
              ) : (
                <Select onValueChange={(v) => setValue("leaveTypeId", v)}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select leave type…" />
                  </SelectTrigger>
                  <SelectContent>
                    {types.map((t) => (
                      <SelectItem key={t.id} value={t.id}>
                        {t.name} ({t.code})
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
              {errors.leaveTypeId && (
                <p className="text-xs text-rose-500">{errors.leaveTypeId.message}</p>
              )}
              {balance && (
                <p className="text-xs text-slate-500 mt-1">
                  Available balance:{" "}
                  <strong className="text-emerald-600">
                    {balance.totalCredited + balance.carryForward - balance.used} days
                  </strong>
                  {balance.pending > 0 && (
                    <span className="text-amber-600 ml-2">({balance.pending} days pending approval)</span>
                  )}
                </p>
              )}
            </div>

            {/* Dates */}
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <Label>From Date</Label>
                <Input type="date" {...register("fromDate")} />
                {errors.fromDate && <p className="text-xs text-rose-500">{errors.fromDate.message}</p>}
              </div>
              <div className="space-y-1.5">
                <Label>To Date</Label>
                <Input
                  type="date"
                  {...register("toDate")}
                  disabled={isHalfDay}
                  min={watch("fromDate")}
                />
                {errors.toDate && <p className="text-xs text-rose-500">{errors.toDate.message}</p>}
              </div>
            </div>

            {/* Half day */}
            {selectedType?.allowHalfDay && (
              <div className="flex items-center gap-3">
                <Switch
                  id="halfDay"
                  checked={isHalfDay}
                  onCheckedChange={(v) => {
                    setValue("isHalfDay", v);
                    if (v) setValue("toDate", watch("fromDate"));
                  }}
                />
                <Label htmlFor="halfDay" className="cursor-pointer">Half Day</Label>
                {isHalfDay && (
                  <Select onValueChange={(v) => setValue("halfDaySession", v as "MORNING" | "AFTERNOON")}>
                    <SelectTrigger className="w-36">
                      <SelectValue placeholder="Session…" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="MORNING">Morning</SelectItem>
                      <SelectItem value="AFTERNOON">Afternoon</SelectItem>
                    </SelectContent>
                  </Select>
                )}
              </div>
            )}

            {/* Reason */}
            <div className="space-y-1.5">
              <Label>Reason</Label>
              <Textarea
                {...register("reason")}
                placeholder="Provide a reason for your leave…"
                rows={3}
              />
              {errors.reason && <p className="text-xs text-rose-500">{errors.reason.message}</p>}
            </div>

            {/* Document URL (if required) */}
            {selectedType?.requiresDocument && (
              <div className="space-y-1.5">
                <Label>Supporting Document URL</Label>
                <Input {...register("documentUrl")} placeholder="https://…" />
              </div>
            )}

            <div className="flex items-center justify-end gap-3 pt-2">
              <Button type="button" variant="outline" asChild>
                <Link href="/leave">Cancel</Link>
              </Button>
              <Button type="submit" disabled={isPending} style={{ background: "#1d3459" }}>
                {isPending ? "Submitting…" : "Submit Application"}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
