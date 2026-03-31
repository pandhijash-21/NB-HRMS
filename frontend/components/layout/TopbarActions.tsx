"use client";

import { useState } from "react";
import { useSession, signOut } from "next-auth/react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Bell } from "lucide-react";
import { useSSE } from "@/lib/hooks/useSSE";
import { useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";

interface TopbarActionsProps {
  isAdmin?: boolean;
}

/**
 * Client-only portion of the Topbar.
 * Handles session, SSE real-time events, notification bell, and the user menu.
 * Kept separate so the parent Topbar can remain a server component.
 */
export function TopbarActions({ isAdmin = false }: TopbarActionsProps) {
  const { data: session } = useSession();
  const router = useRouter();
  const queryClient = useQueryClient();
  const [pendingCount, setPendingCount] = useState(0);
  const [notifications, setNotifications] = useState<
    { id: string; message: string; time: string }[]
  >([]);

  const name = session?.user?.name ?? "User";
  const initials = name
    .split(" ")
    .map((n: string) => n[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);

  // Real-time SSE events
  useSSE({
    onChangeRequestCreated: isAdmin
      ? (data) => {
          setPendingCount((c) => c + 1);
          setNotifications((prev) => [
            {
              id: data.id,
              message: data.message,
              time: new Date().toLocaleTimeString("en-IN", {
                hour: "2-digit",
                minute: "2-digit",
              }),
            },
            ...prev.slice(0, 9),
          ]);
          toast.info(`📋 New approval request`, {
            description: data.message,
            action: {
              label: "Review",
              onClick: () => router.push("/admin/approvals"),
            },
            duration: 8000,
          });
        }
      : undefined,

    onChangeRequestApproved: !isAdmin
      ? (data) => {
          toast.success(`✅ ${data.module} update approved by HR!`, {
            description: "Your profile has been updated.",
            duration: 6000,
          });
          queryClient.invalidateQueries({ queryKey: ["admin", "employees"] });
          queryClient.invalidateQueries({
            queryKey: ["change-request", "pending", data.module],
          });
        }
      : undefined,

    onChangeRequestRejected: !isAdmin
      ? (data) => {
          toast.error(`❌ ${data.module} update was not approved`, {
            description: "Please contact HR for details.",
            duration: 6000,
          });
          queryClient.invalidateQueries({
            queryKey: ["change-request", "pending", data.module],
          });
        }
      : undefined,
  });

  return (
    <div className="flex items-center gap-3">
      {/* Notification Bell — Admin only */}
      {isAdmin && (
        <DropdownMenu
          onOpenChange={(open) => {
            if (open) setPendingCount(0);
          }}
        >
          <DropdownMenuTrigger asChild>
            <button className="relative p-2 rounded-xl hover:bg-slate-100 transition-colors focus:outline-none">
              <Bell className="w-5 h-5 text-slate-600" />
              {pendingCount > 0 && (
                <span className="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] bg-rose-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center px-1 animate-pulse">
                  {pendingCount > 9 ? "9+" : pendingCount}
                </span>
              )}
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent
            align="end"
            className="w-80 p-0 rounded-2xl shadow-xl border-slate-100"
          >
            <div className="px-4 py-3 border-b border-slate-100">
              <p className="text-xs font-bold text-slate-700 uppercase tracking-widest">
                Approval Requests
              </p>
            </div>
            <div className="max-h-64 overflow-y-auto">
              {notifications.length === 0 ? (
                <div className="py-8 text-center text-xs text-slate-400 font-medium">
                  No new requests
                </div>
              ) : (
                notifications.map((n) => (
                  <Link key={n.id} href="/admin/approvals">
                    <div className="flex items-start gap-3 px-4 py-3 hover:bg-slate-50 cursor-pointer border-b border-slate-50 last:border-0 transition-colors">
                      <div className="w-8 h-8 rounded-xl bg-amber-100 flex items-center justify-center shrink-0 mt-0.5">
                        <Bell className="w-3.5 h-3.5 text-amber-600" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-xs font-semibold text-slate-700 leading-snug">
                          {n.message}
                        </p>
                        <p className="text-[10px] text-slate-400 mt-1">{n.time}</p>
                      </div>
                    </div>
                  </Link>
                ))
              )}
            </div>
            {notifications.length > 0 && (
              <div className="px-4 py-2 border-t border-slate-100">
                <Link
                  href="/admin/approvals"
                  className="text-[10px] font-bold text-[#1d3459] hover:underline uppercase tracking-widest"
                >
                  View all requests →
                </Link>
              </div>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      )}

      {/* User Menu */}
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <button className="flex items-center gap-2 rounded-full focus:outline-none focus:ring-2 focus:ring-[#d9b557] focus:ring-offset-2">
            <Avatar className="h-8 w-8">
              <AvatarFallback
                style={{ backgroundColor: "#1d3459", color: "#d9b557" }}
                className="text-xs font-semibold"
              >
                {initials}
              </AvatarFallback>
            </Avatar>
            <span className="hidden md:block text-sm font-medium text-slate-700">
              {name}
            </span>
          </button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-44">
          <DropdownMenuItem disabled>
            <span className="text-xs text-slate-500">{session?.user?.email}</span>
          </DropdownMenuItem>
          <DropdownMenuSeparator />
          <DropdownMenuItem
            className="text-rose-600 cursor-pointer"
            onClick={() => signOut({ callbackUrl: "/login" })}
          >
            Sign out
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}
