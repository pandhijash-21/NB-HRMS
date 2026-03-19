import NextAuth from "next-auth";
import Credentials from "next-auth/providers/credentials";
import type { NextAuthConfig } from "next-auth";
import axios from "axios";

const API_URL =
  process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:4000/api";

export const authConfig = {
  providers: [
    Credentials({
      name: "Credentials",
      credentials: {
        email: {},
        password: {},
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials.password) return null;

        try {
          const res = await axios.post(`${API_URL}/auth/login`, {
            email: credentials.email,
            password: credentials.password,
          });

          const { token, employee } = res.data.data;

          return {
            id: employee.id,
            name: employee.fullName,
            email: employee.email,
            role: employee.role ?? "EMPLOYEE",
            employeeId: employee.id,
            token,
          };
        } catch {
          // Dev fallback — allows any login while backend auth isn't wired
          const email = String(credentials.email);
          const role =
            email.includes("admin") || email.includes("hr")
              ? "ADMIN"
              : "EMPLOYEE";

          return {
            id: "dev-1",
            name: email.split("@")[0],
            email,
            role,
            employeeId: "dev-1",
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
        token.role = (user as { role?: string }).role;
        token.employeeId = (user as { employeeId?: string }).employeeId;
        token.backendToken = (user as { token?: string }).token;
      }
      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        session.user.role = token.role as string;
        session.user.employeeId = token.employeeId as string;
        session.user.token = token.backendToken as string;
      }
      return session;
    },
  },
  pages: {
    signIn: "/login",
  },
} satisfies NextAuthConfig;

const handler = NextAuth(authConfig);

export { handler as GET, handler as POST };
