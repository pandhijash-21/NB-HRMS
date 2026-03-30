"use client";

import { useState } from "react";
import { useForm, SubmitHandler } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Checkbox } from "@/components/ui/checkbox";
import { useOtherInfo, useUpdateOtherInfo } from "../../hooks/useProfile";
import { Skeleton } from "@/components/ui/skeleton";
import { Sparkles, Edit3, Save, X, Ruler, Weight, UserCheck } from "lucide-react";

const otherSchema = z.object({
  skillSet: z.string().nullable().optional(),
  hobbies: z.string().nullable().optional(),
  strength: z.string().nullable().optional(),
  weakness: z.string().nullable().optional(),
  isHandicapped: z.boolean().optional(),
  handicapDetails: z.string().nullable().optional(),
  heightInFeet: z.number().positive().nullable().optional(),
  weightInKg: z.number().positive().nullable().optional(),
});

type OtherFormData = z.infer<typeof otherSchema>;

interface OtherTabProps {
  employeeId: string | number;
}

function ReadOnlyField({ label, value, icon: Icon }: { label: string; value?: string | number | boolean | null; icon?: React.ElementType }) {
  const displayValue = typeof value === "boolean" ? (value ? "Yes" : "No") : value;
  
  return (
    <div className="space-y-1 p-3 rounded-lg bg-slate-50/50 border border-transparent hover:border-slate-100 transition-all">
      <div className="flex items-center gap-1.5 mb-0.5">
        {Icon && <Icon className="w-3 h-3 text-slate-400" />}
        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{label}</p>
      </div>
      <p className="text-sm font-semibold text-slate-700">{displayValue || "—"}</p>
    </div>
  );
}

