"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { otherInfoSchema, type OtherInfoFormData } from "@/lib/validators/otherInfo.schema";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import api from "@/lib/axios";

interface OtherTabProps {
  employeeId: string;
  initialData?: Record<string, unknown>;
  isAdmin?: boolean;
}

function Field({ label, value }: { label: string; value?: string | boolean | null }) {
  const display =
    typeof value === "boolean" ? (value ? "Yes" : "No") : value;
  return (
    <div>
      <p className="text-xs text-slate-500 mb-0.5">{label}</p>
      <p className="text-sm font-medium text-slate-800">{display || "—"}</p>
    </div>
  );
}

export function OtherTab({ employeeId, initialData, isAdmin }: OtherTabProps) {
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [data, setData] = useState<Record<string, unknown> | null>(initialData ?? null);

  const { register, handleSubmit, setValue, formState: { errors } } = useForm<OtherInfoFormData>({
    resolver: zodResolver(otherInfoSchema),
    defaultValues: {
      bank: {
        bankName: (data?.bankName as string) ?? "",
        accountNo: (data?.accountNo as string) ?? "",
        ifscCode: (data?.ifscCode as string) ?? "",
        accountType: (data?.accountType as OtherInfoFormData["bank"]["accountType"]) ?? undefined,
        branchName: (data?.branchName as string) ?? "",
      },
      physicallyHandicapped: (data?.physicallyHandicapped as boolean) ?? false,
      exServiceman: (data?.exServiceman as boolean) ?? false,
      handicapPercentage: (data?.handicapPercentage as number) ?? undefined,
      passportNo: (data?.passportNo as string) ?? "",
      passportExpiry: (data?.passportExpiry as string)?.slice(0, 10) ?? "",
      drivingLicenceNo: (data?.drivingLicenceNo as string) ?? "",
      drivingLicenceExpiry: (data?.drivingLicenceExpiry as string)?.slice(0, 10) ?? "",
      voterId: (data?.voterId as string) ?? "",
    },
  });

  const onSubmit = async (formData: OtherInfoFormData) => {
    setSaving(true);
    try {
      const res = await api.put(`/personal-education/employees/${employeeId}/other`, formData);
      setData(res.data.data);
      setEditing(false);
    } finally {
      setSaving(false);
    }
  };

  if (!editing) {
    return (
      <Card>
        <CardContent className="pt-5 space-y-5">
          <div className="flex justify-between items-center">
            <h3 className="text-sm font-semibold text-slate-700">Other Information</h3>
            {isAdmin && (
              <Button
                size="sm"
                variant="outline"
                onClick={() => setEditing(true)}
                className="text-xs border-[#1d3459] text-[#1d3459] hover:bg-[#1d3459] hover:text-white"
              >
                Edit
              </Button>
            )}
          </div>

          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">Bank Details</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
              <Field label="Bank Name" value={data?.bankName as string} />
              <Field label="Account No" value={data?.accountNo as string} />
              <Field label="IFSC Code" value={data?.ifscCode as string} />
              <Field label="Account Type" value={data?.accountType as string} />
              <Field label="Branch Name" value={data?.branchName as string} />
            </div>
          </div>

          <Separator />

          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">Identity & Status</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
              <Field label="Physically Handicapped" value={data?.physicallyHandicapped as boolean} />
              <Field label="Handicap %" value={data?.handicapPercentage as string} />
              <Field label="Ex-Serviceman" value={data?.exServiceman as boolean} />
              <Field label="Passport No" value={data?.passportNo as string} />
              <Field label="Passport Expiry" value={data?.passportExpiry ? new Date(data.passportExpiry as string).toLocaleDateString("en-IN") : undefined} />
              <Field label="Driving Licence No" value={data?.drivingLicenceNo as string} />
              <Field label="Driving Licence Expiry" value={data?.drivingLicenceExpiry ? new Date(data.drivingLicenceExpiry as string).toLocaleDateString("en-IN") : undefined} />
              <Field label="Voter ID" value={data?.voterId as string} />
            </div>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardContent className="pt-5">
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          <div className="flex justify-between items-center">
            <h3 className="text-sm font-semibold text-slate-700">Edit Other Information</h3>
            <div className="flex gap-2">
              <Button type="button" size="sm" variant="ghost" onClick={() => setEditing(false)}>Cancel</Button>
              <Button
                type="submit"
                size="sm"
                disabled={saving}
                style={{ backgroundColor: "#1d3459" }}
                className="text-white hover:opacity-90"
              >
                {saving ? "Saving…" : "Save"}
              </Button>
            </div>
          </div>

          {/* Bank Details */}
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">Bank Details</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="space-y-1">
                <Label>Bank Name</Label>
                <Input {...register("bank.bankName")} />
              </div>
              <div className="space-y-1">
                <Label>Account No</Label>
                <Input {...register("bank.accountNo")} />
              </div>
              <div className="space-y-1">
                <Label>IFSC Code</Label>
                <Input {...register("bank.ifscCode")} className="uppercase" placeholder="SBIN0001234" />
                {errors.bank?.ifscCode && <p className="text-xs text-rose-500">{errors.bank.ifscCode.message}</p>}
              </div>
              <div className="space-y-1">
                <Label>Account Type</Label>
                <Select
                  defaultValue={(data?.accountType as string) ?? ""}
                  onValueChange={(v) => setValue("bank.accountType", v as OtherInfoFormData["bank"]["accountType"])}
                >
                  <SelectTrigger><SelectValue placeholder="Select…" /></SelectTrigger>
                  <SelectContent>
                    {["SAVINGS", "CURRENT", "SALARY"].map((t) => (
                      <SelectItem key={t} value={t}>{t}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <Label>Branch Name</Label>
                <Input {...register("bank.branchName")} />
              </div>
            </div>
          </div>

          <Separator />

          {/* Identity */}
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">Identity & Status</p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="flex items-center gap-2">
                <input type="checkbox" id="ph" {...register("physicallyHandicapped")} />
                <Label htmlFor="ph">Physically Handicapped</Label>
              </div>
              <div className="flex items-center gap-2">
                <input type="checkbox" id="ex" {...register("exServiceman")} />
                <Label htmlFor="ex">Ex-Serviceman</Label>
              </div>
              <div className="space-y-1">
                <Label>Handicap Percentage</Label>
                <Input type="number" {...register("handicapPercentage")} min={0} max={100} />
              </div>
              <div className="space-y-1">
                <Label>Passport No</Label>
                <Input {...register("passportNo")} />
              </div>
              <div className="space-y-1">
                <Label>Passport Expiry</Label>
                <Input type="date" {...register("passportExpiry")} />
              </div>
              <div className="space-y-1">
                <Label>Driving Licence No</Label>
                <Input {...register("drivingLicenceNo")} />
              </div>
              <div className="space-y-1">
                <Label>Driving Licence Expiry</Label>
                <Input type="date" {...register("drivingLicenceExpiry")} />
              </div>
              <div className="space-y-1">
                <Label>Voter ID</Label>
                <Input {...register("voterId")} />
              </div>
            </div>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
