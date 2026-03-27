"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useSession, signOut } from "next-auth/react";
import axios from "axios";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Lock, Eye, EyeOff, Loader2 } from "lucide-react";

export default function ChangePasswordForm() {
  const router = useRouter();
  const { data: session } = useSession();
  const [loading, setLoading] = useState(false);
  const [showCurrent, setShowCurrent] = useState(false);
  const [showNew, setShowNew] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);

  const [formData, setFormData] = useState({
    currentPassword: "",
    newPassword: "",
    confirmPassword: "",
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (formData.newPassword !== formData.confirmPassword) {
      alert("New passwords do not match.");
      return;
    }

    if (formData.newPassword.length < 6) {
      alert("Password must be at least 6 characters.");
      return;
    }

    setLoading(true);
    try {
      const response = await axios.post(
        `${process.env.NEXT_PUBLIC_API_URL}/auth/change-password`,
        {
          currentPassword: formData.currentPassword,
          newPassword: formData.newPassword,
        },
        {
          headers: {
            Authorization: `Bearer ${session?.user?.token}`,
          },
        }
      );

      if (response.data.success) {
        alert("Password changed successfully! Please log in again.");
        // Sign out to force re-login as per backend logic
        setTimeout(() => {
          signOut({ callbackUrl: "/login" });
        }, 2000);
      }
    } catch (error: any) {
      alert(error.response?.data?.error || "Failed to change password");
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div className="space-y-2">
        <Label className="text-white/80 text-xs font-semibold ml-1">
          CURRENT PASSWORD
        </Label>
        <div className="relative group">
          <div className="absolute left-4 top-1/2 -translate-y-1/2 text-white/40 group-focus-within:text-[#d9b557] transition-colors">
            <Lock className="w-4 h-4" />
          </div>
          <Input
            type={showCurrent ? "text" : "password"}
            required
            className="w-full h-12 pl-12 pr-12 bg-white/5 border-white/10 focus:border-[#d9b557]/50 focus:ring-[#d9b557]/20 text-white placeholder:text-white/20 rounded-2xl transition-all"
            placeholder="••••••••"
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
        <Label className="text-white/80 text-xs font-semibold ml-1">
          NEW PASSWORD
        </Label>
        <div className="relative group">
          <div className="absolute left-4 top-1/2 -translate-y-1/2 text-white/40 group-focus-within:text-[#d9b557] transition-colors">
            <Lock className="w-4 h-4" />
          </div>
          <Input
            type={showNew ? "text" : "password"}
            required
            className="w-full h-12 pl-12 pr-12 bg-white/5 border-white/10 focus:border-[#d9b557]/50 focus:ring-[#d9b557]/20 text-white placeholder:text-white/20 rounded-2xl transition-all"
            placeholder="••••••••"
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
        <Label className="text-white/80 text-xs font-semibold ml-1">
          CONFIRM NEW PASSWORD
        </Label>
        <div className="relative group">
          <div className="absolute left-4 top-1/2 -translate-y-1/2 text-white/40 group-focus-within:text-[#d9b557] transition-colors">
            <Lock className="w-4 h-4" />
          </div>
          <Input
            type={showConfirm ? "text" : "password"}
            required
            className="w-full h-12 pl-12 pr-12 bg-white/5 border-white/10 focus:border-[#d9b557]/50 focus:ring-[#d9b557]/20 text-white placeholder:text-white/20 rounded-2xl transition-all"
            placeholder="••••••••"
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
        disabled={loading}
        className="w-full h-12 bg-white hover:bg-white/90 text-[#1d3459] font-bold rounded-2xl shadow-lg transition-all active:scale-[0.98]"
      >
        {loading ? (
          <Loader2 className="w-5 h-5 animate-spin" />
        ) : (
          "Update Password"
        )}
      </Button>
    </form>
  );
}
