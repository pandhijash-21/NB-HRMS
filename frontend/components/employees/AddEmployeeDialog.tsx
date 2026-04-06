"use client";

import { useState, useEffect } from "react";
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
import { OtpVerification } from "@/components/shared/OtpVerification";
import { PlusCircle, Loader2, UserPlus, ShieldAlert, CheckCircle2, Mail } from "lucide-react";

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

const addEmployeeSchema = z.object({
  fullName: z.string()
    .min(3, "Full name must be at least 3 characters")
    .regex(/^[a-zA-Z\s\.]+$/, "Name should only contain letters, spaces, and dots"),
  personalEmail: z.string()
    .email("Invalid email format")
    .refine((email) => email.toLowerCase().endsWith("@gmail.com"), {
      message: "Personal email must be a Gmail address",
    }),
  personalEmailVerified: z.boolean(),
  institutionalEmail: z.string()
    .email("Invalid institute email format")
    .optional()
    .or(z.literal("")),
  organization: z.enum(["GU", "Platinum Foundation"], "Organization is required"),
  subOrganization: z.string().min(1, "Sub-organization is required"),
  designation: z.string().min(2, "Designation is required"),
  department: z.string().min(2, "Department is required"),
  employeeCategory: z.enum(["TEACHING", "NON_TEACHING", "CONTRACT", "VISITING"]),
  joiningDate: z.string().min(1, "Joining date is required"),
});

type AddEmployeeForm = z.infer<typeof addEmployeeSchema>;

function generateAbbreviation(fullName: string): string {
  const names = fullName.trim().split(/\s+/);
  if (names.length === 1) {
    return names[0].substring(0, 2).toUpperCase();
  }
  const firstName = names[0];
  const lastName = names[names.length - 1];
  return (firstName[0] + lastName[0]).toUpperCase();
}

function generateEmployeeCode(): string {
  const timestamp = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).substring(2, 5).toUpperCase();
  return `EMP-${timestamp}-${random}`;
}

