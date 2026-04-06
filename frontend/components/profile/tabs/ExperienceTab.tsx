"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { experienceSchema, type ExperienceFormData } from "@/lib/validators/experience.schema";
import { useExperiences } from "@/lib/hooks/useExperiences";
import { useUpload } from "@/lib/hooks/useUpload";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Skeleton } from "@/components/ui/skeleton";
import { toast } from "sonner";
import { 
  Briefcase, 
  Building2, 
  Calendar, 
  FileText, 
  Upload, 
  Plus, 
  Trash2,
  DollarSign,
  Users,
  ExternalLink,
  X,
  Loader2,
  AlertCircle
} from "lucide-react";

interface ExperienceTabProps {
  employeeId: string;
  isAdmin?: boolean;
}

const EXPERIENCE_TYPES = [
  { value: "TEACHING", label: "Teaching" },
  { value: "INDUSTRY", label: "Industry" },
  { value: "RESEARCH", label: "Research" },
  { value: "ADMINISTRATIVE", label: "Administrative" },
  { value: "CONSULTANCY", label: "Consultancy" },
  { value: "OTHER", label: "Other" },
];

function FileUploadField({
  label,
  url,
  accept,
  onUpload,
  uploading,
  required,
}: {
  label: string;
  url?: string | null;
  accept: string;
  onUpload: (file: File) => void;
  uploading?: boolean;
  required?: boolean;
}) {
  return (
    <div className="space-y-2">
      <div className="flex items-center gap-1">
        <Label className="text-xs font-medium text-slate-600">{label}</Label>
        {required && <span className="text-rose-500 text-xs">*</span>}
      </div>
      <div className={`border-2 border-dashed rounded-xl p-3 ${url ? 'border-emerald-200 bg-emerald-50/50' : 'border-slate-200'}`}>
        {url ? (
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <FileText className="w-4 h-4 text-emerald-500" />
              <span className="text-xs text-slate-600 line-clamp-1">
                {url.includes('/') ? url.split('/').pop()?.substring(0, 20) : 'Uploaded'}
              </span>
            </div>
            <div className="flex items-center gap-1">
              <a
                href={url}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs text-[#1d3459] hover:underline flex items-center gap-1"
              >
                <ExternalLink className="w-3 h-3" />
              </a>
            </div>
          </div>
        ) : uploading ? (
          <div className="flex items-center justify-center gap-2 py-2">
            <Loader2 className="w-4 h-4 animate-spin text-[#1d3459]" />
            <span className="text-xs text-slate-500">Uploading...</span>
          </div>
        ) : (
          <label className="flex flex-col items-center gap-1 cursor-pointer">
            <input
              type="file"
              accept={accept}
              className="hidden"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) onUpload(file);
              }}
            />
            <Upload className="w-4 h-4 text-slate-400" />
            <span className="text-[10px] text-slate-400">Click to upload</span>
          </label>
        )}
      </div>
    </div>
  );
}

