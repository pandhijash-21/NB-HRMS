"use client";

import { use, useEffect, useState, useMemo } from "react";
import { 
  useRolePermissions, 
  useSystemModules, 
  useRoleMgmtActions,
  useRoleDetails,
  Permission,
  type EmployeeViewScope,
} from "@/lib/hooks/useRole";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import Link from "next/link";
import { ArrowLeft, Search, CheckCircle2, ShieldCheck, ShieldAlert, XCircle, RotateCcw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

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

const CATEGORIES = [
  { id: "ALL", label: "All Modules" },
  { id: "HRMS", label: "HRMS" },
  { id: "CRM", label: "CRM" },
  { id: "ERP", label: "ERP" },
  { id: "COLLABORATION", label: "Collaboration" },
] as const;

export default function PermissionMatrixPage({ params }: { params: Promise<{ id: string }> }) {
  const unwrappedParams = use(params);
  const roleId = unwrappedParams.id;

  const { role, loading: roleLoading } = useRoleDetails(roleId);
  const { modules, loading: modulesLoading } = useSystemModules();
  const { permissions, loading: permsLoading, refetch, applyOptimistic } = useRolePermissions(roleId);
  const { updatePermissions, replacePermissions } = useRoleMgmtActions();

  const [updatingParams, setUpdatingParams] = useState<Record<string, boolean>>({});
  const [selectedCategory, setSelectedCategory] = useState<string>("ALL");
  const [search, setSearch] = useState<string>("");
  const [isBatchUpdating, setIsBatchUpdating] = useState<boolean>(false);

  // Map module metadata
  const moduleDescMap = useMemo(() => {
    const map = new Map<string, { name: string; description: string | null; category: string }>();
    for (const m of modules) {
      map.set(m.key, { name: m.name, description: m.description, category: (m as any).category ?? "HRMS" });
    }
    return map;
  }, [modules]);

  // Modules available to this admin (derived from permissions returned by API)
  const effectiveModules = useMemo(() => {
    if (permissions.length > 0) {
      return permissions.map((p) => {
        const meta = moduleDescMap.get(p.moduleKey);
        return {
          key: p.moduleKey,
          name: p.moduleName || meta?.name || p.moduleKey,
          description: meta?.description || null,
          category: (p.category || meta?.category || "HRMS").toUpperCase(),
          sortOrder: p.sortOrder ?? 0,
        };
      });
    }
    return modules.map((m) => ({
      key: m.key,
      name: m.name,
      description: m.description,
      category: ((m as any).category || "HRMS").toUpperCase(),
      sortOrder: (m as any).sortOrder ?? 0,
    }));
  }, [permissions, modules, moduleDescMap]);

  // Filtered by category and search
  const filteredModules = useMemo(() => {
    return effectiveModules.filter((m) => {
      const matchesCategory = selectedCategory === "ALL" || m.category === selectedCategory;
      const query = search.toLowerCase().trim();
      const matchesSearch =
        !query ||
        m.name.toLowerCase().includes(query) ||
        m.key.toLowerCase().includes(query) ||
        (m.description && m.description.toLowerCase().includes(query));
      return matchesCategory && matchesSearch;
    });
  }, [effectiveModules, selectedCategory, search]);

  const handleScopeChange = async (moduleKey: string, scope: EmployeeViewScope) => {
    const key = `${moduleKey}-scope`;
    const prev = permissions.find((p) => p.moduleKey === moduleKey);
    setUpdatingParams((prev) => ({ ...prev, [key]: true }));
    applyOptimistic(moduleKey, { employeeViewScope: scope });
    try {
      await updatePermissions(roleId, moduleKey, { employeeViewScope: scope });
      await refetch({ silent: true });
    } catch (err: unknown) {
      if (prev) applyOptimistic(moduleKey, { employeeViewScope: prev.employeeViewScope });
      const e = err as { response?: { data?: { message?: string } }; message?: string };
      alert(e?.response?.data?.message || e.message || "Failed to update scope");
    } finally {
      setUpdatingParams((prev) => ({ ...prev, [key]: false }));
    }
  };

  const handleToggle = async (moduleKey: string, field: keyof Permission, nextValue: boolean) => {
    const key = `${moduleKey}-${field}`;
    const prev = permissions.find((p) => p.moduleKey === moduleKey);
    setUpdatingParams((prev) => ({ ...prev, [key]: true }));

    // Cascading updates
    let patch: Partial<Permission> = { [field]: nextValue };
    if (field === "canRead" && nextValue === false) {
      // If revoking read, cascade to all elevated permissions
      patch = {
        canRead: false,
        canWrite: false,
        canApprove: false,
        canDelete: false,
        canExport: false,
      };
    } else if (field !== "canRead" && nextValue === true) {
      // If granting any elevated permission, canRead must be true
      patch = {
        [field]: true,
        canRead: true,
      };
    }

    applyOptimistic(moduleKey, patch);

    try {
      await updatePermissions(roleId, moduleKey, patch);
      await refetch({ silent: true });
    } catch (err: any) {
      if (prev) {
        applyOptimistic(moduleKey, {
          canRead: prev.canRead,
          canWrite: prev.canWrite,
          canApprove: prev.canApprove,
          canDelete: prev.canDelete,
          canExport: prev.canExport,
        });
      }
      alert(err?.response?.data?.message || err.message || "Failed to update permission");
    } finally {
      setUpdatingParams((prev) => ({ ...prev, [key]: false }));
    }
  };

  const handleBatchAction = async (action: "grant_all" | "read_only" | "revoke_all") => {
    if (filteredModules.length === 0) return;
    setIsBatchUpdating(true);
    try {
      const targetKeys = new Set(filteredModules.map((m) => m.key));
      const nextPermissions = permissions.map((p) => {
        if (!targetKeys.has(p.moduleKey)) return p;
        if (action === "grant_all") {
          return { ...p, canRead: true, canWrite: true, canApprove: true, canDelete: true, canExport: true };
        } else if (action === "read_only") {
          return { ...p, canRead: true, canWrite: false, canApprove: false, canDelete: false, canExport: false };
        } else {
          return { ...p, canRead: false, canWrite: false, canApprove: false, canDelete: false, canExport: false };
        }
      });

      // Optimistic update
      for (const m of filteredModules) {
        if (action === "grant_all") {
          applyOptimistic(m.key, { canRead: true, canWrite: true, canApprove: true, canDelete: true, canExport: true });
        } else if (action === "read_only") {
          applyOptimistic(m.key, { canRead: true, canWrite: false, canApprove: false, canDelete: false, canExport: false });
        } else {
          applyOptimistic(m.key, { canRead: false, canWrite: false, canApprove: false, canDelete: false, canExport: false });
        }
      }

      await replacePermissions(roleId, nextPermissions.map((p) => ({
        moduleKey: p.moduleKey,
        canRead: p.canRead,
        canWrite: p.canWrite,
        canApprove: p.canApprove,
        canDelete: p.canDelete,
        canExport: p.canExport,
        employeeViewScope: p.employeeViewScope,
      })));
      await refetch({ silent: true });
    } catch (err: any) {
      await refetch();
      alert(err?.response?.data?.message || err.message || "Failed to batch update permissions");
    } finally {
      setIsBatchUpdating(false);
    }
  };

  const loading = roleLoading || modulesLoading || (permsLoading && permissions.length === 0);

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
      {/* Header */}
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

        {/* Bulk Action Controls */}
        <div className="flex flex-wrap items-center gap-2">
          <Button
            size="sm"
            variant="outline"
            disabled={isBatchUpdating || filteredModules.length === 0}
            onClick={() => handleBatchAction("grant_all")}
            className="text-xs font-bold text-emerald-700 bg-emerald-50 border-emerald-200 hover:bg-emerald-100 h-8"
          >
            <ShieldCheck className="w-3.5 h-3.5 mr-1" /> Grant All
          </Button>
          <Button
            size="sm"
            variant="outline"
            disabled={isBatchUpdating || filteredModules.length === 0}
            onClick={() => handleBatchAction("read_only")}
            className="text-xs font-bold text-blue-700 bg-blue-50 border-blue-200 hover:bg-blue-100 h-8"
          >
            <CheckCircle2 className="w-3.5 h-3.5 mr-1" /> Read Only
          </Button>
          <Button
            size="sm"
            variant="outline"
            disabled={isBatchUpdating || filteredModules.length === 0}
            onClick={() => handleBatchAction("revoke_all")}
            className="text-xs font-bold text-rose-700 bg-rose-50 border-rose-200 hover:bg-rose-100 h-8"
          >
            <XCircle className="w-3.5 h-3.5 mr-1" /> Revoke All
          </Button>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-white p-4 rounded-xl border border-slate-100 shadow-sm">
        {/* Category Tabs */}
        <div className="flex flex-wrap gap-1">
          {CATEGORIES.map((cat) => {
            const count =
              cat.id === "ALL"
                ? effectiveModules.length
                : effectiveModules.filter((m) => m.category === cat.id).length;
            const active = selectedCategory === cat.id;

            return (
              <button
                key={cat.id}
                type="button"
                onClick={() => setSelectedCategory(cat.id)}
                className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-colors inline-flex items-center gap-1.5 ${
                  active
                    ? "bg-[#1d3459] text-white shadow-sm"
                    : "text-slate-600 hover:bg-slate-100"
                }`}
              >
                <span>{cat.label}</span>
                <span
                  className={`text-[10px] px-1.5 py-0.2 rounded-full ${
                    active ? "bg-white/20 text-white" : "bg-slate-200 text-slate-600"
                  }`}
                >
                  {count}
                </span>
              </button>
            );
          })}
        </div>

        {/* Search Input */}
        <div className="relative w-full sm:w-64">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-slate-400 pointer-events-none" />
          <Input
            placeholder="Filter modules..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9 h-9 text-xs bg-slate-50 border-slate-200 focus:bg-white"
          />
        </div>
      </div>

      {/* Matrix Table */}
      <div className="bg-white rounded-2xl border border-slate-100 shadow-xl shadow-slate-200/50 overflow-hidden">
        <div className="overflow-x-auto">
          <Table className="w-full text-sm">
            <TableHeader>
              <TableRow className="border-b border-slate-50 bg-[#1d3459]/[0.02]">
                <TableHead className="px-6 py-4 text-xs font-bold text-[#1d3459] uppercase tracking-wider w-80 border-r border-slate-100">
                  System Module ({filteredModules.length})
                </TableHead>
                {columns.map(col => (
                  <TableHead key={col.key} className="px-6 py-4 text-xs font-bold text-center text-[#1d3459] uppercase tracking-wider">
                    {col.label}
                  </TableHead>
                ))}
              </TableRow>
            </TableHeader>
            <TableBody className="divide-y divide-slate-50">
              {filteredModules.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6} className="text-center py-12 text-slate-400 font-medium text-xs">
                    No modules match the selected filter.
                  </TableCell>
                </TableRow>
              ) : (
                filteredModules.map(module => {
                  const perm = permissions.find(p => p.moduleKey === module.key) || {
                    canRead: false,
                    canWrite: false,
                    canApprove: false,
                    canDelete: false,
                    canExport: false,
                    employeeViewScope: "NONE" as EmployeeViewScope,
                  } as Permission;

                  const viewScope = perm.employeeViewScope ?? "NONE";

                  return (
                    <TableRow key={module.key} className="hover:bg-slate-50/50 transition-colors">
                      <TableCell className="px-6 py-4 border-r border-slate-50">
                        <div className="space-y-1">
                          <div className="flex items-center gap-2">
                            <p className="font-bold text-slate-800 text-sm tracking-tight">{module.name}</p>
                            <span className="text-[9px] font-bold px-1.5 py-0.5 rounded uppercase tracking-wider bg-slate-100 text-slate-600">
                              {module.category}
                            </span>
                          </div>
                          {module.description && (
                            <p className="text-[11px] text-slate-400 font-medium leading-relaxed">{module.description}</p>
                          )}
                          {module.key === "PERSONAL_INFO" && (
                            <div className="pt-2 space-y-1">
                              <p className="text-[10px] font-bold uppercase text-slate-400 tracking-widest">
                                View employees
                              </p>
                              <select
                                className="text-xs border rounded-md px-2 py-1 bg-white"
                                value={viewScope}
                                disabled={!!updatingParams[`${module.key}-scope`]}
                                onChange={(e) => handleScopeChange(module.key, e.target.value as EmployeeViewScope)}
                              >
                                <option value="NONE">Off</option>
                                <option value="SELF">Self only</option>
                                <option value="INSTITUTE">Institute only</option>
                                <option value="UNIVERSITY">University-wide</option>
                              </select>
                              <p className="text-[10px] text-slate-400">
                                Self = own profile only. Institute / University = workforce directory. Edit follows same scope when Write is enabled.
                              </p>
                            </div>
                          )}
                        </div>
                      </TableCell>
                      {columns.map(col => {
                        const isUpdating = updatingParams[`${module.key}-${col.key}`];
                        return (
                          <TableCell key={col.key} className="px-6 py-4 text-center align-middle">
                            <PermissionToggle
                              value={perm[col.key as keyof Permission] as boolean}
                              disabled={isUpdating || isBatchUpdating}
                              onChange={(nextVal) => handleToggle(module.key, col.key as keyof Permission, nextVal)}
                            />
                          </TableCell>
                        );
                      })}
                    </TableRow>
                  );
                })
              )}
            </TableBody>
          </Table>
        </div>
      </div>
    </div>
  );
}
