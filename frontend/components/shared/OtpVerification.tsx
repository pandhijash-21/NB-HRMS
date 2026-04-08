"use client";

import { useState, useRef, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Loader2, Mail, CheckCircle2, AlertCircle, RefreshCw } from "lucide-react";
import { toast } from "sonner";

interface OtpVerificationProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  email: string;
  onVerified: () => void;
}

export function OtpVerification({
  open,
  onOpenChange,
  email,
  onVerified,
}: OtpVerificationProps) {
  const [otp, setOtp] = useState<string[]>(["", "", "", "", "", ""]);
  const [loading, setLoading] = useState(false);
  const [sending, setSending] = useState(false);
  const [verified, setVerified] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [countdown, setCountdown] = useState(0);
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);

  useEffect(() => {
    if (open && email) {
      sendOtp();
    }
  }, [open, email]);

  useEffect(() => {
    if (countdown > 0) {
      const timer = setTimeout(() => setCountdown(countdown - 1), 1000);
      return () => clearTimeout(timer);
    }
  }, [countdown]);

  const sendOtp = async () => {
    setSending(true);
    setError(null);
    try {
      const response = await fetch("/api/otp/send", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.message || "Failed to send OTP");
      }

      toast.success("OTP sent to your email");
      setCountdown(30);
      inputRefs.current[0]?.focus();
    } catch (err: any) {
      setError(err.message || "Failed to send OTP");
    } finally {
      setSending(false);
    }
  };

  const handleOtpChange = (index: number, value: string) => {
    if (value.length > 1) {
      const digits = value.replace(/\D/g, "").slice(0, 6 - index).split("");
      const newOtp = [...otp];
      digits.forEach((digit, i) => {
        if (index + i < 6) {
          newOtp[index + i] = digit;
        }
      });
      setOtp(newOtp);
      const nextIndex = Math.min(index + digits.length, 5);
      inputRefs.current[nextIndex]?.focus();
      if (index + digits.length >= 6) {
        inputRefs.current[5]?.blur();
      }
    } else {
      const newOtp = [...otp];
      newOtp[index] = value.replace(/\D/g, "");
      setOtp(newOtp);
      if (value && index < 5) {
        inputRefs.current[index + 1]?.focus();
      }
    }
    setError(null);
  };

  const handleKeyDown = (index: number, e: React.KeyboardEvent) => {
    if (e.key === "Backspace" && !otp[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
  };

  const handlePaste = (e: React.ClipboardEvent) => {
    e.preventDefault();
    const pastedData = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, 6);
    const newOtp = [...otp];
    pastedData.split("").forEach((char, i) => {
      if (i < 6) newOtp[i] = char;
    });
    setOtp(newOtp);
    const lastFilledIndex = Math.min(pastedData.length, 5);
    inputRefs.current[lastFilledIndex]?.focus();
  };

  const verifyOtp = async () => {
    const otpValue = otp.join("");
    if (otpValue.length !== 6) {
      setError("Please enter a complete 6-digit OTP");
      return;
    }

    setLoading(true);
    setError(null);
    try {
      const response = await fetch("/api/otp/verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, otp: otpValue }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.message || "Invalid OTP");
      }

      setVerified(true);
      toast.success("Email verified successfully!");
      setTimeout(() => {
        onVerified();
        onOpenChange(false);
        setOtp(["", "", "", "", "", ""]);
        setVerified(false);
      }, 1500);
    } catch (err: any) {
      setError(err.message || "Verification failed");
      setOtp(["", "", "", "", "", ""]);
      inputRefs.current[0]?.focus();
    } finally {
      setLoading(false);
    }
  };

  const handleClose = () => {
    onOpenChange(false);
    setOtp(["", "", "", "", "", ""]);
    setError(null);
    setVerified(false);
  };

  return (
    <Dialog open={open} onOpenChange={handleClose}>
      <DialogContent className="w-full border-none shadow-2xl rounded-2xl p-0 overflow-hidden sm:max-w-[min(98vw,28rem)]">
        <div className="bg-gradient-to-br from-[#1d3459] to-[#2a4a7f] p-6 text-white text-center">
          <div className="w-16 h-16 bg-white/10 rounded-full flex items-center justify-center mx-auto mb-4">
            <Mail className="w-8 h-8 text-[#d9b557]" />
          </div>
          <DialogTitle className="text-lg font-bold">Verify Your Email</DialogTitle>
          <DialogDescription className="text-white/70 text-xs mt-2">
            We&apos;ve sent a 6-digit OTP to<br />
            <span className="font-semibold text-white">{email}</span>
          </DialogDescription>
        </div>

        <div className="p-6 space-y-6">
          {error && (
            <div className="flex items-center gap-2 p-3 bg-rose-50 border border-rose-200 rounded-xl text-rose-600 text-xs">
              <AlertCircle className="w-4 h-4 shrink-0" />
              {error}
            </div>
          )}

          {verified && (
            <div className="flex flex-col items-center gap-2 p-4 bg-emerald-50 border border-emerald-200 rounded-xl text-emerald-600">
              <CheckCircle2 className="w-8 h-8" />
              <p className="text-sm font-bold">Verified!</p>
            </div>
          )}

          {!verified && (
            <>
              <div className="space-y-3">
                <Label className="text-xs font-bold text-slate-500 uppercase tracking-wider text-center block">
                  Enter 6-digit OTP
                </Label>
                <div className="flex justify-center gap-2" onPaste={handlePaste}>
                  {otp.map((digit, index) => (
                    <Input
                      key={index}
                      ref={(el) => { inputRefs.current[index] = el; }}
                      type="text"
                      inputMode="numeric"
                      maxLength={6}
                      value={digit}
                      onChange={(e) => handleOtpChange(index, e.target.value)}
                      onKeyDown={(e) => handleKeyDown(index, e)}
                      disabled={loading}
                      className="w-12 h-12 text-center text-xl font-bold rounded-xl border-slate-200 focus:ring-2 focus:ring-[#1d3459]/20 focus:border-[#1d3459] transition-all"
                    />
                  ))}
                </div>
              </div>

              <DialogFooter className="flex-col gap-2">
                <Button
                  onClick={verifyOtp}
                  disabled={loading || otp.join("").length !== 6}
                  className="w-full bg-[#1d3459] hover:bg-[#1d3459]/90 text-white"
                >
                  {loading ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Verifying...
                    </>
                  ) : (
                    "Verify OTP"
                  )}
                </Button>
                <Button
                  variant="ghost"
                  onClick={sendOtp}
                  disabled={sending || countdown > 0}
                  className="w-full text-xs"
                >
                  {sending ? (
                    <>
                      <Loader2 className="mr-2 h-3 w-3 animate-spin" />
                      Sending...
                    </>
                  ) : countdown > 0 ? (
                    <>
                      <RefreshCw className="mr-2 h-3 w-3" />
                      Resend in {countdown}s
                    </>
                  ) : (
                    <>
                      <RefreshCw className="mr-2 h-3 w-3" />
                      Resend OTP
                    </>
                  )}
                </Button>
              </DialogFooter>
            </>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
