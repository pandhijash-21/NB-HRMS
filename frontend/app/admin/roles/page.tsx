"use client";

import { useState } from "react";
import Link from "next/link";
import { useRolesList, useRoleMgmtActions, Role } from "@/lib/hooks/useRole";
import { DataTable } from "@/components/shared/DataTable";
import { ColumnDef } from "@tanstack/react-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Trash2, Settings, Shield } from "lucide-react";
import { Input } from "@/components/ui/input";
import { CreatePositionDialog } from "@/components/employees/CreatePositionDialog";

export default function RolesPage() {
  const [search, setSearch] = useState("");
  const [positionsOnly, setPositionsOnly] = useState(false);

  const { roles, loading, refetch } = useRolesList({ positionsOnly });
  const { deleteRole } = useRoleMgmtActions();

  const handleDelete = async (role: Role) => {
    if (confirm(`Are you sure you want to delete the position role ${role.name}?`)) {
      try {
        await deleteRole(role.id);
        refetch();
      } catch (err: any) {
        alert(err?.response?.data?.message || err.message || "Failed to delete role");
      }
    }
  };

  const filteredRoles = roles.filter(
    (r) =>
      r.name.toLowerCase().includes(search.toLowerCase()) ||
      r.description?.toLowerCase().includes(search.toLowerCase()) ||
      r.positionName?.toLowerCase().includes(search.toLowerCase()),
  );

  const columns: ColumnDef<Role>[] = [
    {
      accessorKey: "positionName",
      header: "Position",
      cell: ({ row }) => (
        <div className="space-y-1">
          <span className="text-sm font-bold text-slate-800 block">
            {row.original.positionName || row.original.name}
          </span>
          <Badge variant="outline" className="text-[9px] font-bold tracking-wider uppercase border-[#1d3459]/20 text-[#1d3459] bg-[#1d3459]/5 px-2 py-0">
            {row.original.name}
          </Badge>
        </div>
      ),
    },
    {
      accessorKey: "description",
      header: "Description",
      cell: ({ row }) => (
        <span className="text-slate-600 text-xs font-medium max-w-[300px] truncate block">
          {row.original.description || <span className="text-slate-400 italic">No description</span>}
        </span>
      ),
    },
    {
      accessorKey: "usersCount",
      header: "Assigned Users",
      cell: ({ row }) => {
        const count = row.original._count?.users || row.original.userCount || 0;
        return (
          <div className="flex items-center gap-2">
            <span className="text-sm font-bold text-[#1d3459] w-6">{count}</span>
            <span className="text-[10px] text-slate-500 font-bold uppercase tracking-wider">Users</span>
          </div>
        );
      },
    },
    {
      id: "actions",
      header: "Actions",
      cell: ({ row }) => {
        const role = row.original;

        return (
          <div className="flex items-center justify-end gap-2 pr-4">
            <Link href={`/admin/roles/${role.id}`}>
              <Button size="sm" variant="outline" className="h-8 gap-2 text-xs font-bold uppercase text-[#1d3459] border-[#1d3459]/20 hover:bg-[#1d3459]/5">
                <Settings className="h-3.5 w-3.5" /> Matrix
              </Button>
            </Link>

            <Button
              size="sm"
              variant="ghost"
              className="h-8 w-8 p-0 text-slate-400 hover:text-rose-600 hover:bg-rose-50"
              onClick={() => handleDelete(role)}
            >
              <Trash2 className="h-4 w-4" />
            </Button>
          </div>
        );
      },
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <Shield className="h-5 w-5 text-[#1d3459]" />
            <h2 className="text-2xl font-bold text-[#1d3459] tracking-tight">Roles &amp; Permissions</h2>
          </div>
          <p className="text-xs text-slate-500 font-medium max-w-2xl">
            Configure permission matrices for all institutional roles and positions. Select a role below to customize its granular access.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <div className="inline-flex rounded-lg border border-slate-200 bg-slate-50 p-0.5 text-xs font-semibold">
            <button
              type="button"
              onClick={() => setPositionsOnly(false)}
              className={`px-3 py-1.5 rounded-md transition-colors ${
                !positionsOnly ? "bg-white text-[#1d3459] shadow-sm font-bold" : "text-slate-500 hover:text-slate-900"
              }`}
            >
              All Roles
            </button>
            <button
              type="button"
              onClick={() => setPositionsOnly(true)}
              className={`px-3 py-1.5 rounded-md transition-colors ${
                positionsOnly ? "bg-white text-[#1d3459] shadow-sm font-bold" : "text-slate-500 hover:text-slate-900"
              }`}
            >
              Positions Only
            </button>
          </div>
          <Input
            placeholder="Find roles or positions…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-56 text-sm bg-white border-slate-200 focus:ring-[#1d3459] h-9"
          />
          <CreatePositionDialog onCreated={refetch} />
        </div>
      </div>

      <DataTable columns={columns} data={filteredRoles} loading={loading} />
    </div>
  );
}
