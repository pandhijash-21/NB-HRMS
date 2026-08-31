import { getServerSession } from "next-auth";
import { redirect } from "next/navigation";
import { authConfig } from "@/app/api/auth/[...nextauth]/route";
import { CollabShell } from "@/components/collab/CollabShell";

export default async function CollabLayout({ children }: { children: React.ReactNode }) {
  const session = await getServerSession(authConfig);
  if (!session) redirect("/login");
  return <CollabShell>{children}</CollabShell>;
}
