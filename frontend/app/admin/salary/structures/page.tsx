"use client";

import Link from "next/link";
import { useSession } from "next-auth/react";
import axios from "axios";
import { useSalaryStructureStatus, useCreateSalaryTemplate } from "@/lib/hooks/useSalary";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function SalaryStructuresPage() {
  const { status: sessionStatus } = useSession();
  const { data, isLoading, isError, error, refetch, isFetching } = useSalaryStructureStatus();
  const createTemplate = useCreateSalaryTemplate();

  const ensureTemplate = async (designationId: string, payCommissionCode: string) => {
    const result = await createTemplate.mutateAsync({ designationId, payCommissionCode });
    return result.id as string;
  };

  const goConfigure = async (
    designationId: string,
    commissionCode: string,
    templateId: string | null,
  ) => {
    const slug = commissionCode.toLowerCase();
    if (!templateId) {
      const id = await ensureTemplate(designationId, commissionCode);
      window.location.href = `/admin/salary/structures/${designationId}/${slug}?templateId=${id}`;
      return;
    }
    window.location.href = `/admin/salary/structures/${designationId}/${slug}?templateId=${templateId}`;
  };

  if (sessionStatus === "loading" || isLoading) {
    return <p className="text-sm text-slate-500">Loading…</p>;
  }

  if (isError) {
    const apiMsg = axios.isAxiosError(error)
      ? (error.response?.data as { message?: string })?.message
      : undefined;
    return (
      <Card className="p-6 max-w-lg">
        <h2 className="font-semibold text-rose-700">Could not load salary structures</h2>
        <p className="text-sm text-slate-600 mt-2">
          {apiMsg ?? "The server rejected the request. Your session may have expired."}
        </p>
        <div className="flex gap-2 mt-4">
          <Button variant="outline" size="sm" onClick={() => refetch()} disabled={isFetching}>
            {isFetching ? "Retrying…" : "Retry"}
          </Button>
          <Link href="/login"><Button size="sm">Go to login</Button></Link>
        </div>
      </Card>
    );
  }

  if (!data?.length) {
    return (
      <Card className="p-6">
        <p className="text-sm text-slate-600">No designations found. Check that designations are seeded and active.</p>
      </Card>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Salary Structures</h1>
          <p className="text-sm text-slate-500">Configure pay commission rules per designation.</p>
        </div>
        <div className="flex gap-2 flex-wrap">
          <Link href="/admin/salary/commissions">
            <Button variant="outline" size="sm">Pay Commissions</Button>
          </Link>
          <Link href="/admin/salary/entry"><Button variant="outline" size="sm">Salary Entry</Button></Link>
          <Link href="/admin/salary/records"><Button variant="outline" size="sm">Records</Button></Link>
        </div>
      </div>

      <div className="grid gap-4">
        {(data ?? []).map((row) => (
          <Card key={row.designation.id} className="p-4 flex flex-col gap-3">
            <h2 className="font-semibold">{row.designation.name}</h2>
            <div className="flex flex-wrap gap-2">
              {row.commissions.map((c) => (
                <Badge
                  key={c.payCommission.id}
                  variant={c.configured ? "default" : "secondary"}
                >
                  {c.payCommission.name} {c.configured ? "Configured" : "Not configured"}
                </Badge>
              ))}
            </div>
            <div className="flex flex-wrap gap-2">
              {row.commissions.map((c) => (
                <Button
                  key={c.payCommission.id}
                  variant="outline"
                  size="sm"
                  onClick={() => goConfigure(row.designation.id, c.payCommission.code, c.templateId)}
                  disabled={createTemplate.isPending}
                >
                  Configure {c.payCommission.name}
                </Button>
              ))}
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
