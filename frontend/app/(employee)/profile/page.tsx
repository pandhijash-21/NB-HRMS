"use client";

import { useSession } from "next-auth/react";
import { useEmployeeBase } from "@/modules/profile/hooks/useProfile";
import { ProfileHeader } from "@/modules/profile/components/ProfileHeader";
import { GeneralTab } from "@/modules/profile/components/tabs/GeneralTab";
import { PersonalTab } from "@/modules/profile/components/tabs/PersonalTab";
import { AddressTab } from "@/modules/profile/components/tabs/AddressTab";
import { OtherTab } from "@/modules/profile/components/tabs/OtherTab";
import { FamilyTab } from "@/modules/profile/components/tabs/FamilyTab";
import { EducationTab } from "@/modules/profile/components/tabs/EducationTab";
import { DocumentsTab } from "@/modules/profile/components/tabs/DocumentsTab";
import { Skeleton } from "@/components/ui/skeleton";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Shield, User, MapPin, Briefcase, Users, GraduationCap, FileCheck } from "lucide-react";

export default function ProfilePage() {
  const { data: session } = useSession();
  const employeeId = session?.user?.employeeId;

  const { data: employee, isLoading, error } = useEmployeeBase(employeeId as string);

  if (isLoading || !employeeId) {
    return (
      <div className="max-w-5xl mx-auto space-y-8 animate-pulse p-6">
        <Skeleton className="h-40 w-full rounded-2xl" />
        <div className="flex gap-4">
            <Skeleton className="h-10 w-24 rounded-lg" />
            <Skeleton className="h-10 w-24 rounded-lg" />
            <Skeleton className="h-10 w-24 rounded-lg" />
        </div>
        <Skeleton className="h-[400px] w-full rounded-2xl" />
      </div>
    );
  }

  if (error || !employee) {
    return (
      <div className="flex flex-col items-center justify-center py-32 text-center">
        <div className="bg-rose-50 p-4 rounded-full mb-4">
            <Shield className="w-8 h-8 text-rose-500" />
        </div>
        <h3 className="text-lg font-bold text-slate-800">Profile Unreachable</h3>
        <p className="text-sm text-slate-500 mt-1 max-w-xs">
          Your profile record could not be retrieved from the server. Please check your connection or contact HR.
        </p>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto space-y-8 p-4 md:p-8 animate-in fade-in duration-500">
      <ProfileHeader employee={employee} />

      <Tabs defaultValue="general" className="w-full">
        <div className="overflow-x-auto pb-2 scrollbar-hide">
            <TabsList className="bg-slate-100/50 p-1.5 h-11 rounded-2xl border border-slate-200/40 w-max min-w-full md:min-w-0">
                <TabItem value="general" icon={Shield} label="General" />
                <TabItem value="personal" icon={User} label="Personal" />
                <TabItem value="address" icon={MapPin} label="Address" />
                <TabItem value="family" icon={Users} label="Family" />
                <TabItem value="education" icon={GraduationCap} label="Academic" />
                <TabItem value="other" icon={Briefcase} label="Professional" />
                <TabItem value="documents" icon={FileCheck} label="Documents" />
            </TabsList>
        </div>

        <div className="mt-8">
            <TabsContent value="general" className="ring-0 focus-visible:ring-0"><GeneralTab employeeId={employeeId} /></TabsContent>
            <TabsContent value="personal" className="ring-0 focus-visible:ring-0"><PersonalTab employeeId={employeeId} /></TabsContent>
            <TabsContent value="address" className="ring-0 focus-visible:ring-0"><AddressTab employeeId={employeeId} /></TabsContent>
            <TabsContent value="family" className="ring-0 focus-visible:ring-0"><FamilyTab employeeId={employeeId} /></TabsContent>
            <TabsContent value="education" className="ring-0 focus-visible:ring-0"><EducationTab employeeId={employeeId} /></TabsContent>
            <TabsContent value="other" className="ring-0 focus-visible:ring-0"><OtherTab employeeId={employeeId} /></TabsContent>
            <TabsContent value="documents" className="ring-0 focus-visible:ring-0"><DocumentsTab employeeId={employeeId} /></TabsContent>
        </div>
      </Tabs>
    </div>
  );
}

function TabItem({ value, icon: Icon, label }: { value: string, icon: any, label: string }) {
    return (
        <TabsTrigger 
            value={value} 
            className="rounded-xl px-6 py-2 text-[10px] font-bold uppercase tracking-widest gap-2 data-[state=active]:bg-[#1d3459] data-[state=active]:text-white data-[state=active]:shadow-lg data-[state=active]:shadow-[#1d3459]/10"
        >
            <Icon className="w-3.5 h-3.5" />
            {label}
        </TabsTrigger>
    );
}
