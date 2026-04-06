"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { academicQualSchema, type AcademicQualFormData } from "@/lib/validators/academic.schema";
import { useAcademicQuals } from "@/lib/hooks/useAcademicQuals";
import { useUpload } from "@/lib/hooks/useUpload";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
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
import { SemMarksheetGrid } from "@/components/shared/SemMarksheetGrid";
import { Skeleton } from "@/components/ui/skeleton";
import { FileText, Upload, AlertCircle } from "lucide-react";
import { toast } from "sonner";

interface EducationTabProps {
  employeeId: string;
  isAdmin?: boolean;
}

const LEVELS = ["SSC", "HSC", "DIPLOMA", "UG", "PG", "PHD", "OTHER"];

const LEVEL_COLORS: Record<string, string> = {
  SSC: "bg-slate-100 text-slate-600",
  HSC: "bg-slate-100 text-slate-600",
  DIPLOMA: "bg-blue-100 text-blue-700",
  UG: "bg-indigo-100 text-indigo-700",
  PG: "bg-purple-100 text-purple-700",
  PHD: "bg-amber-100 text-amber-700",
  OTHER: "bg-slate-100 text-slate-500",
};

const HSC_STREAMS = [
  { value: "SCIENCE", label: "Science" },
  { value: "COMMERCE", label: "Commerce" },
  { value: "ARTS_HUMANITIES", label: "Arts/Humanities" },
];

const MEDIUMS = [
  { value: "GUJARATI", label: "Gujarati" },
  { value: "HINDI", label: "Hindi" },
  { value: "ENGLISH", label: "English" },
  { value: "OTHER", label: "Other" },
];

