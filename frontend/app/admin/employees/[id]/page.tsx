"use client";

import { use } from "react";
import Link from "next/link";
import { useSession } from "next-auth/react";
import { useAdminEmployee, useAdminEmployeeAssignments } from "@/modules/admin/hooks/useAdminEmployees";
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
import { DocumentsTab } from "@/components/profile/tabs/DocumentsTab";
import { SalaryTab } from "@/components/profile/tabs/SalaryTab";
import { BankTab } from "@/components/profile/tabs/BankTab";
import { canManageEmployeeAttendance, canManageLetters } from "@/lib/auth/permissions";
import { Skeleton } from "@/components/ui/skeleton";
import { EmploymentHistory } from "@/components/employees/EmploymentHistory";
import { InstituteTransferDialog } from "@/components/employees/InstituteTransferDialog";
import { DesignationUpgradeDialog } from "@/components/employees/DesignationUpgradeDialog";
import { EmployeePositionDialog } from "@/components/employees/EmployeePositionDialog";

interface PageProps {
  params: Promise<{ id: string }>;
}

export default function AdminEmployeeProfilePage({ params }: PageProps) {
  const { id } = use(params);
  const { data: session } = useSession();
  const perms = (session?.user as { permissions?: Record<string, string[]> })?.permissions;
  const role = (session?.user as { role?: string })?.role;
  const canManageAttendanceSettings = canManageEmployeeAttendance(perms, role);
  const canGenerateLetters = canManageLetters(perms, role);
  const { data: rawEmployee, isLoading: loading, refetch } = useAdminEmployee(id);
  const assignmentsQ = useAdminEmployeeAssignments(id);

  const employee = rawEmployee ? {
    ...rawEmployee.generalInfo,
    ...rawEmployee.personalInfo,
    ...rawEmployee.otherInfo,
    ...rawEmployee.bankInfo,
    ...rawEmployee, // Spreading rawEmployee last ensures its 'id' (Int) takes precedence
    employeeCode: rawEmployee.generalInfo?.employeeCode || `EMP-${rawEmployee.id.toString().padStart(4, '0')}`,
  } : null;

  if (loading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-32 w-full rounded-xl" />
        <Skeleton className="h-10 w-full" />
        <Skeleton className="h-60 w-full" />
      </div>
    );
  }

  if (!employee) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-slate-400 space-y-3">
        <p className="text-sm">Employee not found.</p>
        <Link href="/admin/employees" className="text-xs text-[#1d3459] underline">
          Back to Employee List
        </Link>
      </div>
    );
  }

  const tabs = [
    { value: "general",   label: "General",   content: <GeneralTab   employee={employee} isAdmin onUpdate={refetch} /> },
    { value: "personal",  label: "Personal",  content: <PersonalTab employee={employee} isAdmin onUpdate={refetch} /> },
    { value: "address",   label: "Address",   content: <AddressTab   employeeId={id} isAdmin /> },
    { value: "other",     label: "Other",     content: <OtherTab     employee={employee} employeeId={id} isAdmin onUpdate={refetch} /> },
    { value: "salary",    label: "Salary",    content: <SalaryTab    employee={employee} isAdmin /> },
    { value: "bank",      label: "Bank",      content: <BankTab      employee={employee} isAdmin onUpdate={refetch} /> },
    { value: "family",    label: "Family",    content: <FamilyTab    employeeId={id} isAdmin /> },
    { value: "education", label: "Education", content: <EducationTab employeeId={id} isAdmin /> },
    { value: "experience", label: "Experience", content: <ExperienceTab employeeId={id} isAdmin /> },
    { value: "documents", label: "Documents", content: <DocumentsTab profile={rawEmployee} canManageLetters={canGenerateLetters} /> },
    { value: "attendance", label: "Attendance", content: <AttendanceTab employeeId={Number(id)} canManageSettings={canManageAttendanceSettings} /> },
  ];

  return (
    <div className="max-w-5xl mx-auto space-y-4">
      <div className="text-xs text-slate-400 mb-2">
        <Link href="/admin/employees" className="hover:text-[#1d3459]">← All Employees</Link>
      </div>
      <ProfileHeader
        employee={employee}
        showAuditLog
        actions={
          <div className="flex items-center gap-2 flex-wrap justify-end">
            <EmployeePositionDialog
              employeeId={id}
              currentPosition={rawEmployee?.position ?? null}
              onUpdated={refetch}
            />
            <InstituteTransferDialog employeeId={id} />
            <DesignationUpgradeDialog employeeId={id} />
            <Link
              href={`/profile/edit?employeeId=${id}`}
              className="text-xs px-3 py-1.5 rounded-lg border border-slate-200 bg-white text-[#1d3459] font-semibold hover:bg-slate-50"
            >
              Edit Profile
            </Link>
            <span className="text-xs px-2 py-1 rounded bg-[#d9b557]/20 text-[#1d3459] font-medium">
              HR View
            </span>
          </div>
        }
      />

      <EmploymentHistory
        assignments={assignmentsQ.data ?? []}
        currentSubOrg={employee.subOrganization ?? null}
        currentDesignation={employee.designation ?? null}
      />
      <ProfileTabs tabs={tabs} defaultTab="general" />
    </div>
  );
}