export function ExperienceTab({ employeeId, isAdmin }: ExperienceTabProps) {
  const { experiences, loading, saving, saveExperience, deleteExperience } = useExperiences(employeeId);
  const { upload } = useUpload(employeeId);
  
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingExp, setEditingExp] = useState<ExperienceFormData | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  
  const [expLetterUploading, setExpLetterUploading] = useState(false);
  const [paycheckUploading, setPaycheckUploading] = useState(false);
  const [recommendationUploading, setRecommendationUploading] = useState(false);

  const {
    register,
    handleSubmit,
    setValue,
    reset,
    watch,
    formState: { errors },
  } = useForm<ExperienceFormData>({
    resolver: zodResolver(experienceSchema),
    defaultValues: {
      type: "TEACHING",
      designation: "",
      organizationName: "",
      fromDate: "",
      toDate: "",
      jobDescription: "",
      lastSalary: undefined,
      experienceLetterUrl: "",
      lastPaycheckUrl: "",
      recommendationLetters: [],
    },
  });

  const experienceLetterUrl = watch("experienceLetterUrl");
  const lastPaycheckUrl = watch("lastPaycheckUrl");
  const recommendationLetters = watch("recommendationLetters");

  const handleExperienceLetterUpload = async (file: File) => {
    setExpLetterUploading(true);
    try {
      const url = await upload("experienceLetter", file);
      setValue("experienceLetterUrl", url);
      toast.success("Experience letter uploaded");
    } catch {
      toast.error("Failed to upload experience letter");
    } finally {
      setExpLetterUploading(false);
    }
  };

  const handlePaycheckUpload = async (file: File) => {
    setPaycheckUploading(true);
    try {
      const url = await upload("lastPaycheck", file);
      setValue("lastPaycheckUrl", url);
      toast.success("Last paycheck uploaded");
    } catch {
      toast.error("Failed to upload last paycheck");
    } finally {
      setPaycheckUploading(false);
    }
  };

  const handleRecommendationUpload = async (file: File) => {
    setRecommendationUploading(true);
    try {
      const url = await upload("recommendation", file);
      const current = recommendationLetters || [];
      setValue("recommendationLetters", [...current, url]);
      toast.success("Recommendation letter uploaded");
    } catch {
      toast.error("Failed to upload recommendation letter");
    } finally {
      setRecommendationUploading(false);
    }
  };

  const removeRecommendation = (index: number) => {
    const current = recommendationLetters || [];
    setValue("recommendationLetters", current.filter((_, i) => i !== index));
  };

  const openAdd = () => {
    reset({
      type: "TEACHING",
      designation: "",
      organizationName: "",
      fromDate: "",
      toDate: "",
      jobDescription: "",
      lastSalary: undefined,
      experienceLetterUrl: "",
      lastPaycheckUrl: "",
      recommendationLetters: [],
    });
    setEditingExp(null);
    setDialogOpen(true);
  };

  const openEdit = (exp: any) => {
    reset({
      id: exp.id,
      type: exp.type,
      designation: exp.designation,
      organizationName: exp.organizationName,
      fromDate: exp.fromDate?.slice(0, 10) || "",
      toDate: exp.toDate?.slice(0, 10) || "",
      jobDescription: exp.jobDescription || "",
      lastSalary: exp.lastSalary,
      experienceLetterUrl: exp.experienceLetterUrl || "",
      lastPaycheckUrl: exp.lastPaycheckUrl || "",
      recommendationLetters: exp.recommendationLetters || [],
    });
    setEditingExp(exp);
    setDialogOpen(true);
  };

  const onSubmit = async (data: ExperienceFormData) => {
    await saveExperience({ ...data, id: editingExp?.id });
    setDialogOpen(false);
    reset();
  };

  const confirmDelete = async () => {
    if (deleteId) {
      await deleteExperience(deleteId);
      setDeleteId(null);
      toast.success("Experience removed");
    }
  };

  const formatDate = (date: string) => {
    if (!date) return "";
    return new Date(date).toLocaleDateString("en-IN", {
      month: "short",
      year: "numeric",
    });
  };

  const calculateDuration = (from: string, to: string) => {
    if (!from || !to) return "";
    const fromDate = new Date(from);
    const toDate = new Date(to);
    const months = Math.floor(
      (toDate.getTime() - fromDate.getTime()) / (1000 * 60 * 60 * 24 * 30)
    );
    const years = Math.floor(months / 12);
    const remainingMonths = months % 12;
    if (years > 0) {
      return `${years}y ${remainingMonths}m`;
    }
    return `${remainingMonths}m`;
  };

  if (loading) {
    return (
      <Card>
        <CardContent className="pt-5 space-y-3">
          {Array.from({ length: 2 }).map((_, i) => (
            <Skeleton key={i} className="h-24 w-full" />
          ))}
        </CardContent>
      </Card>
    );
  }

  return (
    <>
      <Card>
        <CardContent className="pt-5 space-y-4">
          <div className="flex justify-between items-center">
            <div>
              <h3 className="text-sm font-semibold text-slate-700">Work Experience</h3>
              {experiences.length === 0 && (
                <p className="text-xs text-rose-500 mt-1 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  Work experience is required
                </p>
              )}
              {experiences.length > 0 && (
                <p className="text-xs text-emerald-600 mt-1">
                  {experiences.length} experience{experiences.length > 1 ? "s" : ""} added
                </p>
              )}
            </div>
            <Button
              size="sm"
              onClick={openAdd}
              style={{ backgroundColor: "#1d3459" }}
              className="text-white text-xs hover:opacity-90"
            >
              <Plus className="w-3 h-3 mr-1" />
              Add Experience
            </Button>
          </div>

          {experiences.length === 0 && (
            <div className="text-center py-8 text-sm text-slate-400 border border-dashed border-slate-200 rounded-lg">
              <Briefcase className="w-8 h-8 mx-auto mb-2 text-slate-300" />
              No work experience added yet.<br />
              Add your previous employment details.
            </div>
          )}

          <div className="space-y-3">
            {experiences.map((exp: any) => (
              <div
                key={exp.id}
                className="p-4 bg-slate-50 rounded-lg border border-slate-100"
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <Badge className="text-xs bg-[#1d3459]/10 text-[#1d3459] border-0">
                        {EXPERIENCE_TYPES.find((t) => t.value === exp.type)?.label || exp.type}
                      </Badge>
                      <p className="text-sm font-semibold text-slate-800">{exp.designation}</p>
                    </div>
                    <div className="flex items-center gap-2 mt-1 text-xs text-slate-500">
                      <Building2 className="w-3 h-3" />
                      {exp.organizationName}
                    </div>
                    <div className="flex items-center gap-2 mt-1 text-xs text-slate-400">
                      <Calendar className="w-3 h-3" />
                      {formatDate(exp.fromDate)} - {formatDate(exp.toDate)}
                      <span className="text-[#1d3459] font-medium">
                        ({calculateDuration(exp.fromDate, exp.toDate)})
                      </span>
                    </div>
                    {exp.jobDescription && (
                      <p className="text-xs text-slate-400 mt-2 line-clamp-2">{exp.jobDescription}</p>
                    )}
                    {exp.lastSalary && (
                      <div className="flex items-center gap-1 mt-2 text-xs text-emerald-600">
                        <DollarSign className="w-3 h-3" />
                        Last Salary: ₹{exp.lastSalary.toLocaleString()}
                      </div>
                    )}
                    <div className="flex flex-wrap gap-2 mt-2">
                      {exp.experienceLetterUrl && (
                        <a
                          href={exp.experienceLetterUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded bg-[#1d3459]/10 text-[#1d3459]"
                        >
                          <FileText className="w-3 h-3" />
                          Experience Letter
                        </a>
                      )}
                      {exp.lastPaycheckUrl && (
                        <a
                          href={exp.lastPaycheckUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded bg-emerald-100 text-emerald-700"
                        >
                          <FileText className="w-3 h-3" />
                          Paycheck
                        </a>
                      )}
                      {exp.recommendationLetters && exp.recommendationLetters.length > 0 && (
                        <span className="inline-flex items-center gap-1 text-xs px-2 py-1 rounded bg-purple-100 text-purple-700">
                          <Users className="w-3 h-3" />
                          {exp.recommendationLetters.length} Recommendation{exp.recommendationLetters.length > 1 ? "s" : ""}
                        </span>
                      )}
                    </div>
                  </div>

                  <div className="flex gap-1 ml-3 shrink-0">
                    <button
                      onClick={() => openEdit(exp)}
                      className="text-xs px-2 py-1 rounded border border-slate-200 text-slate-500 hover:bg-slate-100 transition-colors"
                    >
                      Edit
                    </button>
                    <button
                      onClick={() => setDeleteId(exp.id)}
                      className="text-xs px-2 py-1 rounded border border-rose-200 text-rose-500 hover:bg-rose-50 transition-colors"
                    >
                      Remove
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>
              {editingExp ? "Edit Experience" : "Add Experience"}
            </DialogTitle>
          </DialogHeader>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 py-2">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1">
                <Label>Experience Type *</Label>
                <Select
                  defaultValue={editingExp?.type ?? "TEACHING"}
                  onValueChange={(v) => setValue("type", v as ExperienceFormData["type"])}
                >
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {EXPERIENCE_TYPES.map((t) => (
                      <SelectItem key={t.value} value={t.value}>{t.label}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1">
                <Label>Designation *</Label>
                <Input
                  {...register("designation")}
                  placeholder="e.g., Assistant Professor"
                />
                {errors.designation && (
                  <p className="text-xs text-rose-500">{errors.designation.message}</p>
                )}
              </div>
            </div>

            <div className="space-y-1">
              <Label>Organization Name *</Label>
              <Input
                {...register("organizationName")}
                placeholder="e.g., XYZ University"
              />
              {errors.organizationName && (
                <p className="text-xs text-rose-500">{errors.organizationName.message}</p>
              )}
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1">
                <Label>From Date *</Label>
                <Input type="date" {...register("fromDate")} />
                {errors.fromDate && (
                  <p className="text-xs text-rose-500">{errors.fromDate.message}</p>
                )}
              </div>

              <div className="space-y-1">
                <Label>To Date *</Label>
                <Input type="date" {...register("toDate")} />
                {errors.toDate && (
                  <p className="text-xs text-rose-500">{errors.toDate.message}</p>
                )}
              </div>
            </div>

            <div className="space-y-1">
              <Label>Job Description</Label>
              <Textarea
                {...register("jobDescription")}
                placeholder="Brief description of your role and responsibilities..."
                rows={3}
                className="resize-none"
              />
            </div>

            <div className="space-y-1">
              <Label>Last Salary (Monthly)</Label>
              <div className="relative">
                <DollarSign className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                <Input
                  type="number"
                  {...register("lastSalary")}
                  placeholder="e.g., 50000"
                  className="pl-9"
                />
              </div>
            </div>

            <div className="border-t pt-4">
              <h4 className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-3">
                Document Uploads
              </h4>

              <div className="grid grid-cols-2 gap-4">
                <FileUploadField
                  label="Experience Letter"
                  url={experienceLetterUrl}
                  accept=".pdf,image/*"
                  onUpload={handleExperienceLetterUpload}
                  uploading={expLetterUploading}
                />

                <FileUploadField
                  label="Last Paycheck"
                  url={lastPaycheckUrl}
                  accept=".pdf,image/*"
                  onUpload={handlePaycheckUpload}
                  uploading={paycheckUploading}
                />
              </div>

              <div className="mt-4 space-y-2">
                <div className="flex items-center justify-between">
                  <Label className="text-xs font-medium text-slate-600">
                    Recommendation Letters
                  </Label>
                  <span className="text-[10px] text-slate-400">(Optional, multiple)</span>
                </div>
                <div className="border-2 border-dashed border-slate-200 rounded-xl p-3">
                  {recommendationLetters && recommendationLetters.length > 0 ? (
                    <div className="space-y-2">
                      {recommendationLetters.map((url, index) => (
                        <div
                          key={index}
                          className="flex items-center justify-between bg-slate-50 rounded-lg px-3 py-2"
                        >
                          <div className="flex items-center gap-2">
                            <Users className="w-4 h-4 text-slate-400" />
                            <span className="text-xs text-slate-600">
                              Letter {index + 1}
                            </span>
                          </div>
                          <div className="flex items-center gap-1">
                            <a
                              href={url}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="text-xs text-[#1d3459] hover:underline"
                            >
                              <ExternalLink className="w-3 h-3" />
                            </a>
                            <button
                              type="button"
                              onClick={() => removeRecommendation(index)}
                              className="text-rose-400 hover:text-rose-600"
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </div>
                        </div>
                      ))}
                      <label className="flex items-center justify-center gap-2 cursor-pointer py-2 text-xs text-[#1d3459] hover:bg-slate-100 rounded-lg transition-colors">
                        <input
                          type="file"
                          accept=".pdf,image/*"
                          className="hidden"
                          onChange={(e) => {
                            const file = e.target.files?.[0];
                            if (file) handleRecommendationUpload(file);
                          }}
                          disabled={recommendationUploading}
                        />
                        {recommendationUploading ? (
                          <>
                            <Loader2 className="w-3 h-3 animate-spin" />
                            Uploading...
                          </>
                        ) : (
                          <>
                            <Plus className="w-3 h-3" />
                            Add Another
                          </>
                        )}
                      </label>
                    </div>
                  ) : (
                    <label className="flex flex-col items-center gap-1 cursor-pointer py-2">
                      <input
                        type="file"
                        accept=".pdf,image/*"
                        className="hidden"
                        onChange={(e) => {
                          const file = e.target.files?.[0];
                          if (file) handleRecommendationUpload(file);
                        }}
                        disabled={recommendationUploading}
                      />
                      {recommendationUploading ? (
                        <>
                          <Loader2 className="w-5 h-5 animate-spin text-[#1d3459]" />
                          <span className="text-xs text-slate-500">Uploading...</span>
                        </>
                      ) : (
                        <>
                          <Users className="w-5 h-5 text-slate-300" />
                          <span className="text-xs text-slate-400">
                            Click to add recommendation letter(s)
                          </span>
                        </>
                      )}
                    </label>
                  )}
                </div>
              </div>
            </div>

            <DialogFooter>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={() => setDialogOpen(false)}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={saving}
                style={{ backgroundColor: "#1d3459" }}
                className="text-white hover:opacity-90"
              >
                {saving ? "Saving…" : "Save"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      <Dialog open={!!deleteId} onOpenChange={(o) => !o && setDeleteId(null)}>
        <DialogContent className="max-w-xs">
          <DialogHeader>
            <DialogTitle>Remove Experience</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-slate-600 py-2">
            Are you sure you want to remove this experience record?
          </p>
          <DialogFooter>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={() => setDeleteId(null)}
            >
              Cancel
            </Button>
            <Button
              type="button"
              size="sm"
              className="bg-rose-600 text-white hover:bg-rose-700"
              onClick={confirmDelete}
              disabled={saving}
            >
              Remove
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
