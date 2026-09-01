import { LoginForm } from "@/modules/auth/components/LoginForm";
import { Suspense } from "react";
import Image from "next/image";
import { ThemeToggle } from "@/components/ThemeToggle";

export default function LoginPage() {
  return (
    <div className="min-h-screen bg-background text-foreground transition-colors duration-500 relative overflow-hidden">
      {/* Theme Toggle in top-right */}
      <div className="absolute top-6 right-6 z-50">
        <ThemeToggle />
      </div>

      {/* Decorative Background */}
      <div className="absolute inset-0 z-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-[30%] -left-[10%] w-[800px] h-[800px] rounded-full bg-primary/20 blur-3xl opacity-60 dark:opacity-40 mix-blend-multiply dark:mix-blend-screen" />
        <div className="absolute top-[40%] -right-[20%] w-[600px] h-[600px] rounded-full bg-secondary/30 blur-3xl opacity-50 mix-blend-multiply dark:mix-blend-screen" />
      </div>

      <div className="min-h-screen flex items-center justify-center px-4 py-10 z-10 relative">
        <div className="w-full max-w-5xl">
          <div className="grid grid-cols-1 lg:grid-cols-2 overflow-hidden rounded-[2.5rem] border border-border/50 bg-card/60 backdrop-blur-2xl shadow-2xl">
            {/* Left: Institutional panel */}
            <div className="relative p-10 lg:p-14 flex flex-col justify-between">
              <div className="flex items-center gap-5 z-10">
                <div className="relative h-20 w-20 overflow-hidden rounded-[1.5rem] bg-primary/10 border-2 border-primary/20 shadow-inner">
                  <Image
                    src="/nb-logo.png"
                    alt="NB CRM"
                    fill
                    sizes="80px"
                    className="object-contain p-3"
                    priority
                  />
                </div>
                <div>
                  <p className="text-foreground text-2xl sm:text-3xl font-extrabold tracking-tight leading-none">
                    NB CRM
                  </p>
                  <p className="mt-2 text-primary font-bold tracking-wide">
                    CRM · HRMS · ERP
                  </p>
                </div>
              </div>

              <div className="mt-16 lg:mt-32 z-10">
                <h1 className="text-5xl font-black tracking-tighter text-foreground">
                  Sign in
                </h1>
                <p className="mt-4 text-base font-medium text-muted-foreground max-w-sm leading-relaxed">
                  Secure access for faculty and staff members to manage HR operations and personal profiles.
                </p>
              </div>
            </div>

            {/* Right: Login card */}
            <div className="p-8 lg:p-12 bg-accent/30 dark:bg-accent/10 border-l border-border/30 flex flex-col justify-center">
              <div className="mx-auto w-full max-w-md">
                <div className="rounded-[2rem] bg-card/80 border border-border/50 p-6 lg:p-10 shadow-lg backdrop-blur-md">
                  <Suspense fallback={<div className="h-40 animate-pulse bg-muted rounded-xl" />}>
                    <LoginForm />
                  </Suspense>
                </div>

                <p className="mt-8 text-center text-[11px] font-semibold tracking-wider text-muted-foreground uppercase">
                  &copy; {new Date().getFullYear()} NB CRM
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
