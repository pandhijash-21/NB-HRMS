"use client";

import { useState, useRef } from "react";
import { useForm, useFieldArray } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Plus, Trash2, Clock, CheckCircle2, Upload, Camera, PenTool, Image as ImageIcon, X } from "lucide-react";
import { toast } from "sonner";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useMutation } from "@apollo/client/react";
import { UPDATE_EMPLOYEE_PERSONAL, UPDATE_EMPLOYEE_GENERAL } from "@/lib/graphql";
import { useRequestChange, usePendingRequest } from "@/lib/hooks/useApprovals";
import { useUpload } from "@/lib/hooks/useUpload";

const personalSchema = z.object({
  birthDate: z.string().optional(),
  birthPlace: z.string().optional(),
  homeTown: z.string().optional(),
  gender: z.enum(["MALE", "FEMALE", "OTHER"]).optional(),
  maritalStatus: z.enum(["SINGLE", "MARRIED", "DIVORCED", "WIDOWED"]).optional(),
  nationality: z.string().optional(),
  motherTongue: z.string().optional(),
  bloodGroup: z.enum(["A_POS", "A_NEG", "B_POS", "B_NEG", "O_POS", "O_NEG", "AB_POS", "AB_NEG"]).optional(),
  castCategory: z.string().optional(),
  subCaste: z.string().optional(),
  nomineeName: z.string().optional(),
  nomineeRelation: z.string().optional(),
  passportNo: z.string().optional(),
  passportIssuePlace: z.string().optional(),
  passportIssueDate: z.string().optional(),
  passportExpiryDate: z.string().optional(),
  customFields: z.array(z.object({ key: z.string(), value: z.string() })).optional(),
  photoUrl: z.string().optional(),
  signatureUrl: z.string().optional(),
});

type PersonalFormData = z.infer<typeof personalSchema>;

const BLOOD_GROUPS = ["A_POS", "A_NEG", "B_POS", "B_NEG", "O_POS", "O_NEG", "AB_POS", "AB_NEG"];
const BLOOD_DISPLAY: Record<string, string> = {
  A_POS: "A+", A_NEG: "A−", B_POS: "B+", B_NEG: "B−",
  O_POS: "O+", O_NEG: "O−", AB_POS: "AB+", AB_NEG: "AB−",
};

interface PersonalTabProps {
  employee: Record<string, unknown>;
  isAdmin?: boolean;
  onUpdate?: () => void;
}

function Field({ label, value }: { label: string; value?: string | null }) {
  return (
    <div>
      <p className="text-xs text-slate-500 mb-0.5">{label}</p>
      <p className="text-sm font-medium text-slate-800">{value || "—"}</p>
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
          <img
            src={currentUrl}
            alt={label}
            className="w-full h-32 object-cover rounded-xl border border-slate-200"
          />
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
          className="w-full h-32 border-2 border-dashed border-slate-200 rounded-xl flex flex-col items-center justify-center gap-2 hover:border-[#1d3459]/30 hover:bg-slate-50/50 transition-all disabled:opacity-50"
        >
          <Icon className="w-8 h-8 text-slate-300" />
          <span className="text-xs text-slate-400 font-medium">
            {uploading ? "Uploading..." : "Click to upload"}
          </span>
        </button>
      )}
    </div>
  );
}

