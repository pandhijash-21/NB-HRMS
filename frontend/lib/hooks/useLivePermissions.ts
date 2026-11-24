"use client";

import { useEffect, useState, useCallback, useRef } from "react";
import { useSession } from "next-auth/react";
import api from "@/lib/axios";
import type { PermissionMap } from "@/lib/auth/permissions";

export interface LivePermissionsState {
  permissions: PermissionMap;
  employeeViewScope: "NONE" | "SELF" | "INSTITUTE" | "UNIVERSITY";
  role: string | null;
  loading: boolean;
  refresh: () => Promise<void>;
}

export function useLivePermissions(): LivePermissionsState {
  const { data: session, update } = useSession();
  const sessionUser = session?.user as {
    permissions?: PermissionMap;
    employeeViewScope?: "NONE" | "SELF" | "INSTITUTE" | "UNIVERSITY";
    role?: string;
    token?: string;
  } | undefined;

  const [permissions, setPermissions] = useState<PermissionMap>(sessionUser?.permissions ?? {});
  const [employeeViewScope, setEmployeeViewScope] = useState<"NONE" | "SELF" | "INSTITUTE" | "UNIVERSITY">(
    sessionUser?.employeeViewScope ?? "NONE",
  );
  const [role, setRole] = useState<string | null>(sessionUser?.role ?? null);
  const [loading, setLoading] = useState(false);

  // Sync with initial or updated session
  useEffect(() => {
    if (sessionUser?.permissions) {
      setPermissions(sessionUser.permissions);
    }
    if (sessionUser?.employeeViewScope) {
      setEmployeeViewScope(sessionUser.employeeViewScope);
    }
    if (sessionUser?.role) {
      setRole(sessionUser.role);
    }
  }, [sessionUser?.permissions, sessionUser?.employeeViewScope, sessionUser?.role]);

  const refresh = useCallback(async () => {
    try {
      setLoading(true);
      const res = await api.get("/auth/me");
      const data = res.data?.data;
      if (data) {
        const newPerms = data.permissions ?? {};
        const newScope = data.employeeViewScope ?? "NONE";
        const newRole = data.roleName ?? data.role ?? null;

        setPermissions(newPerms);
        setEmployeeViewScope(newScope);
        if (newRole) setRole(newRole);

        // Update NextAuth session cookie
        if (typeof update === "function") {
          await update({
            permissions: newPerms,
            employeeViewScope: newScope,
            role: newRole,
          });
        }
      }
    } catch (err) {
      console.warn("Failed to refresh live permissions:", err);
    } finally {
      setLoading(false);
    }
  }, [update]);

  // Listen to SSE / broadcast updates
  useEffect(() => {
    const handleUpdate = () => {
      refresh();
    };

    window.addEventListener("live_permissions_updated", handleUpdate);
    return () => {
      window.removeEventListener("live_permissions_updated", handleUpdate);
    };
  }, [refresh]);

  return { permissions, employeeViewScope, role, loading, refresh };
}
