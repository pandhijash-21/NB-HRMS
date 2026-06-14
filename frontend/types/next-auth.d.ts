import "next-auth";

export type PermissionMap = Record<string, string[]>;

declare module "next-auth" {
  interface Session {
    user: {
      id?: string;
      name?: string | null;
      email?: string | null;
      image?: string | null;
      role?: string;
      employeeId?: string | null;
      username?: string | null;
      subOrganization?: string | null;
      token?: string;
      isFirstLogin?: boolean;
      permissions?: PermissionMap;
      employeeViewScope?: "NONE" | "SELF" | "INSTITUTE" | "UNIVERSITY";
    };
  }

  interface User {
    role?: string;
    employeeId?: string | null;
    username?: string | null;
    subOrganization?: string | null;
    token?: string;
    isFirstLogin?: boolean;
    permissions?: PermissionMap;
    employeeViewScope?: "NONE" | "SELF" | "INSTITUTE" | "UNIVERSITY";
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    role?: string;
    employeeId?: string | null;
    username?: string | null;
    subOrganization?: string | null;
    backendToken?: string;
    isFirstLogin?: boolean;
    userId?: string;
    permissions?: PermissionMap;
    employeeViewScope?: "NONE" | "SELF" | "INSTITUTE" | "UNIVERSITY";
  }
}
