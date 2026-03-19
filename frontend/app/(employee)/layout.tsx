import { Sidebar } from "@/components/layout/Sidebar";
import { Topbar } from "@/components/layout/Topbar";

const employeeNav = [
  {
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
        label: "Edit Profile",
        href: "/profile/edit",
        icon: (
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
            <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
            <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
          </svg>
        ),
      },
    ],
  },
];

export default function EmployeeLayout({ children }: { children: React.ReactNode }) {
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
