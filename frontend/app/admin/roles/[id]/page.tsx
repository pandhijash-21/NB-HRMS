"use client";

import { use, useEffect, useState } from "react";
import { 
  useRolePermissions, 
  useSystemModules, 
  useRoleMgmtActions,
  useRoleDetails,
  Permission
} from "@/lib/hooks/useRole";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import Link from "next/link";
import { ArrowLeft, Check, X } from "lucide-react";
import { Button } from "@/components/ui/button";

function PermissionToggle({ 
  value, 
  disabled, 
  onChange 
}: { 
  value: boolean; 
  disabled: boolean;
  onChange: (val: boolean) => void; 
}) {
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={() => onChange(!value)}
      className={`relative inline-flex h-5 w-9 shrink-0 cursor-pointer items-center justify-center rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-[#d9b557] focus:ring-offset-2 ${
        value ? 'bg-emerald-500' : 'bg-slate-200'
      } ${disabled ? 'opacity-50 cursor-not-allowed' : ''}`}
      role="switch"
      aria-checked={value}
    >
      <span
        aria-hidden="true"
        className={`pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
          value ? 'translate-x-4' : 'translate-x-0'
        }`}
      />
    </button>
  );
}

export default function PermissionMatrixPage({ params }: { params: Promise<{ id: string }> }) {
  const unwrappedParams = use(params);
  const roleId = unwrappedParams.id;

  const { role, loading: roleLoading } = useRoleDetails(roleId);
  const { modules, loading: modulesLoading } = useSystemModules();
  const { permissions, loading: permsLoading, refetch } = useRolePermissions(roleId);
  const { updatePermissions } = useRoleMgmtActions();

  const [updatingParams, setUpdatingParams] = useState<Record<string, boolean>>({});

  const handleToggle = async (moduleKey: string, field: keyof Permission, nextValue: boolean) => {
    const key = `${moduleKey}-${field}`;
    setUpdatingParams(prev => ({ ...prev, [key]: true }));

    try {
      await updatePermissions(roleId, moduleKey, { [field]: nextValue });
      await refetch();
    } catch (err: any) {
      alert(err?.response?.data?.message || err.message || "Failed to update permission");
    } finally {
      setUpdatingParams(prev => ({ ...prev, [key]: false }));
    }
  };

  const loading = roleLoading || modulesLoading || permsLoading;

  if (loading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-20 w-full rounded-xl" />
        <Skeleton className="h-[500px] w-full rounded-2xl" />
      </div>
    );
  }

  if (!role) {
    return <div className="text-center p-20 text-slate-500 font-medium">Role not found</div>;
  }

  const columns = [
    { key: 'canRead', label: 'Read / View' },
    { key: 'canWrite', label: 'Create / Edit' },
    { key: 'canApprove', label: 'Approve / Authorize' },
    { key: 'canDelete', label: 'Delete / Archive' },
    { key: 'canExport', label: 'Export Data' },
  ] as const;

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-6 rounded-2xl border border-slate-100 shadow-sm">
        <div className="space-y-2">
          <Link href="/admin/roles">
            <Button size="sm" variant="ghost" className="h-6 px-2 -ml-2 text-xs font-bold text-slate-400 hover:text-[#1d3459] mb-1">
              <ArrowLeft className="h-3 w-3 mr-1" /> Back to Roles
            </Button>
          </Link>
          <div className="flex items-center gap-3">
            <h2 className="text-2xl font-bold text-[#1d3459] tracking-tight">{role.name}</h2>
            <Badge className="bg-[#1d3459]/5 text-[#1d3459] hover:bg-[#1d3459]/10 border-none font-bold">
              Permission Matrix
            </Badge>
          </div>
          <p className="text-xs text-slate-500 font-medium">{role.description || "No description provided."}</p>
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-slate-100 shadow-xl shadow-slate-200/50 overflow-hidden">
        <div className="overflow-x-auto">
          <Table className="w-full text-sm">
            <TableHeader>
              <TableRow className="border-b border-slate-50 bg-[#1d3459]/[0.02]">
                <TableHead className="px-6 py-4 text-xs font-bold text-[#1d3459] uppercase tracking-wider w-64 border-r border-slate-100">
                  System Module
                </TableHead>
                {columns.map(col => (
                  <TableHead key={col.key} className="px-6 py-4 text-xs font-bold text-center text-[#1d3459] uppercase tracking-wider">
                    {col.label}
                  </TableHead>
                ))}
              </TableRow>
            </TableHeader>
            <TableBody className="divide-y divide-slate-50">
              {modules.map(module => {
                const perm = permissions.find(p => p.moduleKey === module.key) || {
                  canRead: false,
                  canWrite: false,
                  canApprove: false,
                  canDelete: false,
                  canExport: false,
                } as Permission;

                return (
                  <TableRow key={module.key} className="hover:bg-slate-50/50 transition-colors">
                    <TableCell className="px-6 py-4 border-r border-slate-50">
                      <div className="space-y-1">
                        <p className="font-bold text-slate-800 text-sm tracking-tight">{module.name}</p>
                        {module.description && (
                          <p className="text-[10px] text-slate-400 font-medium leading-relaxed">{module.description}</p>
                        )}
                      </div>
                    </TableCell>
                    {columns.map(col => {
                      const isUpdating = updatingParams[`${module.key}-${col.key}`];
                      return (
                        <TableCell key={col.key} className="px-6 py-4 text-center align-middle">
                          <PermissionToggle
                            value={perm[col.key as keyof Permission] as boolean}
                            disabled={isUpdating}
                            onChange={(nextVal) => handleToggle(module.key, col.key as keyof Permission, nextVal)}
                          />
                        </TableCell>
                      );
                    })}
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </div>
      </div>
    </div>
  );
}
