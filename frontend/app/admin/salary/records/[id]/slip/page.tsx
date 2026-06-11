"use client";

import { use } from "react";
import Link from "next/link";
import { useSalarySlip } from "@/lib/hooks/useSalary";
import { SalarySlip } from "@/components/salary/SalarySlip";

export default function SalarySlipPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { data, isLoading } = useSalarySlip(id);

  const handlePrint = () => {
    window.print();
  };

  if (isLoading) return <p className="text-sm text-slate-500 p-6">Loading slip…</p>;
  if (!data) return <p className="text-sm text-rose-500 p-6">Slip not found.</p>;

  return (
    <div className="space-y-4 p-4">
      <Link href="/admin/salary/records" className="text-sm text-slate-500 hover:text-slate-800 print:hidden">
        ← Back to records
      </Link>
      <SalarySlip data={data} onPrint={handlePrint} />
    </div>
  );
}
