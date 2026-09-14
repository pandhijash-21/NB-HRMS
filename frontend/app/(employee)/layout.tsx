"use client";

import { Sidebar } from "@/components/layout/Sidebar";
import { Topbar } from "@/components/layout/Topbar";
import { useSession } from "next-auth/react";
import { hasPermission } from "@/lib/auth/permissions";

const iconCalendar = (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
    <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
    <line x1="16" y1="2" x2="16" y2="6" />
    <line x1="8" y1="2" x2="8" y2="6" />
    <line x1="3" y1="10" x2="21" y2="10" />
  </svg>
);

export default function EmployeeLayout({ children }: { children: React.ReactNode }) {
  const { data: session } = useSession();
  const employeeId = (session?.user as any)?.employeeId;
  const permissions = (session?.user as any)?.permissions;

  const canAttendance = hasPermission(permissions, "ATTENDANCE", "READ");
  const canChat = hasPermission(permissions, "CHAT", "READ");
  const canMeet = hasPermission(permissions, "MEETINGS", "READ");
  const canLeave = hasPermission(permissions, "LEAVE", "READ") || hasPermission(permissions, "LEAVE", "WRITE");

  const employeeNav = [
    {
      items: [
        {
          label: "Dashboard",
          href: "/dashboard",
          icon: (
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
              <rect x="3" y="3" width="7" height="7" rx="1" />
              <rect x="14" y="3" width="7" height="7" rx="1" />
              <rect x="3" y="14" width="7" height="7" rx="1" />
              <rect x="14" y="14" width="7" height="7" rx="1" />
            </svg>
          ),
        },
        {
          label: "My Profile",
          href: "/profile",
          icon: (
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
              <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
              <circle cx="12" cy="7" r="4" />
            </svg>
          ),
        },
        ...(employeeId && canAttendance ? [{ label: "Attendance", href: "/attendance", icon: iconCalendar }] : []),
        ...(canChat ? [{ label: "Chat", href: "/chat", icon: iconCalendar }] : []),
        ...(canMeet ? [{ label: "Meet", href: "/meet", icon: iconCalendar }] : []),
        ...(canLeave ? [
          { label: "Leave", href: "/leave", icon: iconCalendar },
          {
            label: "Leave History",
            href: "/leave/history",
            icon: (
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
                <path d="M12 8v4l3 3" />
                <circle cx="12" cy="12" r="9" />
              </svg>
            ),
          },
        ] : []),
      ],
    },
  ];

  return (
    <div className="app-shell">
      <div className="app-main">
        <Sidebar
          title="HRMS"
          subtitle="Employee Portal"
          navGroups={employeeNav}
        />
        <div className="flex flex-col flex-1 min-w-0">
          <Topbar title="Employee Portal" />
          <main className="app-content">{children}</main>
        </div>
      </div>
    </div>
  );
}
