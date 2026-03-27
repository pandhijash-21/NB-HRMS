"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { generalInfoSchema, type GeneralInfoFormData } from "@/lib/validators/generalInfo.schema";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useMutation } from "@apollo/client/react";
import { UPDATE_EMPLOYEE_GENERAL } from "@/lib/graphql";

interface GeneralTabProps {
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

export function GeneralTab({ employee, isAdmin, onUpdate }: GeneralTabProps) {
  const [editing, setEditing] = useState(false);
  const [mutate, { loading }] = useMutation(UPDATE_EMPLOYEE_GENERAL);

  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors },
  } = useForm<GeneralInfoFormData>({
    resolver: zodResolver(generalInfoSchema),
    defaultValues: {
      fullName: (employee.fullName as string) ?? "",
      originalJoiningDate: (employee.originalJoiningDate as string)?.slice(0, 10) ?? "",
      joiningDate: (employee.joiningDate as string)?.slice(0, 10) ?? "",
      incrementMonth: (employee.incrementMonth as string) ?? "",
      organization: (employee.organization as string) ?? "",
      subOrganization: (employee.subOrganization as string) ?? "",
      department: (employee.department as string) ?? "",
      functionalDepartment: (employee.functionalDepartment as string) ?? "",
      firstReporting: (employee.firstReporting as string) ?? "",
      secondReporting: (employee.secondReporting as string) ?? "",
      employeeCategory: (employee.employeeCategory as GeneralInfoFormData["employeeCategory"]) ?? "NON_TEACHING",
      designation: (employee.designation as string) ?? "",
      shift: (employee.shift as string) ?? "",
      appointmentType: (employee.appointmentType as GeneralInfoFormData["appointmentType"]) ?? undefined,
    },
  });

  const onSubmit = async (data: GeneralInfoFormData) => {
    await mutate({
      variables: {
        employeeId: employee.id,
        set: {
          full_name: data.fullName,
          joining_date: data.joiningDate,
          original_joining_date: data.originalJoiningDate,
          designation: data.designation,
          department: data.department,
          functional_department: data.functionalDepartment,
          organization: data.organization,
          sub_organization: data.subOrganization,
          employee_category: data.employeeCategory,
          appointment_type: data.appointmentType,
          shift: data.shift,
          first_reporting: data.firstReporting,
          second_reporting: data.secondReporting,
          increment_month: data.incrementMonth,
        },
      },
    });
    setEditing(false);
    onUpdate?.();
  };

  if (!editing) {
    return (
      <Card>
        <CardContent className="pt-5 space-y-5">
          <div className="flex justify-between items-center">
            <h3 className="text-sm font-semibold text-slate-700">General Information</h3>
            <Button
              size="sm"
              variant="outline"
              onClick={() => setEditing(true)}
              className="text-xs border-[#1d3459] text-[#1d3459] hover:bg-[#1d3459] hover:text-white"
            >
              Edit
            </Button>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
            <Field label="Full Name" value={employee.fullName as string} />
            <Field label="Designation" value={employee.designation as string} />
            <Field label="Department" value={employee.department as string} />
            <Field label="Functional Department" value={employee.functionalDepartment as string} />
            <Field label="Organization" value={employee.organization as string} />
            <Field label="Sub-Organization" value={employee.subOrganization as string} />
            <Field label="Employee Category" value={(employee.employeeCategory as string)?.replace("_", " ")} />
            <Field label="Appointment Type" value={(employee.appointmentType as string)?.replace(/_/g, " ")} />
            <Field label="Shift" value={employee.shift as string} />
            <Field label="Joining Date" value={employee.joiningDate ? new Date(employee.joiningDate as string).toLocaleDateString("en-IN") : undefined} />
            <Field label="Original Joining Date" value={employee.originalJoiningDate ? new Date(employee.originalJoiningDate as string).toLocaleDateString("en-IN") : undefined} />
            <Field label="Increment Month" value={employee.incrementMonth as string} />
            <Field label="First Reporting" value={employee.firstReporting as string} />
            <Field label="Second Reporting" value={employee.secondReporting as string} />
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardContent className="pt-5">
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
          <div className="flex justify-between items-center">
            <h3 className="text-sm font-semibold text-slate-700">Edit General Information</h3>
            <div className="flex gap-2">
              <Button
                type="button"
                size="sm"
                variant="ghost"
                onClick={() => setEditing(false)}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={loading}
                style={{ backgroundColor: "#1d3459" }}
                className="text-white hover:opacity-90"
              >
                {loading ? "Saving…" : "Save"}
              </Button>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <div className="space-y-1">
              <Label>Full Name *</Label>
              <Input {...register("fullName")} />
              {errors.fullName && (
                <p className="text-xs text-rose-500">{errors.fullName.message}</p>
              )}
            </div>
            <div className="space-y-1">
              <Label>Designation *</Label>
              <Input {...register("designation")} />
              {errors.designation && (
                <p className="text-xs text-rose-500">{errors.designation.message}</p>
              )}
            </div>
            <div className="space-y-1">
              <Label>Department *</Label>
              <Input {...register("department")} />
              {errors.department && (
                <p className="text-xs text-rose-500">{errors.department.message}</p>
              )}
            </div>
            <div className="space-y-1">
              <Label>Functional Department</Label>
              <Input {...register("functionalDepartment")} />
            </div>
            <div className="space-y-1">
              <Label>Organization *</Label>
              <Input {...register("organization")} />
              {errors.organization && (
                <p className="text-xs text-rose-500">{errors.organization.message}</p>
              )}
            </div>
            <div className="space-y-1">
              <Label>Sub-Organization</Label>
              <Input {...register("subOrganization")} />
            </div>
            <div className="space-y-1">
              <Label>Employee Category *</Label>
              <Select
                defaultValue={(employee.employeeCategory as string) ?? "NON_TEACHING"}
                onValueChange={(v) => setValue("employeeCategory", v as GeneralInfoFormData["employeeCategory"])}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {["TEACHING", "NON_TEACHING", "CONTRACT", "VISITING"].map((c) => (
                    <SelectItem key={c} value={c}>{c.replace("_", " ")}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1">
              <Label>Appointment Type</Label>
              <Select
                defaultValue={(employee.appointmentType as string) ?? ""}
                onValueChange={(v) => setValue("appointmentType", v as GeneralInfoFormData["appointmentType"])}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select..." />
                </SelectTrigger>
                <SelectContent>
                  {["FULL_TIME_REGULAR", "FULL_TIME_CONTRACT", "PART_TIME", "VISITING", "DEPUTATION"].map((t) => (
                    <SelectItem key={t} value={t}>{t.replace(/_/g, " ")}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1">
              <Label>Shift</Label>
              <Input {...register("shift")} placeholder="e.g. Morning" />
            </div>
            <div className="space-y-1">
              <Label>Joining Date *</Label>
              <Input type="date" {...register("joiningDate")} />
              {errors.joiningDate && (
                <p className="text-xs text-rose-500">{errors.joiningDate.message}</p>
              )}
            </div>
            <div className="space-y-1">
              <Label>Original Joining Date *</Label>
              <Input type="date" {...register("originalJoiningDate")} />
            </div>
            <div className="space-y-1">
              <Label>Increment Month</Label>
              <Input {...register("incrementMonth")} placeholder="e.g. July" />
            </div>
            <div className="space-y-1">
              <Label>First Reporting Manager</Label>
              <Input {...register("firstReporting")} />
            </div>
            <div className="space-y-1">
              <Label>Second Reporting Manager</Label>
              <Input {...register("secondReporting")} />
            </div>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
