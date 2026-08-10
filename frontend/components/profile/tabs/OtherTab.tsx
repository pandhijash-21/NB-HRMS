"use client";

import { useState, useEffect, useRef } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useMutation } from "@apollo/client/react";
import { UPDATE_EMPLOYEE_OTHER, UPDATE_EMPLOYEE_PERSONAL } from "@/lib/graphql";
import { useUpload } from "@/lib/hooks/useUpload";
import { toast } from "sonner";
import { FileText, Upload, Camera, ExternalLink, AlertCircle, CheckCircle2 } from "lucide-react";

const otherInfoSchema = z.object({
  skillSet: z.string().optional(),
  strength: z.string().optional(),
  weakness: z.string().optional(),
  isHandicapped: z.boolean().optional(),
  hobbies: z.string().optional(),
  panNo: z.string()
    .min(1, "PAN Number is required")
    .regex(/^[A-Z]{5}[0-9]{4}[A-Z]$/, "Invalid PAN format (e.g., ABCDE1234F)"),
  aadhaarNo: z.string()
    .min(1, "Aadhaar Number is required")
    .regex(/^\d{12}$/, "Aadhaar must be 12 digits"),
  heightInCm: z.coerce.number().min(1, "Height is required"),
  weightInKg: z.coerce.number().min(1, "Weight is required"),
  aadhaarUrl: z.string().optional(),
  panUrl: z.string().optional(),
  passportUrl: z.string().optional(),
});

type OtherFormData = z.infer<typeof otherInfoSchema>;

interface OtherTabProps {
  employee: Record<string, unknown>;
  employeeId: string;
  isAdmin?: boolean;
  onUpdate?: () => void;
}

function Field({ label, value }: { label: string; value?: string | number | boolean | null }) {
  const display = typeof value === "boolean" ? (value ? "Yes" : "No") : value;
  return (
    <div>
      <p className="text-xs text-slate-500 mb-0.5">{label}</p>
      <p className="text-sm font-medium text-slate-800">{display || "—"}</p>
    </div>
  );
}

function FileUploadBox({
  label,
  currentUrl,
  accept,
  onUpload,
  uploading,
  icon: Icon,
  required,
}: {
  label: string;
  currentUrl?: string | null;
  accept: string;
  onUpload: (file: File) => void;
  uploading?: boolean;
  icon: React.ElementType;
  required?: boolean;
}) {
  const inputRef = useRef<HTMLInputElement>(null);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      onUpload(file);
    }
  };

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-1">
        <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider">
          {label}
        </Label>
        {required && <span className="text-rose-500 text-xs">*</span>}
      </div>
      <input
        ref={inputRef}
        type="file"
        accept={accept}
        onChange={handleFileChange}
        className="hidden"
      />
      {currentUrl ? (
        <div className="relative group">
          {currentUrl.match(/\.(pdf)$/i) ? (
            <div className="h-24 bg-slate-100 rounded-xl border border-slate-200 flex items-center justify-center gap-2">
              <FileText className="w-8 h-8 text-slate-400" />
              <div className="text-center">
                <span className="text-xs text-slate-500 block">PDF Uploaded</span>
                <a
                  href={currentUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-xs text-[#1d3459] hover:underline flex items-center gap-1 justify-center"
                >
                  View <ExternalLink className="w-3 h-3" />
                </a>
              </div>
            </div>
          ) : (
            <img
              src={currentUrl}
              alt={label}
              className="w-full h-24 object-contain rounded-xl border border-slate-200 bg-white p-2"
            />
          )}
          <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity rounded-xl flex items-center justify-center">
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={() => inputRef.current?.click()}
              className="text-white hover:text-white hover:bg-white/20"
            >
              Change
            </Button>
          </div>
          {uploading && (
            <div className="absolute inset-0 bg-black/50 rounded-xl flex items-center justify-center">
              <div className="animate-spin w-6 h-6 border-2 border-white border-t-transparent rounded-full" />
            </div>
          )}
        </div>
      ) : (
        <button
          type="button"
          onClick={() => inputRef.current?.click()}
          disabled={uploading}
          className="w-full h-24 border-2 border-dashed border-slate-200 rounded-xl flex flex-col items-center justify-center gap-2 hover:border-[#1d3459]/30 hover:bg-slate-50/50 transition-all disabled:opacity-50"
        >
          <Icon className="w-6 h-6 text-slate-300" />
          <span className="text-xs text-slate-400 font-medium">
            {uploading ? "Uploading..." : "Click to upload"}
          </span>
        </button>
      )}
    </div>
  );
}

