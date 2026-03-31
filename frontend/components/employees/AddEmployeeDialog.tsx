"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
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
import { useCreateEmployee } from "@/modules/admin/hooks/useAdminEmployees";
import { PlusCircle, Loader2, UserPlus, ShieldAlert } from "lucide-react";

const addEmployeeSchema = z.object({
  fullName: z.string()
    .min(3, "Full name must be at least 3 characters")
    .regex(/^[a-zA-Z\s\.]+$/, "Name should only contain letters, spaces, and dots"),
  email: z.string().email("Invalid institute email"),
  designation: z.string().min(2, "Designation is required"),
  department: z.string().min(2, "Department is required"),
  employeeCategory: z.enum(["TEACHING", "NON_TEACHING", "CONTRACT", "VISITING"]),
  joiningDate: z.string().min(1, "Joining date is required"),
  employeeCode: z.string().min(1, "Employee code is required"),
});

type AddEmployeeForm = z.infer<typeof addEmployeeSchema>;

export function AddEmployeeDialog() {
  const [open, setOpen] = useState(false);
  const [serverError, setServerError] = useState<string | null>(null);
  const createMutation = useCreateEmployee();

  const {
    register,
    handleSubmit,
    reset,
    setValue,
    formState: { errors },
  } = useForm<AddEmployeeForm>({
    resolver: zodResolver(addEmployeeSchema),
    defaultValues: {
      employeeCategory: "TEACHING",
    },
  });

  const onSubmit = async (data: AddEmployeeForm) => {
    setServerError(null);
    try {
      await createMutation.mutateAsync(data);
      setOpen(false);
      reset();
    } catch (err: any) {
      const msg = err.response?.data?.error || err.response?.data?.message || err.message || "An unexpected error occurred";
      setServerError(msg);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="bg-[#1d3459] hover:bg-[#1d3459]/90 text-white gap-2 text-xs font-bold uppercase tracking-widest px-6 h-11 rounded-xl shadow-lg shadow-[#1d3459]/10 transition-all hover:shadow-xl hover:-translate-y-0.5">
          <UserPlus className="h-4 w-4" />
          Add Personnel
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-[550px] border-none shadow-2xl rounded-3xl p-0 overflow-hidden bg-slate-50/50 backdrop-blur-xl">
        <div className="bg-[#1d3459] p-8 text-white relative h-32 overflow-hidden">
             <div className="relative z-10">
                <DialogTitle className="text-xl font-extrabold tracking-tight flex items-center gap-2">
                    <UserPlus className="w-5 h-5 text-[#d9b557]" />
                    Onboard New Employee
                </DialogTitle>
                <DialogDescription className="text-white/60 text-[11px] font-medium mt-1">
                    Establish a new institutional record and system credentials.
                </DialogDescription>
             </div>
             <ShieldAlert className="absolute -right-8 -bottom-8 w-40 h-40 text-white/5 rotate-12" />
        </div>

        <div className="p-8 space-y-6">
          {serverError && (
             <div className="bg-rose-50 border border-rose-200 text-rose-600 px-4 py-3 rounded-xl text-xs font-bold uppercase tracking-tight flex items-center gap-3">
                <ShieldAlert className="w-4 h-4 shrink-0" />
                {serverError}
             </div>
          )}
          <div className="grid grid-cols-2 gap-6">
            <div className="col-span-2 space-y-2">
              <Label htmlFor="fullName" className="text-[10px] font-bold text-slate-400 uppercase ml-1">Full Name *</Label>
              <Input
                id="fullName"
                {...register("fullName")}
                placeholder="e.g. Dr. Rajesh Kumar"
                className="rounded-xl border-slate-200/60 bg-white focus:ring-2 focus:ring-[#1d3459]/10 transition-all text-sm h-11 font-medium"
              />
              {errors.fullName && <p className="text-[10px] text-rose-500 font-bold uppercase tracking-tight">{errors.fullName.message}</p>}
            </div>

            <div className="space-y-2">
              <Label htmlFor="employeeCode" className="text-[10px] font-bold text-slate-400 uppercase ml-1">Unique Code *</Label>
              <Input
                id="employeeCode"
                {...register("employeeCode")}
                placeholder="e.g. ADM001"
                className="rounded-xl border-slate-200/60 bg-white focus:ring-2 focus:ring-[#1d3459]/10 transition-all text-sm h-11 font-medium"
              />
              {errors.employeeCode && <p className="text-[10px] text-rose-500 font-bold uppercase tracking-tight">{errors.employeeCode.message}</p>}
            </div>

            <div className="space-y-2">
              <Label htmlFor="email" className="text-[10px] font-bold text-slate-400 uppercase ml-1">Institutional Email *</Label>
              <Input
                id="email"
                type="email"
                {...register("email")}
                placeholder="rajesh.k@gu.ac.in"
                className="rounded-xl border-slate-200/60 bg-white focus:ring-2 focus:ring-[#1d3459]/10 transition-all text-sm h-11 font-medium"
              />
              {errors.email && <p className="text-[10px] text-rose-500 font-bold uppercase tracking-tight">{errors.email.message}</p>}
            </div>

            <div className="space-y-2">
              <Label htmlFor="designation" className="text-[10px] font-bold text-slate-400 uppercase ml-1">Designation *</Label>
              <Input
                id="designation"
                {...register("designation")}
                placeholder="e.g. Asst. Professor"
                className="rounded-xl border-slate-200/60 bg-white focus:ring-2 focus:ring-[#1d3459]/10 transition-all text-sm h-11 font-medium"
              />
              {errors.designation && <p className="text-[10px] text-rose-500 font-bold uppercase tracking-tight">{errors.designation.message}</p>}
            </div>

            <div className="space-y-2">
              <Label htmlFor="department" className="text-[10px] font-bold text-slate-400 uppercase ml-1">Department *</Label>
              <Input
                id="department"
                {...register("department")}
                placeholder="e.g. Comp. Science"
                className="rounded-xl border-slate-200/60 bg-white focus:ring-2 focus:ring-[#1d3459]/10 transition-all text-sm h-11 font-medium"
              />
              {errors.department && <p className="text-[10px] text-rose-500 font-bold uppercase tracking-tight">{errors.department.message}</p>}
            </div>

            <div className="space-y-2">
              <Label htmlFor="category" className="text-[10px] font-bold text-slate-400 uppercase ml-1">Engagement Category *</Label>
              <Select
                name="category"
                onValueChange={(v) => setValue("employeeCategory", v as any)}
                defaultValue="TEACHING"
              >
                <SelectTrigger id="category" className="rounded-xl border-slate-200/60 bg-white h-11 text-sm font-medium">
                  <SelectValue placeholder="Select..." />
                </SelectTrigger>
                <SelectContent className="rounded-xl border-slate-100 shadow-xl">
                  <SelectItem value="TEACHING" className="text-[10px] font-bold uppercase">Teaching</SelectItem>
                  <SelectItem value="NON_TEACHING" className="text-[10px] font-bold uppercase">Non-Teaching</SelectItem>
                  <SelectItem value="CONTRACT" className="text-[10px] font-bold uppercase">Contract</SelectItem>
                  <SelectItem value="VISITING" className="text-[10px] font-bold uppercase">Visiting</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="joiningDate" className="text-[10px] font-bold text-slate-400 uppercase ml-1">Appointment Date *</Label>
              <Input
                id="joiningDate"
                type="date"
                {...register("joiningDate")}
                className="rounded-xl border-slate-200/60 bg-white h-11 text-sm font-medium"
              />
              {errors.joiningDate && <p className="text-[10px] text-rose-500 font-bold uppercase tracking-tight">{errors.joiningDate.message}</p>}
            </div>
          </div>

          <DialogFooter className="pt-4 gap-3 bg-white/40 -mx-8 -mb-8 p-8 border-t border-slate-100">
            <Button
              type="button"
              variant="ghost"
              onClick={() => setOpen(false)}
              className="text-slate-500 hover:text-slate-800 text-[10px] font-bold uppercase tracking-widest h-11 px-8 rounded-xl"
            >
              Cancel
            </Button>
            <Button
              type="button"
              disabled={createMutation.isPending}
              onClick={handleSubmit(onSubmit)}
              className="bg-[#d9b557] hover:bg-[#c9a547] text-[#1d3459] min-w-[160px] text-[10px] font-bold uppercase tracking-widest h-11 rounded-xl shadow-lg shadow-[#d9b557]/20 transition-all hover:shadow-xl hover:-translate-y-0.5"
            >
              {createMutation.isPending ? (
                <>
                  <Loader2 className="mr-2 h-3.5 w-3.5 animate-spin" />
                  Processing...
                </>
              ) : (
                "Finalize Records"
              )}
            </Button>
          </DialogFooter>
        </div>
      </DialogContent>
    </Dialog>
  );
}
