"use client";

import { useState } from "react";
import { useUsersList, useUserMgmtActions, User } from "@/lib/hooks/useUserMgmt";
import { useRolesList } from "@/lib/hooks/useRole";
import { DataTable } from "@/components/shared/DataTable";
import { AddUserDialog } from "@/components/admin/users/AddUserDialog";
import { EditUserDialog } from "@/components/admin/users/EditUserDialog";
import { ColumnDef } from "@tanstack/react-table";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Button } from "@/components/ui/button";
import { Edit, KeyRound, Trash2 } from "lucide-react";
import { AccountCredentialsDialog } from "@/components/admin/AccountCredentialsDialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

export default function UsersPage() {
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("all");
  const [roleFilter, setRoleFilter] = useState("all");
  
  const [editUser, setEditUser] = useState<User | null>(null);
  const [showEdit, setShowEdit] = useState(false);
  const [credsUser, setCredsUser] = useState<User | null>(null);

  const { users, loading, refetch } = useUsersList({
    search: search ? search : undefined,
    status: statusFilter !== "all" ? statusFilter : undefined,
    roleId: roleFilter !== "all" ? roleFilter : undefined,
  });

  const { roles } = useRolesList();
  const { deleteUser } = useUserMgmtActions();

  const handleDelete = async (user: User) => {
    const label = user.employee?.fullName ?? user.username ?? "this account";
    if (confirm(`Are you sure you want to delete the user account for ${label}?`)) {
      try {
        await deleteUser(user.id);
        refetch();
      } catch (err: any) {
        alert(err.message || "Failed to delete user");
      }
    }
  };

  const currentCount = users?.length || 0;

  const columns: ColumnDef<User>[] = [
    {
      accessorKey: "employee",
      header: "Account",
      cell: ({ row }) => {
        const user = row.original;
        const gi = user.employee?.generalInfo;
        const empFullName = user.employee?.fullName ?? gi?.fullName;
        const empCode = user.employee?.employeeCode ?? gi?.employeeCode;
        const slot = user.positionSlot;
        const label =
          empFullName ??
          slot?.name ??
          slot?.code ??
          user.username ??
          "Unknown";
        const subLabel = empCode ?? (slot ? `ALIAS · ${slot.designation?.name ?? slot.code}` : user.username ? "POSITION" : "—");
        const initials = label.split(" ").map((n) => n[0]).join("").toUpperCase().slice(0, 2) || "??";
        return (
          <div className="flex items-center gap-4">
            <Avatar className="h-10 w-10 shrink-0 border-2 border-white shadow-sm ring-1 ring-slate-100">
              <AvatarImage src={user.employee?.photoUrl || ""} />
              <AvatarFallback style={{ backgroundColor: "#1d3459", color: "#d9b557" }} className="text-xs font-bold">
                {initials}
              </AvatarFallback>
            </Avatar>
            <div className="space-y-0.5">
              <p className="font-bold text-slate-800 text-sm">{label}</p>
              <p className="text-[10px] text-slate-500 font-medium tracking-wide uppercase">{subLabel}</p>
            </div>
          </div>
        );
      },
    },
    {
      accessorKey: "role",
      header: "Assigned Role",
      cell: ({ row }) => {
        const roleName = row.original.role.name;
        return (
          <Badge variant="outline" className="text-[10px] font-bold tracking-wider uppercase border-[#1d3459]/20 text-[#1d3459] bg-[#1d3459]/5">
            {roleName}
          </Badge>
        );
      },
    },
    {
      accessorKey: "isActive",
      header: "Status",
      cell: ({ row }) => {
        const isActive = row.original.isActive;
        return (
          <Badge className={`text-[10px] px-2 py-0.5 border-none font-bold uppercase tracking-tight ${isActive ? "bg-emerald-100 text-emerald-700" : "bg-rose-100 text-rose-600"}`}>
            {isActive ? "ACTIVE" : "INACTIVE"}
          </Badge>
        );
      },
    },
    {
      accessorKey: "lastLoginAt",
      header: "Last Login",
      cell: ({ row }) => {
        const lastLoginAt = row.original.lastLoginAt;
        if (!lastLoginAt) return <span className="text-slate-400 italic text-xs">Never logged in</span>;
        return (
          <span className="text-slate-600 text-xs font-medium">
            {new Date(lastLoginAt).toLocaleString("en-IN", { 
              day: "2-digit", month: "short", year: "numeric", 
              hour: "2-digit", minute: "2-digit" 
            })}
          </span>
        );
      },
    },
    {
      id: "actions",
      header: "Actions",
      cell: ({ row }) => {
        const user = row.original;
        return (
          <div className="flex items-center justify-end gap-2 pr-4">
            <Button
              size="sm"
              variant="ghost"
              title="View login & password"
              className="h-8 w-8 p-0 text-slate-400 hover:text-[#1d3459] hover:bg-[#1d3459]/5"
              onClick={() => setCredsUser(user)}
            >
              <KeyRound className="h-4 w-4" />
            </Button>
            <Button 
              size="sm" 
              variant="ghost" 
              className="h-8 w-8 p-0 text-slate-400 hover:text-[#1d3459] hover:bg-[#1d3459]/5"
              onClick={() => {
                setEditUser(user);
                setShowEdit(true);
              }}
            >
              <Edit className="h-4 w-4" />
            </Button>
            <Button 
              size="sm" 
              variant="ghost" 
              className="h-8 w-8 p-0 text-slate-400 hover:text-rose-600 hover:bg-rose-50"
              onClick={() => handleDelete(user)}
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
          <h2 className="text-2xl font-bold text-[#1d3459] tracking-tight">System Users</h2>
          <p className="text-xs text-slate-500 font-medium">Manage employee login access and system roles ({currentCount} valid accounts)</p>
        </div>
        <div className="flex items-center gap-3">
          <Input
            placeholder="Search by name or code…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-64 text-sm bg-white border-slate-200 focus:ring-[#1d3459] h-10"
          />
          <Select value={statusFilter} onValueChange={setStatusFilter}>
            <SelectTrigger className="w-36 h-10 border-slate-200 bg-white">
              <SelectValue placeholder="Status" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Status</SelectItem>
              <SelectItem value="true">Active</SelectItem>
              <SelectItem value="false">Inactive</SelectItem>
            </SelectContent>
          </Select>
          <Select value={roleFilter} onValueChange={setRoleFilter}>
            <SelectTrigger className="w-40 h-10 border-slate-200 bg-white">
              <SelectValue placeholder="Roles" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Roles</SelectItem>
              {roles.map((r) => (
                <SelectItem key={r.id} value={r.id}>{r.name}</SelectItem>
              ))}
            </SelectContent>
          </Select>

          <AddUserDialog onUserAdded={refetch} />
        </div>
      </div>

      <DataTable columns={columns} data={users} loading={loading} />

      <EditUserDialog 
        user={editUser}
        open={showEdit}
        onOpenChange={setShowEdit}
        onUserUpdated={refetch}
      />

      <AccountCredentialsDialog
        userId={credsUser?.id ?? null}
        title={
          credsUser
            ? `Credentials — ${credsUser.employee?.fullName ?? credsUser.username ?? "User"}`
            : "Login credentials"
        }
        open={!!credsUser}
        onOpenChange={(open) => { if (!open) setCredsUser(null); }}
      />
    </div>
  );
}
