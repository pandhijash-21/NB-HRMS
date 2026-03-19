"use client";

import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { personalInfoSchema, type PersonalInfoFormData } from "@/lib/validators/personalInfo.schema";
import { usePersonalInfo } from "@/lib/hooks/usePersonalInfo";
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
import { MaskedInput } from "@/components/shared/MaskedInput";
import { Skeleton } from "@/components/ui/skeleton";

interface PersonalTabProps {
  employeeId: string;
  isAdmin?: boolean;
}

function Field({ label, value }: { label: string; value?: string | null }) {
  return (
    <div>
      <p className="text-xs text-slate-500 mb-0.5">{label}</p>
      <p className="text-sm font-medium text-slate-800">{value || "—"}</p>
    </div>
  );
}

const BLOOD_GROUPS = ["A_POS", "A_NEG", "B_POS", "B_NEG", "O_POS", "O_NEG", "AB_POS", "AB_NEG"];
const BLOOD_DISPLAY: Record<string, string> = {
  A_POS: "A+", A_NEG: "A−", B_POS: "B+", B_NEG: "B−",
  O_POS: "O+", O_NEG: "O−", AB_POS: "AB+", AB_NEG: "AB−",
};

export function PersonalTab({ employeeId, isAdmin }: PersonalTabProps) {
  const [editing, setEditing] = useState(false);
  const { getPersonalInfo, savePersonalInfo, loading } = usePersonalInfo(employeeId);
  const [info, setInfo] = useState<Record<string, unknown> | null>(null);
  const [fetching, setFetching] = useState(true);

  useEffect(() => {
    getPersonalInfo().then((d) => {
      setInfo(d);
      setFetching(false);
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [employeeId]);

  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors },
  } = useForm<PersonalInfoFormData>({
    resolver: zodResolver(personalInfoSchema),
    defaultValues: {},
    values: info
      ? {
          fatherName: (info.fatherName as string) ?? "",
          motherName: (info.motherName as string) ?? "",
          spouseName: (info.spouseName as string) ?? "",
          dateOfBirth: (info.dateOfBirth as string)?.slice(0, 10) ?? "",
          gender: (info.gender as PersonalInfoFormData["gender"]) ?? "MALE",
          category: (info.category as PersonalInfoFormData["category"]) ?? undefined,
          religion: (info.religion as string) ?? "",
          maritalStatus: (info.maritalStatus as PersonalInfoFormData["maritalStatus"]) ?? undefined,
          nationality: (info.nationality as string) ?? "Indian",
          bloodGroup: (info.bloodGroup as PersonalInfoFormData["bloodGroup"]) ?? undefined,
          aadhaarNo: "",
          panNo: "",
          pfNo: (info.pfNo as string) ?? "",
          uanNo: (info.uanNo as string) ?? "",
          emergencyContactName: (info.emergencyContactName as string) ?? "",
          emergencyContactPhone: (info.emergencyContactPhone as string) ?? "",
        }
      : undefined,
  });

  const onSubmit = async (data: PersonalInfoFormData) => {
    await savePersonalInfo(data);
    setEditing(false);
    const fresh = await getPersonalInfo();
    setInfo(fresh);
  };

  if (fetching) {
    return (
      <Card>
        <CardContent className="pt-5 space-y-3">
          {Array.from({ length: 6 }).map((_, i) => <Skeleton key={i} className="h-10 w-full" />)}
        </CardContent>
      </Card>
    );
  }

  if (!editing) {
    return (
      <Card>
        <CardContent className="pt-5 space-y-5">
          <div className="flex justify-between items-center">
            <h3 className="text-sm font-semibold text-slate-700">Personal Information</h3>
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

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
            <Field label="Date of Birth" value={info?.dateOfBirth ? new Date(info.dateOfBirth as string).toLocaleDateString("en-IN") : undefined} />
            <Field label="Gender" value={info?.gender as string} />
            <Field label="Blood Group" value={info?.bloodGroup ? BLOOD_DISPLAY[info.bloodGroup as string] : undefined} />
            <Field label="Category" value={info?.category as string} />
            <Field label="Marital Status" value={info?.maritalStatus as string} />
            <Field label="Religion" value={info?.religion as string} />
            <Field label="Nationality" value={info?.nationality as string} />
            <Field label="Father's Name" value={info?.fatherName as string} />
            <Field label="Mother's Name" value={info?.motherName as string} />
            <Field label="Spouse Name" value={info?.spouseName as string} />
            <div>
              <p className="text-xs text-slate-500 mb-0.5">Aadhaar No</p>
              <MaskedInput maskedValue={(info?.aadhaarNoMasked as string) ?? "••••••••••••"} />
            </div>
            <div>
              <p className="text-xs text-slate-500 mb-0.5">PAN No</p>
              <MaskedInput maskedValue={(info?.panNoMasked as string) ?? "••••••••••"} />
            </div>
            <Field label="PF No" value={info?.pfNo as string} />
            <Field label="UAN No" value={info?.uanNo as string} />
            <Field label="Emergency Contact" value={info?.emergencyContactName as string} />
            <Field label="Emergency Phone" value={info?.emergencyContactPhone as string} />
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardContent className="pt-5">
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
          <div className="flex justify-between items-center">
            <h3 className="text-sm font-semibold text-slate-700">Edit Personal Information</h3>
            <div className="flex gap-2">
              <Button type="button" size="sm" variant="ghost" onClick={() => setEditing(false)}>Cancel</Button>
              <Button
                type="submit"
                size="sm"
                disabled={loading}
                style={{ backgroundColor: "#1d3459" }}
                className="text-white hover:opacity-90"
              >
                {loading ? "Saving…" : "Save"}
              </Button>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <div className="space-y-1">
              <Label>Date of Birth *</Label>
              <Input type="date" {...register("dateOfBirth")} />
              {errors.dateOfBirth && <p className="text-xs text-rose-500">{errors.dateOfBirth.message}</p>}
            </div>

            <div className="space-y-1">
              <Label>Gender *</Label>
              <Select
                defaultValue={(info?.gender as string) ?? "MALE"}
                onValueChange={(v) => setValue("gender", v as PersonalInfoFormData["gender"])}
              >
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {["MALE", "FEMALE", "OTHER"].map((g) => (
                    <SelectItem key={g} value={g}>{g}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1">
              <Label>Blood Group</Label>
              <Select
                defaultValue={(info?.bloodGroup as string) ?? ""}
                onValueChange={(v) => setValue("bloodGroup", v as PersonalInfoFormData["bloodGroup"])}
              >
                <SelectTrigger><SelectValue placeholder="Select…" /></SelectTrigger>
                <SelectContent>
                  {BLOOD_GROUPS.map((bg) => (
                    <SelectItem key={bg} value={bg}>{BLOOD_DISPLAY[bg]}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1">
              <Label>Category</Label>
              <Select
                defaultValue={(info?.category as string) ?? ""}
                onValueChange={(v) => setValue("category", v as PersonalInfoFormData["category"])}
              >
                <SelectTrigger><SelectValue placeholder="Select…" /></SelectTrigger>
                <SelectContent>
                  {["GENERAL", "OBC", "SC", "ST", "EWS"].map((c) => (
                    <SelectItem key={c} value={c}>{c}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1">
              <Label>Marital Status</Label>
              <Select
                defaultValue={(info?.maritalStatus as string) ?? ""}
                onValueChange={(v) => setValue("maritalStatus", v as PersonalInfoFormData["maritalStatus"])}
              >
                <SelectTrigger><SelectValue placeholder="Select…" /></SelectTrigger>
                <SelectContent>
                  {["SINGLE", "MARRIED", "DIVORCED", "WIDOWED"].map((m) => (
                    <SelectItem key={m} value={m}>{m}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1">
              <Label>Religion</Label>
              <Input {...register("religion")} />
            </div>
            <div className="space-y-1">
              <Label>Nationality</Label>
              <Input {...register("nationality")} />
            </div>
            <div className="space-y-1">
              <Label>Father&apos;s Name</Label>
              <Input {...register("fatherName")} />
            </div>
            <div className="space-y-1">
              <Label>Mother&apos;s Name</Label>
              <Input {...register("motherName")} />
            </div>
            <div className="space-y-1">
              <Label>Spouse Name</Label>
              <Input {...register("spouseName")} />
            </div>

            <div className="space-y-1">
              <Label>Aadhaar No <span className="text-xs text-slate-400">(sensitive)</span></Label>
              <MaskedInput
                isEditing
                {...register("aadhaarNo")}
                placeholder="12-digit Aadhaar number"
                maxLength={12}
              />
              {errors.aadhaarNo && <p className="text-xs text-rose-500">{errors.aadhaarNo.message}</p>}
            </div>

            <div className="space-y-1">
              <Label>PAN No <span className="text-xs text-slate-400">(sensitive)</span></Label>
              <MaskedInput
                isEditing
                {...register("panNo")}
                placeholder="ABCDE1234F"
                className="uppercase"
                maxLength={10}
              />
              {errors.panNo && <p className="text-xs text-rose-500">{errors.panNo.message}</p>}
            </div>

            <div className="space-y-1">
              <Label>PF No</Label>
              <Input {...register("pfNo")} />
            </div>
            <div className="space-y-1">
              <Label>UAN No</Label>
              <Input {...register("uanNo")} />
            </div>
            <div className="space-y-1">
              <Label>Emergency Contact Name</Label>
              <Input {...register("emergencyContactName")} />
            </div>
            <div className="space-y-1">
              <Label>Emergency Contact Phone</Label>
              <Input {...register("emergencyContactPhone")} type="tel" />
            </div>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
