"use client";

import { useSession } from "next-auth/react";
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
import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function ProfilePage() {
  const { data: session } = useSession();
  const employeeId = session?.user?.employeeId;

  const { employee, loading, refetch } = useEmployee(employeeId);

  if (loading || !employeeId) {
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
      <div className="flex flex-col items-center justify-center py-20 text-slate-400">
        <p className="text-sm">Employee profile not found.</p>
      </div>
    );
  }

  const tabs = [
    {
      value: "general",
      label: "General",
      content: <GeneralTab employee={employee} isAdmin={false} onUpdate={refetch} />,
    },
    {
      value: "personal",
      label: "Personal",
      content: <PersonalTab employee={employee} isAdmin={false} onUpdate={refetch} />,
    },
    {
      value: "address",
      label: "Address",
      content: <AddressTab employeeId={employeeId} isAdmin={false} />,
    },
    {
      value: "other",
      label: "Other",
      content: <OtherTab employee={employee} employeeId={employeeId} isAdmin={false} onUpdate={refetch} />,
    },
    {
      value: "salary",
      label: "Salary",
      content: <SalaryTab employee={employee} isAdmin={false} />,
    },
    {
      value: "bank",
      label: "Bank",
      content: <BankTab employee={employee} isAdmin={false} />,
    },
    {
      value: "family",
      label: "Family",
      content: <FamilyTab employeeId={employeeId} isAdmin={false} />,
    },
    {
      value: "education",
      label: "Education",
      content: <EducationTab employeeId={employeeId} isAdmin={false} />,
    },
    {
      value: "documents",
      label: "Documents",
      content: <DocumentsTab employeeId={employeeId} isAdmin={false} />,
    },
  ];

  return (
    <div className="max-w-5xl mx-auto space-y-4">
      <ProfileHeader 
        employee={employee} 
        showAuditLog={false} 
        actions={
          <Link href="/profile/edit">
            <Button size="sm" variant="outline" className="text-xs border-[#1d3459] text-[#1d3459] hover:bg-[#1d3459] hover:text-white">
              Edit Profile
            </Button>
          </Link>
        }
      />
      <ProfileTabs tabs={tabs} defaultTab="general" />
    </div>
  );
}
