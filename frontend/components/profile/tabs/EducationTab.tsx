"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { academicQualSchema, type AcademicQualFormData } from "@/lib/validators/academic.schema";
import { useAcademicQuals } from "@/lib/hooks/useAcademicQuals";
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

export function EducationTab({ employeeId, isAdmin }: EducationTabProps) {
  const { qualifications, loading, saving, saveQualification, deleteQualification } = useAcademicQuals(employeeId);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingQual, setEditingQual] = useState<AcademicQualFormData | null>(null);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [semUrls, setSemUrls] = useState<string[]>([]);

  const { register, handleSubmit, setValue, reset, watch, formState: { errors } } = useForm<AcademicQualFormData>({
    resolver: zodResolver(academicQualSchema),
    defaultValues: { level: "UG", degreeName: "", institution: "", passingYear: new Date().getFullYear() },
  });

  const level = watch("level");

  const openAdd = () => {
    reset({ level: "UG", degreeName: "", institution: "", passingYear: new Date().getFullYear() });
    setEditingQual(null);
    setSemUrls([]);
    setDialogOpen(true);
  };

  const openEdit = (qual: AcademicQualFormData) => {
    reset(qual);
    setEditingQual(qual);
    setSemUrls(qual.semMarksheetUrls ?? []);
    setDialogOpen(true);
  };

  const onSubmit = async (data: AcademicQualFormData) => {
    await saveQualification({
      ...data,
      id: editingQual?.id,
      semMarksheetUrls: semUrls.filter(Boolean),
    });
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

  return (
    <>
      <Card>
        <CardContent className="pt-5 space-y-4">
          <div className="flex justify-between items-center">
            <h3 className="text-sm font-semibold text-slate-700">Academic Qualifications</h3>
            {isAdmin && (
              <Button
                size="sm"
                onClick={openAdd}
                style={{ backgroundColor: "#1d3459" }}
                className="text-white text-xs hover:opacity-90"
              >
                + Add Qualification
              </Button>
            )}
          </div>

          {qualifications.length === 0 && (
            <div className="text-center py-8 text-sm text-slate-400 border border-dashed border-slate-200 rounded-lg">
              No qualifications added yet.
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
                      <p className="text-sm font-semibold text-slate-800">{q.degreeName as string}</p>
                      {q.stream && <span className="text-xs text-slate-500">({q.stream as string})</span>}
                    </div>
                    <p className="text-xs text-slate-500 mt-1">{q.institution as string}</p>
                    <div className="flex flex-wrap gap-4 mt-1.5 text-xs text-slate-400">
                      <span>Passing Year: <strong className="text-slate-600">{q.passingYear as number}</strong></span>
                      {q.percentage && <span>Percentage: <strong className="text-slate-600">{q.percentage as number}%</strong></span>}
                      {q.cgpa && <span>CGPA: <strong className="text-slate-600">{q.cgpa as number}</strong></span>}
                      {q.board && <span>Board: <strong className="text-slate-600">{q.board as string}</strong></span>}
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
                    {q.certificateUrl && (
                      <a
                        href={q.certificateUrl as string}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-block mt-1 text-xs text-[#1d3459] underline"
                      >
                        View Certificate
                      </a>
                    )}
                  </div>

                  {isAdmin && (
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
                  )}
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Add/Edit Dialog */}
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
                  onValueChange={(v) => setValue("level", v as AcademicQualFormData["level"])}
                >
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    {LEVELS.map((l) => <SelectItem key={l} value={l}>{l}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-1">
                <Label>Degree / Certificate Name *</Label>
                <Input {...register("degreeName")} />
                {errors.degreeName && <p className="text-xs text-rose-500">{errors.degreeName.message}</p>}
              </div>

              <div className="space-y-1">
                <Label>Stream / Specialization</Label>
                <Input {...register("stream")} />
              </div>

              <div className="space-y-1">
                <Label>Institution *</Label>
                <Input {...register("institution")} />
                {errors.institution && <p className="text-xs text-rose-500">{errors.institution.message}</p>}
              </div>

              <div className="space-y-1">
                <Label>Board / University</Label>
                <Input {...register("board")} />
              </div>

              <div className="space-y-1">
                <Label>Passing Year *</Label>
                <Input type="number" {...register("passingYear")} min={1970} max={new Date().getFullYear() + 1} />
                {errors.passingYear && <p className="text-xs text-rose-500">{errors.passingYear.message}</p>}
              </div>

              <div className="space-y-1">
                <Label>Percentage</Label>
                <Input type="number" step="0.01" {...register("percentage")} min={0} max={100} />
              </div>

              <div className="space-y-1">
                <Label>CGPA</Label>
                <Input type="number" step="0.01" {...register("cgpa")} min={0} max={10} />
              </div>
            </div>

            {/* Sem Marksheets — only for UG/PG/DIPLOMA */}
            {["UG", "PG", "DIPLOMA"].includes(level) && (
              <div className="space-y-2">
                <Label>Semester Marksheets</Label>
                <SemMarksheetGrid
                  employeeId={employeeId}
                  existingUrls={semUrls}
                  semCount={level === "DIPLOMA" ? 6 : 8}
                  onUpdate={(urls) => setSemUrls(urls)}
                />
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

      {/* Delete Confirm */}
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
