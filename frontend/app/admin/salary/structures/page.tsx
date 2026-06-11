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

  const ensureTemplate = async (designationId: string, payCommissionType: "FIFTH" | "SIXTH") => {
    const result = await createTemplate.mutateAsync({ designationId, payCommissionType });
    return result.id as string;
  };

  const goConfigure = async (designationId: string, commission: "fifth" | "sixth", templateId: string | null) => {
    if (!templateId) {
      const id = await ensureTemplate(designationId, commission === "fifth" ? "FIFTH" : "SIXTH");
      window.location.href = `/admin/salary/structures/${designationId}/${commission}?templateId=${id}`;
      return;
    }
    window.location.href = `/admin/salary/structures/${designationId}/${commission}?templateId=${templateId}`;
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
        <p className="text-xs text-slate-500 mt-2">
          Log out and log back in, then try again.
        </p>
        <div className="flex gap-2 mt-4">
          <Button variant="outline" size="sm" onClick={() => refetch()} disabled={isFetching}>
            {isFetching ? "Retrying…" : "Retry"}
          </Button>
          <Link href="/login">
            <Button size="sm">Go to login</Button>
          </Link>
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
          <p className="text-sm text-slate-500">Configure 5th and 6th Pay Commission rules per designation.</p>
        </div>
        <div className="flex gap-2">
          <Link href="/admin/salary/entry"><Button variant="outline" size="sm">Salary Entry</Button></Link>
          <Link href="/admin/salary/records"><Button variant="outline" size="sm">Records</Button></Link>
        </div>
      </div>

      <div className="grid gap-4">
        {(data ?? []).map((row) => (
          <Card key={row.designation.id} className="p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <h2 className="font-semibold">{row.designation.name}</h2>
              <div className="flex gap-2 mt-1">
                <Badge variant={row.fifthConfigured ? "default" : "secondary"}>
                  5th Pay {row.fifthConfigured ? "Configured" : "Not configured"}
                </Badge>
                <Badge variant={row.sixthConfigured ? "default" : "secondary"}>
                  6th Pay {row.sixthConfigured ? "Configured" : "Not configured"}
                </Badge>
              </div>
            </div>
            <div className="flex gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => goConfigure(row.designation.id, "fifth", row.fifthTemplateId)}
                disabled={createTemplate.isPending}
              >
                Configure 5th Pay
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={() => goConfigure(row.designation.id, "sixth", row.sixthTemplateId)}
                disabled={createTemplate.isPending}
              >
                Configure 6th Pay
              </Button>
              {row.fifthTemplateId && (
                <Link href={`/admin/salary/structures/${row.designation.id}/fifth`} className="sr-only">5th</Link>
              )}
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