export function PersonalTab({ employee, isAdmin, onUpdate }: PersonalTabProps) {
  const [editing, setEditing] = useState(false);
  const [requestSent, setRequestSent] = useState(false);
  const [photoUploading, setPhotoUploading] = useState(false);
  const [signatureUploading, setSignatureUploading] = useState(false);

  const [mutate, { loading: adminSaving }] = useMutation(UPDATE_EMPLOYEE_PERSONAL);
  const [mutateGeneral] = useMutation(UPDATE_EMPLOYEE_GENERAL);

  const requestChange = useRequestChange();
  const { data: pendingRequest } = usePendingRequest("PERSONAL");

  const { upload } = useUpload(employee.id as string);

  const customFieldsObj = (employee.customFields as Record<string, string>) || {};

  const { register, control, handleSubmit, setValue, watch, formState: { errors } } = useForm<PersonalFormData>({
    resolver: zodResolver(personalSchema),
    defaultValues: {
      birthDate: (employee.birthDate as string)?.slice(0, 10) ?? "",
      birthPlace: (employee.birthPlace as string) ?? "",
      homeTown: (employee.homeTown as string) ?? "",
      gender: (employee.gender as PersonalFormData["gender"]) ?? "MALE",
      maritalStatus: (employee.maritalStatus as PersonalFormData["maritalStatus"]) ?? undefined,
      nationality: (employee.nationality as string) ?? "INDIAN",
      motherTongue: (employee.motherTongue as string) ?? "",
      bloodGroup: (employee.bloodGroup as PersonalFormData["bloodGroup"]) ?? undefined,
      castCategory: (employee.castCategory as string) ?? "",
      subCaste: (employee.subCaste as string) ?? "",
      nomineeName: (employee.nomineeName as string) ?? "",
      nomineeRelation: (employee.nomineeRelation as string) ?? "",
      passportNo: (employee.passportNo as string) ?? "",
      passportIssuePlace: (employee.passportIssuePlace as string) ?? "",
      passportIssueDate: (employee.passportIssueDate as string)?.slice(0, 10) ?? "",
      passportExpiryDate: (employee.passportExpiryDate as string)?.slice(0, 10) ?? "",
      customFields: Object.entries(customFieldsObj).map(([key, value]) => ({ key, value: String(value) })),
      photoUrl: (employee.photoUrl as string) ?? "",
      signatureUrl: (employee.signatureUrl as string) ?? "",
    },
  });

  const { fields, append, remove } = useFieldArray({
    control,
    name: "customFields",
  });

  const photoUrl = watch("photoUrl");
  const signatureUrl = watch("signatureUrl");

  const handlePhotoUpload = async (file: File) => {
    setPhotoUploading(true);
    try {
      const url = await upload("photo", file);
      setValue("photoUrl", url);
      toast.success("Photo uploaded successfully");
    } catch {
      toast.error("Failed to upload photo");
    } finally {
      setPhotoUploading(false);
    }
  };

  const handleSignatureUpload = async (file: File) => {
    setSignatureUploading(true);
    try {
      const url = await upload("signature", file);
      setValue("signatureUrl", url);
      toast.success("Signature uploaded successfully");
    } catch {
      toast.error("Failed to upload signature");
    } finally {
      setSignatureUploading(false);
    }
  };

  const onSubmit = async (data: any) => {
    if (isAdmin) {
      const customFieldsMap = data.customFields?.reduce((acc: any, field: any) => {
        if (field.key.trim()) acc[field.key.trim()] = field.value;
        return acc;
      }, {});

      const setPayload: Record<string, unknown> = {
        birth_date: data.birthDate || null,
        birth_place: data.birthPlace,
        home_town: data.homeTown,
        gender: data.gender,
        marital_status: data.maritalStatus,
        nationality: data.nationality,
        mother_tongue: data.motherTongue,
        blood_group: data.bloodGroup || null,
        cast_category: data.castCategory,
        sub_caste: data.subCaste,
        nominee_name: data.nomineeName,
        nominee_relation: data.nomineeRelation,
        passport_no: data.passportNo,
        passport_issue_place: data.passportIssuePlace,
        passport_issue_date: data.passportIssueDate || null,
        passport_expiry_date: data.passportExpiryDate || null,
      };
      if (customFieldsMap && Object.keys(customFieldsMap).length > 0) {
        setPayload.custom_fields = customFieldsMap;
      }
      await mutate({ variables: { employeeId: employee.id, set: setPayload } });

      if (data.photoUrl || data.signatureUrl) {
        await mutateGeneral({
          variables: {
            employeeId: employee.id,
            set: {
              photo_url: data.photoUrl || null,
              signature_url: data.signatureUrl || null,
            },
          },
        });
      }

      setEditing(false);
      onUpdate?.();
    } else {
      const customFieldsMap = data.customFields?.reduce((acc: any, field: any) => {
        if (field.key.trim()) acc[field.key.trim()] = field.value;
        return acc;
      }, {});

      const newData: Record<string, unknown> = {
        birthDate: data.birthDate || null,
        birthPlace: data.birthPlace,
        homeTown: data.homeTown,
        gender: data.gender,
        maritalStatus: data.maritalStatus,
        nationality: data.nationality,
        motherTongue: data.motherTongue,
        bloodGroup: data.bloodGroup || null,
        castCategory: data.castCategory,
        subCaste: data.subCaste,
        nomineeName: data.nomineeName,
        nomineeRelation: data.nomineeRelation,
        passportNo: data.passportNo,
        passportIssuePlace: data.passportIssuePlace,
        passportIssueDate: data.passportIssueDate || null,
        passportExpiryDate: data.passportExpiryDate || null,
        customFields: customFieldsMap,
        photoUrl: data.photoUrl,
        signatureUrl: data.signatureUrl,
      };
      
      requestChange.mutate(
        { module: "PERSONAL", newData },
        {
          onSuccess: () => {
            setEditing(false);
            setRequestSent(true);
            toast.success("Change request submitted for HR approval");
          },
        }
      );
    }
  };

  if (!editing) {
    return (
      <Card>
        <CardContent className="pt-5 space-y-5">
          <div className="flex justify-between items-center">
            <h3 className="text-sm font-semibold text-slate-700">Personal Information</h3>
            {(!pendingRequest || isAdmin) && (
              <Button size="sm" variant="outline" onClick={() => setEditing(true)} className="text-xs border-[#1d3459] text-[#1d3459] hover:bg-[#1d3459] hover:text-white">
                Edit
              </Button>
            )}
          </div>

          {!isAdmin && pendingRequest && pendingRequest.status === "PENDING" && (
            <div className="flex items-start gap-3 p-3 rounded-xl bg-amber-50 border border-amber-200 text-xs shadow-sm">
              <Clock className="w-4 h-4 text-amber-500 mt-0.5 shrink-0" />
              <div>
                <p className="font-bold text-amber-700">Update Pending HR Approval</p>
                <p className="text-amber-600 mt-0.5 leading-relaxed">
                  Submitted {new Date(pendingRequest.requestedAt).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" })}. Your profile will be updated once approved.
                </p>
              </div>
            </div>
          )}

          {!isAdmin && pendingRequest && pendingRequest.status === "REJECTED" && (
            <div className="flex items-start gap-3 p-3 rounded-xl bg-rose-50 border border-rose-200 text-xs shadow-sm">
              <Trash2 className="w-4 h-4 text-rose-500 mt-0.5 shrink-0" />
              <div className="flex-1">
                <p className="font-bold text-rose-700">Update Not Approved</p>
                <p className="text-rose-600 mt-0.5 leading-relaxed">
                  Your request from {new Date(pendingRequest.requestedAt).toLocaleDateString()} was reviewed but not approved.
                </p>
                <Button 
                  variant="link" 
                  size="sm" 
                  className="h-auto p-0 mt-2 text-rose-600 font-bold hover:text-rose-700 text-[10px] uppercase tracking-wider"
                  onClick={() => setEditing(true)}
                >
                  Edit & Resubmit →
                </Button>
              </div>
            </div>
          )}

          {!isAdmin && requestSent && !pendingRequest && (
            <div className="flex items-center gap-2 p-3 rounded-xl bg-emerald-50 border border-emerald-100 text-xs text-emerald-700 font-semibold">
              <CheckCircle2 className="w-4 h-4" />
              Change request submitted. HR will review it shortly.
            </div>
          )}

          {!isAdmin && (
            <p className="text-xs text-slate-400">
              Personal info changes require HR approval before they take effect.
            </p>
          )}

          <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
            <div className="lg:col-span-1 space-y-4">
              <div className="space-y-2">
                <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                  Photo <span className="text-rose-500">*</span>
                </Label>
                {employee.photoUrl ? (
                  <div className="relative group">
                    <img
                      src={employee.photoUrl as string}
                      alt="Profile Photo"
                      className="w-full h-40 object-cover rounded-xl border border-slate-200"
                    />
                  </div>
                ) : (
                  <div className="w-full h-40 border-2 border-dashed border-slate-200 rounded-xl flex flex-col items-center justify-center gap-2 bg-slate-50">
                    <Camera className="w-8 h-8 text-slate-300" />
                    <span className="text-xs text-slate-400">No photo uploaded</span>
                  </div>
                )}
              </div>

              <div className="space-y-2">
                <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider">
                  Signature <span className="text-rose-500">*</span>
                </Label>
                {employee.signatureUrl ? (
                  <div className="relative">
                    <img
                      src={employee.signatureUrl as string}
                      alt="Signature"
                      className="w-full h-24 object-contain rounded-xl border border-slate-200 bg-white"
                    />
                  </div>
                ) : (
                  <div className="w-full h-24 border-2 border-dashed border-slate-200 rounded-xl flex flex-col items-center justify-center gap-2 bg-slate-50">
                    <PenTool className="w-6 h-6 text-slate-300" />
                    <span className="text-xs text-slate-400">No signature uploaded</span>
                  </div>
                )}
              </div>
            </div>

            <div className="lg:col-span-3">
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5 bg-white/30 backdrop-blur-md p-4 rounded-xl border border-white/50 shadow-sm">
                <Field label="Date of Birth" value={employee.birthDate ? new Date(employee.birthDate as string).toLocaleDateString("en-IN") : undefined} />
                <Field label="Birth Place" value={employee.birthPlace as string} />
                <Field label="Home Town" value={employee.homeTown as string} />

                <Field label="Gender" value={employee.gender as string} />
                <Field label="Marital Status" value={employee.maritalStatus as string} />
                <Field label="Nationality" value={employee.nationality as string} />

                <Field label="Mother Tongue" value={employee.motherTongue as string} />
                <Field label="Blood Group" value={employee.bloodGroup ? BLOOD_DISPLAY[employee.bloodGroup as string] : undefined} />
                <div className="hidden lg:block"></div>

                <Field label="Cast Category" value={employee.castCategory as string} />
                <Field label="Sub Caste" value={employee.subCaste as string} />
                <div className="hidden lg:block"></div>

                <Field label="Nominee Name" value={employee.nomineeName as string} />
                <Field label="Nominee Relation" value={employee.nomineeRelation as string} />
                <div className="hidden lg:block"></div>

                <Field label="Passport No" value={employee.passportNo as string} />
                <Field label="Passport Issue Place" value={employee.passportIssuePlace as string} />
                <div className="hidden lg:block"></div>

                <Field label="Passport Issue Date" value={employee.passportIssueDate ? new Date(employee.passportIssueDate as string).toLocaleDateString("en-IN") : undefined} />
                <Field label="Passport Expiry Date" value={employee.passportExpiryDate ? new Date(employee.passportExpiryDate as string).toLocaleDateString("en-IN") : undefined} />

                {Object.entries(customFieldsObj).map(([key, value]) => (
                  <Field key={key} label={key} value={String(value)} />
                ))}
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
            <h3 className="text-sm font-semibold text-slate-700">Edit Personal Information</h3>
            <div className="flex gap-2">
              <Button type="button" size="sm" variant="ghost" onClick={() => setEditing(false)}>Cancel</Button>
              <Button type="submit" size="sm"
                disabled={isAdmin ? adminSaving : requestChange.isPending}
                style={{ backgroundColor: "#1d3459" }} className="text-white hover:opacity-90">
                {isAdmin
                  ? (adminSaving ? "Saving…" : "Save")
                  : (requestChange.isPending ? "Submitting…" : "Request Change")}
              </Button>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
            <div className="lg:col-span-1 space-y-4">
              <FileUploadBox
                label="Upload Photo"
                currentUrl={photoUrl}
                accept="image/*"
                onUpload={handlePhotoUpload}
                uploading={photoUploading}
                icon={Camera}
                required
              />

              <FileUploadBox
                label="Upload Signature"
                currentUrl={signatureUrl}
                accept="image/*"
                onUpload={handleSignatureUpload}
                uploading={signatureUploading}
                icon={PenTool}
                required
              />
            </div>

            <div className="lg:col-span-3">
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 bg-white/40 backdrop-blur-lg p-5 rounded-2xl border border-white/40 shadow">
                <div className="space-y-1">
                  <Label>Date of Birth</Label>
                  <Input type="date" {...register("birthDate")} className="bg-white/50" />
                </div>
                <div className="space-y-1">
                  <Label>Birth Place</Label>
                  <Input {...register("birthPlace")} className="bg-white/50" />
                </div>
                <div className="space-y-1">
                  <Label>Home Town</Label>
                  <Input {...register("homeTown")} className="bg-white/50" />
                </div>

                <div className="space-y-1">
                  <Label>Gender</Label>
                  <Select defaultValue={(employee.gender as string) ?? "MALE"} onValueChange={(v) => setValue("gender", v as PersonalFormData["gender"])}>
                    <SelectTrigger className="bg-white/50"><SelectValue /></SelectTrigger>
                    <SelectContent>
                      {["MALE", "FEMALE", "OTHER"].map((g) => (
                        <SelectItem key={g} value={g}>{g}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-1">
                  <Label>Marital Status</Label>
                  <Select defaultValue={(employee.maritalStatus as string) ?? ""} onValueChange={(v) => setValue("maritalStatus", v as PersonalFormData["maritalStatus"])}>
                    <SelectTrigger className="bg-white/50"><SelectValue placeholder="Select..." /></SelectTrigger>
                    <SelectContent>
                      {["SINGLE", "MARRIED", "DIVORCED", "WIDOWED"].map((m) => (
                        <SelectItem key={m} value={m}>{m}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-1">
                  <Label>Nationality</Label>
                  <Input {...register("nationality")} className="bg-white/50" />
                </div>

                <div className="space-y-1">
                  <Label>Mother Tongue</Label>
                  <Input {...register("motherTongue")} className="bg-white/50" />
                </div>
                <div className="space-y-1">
                  <Label>Blood Group</Label>
                  <Select defaultValue={(employee.bloodGroup as string) ?? ""} onValueChange={(v) => setValue("bloodGroup", v as PersonalFormData["bloodGroup"])}>
                    <SelectTrigger className="bg-white/50"><SelectValue placeholder="Select..." /></SelectTrigger>
                    <SelectContent>
                      {BLOOD_GROUPS.map((bg) => (
                        <SelectItem key={bg} value={bg}>{BLOOD_DISPLAY[bg]}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="hidden lg:block"></div>

                <div className="space-y-1">
                  <Label>Cast Category</Label>
                  <Input {...register("castCategory")} className="bg-white/50" placeholder="e.g. OPEN, OBC, SC, ST" />
                </div>
                <div className="space-y-1">
                  <Label>Sub Caste</Label>
                  <Input {...register("subCaste")} className="bg-white/50" />
                </div>
                <div className="hidden lg:block"></div>

                <div className="space-y-1">
                  <Label>Nominee Name</Label>
                  <Input {...register("nomineeName")} className="bg-white/50" />
                </div>
                <div className="space-y-1">
                  <Label>Nominee Relation</Label>
                  <Input {...register("nomineeRelation")} className="bg-white/50" />
                </div>
                <div className="hidden lg:block"></div>

                <div className="space-y-1">
                  <Label>Passport No</Label>
                  <Input {...register("passportNo")} className="bg-white/50 uppercase" />
                </div>
                <div className="space-y-1">
                  <Label>Passport Issue Place</Label>
                  <Input {...register("passportIssuePlace")} className="bg-white/50" />
                </div>
                <div className="hidden lg:block"></div>

                <div className="space-y-1">
                  <Label>Passport Issue Date</Label>
                  <Input type="date" {...register("passportIssueDate")} className="bg-white/50" />
                </div>
                <div className="space-y-1">
                  <Label>Passport Expiry Date</Label>
                  <Input type="date" {...register("passportExpiryDate")} className="bg-white/50" />
                </div>
              </div>
            </div>
          </div>

          {isAdmin && (
            <div className="space-y-4 pt-4 border-t border-slate-200">
              <div className="flex justify-between items-center">
                <div>
                  <h4 className="text-sm font-semibold text-slate-700">Custom Fields</h4>
                  <p className="text-xs text-slate-500">Dynamically add new information sections to this employee&apos;s profile.</p>
                </div>
                <Button
                  type="button"
                  size="sm"
                  variant="outline"
                  onClick={() => append({ key: "", value: "" })}
                  className="text-xs"
                >
                  <Plus className="w-4 h-4 mr-1" /> Add Field
                </Button>
              </div>

              {fields.length > 0 ? (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {fields.map((field, index) => (
                    <div key={field.id} className="flex gap-2 items-end">
                      <div className="w-1/3 space-y-1">
                        <Label className="text-[10px] uppercase tracking-wider text-slate-500">Label</Label>
                        <Input 
                          {...register(`customFields.${index}.key`)} 
                          placeholder="e.g. License No" 
                          className="bg-white/50 text-sm h-9"
                        />
                      </div>
                      <div className="flex-1 space-y-1">
                        <Label className="text-[10px] uppercase tracking-wider text-slate-500">Value</Label>
                        <Input 
                          {...register(`customFields.${index}.value`)} 
                          placeholder="Value" 
                          className="bg-white/50 text-sm h-9"
                        />
                      </div>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        className="h-9 w-9 text-rose-500 hover:text-rose-600 hover:bg-rose-50 rounded"
                        onClick={() => remove(index)}
                      >
                        <Trash2 className="w-4 h-4" />
                      </Button>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-4 border border-dashed border-slate-200 rounded-lg text-sm text-slate-400 bg-white/20">
                  No custom fields added yet.
                </div>
              )}
            </div>
          )}

        </form>
      </CardContent>
    </Card>
  );
}