export function EducationTab({ employeeId, isAdmin }: EducationTabProps) {
  const { qualifications, loading, saving, saveQualification, deleteQualification } = useAcademicQuals(employeeId);
  const { upload } = useUpload(employeeId);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingQual, setEditingQual] = useState<AcademicQualFormData | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [semUrls, setSemUrls] = useState<string[]>([]);
  const [marksheetRequired, setMarksheetRequired] = useState(false);
  const [certificateRequired, setCertificateRequired] = useState(false);
  const [marksheetUploading, setMarksheetUploading] = useState(false);
  const [certificateUploading, setCertificateUploading] = useState(false);

  const { register, handleSubmit, setValue, reset, watch, formState: { errors } } = useForm<AcademicQualFormData>({
    resolver: zodResolver(academicQualSchema),
    defaultValues: { 
      level: "UG", 
      degreeName: "", 
      institution: "", 
      schoolCollege: "",
      medium: "ENGLISH",
      passingYear: new Date().getFullYear(),
      hscStream: undefined,
      certificateUrl: "",
      marksheetUrl: "",
    },
  });

  const level = watch("level");
  const hscStream = watch("hscStream");
  const medium = watch("medium");
  const schoolCollege = watch("schoolCollege");
  const certificateUrl = watch("certificateUrl");
  const marksheetUrl = watch("marksheetUrl");

  const handleMarksheetUpload = async (file: File) => {
    setMarksheetUploading(true);
    try {
      const url = await upload("marksheet", file);
      setValue("marksheetUrl", url);
      toast.success("Marksheet uploaded successfully");
    } catch {
      toast.error("Failed to upload marksheet");
    } finally {
      setMarksheetUploading(false);
    }
  };

  const handleCertificateUpload = async (file: File) => {
    setCertificateUploading(true);
    try {
      const url = await upload("certificate", file);
      setValue("certificateUrl", url);
      toast.success("Certificate uploaded successfully");
    } catch {
      toast.error("Failed to upload certificate");
    } finally {
      setCertificateUploading(false);
    }
  };

  const getSemCount = (lvl: string): number => {
    switch (lvl) {
      case "UG": return 8;
      case "PG": return 4;
      case "DIPLOMA": return 6;
      default: return 0;
    }
  };

  const getRequiredUploads = (lvl: string) => {
    switch (lvl) {
      case "SSC":
        return { marksheet: true, certificate: false };
      case "HSC":
        return { marksheet: marksheetRequired, certificate: false, hasStream: true };
      case "DIPLOMA":
        return { marksheet: false, certificate: certificateRequired };
      case "UG":
        return { marksheet: true, certificate: true };
      case "PG":
        return { marksheet: true, certificate: true };
      case "PHD":
        return { marksheet: false, certificate: true };
      case "OTHER":
        return { marksheet: false, certificate: true };
      default:
        return { marksheet: false, certificate: false };
    }
  };

  const requiredUploads = getRequiredUploads(level);

  const openAdd = () => {
    reset({ 
      level: "UG", 
      degreeName: "", 
      institution: "", 
      schoolCollege: "",
      medium: "ENGLISH",
      passingYear: new Date().getFullYear(),
      hscStream: undefined,
      certificateUrl: "",
      marksheetUrl: "",
    });
    setEditingQual(null);
    setSemUrls([]);
    setMarksheetRequired(true);
    setCertificateRequired(true);
    setDialogOpen(true);
  };

  const openEdit = (qual: AcademicQualFormData) => {
    reset(qual);
    setEditingQual(qual);
    setSemUrls(qual.semMarksheetUrls ?? []);
    setMarksheetRequired(qual.level === "HSC" ? true : false);
    setCertificateRequired(["DIPLOMA", "UG", "PG", "PHD", "OTHER"].includes(qual.level));
    setDialogOpen(true);
  };

  const onSubmit = async (data: any) => {
    const submissionData = {
      ...data,
      id: editingQual?.id,
      semMarksheetUrls: ["UG", "PG", "DIPLOMA"].includes(data.level) ? semUrls.filter(Boolean) : undefined,
    };
    await saveQualification(submissionData);
    setDialogOpen(false);
    reset();
  };

  if (loading) {
    return (
      <Card>
        <CardContent className="pt-5 space-y-3">
          {Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-20 w-full" />)}
        </CardContent>
      </Card>
    );
  }

  const semCount = getSemCount(level);

  return (
    <>
      <Card>
        <CardContent className="pt-5 space-y-4">
          <div className="flex justify-between items-center">
            <div>
              <h3 className="text-sm font-semibold text-slate-700">Academic Qualifications</h3>
              {qualifications.length === 0 && (
                <p className="text-xs text-rose-500 mt-1 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  Academic qualifications are required
                </p>
              )}
              {qualifications.length > 0 && (
                <p className="text-xs text-emerald-600 mt-1">
                  {qualifications.length} qualification{qualifications.length > 1 ? "s" : ""} added
                </p>
              )}
            </div>
            <Button
              size="sm"
              onClick={openAdd}
              style={{ backgroundColor: "#1d3459" }}
              className="text-white text-xs hover:opacity-90"
            >
              + Add Qualification
            </Button>
          </div>

          {qualifications.length === 0 && (
            <div className="text-center py-8 text-sm text-slate-400 border border-dashed border-slate-200 rounded-lg">
              No qualifications added yet. Please add your academic qualifications.
            </div>
          )}

          <div className="space-y-3">
            {qualifications.map((q: Record<string, unknown>) => (
              <div
                key={q.id as string}
                className="p-4 bg-slate-50 rounded-lg border border-slate-100"
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <Badge className={`text-xs ${LEVEL_COLORS[q.level as string] ?? "bg-slate-100"}`}>
                        {q.level as string}
                      </Badge>
                      {q.medium && (
                        <Badge variant="outline" className="text-xs">
                          {(q.medium as string).charAt(0) + (q.medium as string).slice(1).toLowerCase()} Medium
                        </Badge>
                      )}
                      <p className="text-sm font-semibold text-slate-800">{q.degreeName as string}</p>
                      {Boolean(q.stream) && (
                        <span className="text-slate-400 font-normal ml-2">({q.stream as string})</span>
                      )}
                    </div>
                    <p className="text-xs text-slate-500 mt-1">{q.institution as string}</p>
                    {q.schoolCollege && q.level !== "SSC" && (
                      <p className="text-xs text-slate-400">School/College: {q.schoolCollege as string}</p>
                    )}
                    <div className="flex flex-wrap gap-4 mt-1.5 text-xs text-slate-400">
                      {Boolean(q.passingYear) && (
                        <span>Passing Year: <strong className="text-slate-600">{q.passingYear as number}</strong></span>
                      )}
                      {Boolean(q.percentage) && (
                        <span>Percentage: <strong className="text-slate-600">{q.percentage as number}%</strong></span>
                      )}
                      {Boolean(q.cgpa) && (
                        <span>CGPA: <strong className="text-slate-600">{q.cgpa as number}</strong></span>
                      )}
                      {Boolean(q.board) && (
                        <span>Board: <strong className="text-slate-600">{q.board as string}</strong></span>
                      )}
                    </div>
                    {Array.isArray(q.semMarksheetUrls) && (q.semMarksheetUrls as string[]).length > 0 && (
                      <div className="flex flex-wrap gap-2 mt-2">
                        {(q.semMarksheetUrls as string[]).map((url, i) => (
                          <a
                            key={i}
                            href={url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-xs px-2 py-0.5 rounded bg-[#1d3459]/10 text-[#1d3459] hover:underline"
                          >
                            Sem {i + 1}
                          </a>
                        ))}
                      </div>
                    )}
                    {Boolean(q.certificateUrl) && (
                      <a
                        href={q.certificateUrl as string}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-1 mt-1 text-xs text-[#1d3459] underline"
                      >
                        <FileText className="w-3 h-3" />
                        View Certificate
                      </a>
                    )}
                  </div>

                  <div className="flex gap-1 ml-3 shrink-0">
                    <button
                      onClick={() => openEdit(q as AcademicQualFormData)}
                      className="text-xs px-2 py-1 rounded border border-slate-200 text-slate-500 hover:bg-slate-100 transition-colors"
                    >
                      Edit
                    </button>
                    <button
                      onClick={() => setDeleteId(q.id as string)}
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
        <DialogContent className="max-w-xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>
              {editingQual ? "Edit Qualification" : "Add Qualification"}
            </DialogTitle>
          </DialogHeader>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 py-2">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="space-y-1">
                <Label>Level *</Label>
                <Select
                  defaultValue={editingQual?.level ?? "UG"}
                  onValueChange={(v) => {
                    setValue("level", v as AcademicQualFormData["level"]);
                    setMarksheetRequired(v === "HSC" || v === "SSC");
                    setCertificateRequired(["DIPLOMA", "UG", "PG", "PHD", "OTHER"].includes(v));
                  }}
                >
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {LEVELS.map((l) => <SelectItem key={l} value={l}>{l}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1">
                <Label>Medium *</Label>
                <Select
                  defaultValue={editingQual?.medium ?? "ENGLISH"}
                  onValueChange={(v) => setValue("medium", v as AcademicQualFormData["medium"])}
                >
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {MEDIUMS.map((m) => <SelectItem key={m.value} value={m.value}>{m.label}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1">
                <Label>Degree / Certificate Name *</Label>
                <Input {...register("degreeName")} placeholder="e.g., Bachelor of Science" />
                {errors.degreeName && <p className="text-xs text-rose-500">{errors.degreeName.message}</p>}
              </div>

              {level === "HSC" && (
                <div className="space-y-1">
                  <Label>Stream *</Label>
                  <Select
                    onValueChange={(v) => setValue("hscStream", v as "SCIENCE" | "COMMERCE" | "ARTS_HUMANITIES")}
                  >
                    <SelectTrigger><SelectValue placeholder="Select stream..." /></SelectTrigger>
                    <SelectContent>
                      {HSC_STREAMS.map((s) => (
                        <SelectItem key={s.value} value={s.value}>{s.label}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  {errors.hscStream && <p className="text-xs text-rose-500">{errors.hscStream.message}</p>}
                </div>
              )}

              <div className="space-y-1">
                <Label>Institution / Board / University *</Label>
                <Input {...register("institution")} placeholder="e.g., Gujarat Secondary Board" />
                {errors.institution && <p className="text-xs text-rose-500">{errors.institution.message}</p>}
              </div>

              {level !== "SSC" && (
                <div className="space-y-1">
                  <Label>School / College Name</Label>
                  <Input {...register("schoolCollege")} placeholder="e.g., XYZ College" />
                </div>
              )}

              <div className="space-y-1">
                <Label>Board / University</Label>
                <Input {...register("board")} placeholder="e.g., Gujarat University" />
              </div>

              <div className="space-y-1">
                <Label>Passing Year *</Label>
                <Input type="number" {...register("passingYear")} min={1970} max={new Date().getFullYear() + 1} />
                {errors.passingYear && <p className="text-xs text-rose-500">{errors.passingYear.message}</p>}
              </div>

              <div className="space-y-1">
                <Label>Percentage</Label>
                <Input type="number" step="0.01" {...register("percentage")} min={0} max={100} placeholder="0-100" />
              </div>

              <div className="space-y-1">
                <Label>CGPA</Label>
                <Input type="number" step="0.01" {...register("cgpa")} min={0} max={10} placeholder="0-10" />
              </div>
            </div>

            {["UG", "PG", "DIPLOMA"].includes(level) && (
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label>Semester Marksheets</Label>
                  <span className="text-xs text-slate-500">
                    {level === "DIPLOMA" ? "6 semesters" : level === "PG" ? "4 semesters" : "8 semesters"}
                  </span>
                </div>
                <SemMarksheetGrid
                  employeeId={employeeId}
                  existingUrls={semUrls}
                  semCount={semCount}
                  onUpdate={(urls) => setSemUrls(urls)}
                />
              </div>
            )}

            {(level === "SSC" || level === "HSC") && (
              <div className="space-y-2">
                <Label>Marksheet Upload {requiredUploads.marksheet && <span className="text-rose-500">*</span>}</Label>
                <div className="border-2 border-dashed border-slate-200 rounded-xl p-4">
                  {marksheetUrl ? (
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <FileText className="w-5 h-5 text-emerald-500" />
                        <span className="text-xs text-slate-600">Marksheet uploaded</span>
                      </div>
                      <button
                        type="button"
                        onClick={() => setValue("marksheetUrl", "")}
                        className="text-xs text-rose-500 hover:underline"
                      >
                        Remove
                      </button>
                    </div>
                  ) : (
                    <label className="flex flex-col items-center gap-2 cursor-pointer">
                      <input
                        type="file"
                        accept="image/*,.pdf"
                        className="hidden"
                        onChange={(e) => {
                          const file = e.target.files?.[0];
                          if (file) handleMarksheetUpload(file);
                        }}
                        disabled={marksheetUploading}
                      />
                      {marksheetUploading ? (
                        <div className="animate-spin w-6 h-6 border-2 border-[#1d3459] border-t-transparent rounded-full" />
                      ) : (
                        <>
                          <Upload className="w-6 h-6 text-slate-300" />
                          <span className="text-xs text-slate-400">
                            Click to upload marksheet (PDF/Image)
                          </span>
                        </>
                      )}
                    </label>
                  )}
                </div>
              </div>
            )}

            {requiredUploads.certificate && (
              <div className="space-y-2">
                <Label>
                  {level === "DIPLOMA" ? "Diploma Certificate" : 
                   level === "PHD" ? "PhD Certificate" : 
                   level === "OTHER" ? "Certificate" : "Degree Certificate"}
                  {" "}<span className="text-rose-500">*</span>
                </Label>
                <div className="border-2 border-dashed border-slate-200 rounded-xl p-4">
                  {certificateUrl ? (
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <FileText className="w-5 h-5 text-emerald-500" />
                        <span className="text-xs text-slate-600">Certificate uploaded</span>
                      </div>
                      <button
                        type="button"
                        onClick={() => setValue("certificateUrl", "")}
                        className="text-xs text-rose-500 hover:underline"
                      >
                        Remove
                      </button>
                    </div>
                  ) : (
                    <label className="flex flex-col items-center gap-2 cursor-pointer">
                      <input
                        type="file"
                        accept="image/*,.pdf"
                        className="hidden"
                        onChange={(e) => {
                          const file = e.target.files?.[0];
                          if (file) handleCertificateUpload(file);
                        }}
                        disabled={certificateUploading}
                      />
                      {certificateUploading ? (
                        <div className="animate-spin w-6 h-6 border-2 border-[#1d3459] border-t-transparent rounded-full" />
                      ) : (
                        <>
                          <Upload className="w-6 h-6 text-slate-300" />
                          <span className="text-xs text-slate-400">
                            Click to upload certificate (PDF/Image)
                          </span>
                        </>
                      )}
                    </label>
                  )}
                </div>
              </div>
            )}

            <DialogFooter>
              <Button type="button" variant="ghost" size="sm" onClick={() => setDialogOpen(false)}>Cancel</Button>
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
            <DialogTitle>Remove Qualification</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-slate-600 py-2">Remove this qualification record?</p>
          <DialogFooter>
            <Button type="button" variant="ghost" size="sm" onClick={() => setDeleteId(null)}>Cancel</Button>
            <Button
              type="button"
              size="sm"
              className="bg-rose-600 text-white hover:bg-rose-700"
              onClick={() => { if (deleteId) { deleteQualification(deleteId); setDeleteId(null); } }}
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
