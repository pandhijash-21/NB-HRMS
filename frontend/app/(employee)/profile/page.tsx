"use client";

import { useSession } from "next-auth/react";
import { useAdminEmployee } from "@/modules/admin/hooks/useAdminEmployees";
import { ProfileHeader } from "@/components/profile/ProfileHeader";
import { ProfileTabs } from "@/components/profile/ProfileTabs";
import { GeneralTab } from "@/components/profile/tabs/GeneralTab";
import { PersonalTab } from "@/components/profile/tabs/PersonalTab";
import { AddressTab } from "@/components/profile/tabs/AddressTab";
import { OtherTab } from "@/components/profile/tabs/OtherTab";
import { FamilyTab } from "@/components/profile/tabs/FamilyTab";
import { EducationTab } from "@/components/profile/tabs/EducationTab";
import { ExperienceTab } from "@/components/profile/tabs/ExperienceTab";
import { AttendanceTab } from "@/components/profile/tabs/AttendanceTab";
import { BankTab } from "@/components/profile/tabs/BankTab";
import { SalaryTab } from "@/components/profile/tabs/SalaryTab";
import { Skeleton } from "@/components/ui/skeleton";

export default function ProfilePage() {
  const { data: session } = useSession();
  const employeeId = (session?.user as any)?.employeeId;

  const { data: rawEmployee, isLoading, refetch } = useAdminEmployee(employeeId);

  // Same flattening pattern as admin [id]/page.tsx
  const employee = rawEmployee ? {
    ...rawEmployee.generalInfo,
    ...rawEmployee.personalInfo,
    ...rawEmployee.otherInfo,
    ...rawEmployee.bankInfo,
    ...rawEmployee,
    employeeCode: rawEmployee.generalInfo?.employeeCode || `EMP-${String(rawEmployee.id).padStart(4, "0")}`,
    // Email comes from the local address record
    email: rawEmployee.addresses?.find((a: any) => a.addressType === "LOCAL")?.instituteEmail
      || rawEmployee.addresses?.[0]?.personalEmail
      || "",
  } : null;

  if (isLoading || !employeeId) {
    return (
      <div className="max-w-5xl mx-auto space-y-4">
        <Skeleton className="h-32 w-full rounded-xl" />
        <Skeleton className="h-10 w-full" />
        <Skeleton className="h-60 w-full" />
      </div>
    );
  }

  if (!employee) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-slate-400 space-y-3">
        <p className="text-sm">Profile could not be loaded. Please contact HR.</p>
      </div>
    );
  }

  const tabs = [
    { value: "general",   label: "General",   content: <GeneralTab   employee={employee} isAdmin={false} onUpdate={refetch} /> },
    { value: "personal",  label: "Personal",  content: <PersonalTab  employee={employee} isAdmin={false} onUpdate={refetch} /> },
    { value: "address",   label: "Address",   content: <AddressTab   employeeId={String(employeeId)} isAdmin={false} /> },
    { value: "other",     label: "Other",     content: <OtherTab     employee={employee} employeeId={String(employeeId)} isAdmin={false} onUpdate={refetch} /> },
    { value: "bank",      label: "Bank",      content: <BankTab      employee={employee} allowEdit onUpdate={refetch} /> },
    { value: "salary",    label: "Salary",    content: <SalaryTab    employee={employee} isAdmin={false} /> },
    { value: "family",    label: "Family",    content: <FamilyTab    employeeId={String(employeeId)} isAdmin={false} /> },
    { value: "education", label: "Education", content: <EducationTab employeeId={String(employeeId)} isAdmin={false} /> },
    { value: "experience", label: "Experience", content: <ExperienceTab employeeId={String(employeeId)} isAdmin={false} /> },
    { value: "attendance", label: "Attendance", content: <AttendanceTab /> },
  ];

  return (
    <div className="max-w-5xl mx-auto space-y-4">
      <ProfileHeader employee={employee} />
      <ProfileTabs tabs={tabs} defaultTab="general" />
    </div>
  );
}
