"use client";

import { useMemo, useState } from "react";
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
import { useEmployeeNames } from "@/modules/admin/hooks/useAdminEmployees";
import { DESIGNATIONS } from "@/lib/constants/designations";
import { Badge } from "@/components/ui/badge";

const INSTITUTES = [
  "Gandhinagar Institute of Technology",
  "Gandhinagar Institute of Management",
  "Gandhinagar Institute of Commerce",
  "Gandhinagar Institute of Science",
  "Gandhinagar Institute of Research & Development",
  "Gandhinagar Institute of Liberal Studies",
  "Gandhinagar Institute of Computer Science & Applications",
  "Gandhinagar Institute of Law",
  "Gandhinagar Institute of Valuation Studies",
  "Gandhinagar Institute of Design",
  "Gandhinagar Institute of Pharmacy",
  "Gandhinagar Institute of Nursing",
  "Gandhinagar Institute of Skill Development",
  "Gandhinagar Institute of Library & Information Science",
  "Gandhinagar Institute of Vocational Education",
];

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
  const { data: employeeNames = [] } = useEmployeeNames();

  const selectableEmployees = useMemo(() => {
    return employeeNames;
  }, [employeeNames, employee.id]);

  const resolveApproverLabel = (userId?: string | null) => {
    if (!userId) return null;
    const match = employeeNames.find((e) => e.userId === userId);
    if (!match) return userId;
    return `${match.fullName}${match.employeeCode ? ` (${match.employeeCode})` : ""}`;
  };

  const {
    register,
    handleSubmit,
    setValue,
    watch,
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
      firstApproverUserId: (employee.firstApproverUserId as string | null) ?? null,
      secondApproverUserId: (employee.secondApproverUserId as string | null) ?? null,
      thirdApproverUserId: (employee.thirdApproverUserId as string | null) ?? null,
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
          first_approver_user_id: data.firstApproverUserId ?? null,
          second_approver_user_id: data.secondApproverUserId ?? null,
          third_approver_user_id: data.thirdApproverUserId ?? null,
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
            <h3 className="text-sm font-semibold text-slate-700">
              {isAdmin ? "General Information" : "Employment Records"}
            </h3>
            {isAdmin && (
              <Button
                size="sm"
                variant="outline"
                onClick={() => setEditing(true)}
                className="text-xs border-[#1d3459] text-[#1d3459] hover:bg-[#1d3459] hover:text-white"
              >
                Edit
              </Button>
            )}
          </div>
          {!isAdmin && (
            <p className="text-xs text-slate-400">
              Official institutional data provided by the Registrar/HR office. These details are read-only.
            </p>
          )}


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
            <Field label="First Reporting" value={resolveApproverLabel(employee.firstApproverUserId as string | null)} />
            <Field label="Second Reporting" value={resolveApproverLabel(employee.secondApproverUserId as string | null)} />
            <Field label="Third Reporting" value={resolveApproverLabel(employee.thirdApproverUserId as string | null)} />
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

          <div className="rounded-xl border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800">
            <div className="font-semibold">Institute transfer & promotion history</div>
            <div className="mt-0.5">
              Designation/Sub-Organization changes are tracked via <span className="font-semibold">Institute Transfer</span> and{" "}
              <span className="font-semibold">Designation Upgrade</span> (effective-dated). They are read-only here to preserve history.
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
              <Select
                value={watch("designation")}
                onValueChange={(v) => setValue("designation", v, { shouldValidate: true })}
                disabled
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select designation..." />
                </SelectTrigger>
                <SelectContent className="max-h-[240px]">
                  {/* keep current value selectable even if it's not in the predefined list */}
                  {watch("designation") && !(DESIGNATIONS as readonly string[]).includes(watch("designation")) ? (
                    <SelectItem value={watch("designation")}>
                      {watch("designation")} (existing)
                    </SelectItem>
                  ) : null}
                  {DESIGNATIONS.map((d) => (
                    <SelectItem key={d} value={d}>
                      {d}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <div className="flex gap-2 flex-wrap">
                <Badge variant="outline" className="text-[10px]">Managed via Designation Upgrade</Badge>
              </div>
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
              <Select
                defaultValue={(employee.subOrganization as string) ?? ""}
                onValueChange={(v) => setValue("subOrganization", v)}
                disabled
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select institute..." />
                </SelectTrigger>
                <SelectContent>
                  {INSTITUTES.map((institute) => (
                    <SelectItem key={institute} value={institute}>{institute}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <div className="flex gap-2 flex-wrap">
                <Badge variant="outline" className="text-[10px]">Managed via Institute Transfer</Badge>
              </div>
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
              <Select
                value={watch("firstApproverUserId") == null ? "__null__" : String(watch("firstApproverUserId"))}
                onValueChange={(v) => setValue("firstApproverUserId", v === "__null__" ? null : v)}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select approver..." />
                </SelectTrigger>
                <SelectContent className="max-h-[220px]">
                  <SelectItem value="__null__" className="text-[10px] font-extrabold text-slate-500">NULL (bypass this layer)</SelectItem>
                  {selectableEmployees.map((emp) => (
                    <SelectItem key={emp.userId} value={emp.userId} className="text-[10px] font-medium py-2">
                      {emp.fullName}{emp.employeeCode ? ` (${emp.employeeCode})` : ""}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1">
              <Label>Second Reporting Manager</Label>
              <Select
                value={watch("secondApproverUserId") == null ? "__null__" : String(watch("secondApproverUserId"))}
                onValueChange={(v) => setValue("secondApproverUserId", v === "__null__" ? null : v)}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select approver..." />
                </SelectTrigger>
                <SelectContent className="max-h-[220px]">
                  <SelectItem value="__null__" className="text-[10px] font-extrabold text-slate-500">NULL (bypass this layer)</SelectItem>
                  {selectableEmployees.map((emp) => (
                    <SelectItem key={emp.userId} value={emp.userId} className="text-[10px] font-medium py-2">
                      {emp.fullName}{emp.employeeCode ? ` (${emp.employeeCode})` : ""}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1">
              <Label>Third Reporting Manager</Label>
              <Select
                value={watch("thirdApproverUserId") == null ? "__null__" : String(watch("thirdApproverUserId"))}
                onValueChange={(v) => setValue("thirdApproverUserId", v === "__null__" ? null : v)}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select approver..." />
                </SelectTrigger>
                <SelectContent className="max-h-[220px]">
                  <SelectItem value="__null__" className="text-[10px] font-extrabold text-slate-500">NULL (bypass this layer)</SelectItem>
                  {selectableEmployees.map((emp) => (
                    <SelectItem key={emp.userId} value={emp.userId} className="text-[10px] font-medium py-2">
                      {emp.fullName}{emp.employeeCode ? ` (${emp.employeeCode})` : ""}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
