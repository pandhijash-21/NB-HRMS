import type { Institute } from "@/lib/hooks/useInstitutes";

/** Resolve display label for a stored subOrganization (code or full name). */
export function instituteLabel(
  subOrgOrId: string | null | undefined,
  institutes: Institute[],
): string {
  if (!subOrgOrId) return "—";
  const match = institutes.find(
    (i) =>
      i.id === subOrgOrId ||
      i.code.toLowerCase() === subOrgOrId.toLowerCase() ||
      i.name.toLowerCase() === subOrgOrId.toLowerCase(),
  );
  return match ? `${match.name} (${match.code})` : subOrgOrId;
}

export function instituteById(id: string | null | undefined, institutes: Institute[]) {
  if (!id) return undefined;
  return institutes.find((i) => i.id === id);
}
