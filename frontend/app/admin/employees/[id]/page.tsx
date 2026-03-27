"use client";

import { use } from "react";
import Link from "next/link";
import { useEmployee } from "@/lib/hooks/useEmployee";
import { ProfileHeader } from "@/components/profile/ProfileHeader";
import { ProfileTabs } from "@/components/profile/ProfileTabs";
import { GeneralTab } from "@/components/profile/tabs/GeneralTab";
import { PersonalTab } from "@/components/profile/tabs/PersonalTab";
import { AddressTab } from "@/components/profile/tabs/AddressTab";
import { OtherTab } from "@/components/profile/tabs/OtherTab";
import { FamilyTab } from "@/components/profile/tabs/FamilyTab";
import { EducationTab } from "@/components/profile/tabs/EducationTab";
import { SalaryTab } from "@/components/profile/tabs/SalaryTab";
import { BankTab } from "@/components/profile/tabs/BankTab";
import { DocumentsTab } from "@/components/profile/tabs/DocumentsTab";
import { Skeleton } from "@/components/ui/skeleton";

interface PageProps {
  params: Promise<{ id: string }>;
}

export default function AdminEmployeeProfilePage({ params }: PageProps) {
  const { id } = use(params);
  const { employee, loading, refetch } = useEmployee(id);

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
    { value: "bank",      label: "Bank",      content: <BankTab      employee={employee} isAdmin /> },
    { value: "family",    label: "Family",    content: <FamilyTab    employeeId={id} isAdmin /> },
    { value: "education", label: "Education", content: <EducationTab employeeId={id} isAdmin /> },
    { value: "documents", label: "Documents", content: <DocumentsTab employeeId={id} isAdmin /> },
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
          <span className="text-xs px-2 py-1 rounded bg-[#d9b557]/20 text-[#1d3459] font-medium">
            HR View
          </span>
        }
      />
      <ProfileTabs tabs={tabs} defaultTab="general" />
    </div>
  );
}
