"use client";

import { useSession } from "next-auth/react";
import { useSearchParams } from "next/navigation";
import { useEmployee } from "@/lib/hooks/useEmployee";
import { Skeleton } from "@/components/ui/skeleton";
import { GeneralTab } from "@/components/profile/tabs/GeneralTab";
import { PersonalTab } from "@/components/profile/tabs/PersonalTab";
import { AddressTab } from "@/components/profile/tabs/AddressTab";
import { OtherTab } from "@/components/profile/tabs/OtherTab";
import { SalaryTab } from "@/components/profile/tabs/SalaryTab";
import { BankTab } from "@/components/profile/tabs/BankTab";
import { FamilyTab } from "@/components/profile/tabs/FamilyTab";
import { EducationTab } from "@/components/profile/tabs/EducationTab";
import { EditAttendanceSettingsTab } from "@/components/profile/tabs/EditAttendanceSettingsTab";
import { canManageEmployeeAttendance } from "@/lib/auth/permissions";

export default function EmployeeProfileEditPage() {
  const { data: session } = useSession();
  const searchParams = useSearchParams();
  const queryEmployeeId = searchParams.get("employeeId");
  const sessionEmployeeId = session?.user?.employeeId;
  const targetEmployeeId = queryEmployeeId ?? sessionEmployeeId;
  const isAdminEditingOther =
    !!queryEmployeeId &&
    (!sessionEmployeeId || String(sessionEmployeeId) !== String(queryEmployeeId));
  const canEditAttendance =
    isAdminEditingOther &&
    canManageEmployeeAttendance(
      (session?.user as { permissions?: Record<string, string[]>; role?: string })?.permissions,
      (session?.user as { role?: string })?.role,
    );

  const { employee, loading, refetch } = useEmployee(targetEmployeeId ?? undefined);

  if (loading || !targetEmployeeId) {
    return (
      <div className="space-y-6">
        <header className="mb-8">
          <Skeleton className="h-8 w-48 mb-2" />
          <Skeleton className="h-4 w-96" />
        </header>
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton key={i} className="h-64 w-full rounded-2xl" />
        ))}
      </div>
    );
  }

  if (!employee) {
    return (
      <div className="flex h-64 items-center justify-center rounded-2xl border border-rose-100 bg-rose-50 text-rose-500">
        Employee profile not found.
      </div>
    );
  }

  return (
    <div className="space-y-8 pb-12">
      <header className="flex flex-col gap-2 md:flex-row md:items-end md:justify-between border-b border-slate-200/50 pb-5">
        <div>
          <h1 className="text-2xl font-bold text-slate-800 tracking-tight">
            Comprehensive Profile Review
          </h1>
          <p className="text-sm text-slate-500 mt-1">
            Review and update your information across all categories in one continuous page.
            Click 'Edit' on any section to modify its contents.
          </p>
        </div>
      </header>

      <div className="space-y-10">
        <section id="general">
          <h2 className="text-lg font-bold text-slate-700 mb-4 px-1">1. General Information</h2>
          <GeneralTab employee={employee} onUpdate={refetch} isAdmin={true} />
        </section>

        <section id="personal">
          <h2 className="text-lg font-bold text-slate-700 mb-4 px-1">2. Personal Details</h2>
          <PersonalTab employee={employee} onUpdate={refetch} isAdmin={true} />
        </section>

        <section id="address">
          <h2 className="text-lg font-bold text-slate-700 mb-4 px-1">3. Contact & Address</h2>
          <AddressTab employeeId={employee.id} isAdmin={true} />
        </section>

        <section id="other">
          <h2 className="text-lg font-bold text-slate-700 mb-4 px-1">4. Other Information</h2>
          <OtherTab employee={employee} employeeId={employee.id} onUpdate={refetch} isAdmin={true} />
        </section>

        <section id="family">
          <h2 className="text-lg font-bold text-slate-700 mb-4 px-1">5. Family Members</h2>
          <FamilyTab employeeId={employee.id} isAdmin={true} />
        </section>

        <section id="education">
          <h2 className="text-lg font-bold text-slate-700 mb-4 px-1">6. Academic Qualifications</h2>
          <EducationTab employeeId={employee.id} isAdmin={true} />
        </section>

        <section id="salary">
          <h2 className="text-lg font-bold text-slate-700 mb-4 px-1">7. Salary Information</h2>
          <SalaryTab employee={employee} isAdmin={true} />
        </section>

        <section id="bank">
          <h2 className="text-lg font-bold text-slate-700 mb-4 px-1">8. Bank Details</h2>
          <BankTab employee={employee} isAdmin={true} />
        </section>

        {canEditAttendance && (
          <section id="attendance">
            <h2 className="text-lg font-bold text-slate-700 mb-4 px-1">9. Attendance — Punch window</h2>
            <EditAttendanceSettingsTab employeeId={Number(queryEmployeeId)} />
          </section>
        )}
      </div>
    </div>
  );
}
