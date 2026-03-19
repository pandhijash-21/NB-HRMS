import { Badge } from "@/components/ui/badge";

interface VerificationBadgeProps {
  verified: boolean;
  label?: string;
}

export function VerificationBadge({ verified, label }: VerificationBadgeProps) {
  return verified ? (
    <Badge className="bg-emerald-100 text-emerald-700 border-emerald-200 text-xs">
      ✓ {label ?? "Verified"}
    </Badge>
  ) : (
    <Badge variant="outline" className="border-amber-300 text-amber-700 text-xs">
      Pending Verification
    </Badge>
  );
}
