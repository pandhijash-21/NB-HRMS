"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { signOut, useSession } from "next-auth/react";
import { useChangePassword } from "../hooks/useAuth";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Lock, Eye, EyeOff, Loader2, CheckCircle2 } from "lucide-react";
import { passwordPolicyIssue, PASSWORD_POLICY_HINT } from "@/lib/passwordPolicy";

export function ChangePasswordForm() {
  const router = useRouter();
  const { data: session, status } = useSession();
  const changePasswordMutation = useChangePassword();
  
  const [showCurrent, setShowCurrent] = useState(false);
  const [showNew, setShowNew] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [success, setSuccess] = useState(false);

  const [formData, setFormData] = useState({
    currentPassword: "",
    newPassword: "",
    confirmPassword: "",
  });

  const isFirstLogin = (session?.user as any)?.isFirstLogin;

  useEffect(() => {
    if (status === "authenticated" && !isFirstLogin) {
      router.replace("/home");
    }
  }, [status, isFirstLogin, router]);

  if (status === "authenticated" && !isFirstLogin) {
    return null;
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (formData.newPassword !== formData.confirmPassword) {
      alert("New passwords do not match.");
      return;
    }

    const policyError = passwordPolicyIssue(formData.newPassword);
    if (policyError) {
      alert(policyError);
      return;
    }

    changePasswordMutation.mutate(
      {
        currentPassword: formData.currentPassword,
        newPassword: formData.newPassword,
      },
      {
        onSuccess: () => {
          setSuccess(true);
          setTimeout(() => {
            signOut({ callbackUrl: "/login" });
          }, 3000);
        },
        onError: (error: any) => {
          alert(error.response?.data?.error || "Failed to change password");
        },
      }
    );
  };

  if (success) {
    return (
      <div className="flex flex-col items-center justify-center space-y-4 py-8 animate-in fade-in zoom-in duration-500">
        <div className="w-16 h-16 bg-emerald-500/20 rounded-full flex items-center justify-center">
          <CheckCircle2 className="w-10 h-10 text-emerald-500" />
        </div>
        <div className="text-center space-y-2">
          <h2 className="text-2xl font-bold text-white">Password Updated!</h2>
          <p className="text-white/60 text-sm">
            Redirecting you to login with your new credentials...
          </p>
        </div>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {isFirstLogin && (
        <div className="bg-amber-500/10 border border-amber-500/20 rounded-xl p-4 mb-2 text-amber-200/80 text-xs leading-relaxed">
          <strong>Security Requirement:</strong> {PASSWORD_POLICY_HINT} You will sign in again afterward.
        </div>
      )}

      <div className="space-y-2">
        <Label htmlFor="currentPassword" className="text-white/80 text-xs font-semibold ml-1 uppercase">
          Current Password
        </Label>
        <div className="relative group">
          <div className="absolute left-4 top-1/2 -translate-y-1/2 text-white/40 group-focus-within:text-[#d9b557] transition-colors">
            <Lock className="w-4 h-4" />
          </div>
          <Input
            id="currentPassword"
            name="currentPassword"
            type={showCurrent ? "text" : "password"}
            required
            className="w-full h-12 pl-12 pr-12 bg-white/5 border-white/10 focus:border-[#d9b557]/50 focus:ring-[#d9b557]/20 text-white placeholder:text-white/20 rounded-2xl transition-all"
            placeholder={isFirstLogin ? "Default password (DOB)" : "••••••••"}
            value={formData.currentPassword}
            onChange={(e) =>
              setFormData({ ...formData, currentPassword: e.target.value })
            }
          />
          <button
            type="button"
            onClick={() => setShowCurrent(!showCurrent)}
            className="absolute right-4 top-1/2 -translate-y-1/2 text-white/20 hover:text-white/60 transition-colors"
          >
            {showCurrent ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
          </button>
        </div>
      </div>

      <div className="space-y-2">
        <Label htmlFor="newPassword" className="text-white/80 text-xs font-semibold ml-1 uppercase">
          New Password
        </Label>
        <div className="relative group">
          <div className="absolute left-4 top-1/2 -translate-y-1/2 text-white/40 group-focus-within:text-[#d9b557] transition-colors">
            <Lock className="w-4 h-4" />
          </div>
          <Input
            id="newPassword"
            name="newPassword"
            type={showNew ? "text" : "password"}
            required
            className="w-full h-12 pl-12 pr-12 bg-white/5 border-white/10 focus:border-[#d9b557]/50 focus:ring-[#d9b557]/20 text-white placeholder:text-white/20 rounded-2xl transition-all"
            placeholder="At least 6 characters"
            value={formData.newPassword}
            onChange={(e) =>
              setFormData({ ...formData, newPassword: e.target.value })
            }
          />
          <button
            type="button"
            onClick={() => setShowNew(!showNew)}
            className="absolute right-4 top-1/2 -translate-y-1/2 text-white/20 hover:text-white/60 transition-colors"
          >
            {showNew ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
          </button>
        </div>
      </div>

      <div className="space-y-2">
        <Label htmlFor="confirmPassword" className="text-white/80 text-xs font-semibold ml-1 uppercase">
          Confirm New Password
        </Label>
        <div className="relative group">
          <div className="absolute left-4 top-1/2 -translate-y-1/2 text-white/40 group-focus-within:text-[#d9b557] transition-colors">
            <Lock className="w-4 h-4" />
          </div>
          <Input
            id="confirmPassword"
            name="confirmPassword"
            type={showConfirm ? "text" : "password"}
            required
            className="w-full h-12 pl-12 pr-12 bg-white/5 border-white/10 focus:border-[#d9b557]/50 focus:ring-[#d9b557]/20 text-white placeholder:text-white/20 rounded-2xl transition-all"
            placeholder="Repeat new password"
            value={formData.confirmPassword}
            onChange={(e) =>
              setFormData({ ...formData, confirmPassword: e.target.value })
            }
          />
          <button
            type="button"
            onClick={() => setShowConfirm(!showConfirm)}
            className="absolute right-4 top-1/2 -translate-y-1/2 text-white/20 hover:text-white/60 transition-colors"
          >
            {showConfirm ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
          </button>
        </div>
      </div>

      <Button
        type="submit"
        disabled={changePasswordMutation.isPending}
        className="w-full h-12 bg-white hover:bg-white/90 text-[#1d3459] font-bold rounded-2xl shadow-lg transition-all active:scale-[0.98]"
      >
        {changePasswordMutation.isPending ? (
          <Loader2 className="w-5 h-5 animate-spin" />
        ) : (
          "Update Password"
        )}
      </Button>
    </form>
  );
}
