import "next-auth";

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
    };
  }

  interface User {
    role?: string;
    employeeId?: string | null;
    username?: string | null;
    subOrganization?: string | null;
    token?: string;
    isFirstLogin?: boolean;
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
  }
}
