"use client";

import { useState } from "react";
import { useRolesList, useRoleMgmtActions, Role } from "@/lib/hooks/useRole";
import { DataTable } from "@/components/shared/DataTable";
import { AddRoleDialog } from "@/components/admin/roles/AddRoleDialog";
import { ColumnDef } from "@tanstack/react-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Edit, Trash2, Settings } from "lucide-react";
import Link from "next/link";
import { Input } from "@/components/ui/input";

export default function RolesPage() {
  const [search, setSearch] = useState("");

  const { roles, loading, refetch } = useRolesList();
  const { deleteRole } = useRoleMgmtActions();

  const handleDelete = async (role: Role) => {
    if (confirm(`Are you sure you want to delete the role ${role.name}?`)) {
      try {
        await deleteRole(role.id);
        refetch();
      } catch (err: any) {
        alert(err?.response?.data?.message || err.message || "Failed to delete role");
      }
    }
  };

  const filteredRoles = roles.filter(
    (r) => r.name.toLowerCase().includes(search.toLowerCase()) || 
           r.description?.toLowerCase().includes(search.toLowerCase())
  );

  const columns: ColumnDef<Role>[] = [
    {
      accessorKey: "name",
      header: "Role Name",
      cell: ({ row }) => (
        <Badge variant="outline" className="text-xs font-bold tracking-wider uppercase border-[#1d3459]/20 text-[#1d3459] bg-[#1d3459]/5 px-3 py-1">
          {row.original.name}
        </Badge>
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
        const count = row.original._count?.users || 0;
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
          <h2 className="text-2xl font-bold text-[#1d3459] tracking-tight">Roles Overview</h2>
          <p className="text-xs text-slate-500 font-medium">Manage generic institutional security roles and metadata</p>
        </div>
        <div className="flex items-center gap-3">
          <Input
            placeholder="Find roles…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-64 text-sm bg-white border-slate-200 focus:ring-[#1d3459] h-10"
          />
          <AddRoleDialog onRoleAdded={refetch} />
        </div>
      </div>

      <DataTable columns={columns} data={filteredRoles} loading={loading} />
    </div>
  );
}
