"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { usePersonalInfo, useUpdatePersonalInfo } from "../../hooks/useProfile";
import { Skeleton } from "@/components/ui/skeleton";
import { UserCircle, Edit3, Save, X, Eye, EyeOff, Info } from "lucide-react";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";

const personalSchema = z.object({
  birthDate: z.string().min(1, "Birth date is required"),
  birthPlace: z.string().nullable().optional(),
  homeTown: z.string().nullable().optional(),
  gender: z.enum(["MALE", "FEMALE", "OTHER"]),
  maritalStatus: z.enum(["SINGLE", "MARRIED", "DIVORCED", "WIDOWED"]),
  nationality: z.string().optional(),
  bloodGroup: z.enum(["A_POS", "A_NEG", "B_POS", "B_NEG", "O_POS", "O_NEG", "AB_POS", "AB_NEG"]).nullable().optional(),
  aadhaarNo: z.string().min(12, "Aadhaar must be 12 digits").max(12).optional(),
  panNo: z.string().min(10, "PAN must be 10 characters").max(10).optional(),
  passportNo: z.string().nullable().optional(),
});

type PersonalFormData = z.infer<typeof personalSchema>;

interface PersonalTabProps {
  employeeId: string | number;
}

function ReadOnlyField({ label, value, sensitive = false }: { label: string; value?: string | null; sensitive?: boolean }) {
  const [show, setShow] = useState(false);
  
  const displayValue = sensitive && !show 
    ? value?.replace(/.(?=.{4})/g, "•") 
    : value;

  return (
    <div className="space-y-1 p-3 rounded-lg bg-slate-50/50 border border-transparent hover:border-slate-100 transition-all group relative">
      <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{label}</p>
      <div className="flex items-center justify-between gap-2">
        <p className="text-sm font-semibold text-slate-700 truncate">{displayValue || "—"}</p>
        {sensitive && value && (
          <button 
            type="button" 
            onClick={() => setShow(!show)}
            className="text-slate-400 hover:text-[#1d3459] transition-colors"
          >
            {show ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
          </button>
        )}
      </div>
    </div>
  );
}

export function PersonalTab({ employeeId }: PersonalTabProps) {
  const [isEditing, setIsEditing] = useState(false);
  const { data: personal, isLoading } = usePersonalInfo(employeeId);
  const updateMutation = useUpdatePersonalInfo(employeeId);

  const { register, handleSubmit, setValue, watch, formState: { errors } } = useForm<PersonalFormData>({
    resolver: zodResolver(personalSchema),
    values: personal ? {
      birthDate: personal.birthDate.split('T')[0],
      birthPlace: personal.birthPlace,
      homeTown: personal.homeTown,
      gender: personal.gender,
      maritalStatus: personal.maritalStatus,
      nationality: personal.nationality || "INDIAN",
      bloodGroup: personal.bloodGroup,
      aadhaarNo: personal.aadhaarNo || "",
      panNo: personal.panNo || "",
      passportNo: personal.passportNo,
    } : undefined
  });

  const onSubmit = (data: PersonalFormData) => {
    updateMutation.mutate(data, {
      onSuccess: () => setIsEditing(false),
    });
  };

  if (isLoading) return <Skeleton className="h-[400px] w-full rounded-2xl" />;

  return (
    <Card className="border-none shadow-none bg-transparent">
      <CardHeader className="px-0 pt-0 pb-6 flex flex-row items-center justify-between space-y-0">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <UserCircle className="w-4 h-4 text-[#1d3459]" />
            <CardTitle className="text-sm font-bold text-slate-800 uppercase tracking-tight">
              Personal Profile
            </CardTitle>
          </div>
          <p className="text-[11px] text-slate-500 font-medium">
            Manage your personal data and identification documents.
          </p>
        </div>
        {!isEditing ? (
          <Button 
            onClick={() => setIsEditing(true)}
            size="sm" 
            variant="outline" 
            className="h-8 border-[#1d3459]/20 text-[#1d3459] hover:bg-[#1d3459] hover:text-white transition-all gap-2 px-4 rounded-xl font-bold text-[10px] uppercase"
          >
            <Edit3 className="w-3 h-3" /> Edit Profile
          </Button>
        ) : (
          <div className="flex gap-2">
            <Button 
              onClick={() => setIsEditing(false)}
              size="sm" 
              variant="ghost" 
              className="h-8 text-slate-500 font-bold text-[10px] uppercase"
            >
              <X className="w-3 h-3 mr-1" /> Discard
            </Button>
            <Button 
              onClick={handleSubmit(onSubmit)}
              disabled={updateMutation.isPending}
              size="sm" 
              className="h-8 bg-[#d9b557] hover:bg-[#c9a547] text-[#1d3459] font-bold text-[10px] uppercase gap-2 px-4 rounded-xl shadow-lg shadow-[#d9b557]/20"
            >
              {updateMutation.isPending ? <Save className="w-3 h-3 animate-pulse" /> : <Save className="w-3 h-3" />}
              Save Changes
            </Button>
          </div>
        )}
      </CardHeader>
      <CardContent className="px-0">
        {updateMutation.isSuccess && !isEditing && (
          <div className="mb-6 p-3 bg-emerald-50 border border-emerald-100 rounded-xl flex items-center gap-3 text-emerald-700 text-xs font-semibold animate-in fade-in slide-in-from-top-2">
            <Badge className="bg-emerald-500 border-none">Success</Badge>
            Your personal information has been updated and a change request was logged.
          </div>
        )}

        <div className="bg-white/50 border border-slate-100 rounded-2xl p-6 shadow-sm">
          {!isEditing ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <ReadOnlyField label="Date of Birth" value={personal?.birthDate ? new Date(personal.birthDate).toLocaleDateString("en-IN", { day: '2-digit', month: 'short', year: 'numeric' }) : null} />
              <ReadOnlyField label="Place of Birth" value={personal?.birthPlace} />
              <ReadOnlyField label="Home Town" value={personal?.homeTown} />
              <ReadOnlyField label="Gender" value={personal?.gender} />
              <ReadOnlyField label="Marital Status" value={personal?.maritalStatus} />
              <ReadOnlyField label="Nationality" value={personal?.nationality} />
              <ReadOnlyField label="Blood Group" value={personal?.bloodGroup?.replace("_", " ")} />
              <ReadOnlyField label="Aadhaar Card" value={personal?.aadhaarNo} sensitive />
              <ReadOnlyField label="PAN Card" value={personal?.panNo} sensitive />
              <ReadOnlyField label="Passport No" value={personal?.passportNo} />
            </div>
          ) : (
            <form className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
              <div className="space-y-1.5">
                <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">DOB *</Label>
                <Input type="date" {...register("birthDate")} className="h-10 border-slate-200 focus:ring-[#1d3459] rounded-xl text-sm" />
                {errors.birthDate && <p className="text-[10px] text-rose-500 mt-1 font-medium">{errors.birthDate.message}</p>}
              </div>

              <div className="space-y-1.5">
                <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Birth Place</Label>
                <Input {...register("birthPlace")} className="h-10 border-slate-200 focus:ring-[#1d3459] rounded-xl text-sm" placeholder="City, State" />
              </div>

              <div className="space-y-1.5">
                <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Home Town</Label>
                <Input {...register("homeTown")} className="h-10 border-slate-200 focus:ring-[#1d3459] rounded-xl text-sm" placeholder="Origin City" />
              </div>

              <div className="space-y-1.5">
                <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Gender *</Label>
                <Select onValueChange={(v) => setValue("gender", v as any)} defaultValue={watch("gender")}>
                  <SelectTrigger className="h-10 border-slate-200 rounded-xl text-sm">
                    <SelectValue placeholder="Select..." />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="MALE">Male</SelectItem>
                    <SelectItem value="FEMALE">Female</SelectItem>
                    <SelectItem value="OTHER">Other</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1.5">
                <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Marital Status *</Label>
                <Select onValueChange={(v) => setValue("maritalStatus", v as any)} defaultValue={watch("maritalStatus")}>
                  <SelectTrigger className="h-10 border-slate-200 rounded-xl text-sm">
                    <SelectValue placeholder="Select..." />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="SINGLE">Single</SelectItem>
                    <SelectItem value="MARRIED">Married</SelectItem>
                    <SelectItem value="DIVORCED">Divorced</SelectItem>
                    <SelectItem value="WIDOWED">Widowed</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1.5">
                <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Blood Group</Label>
                <Select onValueChange={(v) => setValue("bloodGroup", v as any)} defaultValue={watch("bloodGroup") || ""}>
                  <SelectTrigger className="h-10 border-slate-200 rounded-xl text-sm">
                    <SelectValue placeholder="Select..." />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="A_POS">A+</SelectItem>
                    <SelectItem value="A_NEG">A-</SelectItem>
                    <SelectItem value="B_POS">B+</SelectItem>
                    <SelectItem value="B_NEG">B-</SelectItem>
                    <SelectItem value="O_POS">O+</SelectItem>
                    <SelectItem value="O_NEG">O-</SelectItem>
                    <SelectItem value="AB_POS">AB+</SelectItem>
                    <SelectItem value="AB_NEG">AB-</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1.5">
                <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Aadhaar No</Label>
                <div className="relative">
                  <Input {...register("aadhaarNo")} maxLength={12} className="h-10 border-slate-200 focus:ring-[#1d3459] rounded-xl text-sm pr-10" />
                  <Info className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-300" />
                </div>
                {errors.aadhaarNo && <p className="text-[10px] text-rose-500 mt-1 font-medium">{errors.aadhaarNo.message}</p>}
              </div>

              <div className="space-y-1.5">
                <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">PAN Card No</Label>
                <Input {...register("panNo")} maxLength={10} className="h-10 border-slate-200 focus:ring-[#1d3459] rounded-xl text-sm uppercase" />
                {errors.panNo && <p className="text-[10px] text-rose-500 mt-1 font-medium">{errors.panNo.message}</p>}
              </div>

              <div className="space-y-1.5">
                <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Passport No</Label>
                <Input {...register("passportNo")} className="h-10 border-slate-200 focus:ring-[#1d3459] rounded-xl text-sm uppercase" />
              </div>
            </form>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