export function OtherTab({ employeeId }: OtherTabProps) {
  const [isEditing, setIsEditing] = useState(false);
  const { data: other, isLoading } = useOtherInfo(employeeId);
  const updateMutation = useUpdateOtherInfo(employeeId);

  const { register, handleSubmit, setValue, watch, formState: { errors } } = useForm<OtherFormData>({
    resolver: zodResolver(otherSchema),
    values: other ? {
      skillSet: (other as any).skillSet ?? null,
      hobbies: other.hobbies ?? null,
      strength: (other as any).strength ?? null,
      weakness: (other as any).weakness ?? null,
      isHandicapped: (other as any).isHandicapped ?? false,
      handicapDetails: (other as any).handicapDetails ?? null,
      heightInFeet: other.height ?? null,
      weightInKg: other.weight ?? null,
    } : undefined
  });

  const onSubmit: SubmitHandler<OtherFormData> = (data) => {
    updateMutation.mutate(data, {
      onSuccess: () => setIsEditing(false),
    });
  };

  if (isLoading) return <Skeleton className="h-[300px] w-full rounded-2xl" />;

  return (
    <Card className="border-none shadow-none bg-transparent">
      <CardHeader className="px-0 pt-0 pb-6 flex flex-row items-center justify-between space-y-0">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <Sparkles className="w-4 h-4 text-[#1d3459]" />
            <CardTitle className="text-sm font-bold text-slate-800 uppercase tracking-tight">
              Talents &amp; Attributes
            </CardTitle>
          </div>
          <p className="text-[11px] text-slate-500 font-medium">
            Personal skills, hobbies, and physical measurements.
          </p>
        </div>
        {!isEditing ? (
          <Button 
            onClick={() => setIsEditing(true)}
            size="sm" 
            variant="outline" 
            className="h-8 border-[#1d3459]/20 text-[#1d3459] hover:bg-[#1d3459] hover:text-white transition-all gap-2 px-4 rounded-xl font-bold text-[10px] uppercase"
          >
            <Edit3 className="w-3 h-3" /> Edit Info
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
              className="h-8 bg-[#d9b557] hover:bg-[#c9a547] text-[#1d3459] font-bold text-[10px] uppercase gap-2 px-4 rounded-xl shadow-lg"
            >
              {updateMutation.isPending ? <Save className="w-3 h-3 animate-pulse" /> : <Save className="w-3 h-3" />}
              Save Changes
            </Button>
          </div>
        )}
      </CardHeader>
      <CardContent className="px-0">
        <div className="bg-white/50 border border-slate-100 rounded-2xl p-6 shadow-sm">
          {!isEditing ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <div className="lg:col-span-1">
                <ReadOnlyField label="Skills / Proficiencies" value={(other as any)?.skillSet ?? other?.skills} />
              </div>
              <div className="lg:col-span-1">
                <ReadOnlyField label="Interests & Hobbies" value={other?.hobbies} />
              </div>
              <ReadOnlyField label="Height (ft)" value={other?.height} icon={Ruler} />
              <ReadOnlyField label="Weight (kg)" value={other?.weight} icon={Weight} />
              <ReadOnlyField label="Handicapped?" value={(other as any)?.isHandicapped} icon={UserCheck} />
              {(other as any)?.isHandicapped && (
                <div className="lg:col-span-3">
                   <ReadOnlyField label="Handicap Details" value={(other as any)?.handicapDetails} />
                </div>
              )}
              <div className="lg:col-span-3 grid grid-cols-1 md:grid-cols-2 gap-6 pt-4 border-t border-slate-50 mt-2">
                  <ReadOnlyField label="Strengths" value={(other as any)?.strength} />
                  <ReadOnlyField label="Weaknesses" value={(other as any)?.weakness} />
              </div>
            </div>
          ) : (
            <form className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                <div className="space-y-1.5 md:col-span-2">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Skill Set</Label>
                  <Input {...register("skillSet")} className="h-10 rounded-xl" placeholder="e.g. React, Node.js, Project Management" />
                </div>
                <div className="space-y-1.5 md:col-span-2">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Hobbies</Label>
                  <Input {...register("hobbies")} className="h-10 rounded-xl" placeholder="e.g. Reading, Traveling, Chess" />
                </div>
                <div className="space-y-1.5 md:col-span-1">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Height (Feet)</Label>
                  <Input
                    type="number"
                    step="0.1"
                    className="h-10 rounded-xl"
                    onChange={(e) => setValue("heightInFeet", e.target.value ? parseFloat(e.target.value) : null)}
                  />
                  {errors.heightInFeet && <p className="text-[10px] text-rose-500">{errors.heightInFeet.message}</p>}
                </div>
                <div className="space-y-1.5 md:col-span-1">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Weight (Kg)</Label>
                  <Input
                    type="number"
                    step="0.1"
                    className="h-10 rounded-xl"
                    onChange={(e) => setValue("weightInKg", e.target.value ? parseFloat(e.target.value) : null)}
                  />
                  {errors.weightInKg && <p className="text-[10px] text-rose-500">{errors.weightInKg.message}</p>}
                </div>
                
                <div className="md:col-span-2 flex items-center space-x-2 py-2">
                  <Checkbox 
                    id="isHandicapped" 
                    checked={watch("isHandicapped") ?? false}
                    onCheckedChange={(checked: boolean) => setValue("isHandicapped", checked)}
                  />
                  <Label htmlFor="isHandicapped" className="text-sm font-medium text-slate-700">Physical Handicap / Disability</Label>
                </div>

                {watch("isHandicapped") && (
                  <div className="space-y-1.5 md:col-span-2 animate-in slide-in-from-top-2">
                    <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Handicap Details</Label>
                    <Input {...register("handicapDetails")} className="h-10 rounded-xl" placeholder="Please specify nature of disability" />
                  </div>
                )}

                <div className="space-y-1.5">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Strengths</Label>
                  <Input {...register("strength")} className="h-10 rounded-xl" />
                </div>
                <div className="space-y-1.5">
                  <Label className="text-[10px] font-bold text-slate-500 uppercase ml-1">Weaknesses</Label>
                  <Input {...register("weakness")} className="h-10 rounded-xl" />
                </div>
              </div>
            </form>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