function BmiIndicator({ bmi }: { bmi: number | null }) {
  if (bmi === null || isNaN(bmi)) return null;

  let category = "";
  let colorClass = "";
  if (bmi < 18.5) {
    category = "Underweight";
    colorClass = "text-blue-600 bg-blue-50 border-blue-200";
  } else if (bmi < 25) {
    category = "Normal";
    colorClass = "text-emerald-600 bg-emerald-50 border-emerald-200";
  } else if (bmi < 30) {
    category = "Overweight";
    colorClass = "text-amber-600 bg-amber-50 border-amber-200";
  } else {
    category = "Obese";
    colorClass = "text-rose-600 bg-rose-50 border-rose-200";
  }

  return (
    <div className={`px-3 py-1.5 rounded-lg border text-xs font-bold ${colorClass}`}>
      BMI: {bmi.toFixed(1)} ({category})
    </div>
  );
}

export function OtherTab({ employee, employeeId, isAdmin, onUpdate }: OtherTabProps) {
  const [editing, setEditing] = useState(false);
  const [aadhaarUploading, setAadhaarUploading] = useState(false);
  const [panUploading, setPanUploading] = useState(false);
  const [passportUploading, setPassportUploading] = useState(false);
  
  const [mutateOther] = useMutation(UPDATE_EMPLOYEE_OTHER);
  const [mutatePersonal] = useMutation(UPDATE_EMPLOYEE_PERSONAL);
  const [saving, setSaving] = useState(false);

  const { upload } = useUpload(employeeId);

  const { register, handleSubmit, setValue, watch, formState: { errors } } = useForm<OtherFormData>({
    resolver: zodResolver(otherInfoSchema) as any,
    defaultValues: {
      skillSet: (employee.skillSet as string) ?? "",
      strength: (employee.strength as string) ?? "",
      weakness: (employee.weakness as string) ?? "",
      isHandicapped: (employee.isHandicapped as boolean) ?? false,
      hobbies: (employee.hobbies as string) ?? "",
      panNo: (employee.panNo as string) ?? "",
      aadhaarNo: (employee.aadhaarNo as string) ?? "",
      heightInCm: (employee.heightInCm as number) ?? undefined,
      weightInKg: (employee.weightInKg as number) ?? undefined,
      aadhaarUrl: (employee.aadhaarUrl as string) ?? "",
      panUrl: (employee.panUrl as string) ?? "",
      passportUrl: (employee.passportUrl as string) ?? "",
    },
  });

  const heightInCm = watch("heightInCm");
  const weightInKg = watch("weightInKg");
  const aadhaarUrl = watch("aadhaarUrl");
  const panUrl = watch("panUrl");
  const passportUrl = watch("passportUrl");

  const bmi = heightInCm && weightInKg
    ? weightInKg / Math.pow(heightInCm / 100, 2)
    : null;

  const handleAadhaarUpload = async (file: File) => {
    setAadhaarUploading(true);
    try {
      const url = await upload("aadhaarCard", file);
      setValue("aadhaarUrl", url);
      toast.success("Aadhaar card uploaded successfully");
    } catch {
      toast.error("Failed to upload Aadhaar card");
    } finally {
      setAadhaarUploading(false);
    }
  };

  const handlePanUpload = async (file: File) => {
    setPanUploading(true);
    try {
      const url = await upload("panCard", file);
      setValue("panUrl", url);
      toast.success("PAN card uploaded successfully");
    } catch {
      toast.error("Failed to upload PAN card");
    } finally {
      setPanUploading(false);
    }
  };

  const handlePassportUpload = async (file: File) => {
    setPassportUploading(true);
    try {
      const url = await upload("passport", file);
      setValue("passportUrl", url);
      toast.success("Passport uploaded successfully");
    } catch {
      toast.error("Failed to upload Passport");
    } finally {
      setPassportUploading(false);
    }
  };

  const onSubmit = async (data: any) => {
    setSaving(true);
    try {
      await mutateOther({
        variables: {
          employeeId: employee.id,
          set: {
            skill_set: data.skillSet,
            strength: data.strength,
            weakness: data.weakness,
            is_handicapped: data.isHandicapped,
            hobbies: data.hobbies,
            height_in_cm: data.heightInCm,
            weight_in_kg: data.weightInKg,
            aadhaar_url: data.aadhaarUrl || null,
            pan_url: data.panUrl || null,
            passport_url: data.passportUrl || null,
          },
        },
      });

      await mutatePersonal({
         variables: {
            employeeId: employee.id,
            set: {
               pan_no: data.panNo,
               aadhaar_no: data.aadhaarNo,
            }
         }
      })
      setEditing(false);
      onUpdate?.();
      toast.success("Other information updated successfully");
    } catch {
      toast.error("Failed to update other information");
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
            <Button size="sm" variant="outline" onClick={() => setEditing(true)} className="text-xs border-[#1d3459] text-[#1d3459] hover:bg-[#1d3459] hover:text-white">
              Edit
            </Button>
          </div>
          
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <div className="lg:col-span-2">
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5 bg-white/30 backdrop-blur-md p-4 rounded-xl border border-white/50 shadow-sm">
                <Field label="Skill Set" value={employee.skillSet as string} />
                <div className="hidden lg:block"></div><div className="hidden lg:block"></div>

                <Field label="Strength" value={employee.strength as string} />
                <div className="hidden lg:block"></div><div className="hidden lg:block"></div>

                <Field label="Weakness" value={employee.weakness as string} />
                <div className="hidden lg:block"></div><div className="hidden lg:block"></div>

                <Field label="Is Handicapped?" value={employee.isHandicapped as boolean} />
                <div className="hidden lg:block"></div><div className="hidden lg:block"></div>

                <Field label="Hobbies" value={employee.hobbies as string} />
                <div className="hidden lg:block"></div><div className="hidden lg:block"></div>

                <div className="sm:col-span-1">
                  <Field label="PAN No" value={employee.panNo as string} />
                  {!!employee.panNo && (
                    <p className="text-[10px] text-emerald-600 font-medium flex items-center gap-1 mt-1">
                      <CheckCircle2 className="w-3 h-3" /> Verified
                    </p>
                  )}
                </div>
                
                <div className="sm:col-span-1">
                  <Field label="Aadhaar No" value={employee.aadhaarNo ? `XXXX XXXX ${(employee.aadhaarNo as string).slice(-4)}` : undefined} />
                  {!!employee.aadhaarNo && (
                    <p className="text-[10px] text-emerald-600 font-medium flex items-center gap-1 mt-1">
                      <CheckCircle2 className="w-3 h-3" /> Verified
                    </p>
                  )}
                </div>
                
                <div className="hidden lg:block"></div>

                <div className="sm:col-span-1">
                  <Field label="Height (cm)" value={employee.heightInCm ? `${employee.heightInCm} cm` : undefined} />
                </div>
                
                <div className="sm:col-span-1">
                  <Field label="Weight (kg)" value={employee.weightInKg ? `${employee.weightInKg} kg` : undefined} />
                </div>
                
                <div className="sm:col-span-1 flex items-end">
                  {bmi !== null && <BmiIndicator bmi={bmi} />}
                </div>
              </div>
            </div>

            <div className="space-y-4">
              <div className="space-y-2">
                <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                  Aadhaar Card <span className="text-rose-500">*</span>
                </Label>
                {employee.aadhaarUrl ? (
                  <div className="relative group">
                    {String(employee.aadhaarUrl).match(/\.(pdf)$/i) ? (
                      <div className="h-20 bg-slate-100 rounded-xl border border-slate-200 flex items-center justify-center gap-2">
                        <FileText className="w-6 h-6 text-slate-400" />
                        <span className="text-xs text-slate-500">PDF</span>
                      </div>
                    ) : (
                      <img
                        src={employee.aadhaarUrl as string}
                        alt="Aadhaar"
                        className="w-full h-20 object-contain rounded-xl border border-slate-200 bg-white p-1"
                      />
                    )}
                  </div>
                ) : (
                  <div className="w-full h-20 border-2 border-dashed border-slate-200 rounded-xl flex flex-col items-center justify-center gap-1 bg-slate-50">
                    <AlertCircle className="w-5 h-5 text-rose-400" />
                    <span className="text-[10px] text-rose-400 font-medium">Required</span>
                  </div>
                )}
              </div>

              <div className="space-y-2">
                <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                  PAN Card <span className="text-rose-500">*</span>
                </Label>
                {employee.panUrl ? (
                  <div className="relative group">
                    {String(employee.panUrl).match(/\.(pdf)$/i) ? (
                      <div className="h-20 bg-slate-100 rounded-xl border border-slate-200 flex items-center justify-center gap-2">
                        <FileText className="w-6 h-6 text-slate-400" />
                        <span className="text-xs text-slate-500">PDF</span>
                      </div>
                    ) : (
                      <img
                        src={employee.panUrl as string}
                        alt="PAN"
                        className="w-full h-20 object-contain rounded-xl border border-slate-200 bg-white p-1"
                      />
                    )}
                  </div>
                ) : (
                  <div className="w-full h-20 border-2 border-dashed border-slate-200 rounded-xl flex flex-col items-center justify-center gap-1 bg-slate-50">
                    <AlertCircle className="w-5 h-5 text-rose-400" />
                    <span className="text-[10px] text-rose-400 font-medium">Required</span>
                  </div>
                )}
              </div>

              <div className="space-y-2">
                <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                  Passport
                </Label>
                {employee.passportUrl ? (
                  <div className="relative group">
                    {String(employee.passportUrl).match(/\.(pdf)$/i) ? (
                      <div className="h-20 bg-slate-100 rounded-xl border border-slate-200 flex items-center justify-center gap-2">
                        <FileText className="w-6 h-6 text-slate-400" />
                        <span className="text-xs text-slate-500">PDF</span>
                      </div>
                    ) : (
                      <img
                        src={employee.passportUrl as string}
                        alt="Passport"
                        className="w-full h-20 object-contain rounded-xl border border-slate-200 bg-white p-1"
                      />
                    )}
                  </div>
                ) : (
                  <div className="w-full h-20 border-2 border-dashed border-slate-200 rounded-xl flex flex-col items-center justify-center gap-1 bg-slate-50">
                    <span className="text-[10px] text-slate-400 font-medium">Optional</span>
                  </div>
                )}
              </div>
            </div>
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
            <h3 className="text-sm font-semibold text-slate-700">Edit Other Information</h3>
            <div className="flex gap-2">
              <Button type="button" size="sm" variant="ghost" onClick={() => setEditing(false)}>Cancel</Button>
              <Button type="submit" size="sm" disabled={saving} style={{ backgroundColor: "#1d3459" }} className="text-white hover:opacity-90">
                {saving ? "Saving…" : "Save"}
              </Button>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <div className="lg:col-span-2">
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 bg-white/40 backdrop-blur-lg p-5 rounded-2xl border border-white/40 shadow">
                
                <div className="space-y-1 lg:col-span-3">
                  <Label>Skill Set</Label>
                  <Input {...register("skillSet")} className="bg-white/50" />
                </div>
                
                <div className="space-y-1 lg:col-span-3">
                  <Label>Strength</Label>
                  <Input {...register("strength")} className="bg-white/50" />
                </div>

                <div className="space-y-1 lg:col-span-3">
                  <Label>Weakness</Label>
                  <Input {...register("weakness")} className="bg-white/50" />
                </div>

                <div className="flex items-center gap-2 lg:col-span-3 py-2">
                  <input type="checkbox" id="isHandicapped" {...register("isHandicapped")} className="h-4 w-4 rounded border-slate-300" />
                  <Label htmlFor="isHandicapped">Is Handicapped?</Label>
                </div>

                <div className="space-y-1 lg:col-span-3">
                  <Label>Hobbies</Label>
                  <Input {...register("hobbies")} className="bg-white/50" />
                </div>

                <div className="space-y-1 lg:col-span-3 border-t pt-4 mt-2">
                  <h4 className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-3">Identity Documents</h4>
                </div>

                <div className="space-y-1">
                  <Label>PAN No <span className="text-rose-500">*</span></Label>
                  <Input {...register("panNo")} className="bg-white/50 uppercase" placeholder="ABCDE1234F" />
                  {errors.panNo && <p className="text-[10px] text-rose-500">{errors.panNo.message}</p>}
                </div>
                
                <div className="space-y-1">
                  <Label>Aadhaar No <span className="text-rose-500">*</span></Label>
                  <Input {...register("aadhaarNo")} className="bg-white/50" placeholder="12-digit Aadhaar" maxLength={12} />
                  {errors.aadhaarNo && <p className="text-[10px] text-rose-500">{errors.aadhaarNo.message}</p>}
                </div>
                
                <div className="hidden lg:block"></div>

                <div className="space-y-1 lg:col-span-3 border-t pt-4 mt-2">
                  <h4 className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-3">Physical Details</h4>
                </div>

                <div className="space-y-1">
                  <Label>Height (cm) <span className="text-rose-500">*</span></Label>
                  <Input type="number" step="0.1" {...register("heightInCm")} className="bg-white/50" placeholder="e.g., 170" />
                  {errors.heightInCm && <p className="text-[10px] text-rose-500">{errors.heightInCm.message}</p>}
                </div>
                
                <div className="space-y-1">
                  <Label>Weight (kg) <span className="text-rose-500">*</span></Label>
                  <Input type="number" step="0.1" {...register("weightInKg")} className="bg-white/50" placeholder="e.g., 70" />
                  {errors.weightInKg && <p className="text-[10px] text-rose-500">{errors.weightInKg.message}</p>}
                </div>
                
                <div className="space-y-1 flex items-end">
                  {bmi !== null ? (
                    <BmiIndicator bmi={bmi} />
                  ) : (
                    <div className="text-xs text-slate-400">Enter height & weight to calculate BMI</div>
                  )}
                </div>
              </div>
            </div>

            <div className="space-y-4">
              <div className="space-y-2">
                <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                  Upload Aadhaar Card <span className="text-rose-500">*</span>
                </Label>
                <FileUploadBox
                  label=""
                  currentUrl={aadhaarUrl}
                  accept="image/*,.pdf"
                  onUpload={handleAadhaarUpload}
                  uploading={aadhaarUploading}
                  icon={FileText}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                  Upload PAN Card <span className="text-rose-500">*</span>
                </Label>
                <FileUploadBox
                  label=""
                  currentUrl={panUrl}
                  accept="image/*,.pdf"
                  onUpload={handlePanUpload}
                  uploading={panUploading}
                  icon={FileText}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                  Upload Passport
                </Label>
                <FileUploadBox
                  label=""
                  currentUrl={passportUrl}
                  accept="image/*,.pdf"
                  onUpload={handlePassportUpload}
                  uploading={passportUploading}
                  icon={FileText}
                />
              </div>
            </div>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
