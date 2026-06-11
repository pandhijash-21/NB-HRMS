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
        identifier: {},
        password: {},
      },
      async authorize(credentials) {
        if (!credentials?.identifier || !credentials.password) return null;

        try {
          const res = await axios.post(`${API_URL}/auth/login`, {
            identifier: String(credentials.identifier),
            password:   String(credentials.password),
          });

          const { token, isFirstLogin, user } = res.data.data;

          return {
            id:           String(user.id),
            name:         user.name,
            email:        null,
            role:         user.role ?? "EMPLOYEE",
            employeeId:   user.employeeId != null ? String(user.employeeId) : null,
            username:     user.username ?? null,
            subOrganization: user.subOrganization ?? null,
            isFirstLogin: isFirstLogin ?? false,
            token,
          };
        } catch (err: any) {
          return null;
        }
      },
    }),
  ],
  session: { strategy: "jwt" },
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        const u = user as { id?: string; role?: string; employeeId?: string | null; username?: string | null; subOrganization?: string | null; token?: string; isFirstLogin?: boolean };
        token.userId = u.id;
        token.role = u.role;
        token.employeeId = u.employeeId;
        token.username = u.username;
        token.subOrganization = u.subOrganization;
        token.backendToken = u.token;
        token.isFirstLogin = u.isFirstLogin;
      }
      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        const u = session.user as any;
        u.id = (token.userId as string) ?? u.id;
        u.role = token.role as string;
        u.employeeId = (token.employeeId as string | null) ?? null;
        u.username = (token.username as string | null) ?? null;
        u.subOrganization = (token.subOrganization as string | null) ?? null;
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