export function AddEmployeeDialog() {
  const [open, setOpen] = useState(false);
  const [serverError, setServerError] = useState<string | null>(null);
  const [showOtpVerification, setShowOtpVerification] = useState(false);
  const [pendingEmail, setPendingEmail] = useState("");
  const [abbreviation, setAbbreviation] = useState("");
  const [employeeCode] = useState(generateEmployeeCode());
  const [otpVerified, setOtpVerified] = useState(false);
  const createMutation = useCreateEmployee();

  const {
    register,
    handleSubmit,
    reset,
    setValue,
    watch,
    formState: { errors, isValid },
  } = useForm<AddEmployeeForm>({
    resolver: zodResolver(addEmployeeSchema),
    defaultValues: {
      fullName: "",
      personalEmail: "",
      institutionalEmail: "",
      organization: "GU",
      subOrganization: "",
      designation: "",
      department: "",
      employeeCategory: "TEACHING",
      joiningDate: "",
      personalEmailVerified: false,
    },
    mode: "onChange",
  });

  const fullName = watch("fullName");
  const organization = watch("organization");

  useEffect(() => {
    if (fullName && fullName.length >= 3) {
      const abbrev = generateAbbreviation(fullName);
      setAbbreviation(abbrev);
    } else {
      setAbbreviation("");
    }
  }, [fullName]);

  const handleSendOtp = async (email: string) => {
    setPendingEmail(email);
    setShowOtpVerification(true);
  };

  const handleOtpVerified = () => {
    setOtpVerified(true);
    setValue("personalEmailVerified", true);
    setShowOtpVerification(false);
  };

  const onSubmit = async (data: AddEmployeeForm) => {
    // setServerError(null); // OTP check removed as it's now optional

    setServerError(null);
    try {
      const submissionData = {
        ...data,
        abbreviation,
        employeeCode,
        institutionalEmail: data.institutionalEmail || undefined,
      };
      await createMutation.mutateAsync(submissionData);
      setOpen(false);
      reset();
      setOtpVerified(false);
      setAbbreviation("");
    } catch (err: any) {
      const msg = err.response?.data?.error || err.response?.data?.message || err.message || "An unexpected error occurred";
      setServerError(msg);
    }
  };

  const handleDialogClose = (isOpen: boolean) => {
    if (!isOpen) {
      reset();
      setOtpVerified(false);
      setAbbreviation("");
      setShowOtpVerification(false);
      setServerError(null);
    }
    setOpen(isOpen);
  };

  return (
    <>
      <Dialog open={open} onOpenChange={handleDialogClose}>
        <DialogTrigger asChild>
          <Button className="bg-[#1d3459] hover:bg-[#1d3459]/90 text-white gap-2 text-xs font-bold uppercase tracking-widest px-6 h-11 rounded-xl shadow-lg shadow-[#1d3459]/10 transition-all hover:shadow-xl hover:-translate-y-0.5">
            <UserPlus className="h-4 w-4" />
            Add Personnel
          </Button>
        </DialogTrigger>
        <DialogContent className="sm:max-w-[650px] border-none shadow-2xl rounded-3xl p-0 overflow-hidden bg-slate-50/50 backdrop-blur-xl max-h-[90vh] overflow-y-auto">
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
                <Label htmlFor="employeeCode" className="text-[10px] font-bold text-slate-400 uppercase ml-1">Employee Code</Label>
                <Input
                  id="employeeCode"
                  value={employeeCode}
                  disabled
                  className="rounded-xl border-slate-200/60 bg-slate-100 text-sm h-11 font-medium cursor-not-allowed"
                />
                <p className="text-[9px] text-slate-400 uppercase ml-1">Auto-generated, unique</p>
              </div>

              <div className="space-y-2">
                <Label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Abbreviation</Label>
                <Input
                  value={abbreviation}
                  disabled
                  placeholder="e.g. RK"
                  className="rounded-xl border-slate-200/60 bg-slate-100 text-sm h-11 font-medium cursor-not-allowed"
                />
                <p className="text-[9px] text-slate-400 uppercase ml-1">Auto-generated from name</p>
              </div>

              <div className="col-span-2 space-y-2">
                <Label htmlFor="personalEmail" className="text-[10px] font-bold text-slate-400 uppercase ml-1">
                  Personal Email (Gmail) *
                </Label>
                <div className="flex gap-2">
                  <div className="flex-1 relative">
                    <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
                    <Input
                      id="personalEmail"
                      type="email"
                      {...register("personalEmail")}
                      placeholder="yourname@gmail.com"
                      className="pl-10 rounded-xl border-slate-200/60 bg-white focus:ring-2 focus:ring-[#1d3459]/10 transition-all text-sm h-11 font-medium"
                    />
                  </div>
                  {!otpVerified ? (
                    <Button
                      type="button"
                      variant="outline"
                      onClick={() => handleSendOtp(watch("personalEmail"))}
                      disabled={!watch("personalEmail") || !!errors.personalEmail}
                      className="rounded-xl border-[#d9b557] text-[#d9b557] hover:bg-[#d9b557] hover:text-white h-11 px-4 text-xs font-bold"
                    >
                      <span className="text-[9px] font-bold text-[#d9b557] mr-1 uppercase">(Optional)</span>
                      Verify OTP
                    </Button>
                  ) : (
                    <div className="flex items-center gap-2 px-4 bg-emerald-50 border border-emerald-200 rounded-xl text-emerald-600">
                      <CheckCircle2 className="w-4 h-4" />
                      <span className="text-xs font-bold">Verified</span>
                    </div>
                  )}
                </div>
                {errors.personalEmail && <p className="text-[10px] text-rose-500 font-bold uppercase tracking-tight">{errors.personalEmail.message}</p>}
              </div>

              <div className="col-span-2 space-y-2">
                <Label htmlFor="institutionalEmail" className="text-[10px] font-bold text-slate-400 uppercase ml-1">Institutional Email (Optional)</Label>
                <Input
                  id="institutionalEmail"
                  type="email"
                  {...register("institutionalEmail")}
                  placeholder="firstname.lastname@gandhinagaruni.ac.in"
                  className="rounded-xl border-slate-200/60 bg-white focus:ring-2 focus:ring-[#1d3459]/10 transition-all text-sm h-11 font-medium"
                />
                <p className="text-[9px] text-slate-400 uppercase ml-1">Format: firstname.lastname@gandhinagaruni.ac.in</p>
                {errors.institutionalEmail && <p className="text-[10px] text-rose-500 font-bold uppercase tracking-tight">{errors.institutionalEmail.message}</p>}
              </div>

              <div className="space-y-2">
                <Label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Organization *</Label>
                <Select
                  name="organization"
                  onValueChange={(v) => setValue("organization", v as "GU" | "Platinum Foundation")}
                  defaultValue="GU"
                >
                  <SelectTrigger id="organization" className="rounded-xl border-slate-200/60 bg-white h-11 text-sm font-medium">
                    <SelectValue placeholder="Select..." />
                  </SelectTrigger>
                  <SelectContent className="rounded-xl border-slate-100 shadow-xl">
                    <SelectItem value="GU" className="text-[10px] font-bold uppercase">GU</SelectItem>
                    <SelectItem value="Platinum Foundation" className="text-[10px] font-bold uppercase">Platinum Foundation</SelectItem>
                  </SelectContent>
                </Select>
                {errors.organization && <p className="text-[10px] text-rose-500 font-bold uppercase tracking-tight">{errors.organization.message}</p>}
              </div>

              <div className="space-y-2">
                <Label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Sub-Organization *</Label>
                <Select
                  name="subOrganization"
                  onValueChange={(v) => setValue("subOrganization", v)}
                >
                  <SelectTrigger id="subOrganization" className="rounded-xl border-slate-200/60 bg-white h-11 text-sm font-medium">
                    <SelectValue placeholder="Select Institute..." />
                  </SelectTrigger>
                  <SelectContent className="rounded-xl border-slate-100 shadow-xl max-h-[200px]">
                    {INSTITUTES.map((institute) => (
                      <SelectItem key={institute} value={institute} className="text-[10px] font-medium py-2">
                        {institute}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {errors.subOrganization && <p className="text-[10px] text-rose-500 font-bold uppercase tracking-tight">{errors.subOrganization.message}</p>}
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
                <Label className="text-[10px] font-bold text-slate-400 uppercase ml-1">Engagement Category *</Label>
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
                onClick={() => handleDialogClose(false)}
                className="text-slate-500 hover:text-slate-800 text-[10px] font-bold uppercase tracking-widest h-11 px-8 rounded-xl"
              >
                Cancel
              </Button>
              <Button
                type="button"
                disabled={createMutation.isPending}
                onClick={handleSubmit(onSubmit)}
                className="bg-[#d9b557] hover:bg-[#c9a547] text-[#1d3459] min-w-[170px] text-[10px] font-bold uppercase tracking-widest h-11 rounded-xl shadow-lg shadow-[#d9b557]/20 transition-all hover:shadow-xl hover:-translate-y-0.5"
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

      <OtpVerification
        open={showOtpVerification}
        onOpenChange={setShowOtpVerification}
        email={pendingEmail}
        onVerified={handleOtpVerified}
      />
    </>
  );
}
