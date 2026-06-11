import { Sidebar } from "@/components/layout/Sidebar";
import { Topbar } from "@/components/layout/Topbar";
import { getServerSession } from "next-auth";
import { authConfig } from "@/app/api/auth/[...nextauth]/route";
import { redirect } from "next/navigation";
import { AppProviders } from "../providers";

// Any authenticated employee can be a reporting manager
const APPROVER_ROLES = ["HOD", "HOI", "REGISTRAR", "VC", "EMPLOYEE", "HR", "ADMIN"];

export const ROLE_LABELS: Record<string, string> = {
  FIRST_REPORTING:  "1st Reporting Manager",
  SECOND_REPORTING: "2nd Reporting Manager",
  THIRD_REPORTING:  "3rd Reporting Manager",
  // kept for historical data
  HOD: "Head of Department", HOI: "Head of Institution",
  REGISTRAR: "Registrar", VC: "Vice Chancellor",
  ADMIN: "Administrator", HR: "HR", EMPLOYEE: "Reporting Manager",
};

const approverNav = [
  {
    heading: "Leave Approvals",
    items: [
      {
        label: "Pending Approvals",
        href: "/approvals",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <path d="M9 11l3 3L22 4" />
            <path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11" />
          </svg>
        ),
      },
      {
        label: "History",
        href: "/approvals/history",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <path d="M12 8v4l3 3" />
            <circle cx="12" cy="12" r="9" />
          </svg>
        ),
      },
    ],
  },
  {
    heading: "My Account",
    items: [
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
      {
        label: "My Leave",
        href: "/leave",
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
];

export default async function ApproverLayout({ children }: { children: React.ReactNode }) {
  const session = await getServerSession(authConfig) as any;
  const role = (session?.user as any)?.role ?? "";
  const subOrg = (session?.user as any)?.subOrganization ?? null;

  if (!session) {
    redirect("/login");
  }

  const roleLabel = ROLE_LABELS[role] ?? "Reporting Manager";
  const subtitle = subOrg ? `${roleLabel} - ${String(subOrg).toUpperCase()}` : roleLabel;

  return (
    <AppProviders>
      <div className="app-shell">
        <div className="app-main">
          <Sidebar
            title="HRMS"
            subtitle={subtitle}
            navGroups={approverNav}
          />
          <div className="flex flex-col flex-1 min-w-0">
            <Topbar title={subtitle} />
            <main className="app-content">{children}</main>
          </div>
        </div>
      </div>
    </AppProviders>
  );
}
