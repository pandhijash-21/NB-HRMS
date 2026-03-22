import "next-auth";

declare module "next-auth" {
  interface Session {
    user: {
      name?: string | null;
      email?: string | null;
      image?: string | null;
      role?: string;
      employeeId?: string;
      isFirstLogin?: boolean;
      token?: string;
    };
  }

  interface User {
    role?: string;
    employeeId?: string;
    isFirstLogin?: boolean;
    token?: string;
  }
}

declare module "next-auth/jwt" {
  interface JWT {
    role?: string;
    employeeId?: string;
    isFirstLogin?: boolean;
    backendToken?: string;
  }
}
