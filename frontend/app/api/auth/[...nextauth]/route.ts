import NextAuth from "next-auth";
import Credentials from "next-auth/providers/credentials";
import type { NextAuthOptions } from "next-auth";
import axios from "axios";

const API_URL =
  process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:4000/api";

export const authConfig = {
  providers: [
    Credentials({
      name: "Credentials",
      credentials: {
        employeeId: {},
        password: {},
      },
      async authorize(credentials) {
        if (!credentials?.employeeId || !credentials.password) return null;

        try {
          const res = await axios.post(`${API_URL}/auth/login`, {
            employeeId: Number(credentials.employeeId),
            password:   String(credentials.password),
          });

          const { token, isFirstLogin, employee } = res.data.data;

          return {
            id:           String(employee.id),
            name:         employee.name,
            email:        null,
            role:         employee.role ?? "EMPLOYEE",
            employeeId:   String(employee.id),
            isFirstLogin: isFirstLogin ?? false,
            token,
          };
        } catch {
          // Dev fallback — allows any login while backend auth isn't wired
          const empId = Number(credentials.employeeId);
          const role = (empId === 1) ? "ADMIN" : "EMPLOYEE";

          return {
            id: String(empId),
            name: `Employee #${empId}`,
            email: null,
            role,
            employeeId: String(empId),
            token: "",
          };
        }
      },
    }),
  ],
  session: { strategy: "jwt" },
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        const u = user as { role?: string; employeeId?: string; token?: string; isFirstLogin?: boolean };
        token.role = u.role;
        token.employeeId = u.employeeId;
        token.backendToken = u.token;
        token.isFirstLogin = u.isFirstLogin;
      }
      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        const u = session.user as any;
        u.role = token.role as string;
        u.employeeId = token.employeeId as string;
        u.token = token.backendToken as string;
        u.isFirstLogin = token.isFirstLogin as boolean;
      }
      return session;
    },
  },
  pages: {
    signIn: "/login",
  },
} satisfies NextAuthOptions;

const handler = NextAuth(authConfig);

export { handler as GET, handler as POST };
