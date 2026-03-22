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
        } catch (err: unknown) {
          // Log server-side so we can diagnose in nodemon output
          if (axios.isAxiosError(err)) {
            console.error('[NextAuth] login failed:', err.response?.status, err.response?.data ?? err.message);
          } else {
            console.error('[NextAuth] login error:', err);
          }
          return null;
        }
      },
    }),
  ],
  session: { strategy: "jwt" },
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        const u = user as {
          role?: string;
          employeeId?: string;
          isFirstLogin?: boolean;
          token?: string;
        };
        token.role         = u.role;
        token.employeeId   = u.employeeId;
        token.isFirstLogin = u.isFirstLogin;
        token.backendToken = u.token;
      }
      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        session.user.role         = token.role         as string;
        session.user.employeeId   = token.employeeId   as string;
        session.user.isFirstLogin = token.isFirstLogin as boolean;
        session.user.token        = token.backendToken as string;
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
