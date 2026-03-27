"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from "@/components/ui/select";
import { useMutation } from "@apollo/client/react";
import { UPDATE_EMPLOYEE_SALARY } from "@/lib/graphql";

const salarySchema = z.object({
  payCommission: z.string().optional(),
  payGrade: z.string().optional(),
  basicSalary: z.coerce.number().optional(),
  agp: z.coerce.number().optional(),
  grossSalary: z.coerce.number().optional(),
});

type SalaryFormData = z.infer<typeof salarySchema>;

interface SalaryTabProps {
  employee: Record<string, unknown>;
  isAdmin?: boolean;
}

function Field({ label, value }: { label: string; value?: string | number | null }) {
  return (
    <div>
      <p className="text-xs text-slate-500 mb-0.5">{label}</p>
      <p className="text-sm font-medium text-slate-800">{value || "—"}</p>
    </div>
  );
}

export function SalaryTab({ employee, isAdmin }: SalaryTabProps) {
  const [editing, setEditing] = useState(false);
  const [mutate, { loading }] = useMutation(UPDATE_EMPLOYEE_SALARY);

  const { register, handleSubmit, setValue } = useForm<SalaryFormData>({
    // @ts-expect-error - zod resolver type mismatch for optional fields
    resolver: zodResolver(salarySchema),
    defaultValues: {
      payCommission: (employee.payCommission as string) ?? "",
      payGrade: (employee.payGrade as string) ?? "",
      basicSalary: (employee.basicSalary as number) ?? undefined,
      agp: (employee.agp as number) ?? undefined,
      grossSalary: (employee.grossSalary as number) ?? undefined,
    },
  });

  const onSubmit = async (data: any) => {
    await mutate({
      variables: {
        employeeId: employee.id,
        set: {
          pay_commission: data.payCommission,
          pay_grade: data.payGrade,
          basic_salary: data.basicSalary,
          agp: data.agp,
          gross_salary: data.grossSalary,
        },
      },
    });
    setEditing(false);
  };

  if (!editing) {
    return (
      <Card>
        <CardContent className="pt-5 space-y-5">
          <div className="flex justify-between items-center">
            <h3 className="text-sm font-semibold text-slate-700">Salary Information</h3>
            {isAdmin && (
              <Button size="sm" variant="outline" onClick={() => setEditing(true)} className="text-xs border-[#1d3459] text-[#1d3459] hover:bg-[#1d3459] hover:text-white">
                Edit
              </Button>
            )}
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5 bg-white/30 backdrop-blur-md p-4 rounded-xl border border-white/50 shadow-sm">
            <Field label="Pay Commission" value={employee.payCommission as string} />
            <Field label="AGP" value={employee.agp as number} />
            <div className="hidden sm:block"></div> {/* Spacer to match layout */}
            <Field label="Pay Grade" value={employee.payGrade as string} />
            <Field label="Gross Salary" value={(employee.grossSalary as number) ? `₹${employee.grossSalary}` : undefined} />
            <div className="hidden sm:block"></div>
            <Field label="Basic Salary" value={(employee.basicSalary as number) ? `₹${employee.basicSalary}` : undefined} />
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
            <h3 className="text-sm font-semibold text-slate-700">Edit Salary Information</h3>
            <div className="flex gap-2">
              <Button type="button" size="sm" variant="ghost" onClick={() => setEditing(false)}>Cancel</Button>
              <Button type="submit" size="sm" disabled={loading} style={{ backgroundColor: "#1d3459" }} className="text-white hover:opacity-90">
                {loading ? "Saving…" : "Save"}
              </Button>
            </div>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 bg-white/40 backdrop-blur-lg p-5 rounded-2xl border border-white/40 shadow">
            <div className="space-y-1">
              <Label>Pay Commission</Label>
              <Select defaultValue={(employee.payCommission as string) ?? ""} onValueChange={(v) => setValue("payCommission", v)}>
                 <SelectTrigger className="bg-white/50"><SelectValue placeholder="Select" /></SelectTrigger>
                 <SelectContent>
                    <SelectItem value="5TH PAY">5TH PAY</SelectItem>
                    <SelectItem value="6TH PAY">6TH PAY</SelectItem>
                    <SelectItem value="7TH PAY">7TH PAY</SelectItem>
                    <SelectItem value="CONSOLIDATED">CONSOLIDATED</SelectItem>
                 </SelectContent>
              </Select>
            </div>
            <div className="space-y-1">
              <Label>AGP</Label>
              <Input type="number" {...register("agp")} className="bg-white/50" />
            </div>
            <div className="space-y-1 hidden lg:block"></div>
            <div className="space-y-1">
              <Label>Pay Grade</Label>
              <Input {...register("payGrade")} className="bg-white/50" />
            </div>
            <div className="space-y-1">
              <Label>Gross Salary</Label>
              <Input type="number" {...register("grossSalary")} className="bg-white/50" />
            </div>
            <div className="space-y-1 hidden lg:block"></div>
            <div className="space-y-1">
              <Label>Basic Salary</Label>
              <Input type="number" {...register("basicSalary")} className="bg-white/50" />
            </div>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
