"use client";

import { useState, useMemo } from "react";
import { useForm, SubmitHandler } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { useAcademicQualifications, useAcademicActions } from "../../hooks/useProfile";
import { Skeleton } from "@/components/ui/skeleton";
import { GraduationCap, Plus, Trash2, School, Calendar, Award, FileText, ExternalLink } from "lucide-react";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger, DialogFooter } from "@/components/ui/dialog";

const academicSchema = z.object({
  degreeType: z.enum(['SSC', 'HSC', 'DIPLOMA', 'BACHELOR', 'MASTER', 'PHD']),
  degreeName: z.string().min(1, "Degree name is required"),
  boardUniversity: z.string().min(1, "Required"),
  schoolCollege: z.string().min(1, "Required"),
  passingYear: z.number().int().min(1950).max(new Date().getFullYear()),
  percentage: z.number().min(0).max(100).optional().nullable(),
  grade: z.string().optional().nullable(),
  specialization: z.string().optional().nullable(),
  certificateUrl: z.string().url().optional().nullable().or(z.literal('')),
});

type AcademicFormData = z.infer<typeof academicSchema>;

interface EducationTabProps {
  employeeId: string | number;
}

export function EducationTab({ employeeId }: EducationTabProps) {
  const [open, setOpen] = useState(false);
  const { data: qualifications, isLoading } = useAcademicQualifications(employeeId);
  const { addMutation } = useAcademicActions(employeeId);

  const { register, handleSubmit, setValue, reset, watch, formState: { errors } } = useForm<AcademicFormData>({
    resolver: zodResolver(academicSchema),
  });

  const onSubmit: SubmitHandler<AcademicFormData> = (data) => {
    addMutation.mutate(data, {
      onSuccess: () => {
        setOpen(false);
        reset();
      },
    });
  };

  if (isLoading) return <Skeleton className="h-[400px] rounded-2xl" />;

  return (
    <Card className="border-none shadow-none bg-transparent">
      <CardHeader className="px-0 pt-0 pb-6 flex flex-row items-center justify-between space-y-0">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <GraduationCap className="w-4 h-4 text-[#1d3459]" />
            <CardTitle className="text-sm font-bold text-slate-800 uppercase tracking-tight">
              Academic Background
            </CardTitle>
          </div>
          <p className="text-[11px] text-slate-500 font-medium">
            Your educational qualifications and certifications.
          </p>
        </div>
        
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button size="sm" className="bg-[#1d3459] hover:bg-[#1d3459]/90 text-white rounded-xl px-4 gap-2 font-bold text-[10px] uppercase">
                <Plus className="w-3 h-3" /> Add Qualification
            </Button>
          </DialogTrigger>
          <DialogContent className="max-w-lg rounded-2xl border-none shadow-2xl">
            <DialogHeader>
              <DialogTitle className="text-lg font-bold text-slate-800">Add Academic Record</DialogTitle>
            </DialogHeader>
            <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 py-2">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Type *</Label>
                  <Select onValueChange={(v) => setValue("degreeType", v as AcademicFormData["degreeType"])}>
                    <SelectTrigger className="rounded-xl h-10">
                        <SelectValue placeholder="Select..." />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="SSC">SSC (10th)</SelectItem>
                        <SelectItem value="HSC">HSC (12th)</SelectItem>
                        <SelectItem value="DIPLOMA">Diploma</SelectItem>
                        <SelectItem value="BACHELOR">Bachelor&apos;s</SelectItem>
                        <SelectItem value="MASTER">Master&apos;s</SelectItem>
                        <SelectItem value="PHD">PhD</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-1.5">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Degree Name *</Label>
                  <Input {...register("degreeName")} className="rounded-xl h-10" placeholder="e.g. B.Tech CSE" />
                  {errors.degreeName && <p className="text-[10px] text-rose-500">{errors.degreeName.message}</p>}
                </div>
                <div className="space-y-1.5 col-span-2">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">
                    {watch("degreeType") === "SSC" ? "Board *" : "University / Board *"}
                  </Label>
                  <Input {...register("boardUniversity")} className="rounded-xl h-10" />
                </div>
                <div className="space-y-1.5 col-span-2">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">
                    {watch("degreeType") === "SSC" ? "School Name *" : "Institution / College Name *"}
                  </Label>
                  <Input {...register("schoolCollege")} className="rounded-xl h-10" />
                </div>
                <div className="space-y-1.5">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Passing Year *</Label>
                  <Input
                    type="number"
                    className="rounded-xl h-10"
                    onChange={(e) => setValue("passingYear", parseInt(e.target.value, 10))}
                  />
                  {errors.passingYear && <p className="text-[10px] text-rose-500">{errors.passingYear.message}</p>}
                </div>
                <div className="space-y-1.5">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Percentage / CGPA</Label>
                  <Input
                    type="number"
                    step="0.01"
                    className="rounded-xl h-10"
                    onChange={(e) => setValue("percentage", e.target.value ? parseFloat(e.target.value) : null)}
                  />
                </div>
              </div>

              <DialogFooter className="pt-4">
                <Button type="submit" disabled={addMutation.isPending} className="w-full bg-[#d9b557] hover:bg-[#c9a547] text-[#1d3459] font-bold uppercase text-[10px] h-10 rounded-xl">
                    {addMutation.isPending ? "Saving..." : "Add Record"}
                </Button>
              </DialogFooter>
            </form>
          </DialogContent>
        </Dialog>
      </CardHeader>

      <CardContent className="px-0">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {qualifications && qualifications.length > 0 ? (
            qualifications.map((q) => (
              <div key={q.id} className="bg-white/50 border border-slate-100 rounded-2xl p-5 shadow-sm hover:shadow-md transition-all group">
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-[#1d3459]/5 flex items-center justify-center text-[#1d3459]">
                      <School className="w-5 h-5" />
                    </div>
                    <div>
                      <h4 className="font-bold text-slate-800 text-sm leading-tight">{q.degreeName}</h4>
                      <p className="text-[10px] font-bold text-[#d9b557] uppercase tracking-wider">{(q as any).degreeType}</p>
                    </div>
                  </div>
                  <Badge variant="outline" className="bg-emerald-50 text-emerald-600 border-none text-[9px] font-bold uppercase">
                    {(q as any).isVerified ? "Verified" : "Pending"}
                  </Badge>
                </div>

                <div className="mt-4 space-y-3">
                  <div className="flex items-center gap-2 text-xs text-slate-500">
                    <Award className="w-3.5 h-3.5 text-slate-300" />
                    <span className="font-medium">{(q as any).boardUniversity}</span>
                  </div>
                  <div className="flex items-center gap-2 text-xs text-slate-500">
                    <Calendar className="w-3.5 h-3.5 text-slate-300" />
                    <span className="font-medium text-slate-400">Class of {(q as any).passingYear}</span>
                    {(q as any).percentage && (
                      <>
                        <span className="w-1 h-1 rounded-full bg-slate-300 mx-1" />
                        <span className="font-bold text-slate-700">{(q as any).percentage}%</span>
                      </>
                    )}
                  </div>
                </div>

                {/* Certificate + Sem-wise marksheets */}
                <div className="mt-5 pt-4 border-t border-slate-50 space-y-3">
                  {/* Certificate */}
                  <div className="flex items-center justify-between">
                    {q.certificateUrl ? (
                      <a href={q.certificateUrl} target="_blank" rel="noreferrer"
                        className="flex items-center gap-1.5 text-[10px] font-bold text-[#1d3459] hover:underline uppercase tracking-widest">
                        <FileText className="w-3 h-3" /> Certificate <ExternalLink className="w-2.5 h-2.5" />
                      </a>
                    ) : (
                      <span className="text-[9px] text-slate-300 font-bold uppercase tracking-widest">No Certificate</span>
                    )}
                    <div className="opacity-0 group-hover:opacity-100 transition-opacity">
                      <Button variant="ghost" size="icon" className="h-7 w-7 text-rose-400 hover:text-rose-500 hover:bg-rose-50">
                        <Trash2 className="w-3.5 h-3.5" />
                      </Button>
                    </div>
                  </div>

                  {/* Sem-wise Marksheets — only for relevant degree types */}
                  {['DIPLOMA', 'BACHELOR', 'MASTER', 'PHD'].includes((q as any).degreeType) && (
                    <div>
                      <p className="text-[9px] font-bold text-slate-400 uppercase tracking-widest mb-2">Semester Marksheets</p>
                      <div className="grid grid-cols-4 gap-1.5">
                        {[1, 2, 3, 4, 5, 6, 7, 8].map((sem) => {
                          const urlKey = `sem${sem}MarksheetUrl` as keyof typeof q;
                          const url = (q as any)[urlKey] as string | null;
                          return (
                            <div key={sem}>
                              {url ? (
                                <a href={url} target="_blank" rel="noreferrer"
                                  className="flex items-center justify-center py-1.5 rounded-lg bg-emerald-50 border border-emerald-100 text-[9px] font-bold text-emerald-600 hover:bg-emerald-100 transition-colors gap-1">
                                  <ExternalLink className="w-2.5 h-2.5" /> Sem {sem}
                                </a>
                              ) : (
                                <label className="flex items-center justify-center py-1.5 rounded-lg bg-slate-50 border border-dashed border-slate-200 text-[9px] font-bold text-slate-400 cursor-pointer hover:border-[#1d3459]/30 hover:text-[#1d3459] transition-colors">
                                  +&nbsp;S{sem}
                                  <input type="file" accept="application/pdf,image/*" className="hidden" />
                                </label>
                              )}
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  )}
                </div>

              </div>
            ))
          ) : (
            <div className="col-span-full py-12 text-center bg-slate-50 rounded-2xl border border-dashed border-slate-200 text-sm text-slate-400 font-medium">
                No academic records found.
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
