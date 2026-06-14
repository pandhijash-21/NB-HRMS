import type { Session } from "next-auth";
import type { PermissionMap } from "./permissions";

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:4000/api";

export type SessionAuthContext = {
  permissions: PermissionMap;
  employeeViewScope: "NONE" | "SELF" | "INSTITUTE" | "UNIVERSITY";
};

/** Permissions from NextAuth session, or fetched from /auth/me when missing (legacy sessions). */
export async function resolveSessionAuthContext(
  session: Session | null,
): Promise<SessionAuthContext> {
  const user = session?.user as {
    permissions?: PermissionMap;
    employeeViewScope?: string;
    token?: string;
  } | undefined;

  const fromSession = user?.permissions;
  const scopeFromSession = user?.employeeViewScope as SessionAuthContext["employeeViewScope"] | undefined;
  if (fromSession && Object.keys(fromSession).length > 0 && scopeFromSession) {
    return { permissions: fromSession, employeeViewScope: scopeFromSession };
  }

  const token = user?.token;
  if (!token) {
    return {
      permissions: fromSession ?? {},
      employeeViewScope: scopeFromSession ?? "NONE",
    };
  }

  try {
    const base = API_URL.endsWith("/") ? API_URL : `${API_URL}/`;
    const res = await fetch(`${base}auth/me`, {
      headers: { Authorization: `Bearer ${token}` },
      cache: "no-store",
    });
    if (!res.ok) {
      return {
        permissions: fromSession ?? {},
        employeeViewScope: scopeFromSession ?? "NONE",
      };
    }
    const json = await res.json();
    return {
      permissions: (json.data?.permissions as PermissionMap) ?? fromSession ?? {},
      employeeViewScope:
        (json.data?.employeeViewScope as SessionAuthContext["employeeViewScope"]) ??
        scopeFromSession ??
        "NONE",
    };
  } catch {
    return {
      permissions: fromSession ?? {},
      employeeViewScope: scopeFromSession ?? "NONE",
    };
  }
}

export async function resolveSessionPermissions(session: Session | null): Promise<PermissionMap> {
  const ctx = await resolveSessionAuthContext(session);
  return ctx.permissions;
}
