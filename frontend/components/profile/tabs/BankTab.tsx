"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import api from "@/lib/axios";

const bankSchema = z.object({
  bankName: z.string().optional(),
  bankAccountNo: z.string().optional(),
  bankBranchCode: z.string().optional(),
  ifscCode: z.string().optional(),
});

type BankFormData = z.infer<typeof bankSchema>;

interface BankTabProps {
  employee: Record<string, unknown>;
  isAdmin?: boolean;
  allowEdit?: boolean;
  onUpdate?: () => void;
}

function Field({ label, value }: { label: string; value?: string | number | null }) {
  return (
    <div>
      <p className="text-xs text-slate-500 mb-0.5">{label}</p>
      <p className="text-sm font-medium text-slate-800">{value || "—"}</p>
    </div>
  );
}

export function BankTab({ employee, isAdmin, allowEdit, onUpdate }: BankTabProps) {
  const canEdit = Boolean(isAdmin || allowEdit);
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);

  const { register, handleSubmit } = useForm<BankFormData>({
    resolver: zodResolver(bankSchema),
    defaultValues: {
      bankName: (employee.bankName as string) ?? "",
      bankAccountNo: (employee.bankAccountNo as string) ?? "",
      bankBranchCode: (employee.bankBranchCode as string) ?? "",
      ifscCode: (employee.ifscCode as string) ?? "",
    },
  });

  const onSubmit = async (data: BankFormData) => {
    setSaving(true);
    try {
      await api.patch(`employees/${employee.id}/bank`, {
        bankName: data.bankName || null,
        bankAccountNo: data.bankAccountNo || null,
        bankBranchCode: data.bankBranchCode || null,
        ifscCode: data.ifscCode || null,
      });
      toast.success("Bank details saved");
      setEditing(false);
      onUpdate?.();
    } catch (err: any) {
      toast.error(err.response?.data?.message ?? "Failed to save bank details");
    } finally {
      setSaving(false);
    }
  };

  if (!editing) {
    return (
      <Card>
        <CardContent className="pt-5 space-y-5">
          <div className="flex justify-between items-center">
            <h3 className="text-sm font-semibold text-slate-700">Bank Information</h3>
            {canEdit && (
              <Button size="sm" variant="outline" onClick={() => setEditing(true)} className="text-xs border-[#1d3459] text-[#1d3459] hover:bg-[#1d3459] hover:text-white">
                Edit
              </Button>
            )}
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 bg-white/30 backdrop-blur-md p-4 rounded-xl border border-white/50 shadow-sm">
            <Field label="Bank Name" value={employee.bankName as string} />
            <Field label="Bank Branch Code" value={employee.bankBranchCode as string} />
            <Field label="Bank A/C No" value={employee.bankAccountNo as string} />
            <Field label="IFSC Code" value={employee.ifscCode as string} />
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardContent className="pt-5">
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
          <div className="flex justify-between items-center mb-4">
            <h3 className="text-sm font-semibold text-slate-700">Edit Bank Information</h3>
            <div className="flex gap-2">
              <Button type="button" size="sm" variant="ghost" onClick={() => setEditing(false)}>Cancel</Button>
              <Button type="submit" size="sm" disabled={saving} style={{ backgroundColor: "#1d3459" }} className="text-white hover:opacity-90">
                {saving ? "Saving…" : "Save"}
              </Button>
            </div>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 bg-white/40 backdrop-blur-lg p-5 rounded-2xl border border-white/40 shadow">
            <div className="space-y-1">
              <Label>Bank Name</Label>
              <Input {...register("bankName")} className="bg-white/50" />
            </div>
            <div className="space-y-1">
              <Label>Bank Branch Code</Label>
              <Input {...register("bankBranchCode")} className="bg-white/50" />
            </div>
            <div className="space-y-1">
              <Label>Bank A/C No</Label>
              <Input {...register("bankAccountNo")} className="bg-white/50" />
            </div>
            <div className="space-y-1">
              <Label>IFSC Code</Label>
              <Input {...register("ifscCode")} className="bg-white/50 uppercase" />
            </div>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
