import { getServerSession } from "next-auth";
import { authConfig } from "@/app/api/auth/[...nextauth]/route";
import { redirect } from "next/navigation";
import { AppProviders } from "../providers";
import { AdminShell } from "@/components/admin/AdminShell";
import { canAccessAdminPortal } from "@/lib/auth/permissions";
import { resolveSessionAuthContext } from "@/lib/auth/sessionPermissions";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const session = await getServerSession(authConfig);

  if (!session) {
    redirect("/login");
  }

  const { permissions: perms, employeeViewScope } = await resolveSessionAuthContext(session);
  if (!canAccessAdminPortal(perms, employeeViewScope)) {
    redirect("/dashboard");
  }

  return (
    <AppProviders>
      <AdminShell>{children}</AdminShell>
    </AppProviders>
  );
}
