"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";

interface NavItem {
  label: string;
  href: string;
  icon: React.ReactNode;
}

interface SidebarProps {
  title: string;
  subtitle?: string;
  navGroups: { heading?: string; items: NavItem[] }[];
  footer?: React.ReactNode;
}

export function Sidebar({ title, subtitle, navGroups, footer }: SidebarProps) {
  const pathname = usePathname();

  return (
    <aside className="app-sidebar flex flex-col h-full">
      {/* Logo / Brand */}
      <div
        className="flex flex-col px-5 py-5 border-b border-slate-100"
        style={{ backgroundColor: "#1d3459" }}
      >
        <span className="text-base font-bold tracking-tight text-white">
          {title}
        </span>
        {subtitle && (
          <span className="text-xs text-slate-300 mt-0.5">{subtitle}</span>
        )}
      </div>

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto py-2">
        {navGroups.map((group, gi) => (
          <div key={gi}>
            {group.heading && (
              <p className="app-sidebar-section-title">{group.heading}</p>
            )}
            {group.items.map((item) => {
              const active =
                pathname === item.href ||
                (item.href !== "/" && pathname.startsWith(item.href));
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={cn(
                    "app-sidebar-link",
                    active && "app-sidebar-link-active"
                  )}
                >
                  <span className="w-4 h-4 shrink-0">{item.icon}</span>
                  {item.label}
                </Link>
              );
            })}
          </div>
        ))}
      </nav>

      {/* Footer */}
      {footer && (
        <div className="border-t border-slate-100 px-5 py-4">{footer}</div>
      )}
    </aside>
  );
}
