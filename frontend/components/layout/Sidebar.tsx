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
      <div className="flex flex-col px-6 py-6 border-b border-white/20 bg-white/10 backdrop-blur-md">
        <span className="text-xl font-extrabold tracking-tight text-[#1d3459] flex items-center gap-2">
          <div className="w-6 h-6 rounded-lg bg-[#1d3459] text-[#d9b557] flex items-center justify-center">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="w-4 h-4">
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
              <circle cx="9" cy="7" r="4" />
              <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
              <path d="M16 3.13a4 4 0 0 1 0 7.75" />
            </svg>
          </div>
          {title}
        </span>
        {subtitle && (
          <span className="text-[0.65rem] font-bold uppercase tracking-wider text-slate-400 mt-1 pl-8">
            {subtitle}
          </span>
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
