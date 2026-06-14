"use client";

import { useEffect, useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Copy, KeyRound, RefreshCw } from "lucide-react";
import { toast } from "sonner";
import {
  fetchUserCredentials,
  resetUserPassword,
  type AccountCredentials,
} from "@/lib/hooks/useCredentials";

type Props = {
  userId: string | null;
  title?: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Shown once after alias creation */
  initialCredentials?: { loginId: string; password: string } | null;
};

export function AccountCredentialsDialog({
  userId,
  title = "Login credentials",
  open,
  onOpenChange,
  initialCredentials,
}: Props) {
  const [creds, setCreds] = useState<AccountCredentials | null>(null);
  const [revealedPassword, setRevealedPassword] = useState<string | null>(null);
  const [customPassword, setCustomPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [resetting, setResetting] = useState(false);

  useEffect(() => {
    if (!open) {
      setCreds(null);
      setRevealedPassword(null);
      setCustomPassword("");
      return;
    }
    setRevealedPassword(initialCredentials?.password ?? null);
    if (!userId) return;

    setLoading(true);
    fetchUserCredentials(userId)
      .then((c) => {
        setCreds(c);
        if (!initialCredentials && c.password) setRevealedPassword(c.password);
      })
      .catch((e) => toast.error(e?.response?.data?.error || "Failed to load credentials"))
      .finally(() => setLoading(false));
  }, [open, userId, initialCredentials]);

  const loginId = initialCredentials?.loginId ?? creds?.loginId;
  const displayPassword = revealedPassword ?? creds?.password;

  const copy = (text: string, label: string) => {
    navigator.clipboard.writeText(text);
    toast.success(`${label} copied`);
  };

  const handleReset = async () => {
    if (!userId) return;
    setResetting(true);
    try {
      const result = await resetUserPassword(
        userId,
        customPassword.trim() || undefined,
      );
      setRevealedPassword(result.password);
      if (result.loginId) setCreds((prev) => (prev ? { ...prev, loginId: result.loginId } : prev));
      toast.success("Password reset — share with the account holder");
      setCustomPassword("");
    } catch (e: unknown) {
      const ax = e as { response?: { data?: { error?: string } } };
      toast.error(ax.response?.data?.error || "Reset failed");
    } finally {
      setResetting(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2 text-[#1d3459]">
            <KeyRound className="h-5 w-5" />
            {title}
          </DialogTitle>
        </DialogHeader>

        {loading ? (
          <p className="text-sm text-slate-500 py-4">Loading…</p>
        ) : (
          <div className="space-y-4">
            {creds?.canLogin === false && (
              <p className="text-xs text-amber-700 bg-amber-50 border border-amber-100 rounded-lg px-3 py-2">
                Account inactive or missing login id.
              </p>
            )}

            <div className="rounded-lg border bg-slate-50 p-4 space-y-3">
              <div>
                <p className="text-[10px] font-bold uppercase text-slate-400 tracking-widest">Login ID</p>
                <div className="flex items-center justify-between gap-2 mt-1">
                  <p className="font-mono font-bold text-[#1d3459]">{loginId ?? "—"}</p>
                  {loginId && (
                    <Button type="button" size="sm" variant="ghost" onClick={() => copy(loginId, "Login ID")}>
                      <Copy className="h-3.5 w-3.5" />
                    </Button>
                  )}
                </div>
              </div>

              <div>
                <p className="text-[10px] font-bold uppercase text-slate-400 tracking-widest">Password</p>
                <div className="flex items-center justify-between gap-2 mt-1">
                  <p className="font-mono text-sm">
                    {displayPassword ?? "—"}
                  </p>
                  {displayPassword && (
                    <Button type="button" size="sm" variant="ghost" onClick={() => copy(displayPassword, "Password")}>
                      <Copy className="h-3.5 w-3.5" />
                    </Button>
                  )}
                </div>
                {creds?.passwordNote && !displayPassword && (
                  <p className="text-xs text-slate-500 mt-2">{creds.passwordNote}</p>
                )}
              </div>

              {creds && (
                <div className="flex gap-2 flex-wrap">
                  <Badge variant="outline" className="text-[9px] uppercase">
                    {creds.accountType}
                  </Badge>
                  {creds.isFirstLogin && (
                    <Badge className="text-[9px] bg-blue-100 text-blue-700">Unchanged password</Badge>
                  )}
                </div>
              )}
            </div>

            {creds?.passwordNote && (
              <p className="text-xs text-slate-500">{creds.passwordNote}</p>
            )}

            {userId && (
              <div className="border-t pt-4 space-y-2">
                <p className="text-xs font-semibold text-slate-600">Reset password</p>
                <Input
                  type="text"
                  placeholder="Optional custom password (min 8 chars)"
                  value={customPassword}
                  onChange={(e) => setCustomPassword(e.target.value)}
                />
                <Button
                  type="button"
                  variant="outline"
                  className="w-full"
                  disabled={resetting}
                  onClick={handleReset}
                >
                  <RefreshCw className={`h-4 w-4 mr-2 ${resetting ? "animate-spin" : ""}`} />
                  {resetting ? "Resetting…" : "Reset & show new password"}
                </Button>
              </div>
            )}
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
