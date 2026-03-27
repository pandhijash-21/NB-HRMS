"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useMutation } from "@apollo/client/react";
import { UPDATE_EMPLOYEE_OTHER, UPDATE_EMPLOYEE_PERSONAL } from "@/lib/graphql";

const otherInfoSchema = z.object({
  skillSet: z.string().optional(),
  strength: z.string().optional(),
  weakness: z.string().optional(),
  isHandicapped: z.boolean().optional(),
  hobbies: z.string().optional(),
  panNo: z.string().optional(),
  aadhaarNo: z.string().optional(),
  passportNo: z.string().optional(),
  passportIssuePlace: z.string().optional(),
  heightInFeet: z.coerce.number().optional(),
  weightInKg: z.coerce.number().optional(),
  passportIssueDate: z.string().optional(),
  passportExpiryDate: z.string().optional(),
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

export function OtherTab({ employee, employeeId, isAdmin, onUpdate }: OtherTabProps) {
  const [editing, setEditing] = useState(false);
  
  const [mutateOther] = useMutation(UPDATE_EMPLOYEE_OTHER);
  const [mutatePersonal] = useMutation(UPDATE_EMPLOYEE_PERSONAL);
  const [saving, setSaving] = useState(false);

  const { register, handleSubmit, formState: { errors } } = useForm<OtherFormData>({
    // @ts-expect-error - zod resolver mismatch for coerced numbers
    resolver: zodResolver(otherInfoSchema),
    defaultValues: {
      skillSet: (employee.skillSet as string) ?? "",
      strength: (employee.strength as string) ?? "",
      weakness: (employee.weakness as string) ?? "",
      isHandicapped: (employee.isHandicapped as boolean) ?? false,
      hobbies: (employee.hobbies as string) ?? "",
      panNo: (employee.panNo as string) ?? "",
      aadhaarNo: (employee.aadhaarNo as string) ?? "",
      passportNo: (employee.passportNo as string) ?? "",
      passportIssuePlace: (employee.passportIssuePlace as string) ?? "",
      heightInFeet: (employee.heightInFeet as number) ?? undefined,
      weightInKg: (employee.weightInKg as number) ?? undefined,
      passportIssueDate: (employee.passportIssueDate as string)?.slice(0, 10) ?? "",
      passportExpiryDate: (employee.passportExpiryDate as string)?.slice(0, 10) ?? "",
    },
  });

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
            height_in_feet: data.heightInFeet,
            weight_in_kg: data.weightInKg,
          },
        },
      });

      await mutatePersonal({
         variables: {
            employeeId: employee.id,
            set: {
               pan_no: data.panNo,
               aadhaar_no: data.aadhaarNo,
               passport_no: data.passportNo,
               passport_issue_place: data.passportIssuePlace,
               passport_issue_date: data.passportIssueDate || null,
               passport_expiry_date: data.passportExpiryDate || null,
            }
         }
      })
      setEditing(false);
      onUpdate?.();
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

            <Field label="PAN No" value={employee.panNo as string} />
            <Field label="Adhaar No" value={employee.aadhaarNo as string} />
            <div className="hidden lg:block"></div>

            <Field label="Passport No" value={employee.passportNo as string} />
            <Field label="Passport Issue Date" value={employee.passportIssueDate ? new Date(employee.passportIssueDate as string).toLocaleDateString("en-IN") : undefined} />
            <div className="hidden lg:block"></div>

            <Field label="Passport Issue Place" value={employee.passportIssuePlace as string} />
            <Field label="Passport Expiry Dat" value={employee.passportExpiryDate ? new Date(employee.passportExpiryDate as string).toLocaleDateString("en-IN") : undefined} />
            <div className="hidden lg:block"></div>

            <Field label="Height (In Feet)" value={employee.heightInFeet as number} />
            <Field label="Weight (In Kg)" value={employee.weightInKg as number} />
            <div className="hidden lg:block"></div>
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

            <div className="space-y-1">
              <Label>PAN No</Label>
              <Input {...register("panNo")} className="bg-white/50 uppercase" />
            </div>
            <div className="space-y-1">
              <Label>Aadhaar No</Label>
              <Input {...register("aadhaarNo")} className="bg-white/50" />
            </div>
            <div className="hidden lg:block"></div>

            <div className="space-y-1">
              <Label>Passport No</Label>
              <Input {...register("passportNo")} className="bg-white/50 uppercase" />
            </div>
            <div className="space-y-1">
              <Label>Passport Issue Date</Label>
              <Input type="date" {...register("passportIssueDate")} className="bg-white/50" />
            </div>
            <div className="hidden lg:block"></div>
            
            <div className="space-y-1">
              <Label>Passport Issue Place</Label>
              <Input {...register("passportIssuePlace")} className="bg-white/50" />
            </div>
            <div className="space-y-1">
              <Label>Passport Expiry Date</Label>
              <Input type="date" {...register("passportExpiryDate")} className="bg-white/50" />
            </div>
            <div className="hidden lg:block"></div>

            <div className="space-y-1">
              <Label>Height (In Feet)</Label>
              <Input type="number" step="0.01" {...register("heightInFeet")} className="bg-white/50" />
            </div>
            <div className="space-y-1">
              <Label>Weight (In Kg)</Label>
              <Input type="number" step="0.01" {...register("weightInKg")} className="bg-white/50" />
            </div>

          </div>
        </form>
      </CardContent>
    </Card>
  );
}
