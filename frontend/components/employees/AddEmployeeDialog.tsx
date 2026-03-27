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
import { useCreateEmployee } from "@/lib/hooks/useEmployee";
import { PlusCircle, Loader2 } from "lucide-react";

const addEmployeeSchema = z.object({
  fullName: z.string().min(3, "Full name must be at least 3 characters"),
  email: z.string().email("Invalid institute email"),
  designation: z.string().min(2, "Designation is required"),
  department: z.string().min(2, "Department is required"),
  employeeCategory: z.enum(["TEACHING", "NON_TEACHING", "CONTRACT", "VISITING"]),
  joiningDate: z.string().min(1, "Joining date is required"),
  employeeCode: z.string().min(1, "Employee code is required"),
});

type AddEmployeeForm = z.infer<typeof addEmployeeSchema>;

export function AddEmployeeDialog({ onEmployeeAdded }: { onEmployeeAdded: () => void }) {
  const [open, setOpen] = useState(false);
  const { createEmployee } = useCreateEmployee();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
    setLoading(true);
    setError(null);
    try {
      await createEmployee(data);
      setOpen(false);
      reset();
      onEmployeeAdded();
    } catch (err: any) {
      setError(err.response?.data?.message || err.message || "Failed to create employee");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="bg-[#1d3459] hover:bg-[#1d3459]/90 text-white gap-2 text-sm">
          <PlusCircle className="h-4 w-4" />
          Add Employee
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-[500px] border-none shadow-2xl">
        <DialogHeader>
          <DialogTitle className="text-[#1d3459] font-bold">Add New Employee</DialogTitle>
          <DialogDescription className="text-slate-500 text-xs text-balance">
            Create a base employee record and a system user account. Detailed information can be added later.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 py-4">
          {error && (
            <div className="p-3 bg-rose-50 text-rose-600 border border-rose-100 rounded-lg text-xs font-medium">
              {error}
            </div>
          )}

          <div className="grid grid-cols-2 gap-4">
            <div className="col-span-2 space-y-1.5">
              <Label htmlFor="fullName" className="text-slate-700 font-semibold text-xs">Full Name *</Label>
              <Input
                id="fullName"
                {...register("fullName")}
                placeholder="e.g. Dr. Rajesh Kumar"
                className="border-slate-200 focus:border-[#1d3459] transition-all text-sm h-9"
              />
              {errors.fullName && <p className="text-[10px] text-rose-500 font-medium">{errors.fullName.message}</p>}
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="employeeCode" className="text-slate-700 font-semibold text-xs">Employee Code *</Label>
              <Input
                id="employeeCode"
                {...register("employeeCode")}
                placeholder="e.g. ADM001"
                className="border-slate-200 focus:border-[#1d3459] transition-all text-sm h-9"
              />
              {errors.employeeCode && <p className="text-[10px] text-rose-500 font-medium">{errors.employeeCode.message}</p>}
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="email" className="text-slate-700 font-semibold text-xs">Institute Email *</Label>
              <Input
                id="email"
                type="email"
                {...register("email")}
                placeholder="rajesh.kumar@uni.ac.in"
                className="border-slate-200 focus:border-[#1d3459] transition-all text-sm h-9"
              />
              {errors.email && <p className="text-[10px] text-rose-500 font-medium">{errors.email.message}</p>}
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="designation" className="text-slate-700 font-semibold text-xs">Designation *</Label>
              <Input
                id="designation"
                {...register("designation")}
                placeholder="e.g. Assistant Professor"
                className="border-slate-200 focus:border-[#1d3459] transition-all text-sm h-9"
              />
              {errors.designation && <p className="text-[10px] text-rose-500 font-medium">{errors.designation.message}</p>}
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="department" className="text-slate-700 font-semibold text-xs">Department *</Label>
              <Input
                id="department"
                {...register("department")}
                placeholder="e.g. Computer Science"
                className="border-slate-200 focus:border-[#1d3459] transition-all text-sm h-9"
              />
              {errors.department && <p className="text-[10px] text-rose-500 font-medium">{errors.department.message}</p>}
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="category" className="text-slate-700 font-semibold text-xs">Category *</Label>
              <Select
                onValueChange={(v) => setValue("employeeCategory", v as any)}
                defaultValue="TEACHING"
              >
                <SelectTrigger className="border-slate-200 focus:ring-[#1d3459] h-9 text-sm">
                  <SelectValue placeholder="Select category" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="TEACHING">Teaching</SelectItem>
                  <SelectItem value="NON_TEACHING">Non-Teaching</SelectItem>
                  <SelectItem value="CONTRACT">Contract</SelectItem>
                  <SelectItem value="VISITING">Visiting</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="joiningDate" className="text-slate-700 font-semibold text-xs">Joining Date *</Label>
              <Input
                id="joiningDate"
                type="date"
                {...register("joiningDate")}
                className="border-slate-200 focus:border-[#1d3459] transition-all text-sm h-9"
              />
              {errors.joiningDate && <p className="text-[10px] text-rose-500 font-medium">{errors.joiningDate.message}</p>}
            </div>
          </div>

          <DialogFooter className="pt-4 border-t border-slate-50">
            <Button
              type="button"
              variant="ghost"
              onClick={() => setOpen(false)}
              className="text-slate-500 hover:text-slate-800 text-xs"
            >
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={loading}
              className="bg-[#1d3459] hover:bg-[#1d3459]/90 text-white min-w-[100px] text-xs h-9 shadow-lg shadow-[#1d3459]/20"
            >
              {loading ? (
                <>
                  <Loader2 className="mr-2 h-3 w-3 animate-spin" />
                  Saving...
                </>
              ) : (
                "Create Employee"
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
