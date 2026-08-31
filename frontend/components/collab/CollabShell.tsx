"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useSession } from "next-auth/react";
import { MessageSquare, Video, CalendarDays, ArrowLeft } from "lucide-react";
import { cn } from "@/lib/utils";
import { canAccessAdminPortal } from "@/lib/auth/permissions";

export function CollabShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const { data: session } = useSession();
  const su = session?.user as { permissions?: Record<string, string[]>; employeeViewScope?: string; role?: string };
  const isAdmin = canAccessAdminPortal(su?.permissions, su?.employeeViewScope) || su?.role === "ADMIN";
  const home = isAdmin ? "/admin/dashboard" : "/dashboard";

  const items = [
    { href: "/chat", label: "Chat", icon: MessageSquare },
    { href: "/meet", label: "Meet", icon: Video },
    ...(isAdmin ? [{ href: "/admin/meetings", label: "All meetings", icon: CalendarDays }] : []),
  ];

  return (
    <div className="h-dvh flex flex-col bg-background text-foreground">
      <header className="h-14 shrink-0 border-b border-border/60 bg-card/80 backdrop-blur-xl flex items-center gap-3 px-3 sm:px-5">
        <Link
          href={home}
          className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground"
        >
          <ArrowLeft className="size-4" />
        <span className="hidden sm:inline">NB HRMS</span>
        </Link>
        <div className="h-5 w-px bg-border" />
        <span className="text-sm font-extrabold tracking-tight">NB CRM</span>
        <div className="h-5 w-px bg-border" />
        <nav className="flex items-center gap-1">
          {items.map((item) => {
            const active = pathname === item.href || pathname.startsWith(item.href + "/");
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "inline-flex items-center gap-2 rounded-lg px-3 py-1.5 text-sm font-medium transition-colors",
                  active ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-accent hover:text-foreground",
                )}
              >
                <Icon className="size-4" />
                {item.label}
              </Link>
            );
          })}
        </nav>
      </header>
      <div className="flex-1 min-h-0">{children}</div>
    </div>
  );
}
