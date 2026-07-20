"use client";

import { use } from "react";
import Link from "next/link";
import { useSession } from "next-auth/react";
import { useEmployeeSalarySlip } from "@/lib/hooks/useSalary";
import { SalarySlip } from "@/components/salary/SalarySlip";

interface PageProps {
  params: Promise<{ recordId: string }>;
  searchParams: Promise<{ employeeId?: string }>;
}

export default function EmployeeSalarySlipPage({ params, searchParams }: PageProps) {
  const { recordId } = use(params);
  const { employeeId: employeeIdParam } = use(searchParams);
  const { data: session } = useSession();
  const sessionEmployeeId = Number((session?.user as { employeeId?: number })?.employeeId);
  const employeeId = Number(employeeIdParam) || sessionEmployeeId;

  const { data, isLoading } = useEmployeeSalarySlip(employeeId, recordId);

  const handlePrint = () => {
    window.print();
  };

  if (!employeeId) {
    return <p className="text-sm text-rose-500 p-6">Employee ID is required.</p>;
  }

  if (isLoading) return <p className="text-sm text-slate-500 p-6">Loading slip…</p>;
  if (!data) return <p className="text-sm text-rose-500 p-6">Slip not found.</p>;

  return (
    <div className="max-w-3xl mx-auto space-y-4 p-4">
      <Link href="/profile?tab=salary" className="text-sm text-slate-500 hover:text-slate-800 print:hidden">
        ← Back to profile
      </Link>
      <SalarySlip data={data} onPrint={handlePrint} />
    </div>
  );
}
