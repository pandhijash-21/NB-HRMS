"use client";

import { useEffect, useState } from "react";
import { useSession } from "next-auth/react";
import { Sidebar } from "@/components/layout/Sidebar";
import { Topbar } from "@/components/layout/Topbar";
import api from "@/lib/axios";
import {
  filterAdminNav,
  type NavGroupDef,
  type PermissionMap,
} from "@/lib/auth/permissions";

const adminNav: NavGroupDef[] = [
  {
    heading: "Overview",
    items: [
      {
        label: "Dashboard",
        href: "/admin/dashboard",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <rect x="3" y="3" width="7" height="7" rx="1" />
            <rect x="14" y="3" width="7" height="7" rx="1" />
            <rect x="3" y="14" width="7" height="7" rx="1" />
            <rect x="14" y="14" width="7" height="7" rx="1" />
          </svg>
        ),
      },
    ],
  },
  {
    heading: "HR Management",
    items: [
      {
        label: "Employees",
        href: "/admin/employees",
        module: "PERSONAL_INFO",
        action: "READ",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
            <path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
        ),
      },
      {
        label: "Audit Logs",
        href: "/admin/audit",
        module: "REPORTS",
        action: "READ",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
            <polyline points="14 2 14 8 20 8" />
            <line x1="16" y1="13" x2="8" y2="13" />
            <line x1="16" y1="17" x2="8" y2="17" />
            <polyline points="10 9 9 9 8 9" />
          </svg>
        ),
      },
      {
        label: "Approvals",
        href: "/admin/approvals",
        module: "LEAVE",
        action: "APPROVE",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <path d="M9 11l3 3L22 4" />
            <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11" />
          </svg>
        ),
      },
      {
        label: "Leave Management",
        href: "/admin/leaves",
        module: "LEAVE",
        action: "WRITE",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
            <line x1="16" y1="2" x2="16" y2="6" />
            <line x1="8" y1="2" x2="8" y2="6" />
            <line x1="3" y1="10" x2="21" y2="10" />
          </svg>
        ),
      },
      {
        label: "Pay Commissions",
        href: "/admin/salary/commissions",
        module: "SALARY",
        action: "READ",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <rect x="2" y="5" width="20" height="14" rx="2" />
            <line x1="2" y1="10" x2="22" y2="10" />
          </svg>
        ),
      },
      {
        label: "Salary Structures",
        href: "/admin/salary/structures",
        module: "SALARY",
        action: "READ",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <line x1="12" y1="1" x2="12" y2="23" />
            <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
          </svg>
        ),
      },
      {
        label: "Institutes",
        href: "/admin/institutes",
        module: "USER_MGMT",
        action: "READ",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <path d="M3 21h18" />
            <path d="M5 21V7l8-4v18" />
            <path d="M19 21V11l-6-4" />
            <path d="M9 9v.01" />
            <path d="M9 12v.01" />
            <path d="M9 15v.01" />
            <path d="M9 18v.01" />
          </svg>
        ),
      },
      {
        label: "Designations",
        href: "/admin/designations",
        module: "USER_MGMT",
        action: "READ",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
            <circle cx="12" cy="7" r="4" />
          </svg>
        ),
      },
      {
        label: "Letters",
        href: "/admin/letters",
        module: "FIELD_MGMT",
        action: "READ",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
            <polyline points="14 2 14 8 20 8" />
            <path d="M16 13H8" />
            <path d="M16 17H8" />
            <path d="M10 9H8" />
          </svg>
        ),
      },
      {
        label: "Attendance",
        href: "/admin/attendance",
        module: "ATTENDANCE",
        action: "READ",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
            <line x1="16" y1="2" x2="16" y2="6" />
            <line x1="8" y1="2" x2="8" y2="6" />
            <line x1="3" y1="10" x2="21" y2="10" />
          </svg>
        ),
      },
    ],
  },
  {
    heading: "System Admin",
    items: [
      {
        label: "User Management",
        href: "/admin/users",
        module: "USER_MGMT",
        action: "READ",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <path d="M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M22 21v-2a4 4 0 00-3-3.87" />
            <path d="M16 3.13a4 4 0 010 7.75" />
          </svg>
        ),
      },
      {
        label: "Roles & Permissions",
        href: "/admin/roles",
        module: "ROLE_MGMT",
        action: "READ",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
          </svg>
        ),
      },
    ],
  },
];

export function AdminShell({ children }: { children: React.ReactNode }) {
  const { data: session } = useSession();
  const [perms, setPerms] = useState<PermissionMap>(
    (session?.user as { permissions?: PermissionMap })?.permissions ?? {},
  );
  const [viewScope, setViewScope] = useState<string>(
    (session?.user as { employeeViewScope?: string })?.employeeViewScope ?? "NONE",
  );

  useEffect(() => {
    const fromSession = (session?.user as { permissions?: PermissionMap })?.permissions;
    const scopeFromSession = (session?.user as { employeeViewScope?: string })?.employeeViewScope;
    if (fromSession && Object.keys(fromSession).length > 0 && scopeFromSession) {
      setPerms(fromSession);
      setViewScope(scopeFromSession);
      return;
    }
    api.get("auth/me").then(({ data }) => {
      setPerms(data.data?.permissions ?? fromSession ?? {});
      setViewScope(data.data?.employeeViewScope ?? scopeFromSession ?? "NONE");
    }).catch(() => {});
  }, [session]);

  const navGroups = filterAdminNav(adminNav, perms, viewScope);

  return (
    <div className="app-shell">
      <div className="app-main">
        <Sidebar
          title="HRMS Admin"
          subtitle="Management Portal"
          navGroups={navGroups}
        />
        <div className="flex flex-col flex-1 min-w-0">
          <Topbar title="HRMS Admin" isAdmin={true} />
          <main className="app-content">{children}</main>
        </div>
      </div>
    </div>
  );
}
