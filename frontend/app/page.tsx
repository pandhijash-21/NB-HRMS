import Link from "next/link";
import { ThemeToggle } from "@/components/ThemeToggle";

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-background text-foreground relative overflow-hidden transition-colors duration-500">
      
      {/* Absolute Header for Theme Toggle */}
      <div className="absolute top-6 right-6 z-50">
        <ThemeToggle />
      </div>

      {/* Background decoration */}
      <div className="absolute inset-0 z-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-1/4 -right-1/4 w-[800px] h-[800px] rounded-full bg-primary/10 blur-3xl opacity-50 dark:opacity-30" />
        <div className="absolute -bottom-1/4 -left-1/4 w-[600px] h-[600px] rounded-full bg-secondary/10 blur-3xl opacity-50 dark:opacity-30" />
      </div>

      <div className="text-center max-w-xl px-6 z-10 glass-card">
        {/* Logo */}
        <div className="inline-flex items-center justify-center w-24 h-24 rounded-[2rem] mb-8 shadow-xl bg-primary/10 border-2 border-primary/20 backdrop-blur-md">
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2}
            className="w-12 h-12 text-primary"
          >
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
            <path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
        </div>

        <h1 className="text-5xl font-extrabold tracking-tight text-foreground">
          HRMS Portal
        </h1>
        <p className="mt-3 text-xl text-primary font-medium tracking-wide">
          Gandhinagar University
        </p>
        <p className="mt-5 text-base text-muted-foreground max-w-md mx-auto leading-relaxed">
          Human Resource Management System — manage employees, profiles, documents, and seamlessly orchestrate workflows.
        </p>

        <div className="mt-12 flex flex-col sm:flex-row gap-4 justify-center">
          <Link
            href="/login"
            className="inline-flex items-center justify-center px-8 py-3.5 rounded-2xl text-sm font-bold text-primary-foreground bg-primary shadow-lg shadow-primary/30 transition-all hover:scale-[1.02] hover:shadow-xl hover:bg-primary/90"
          >
            Employee Login
          </Link>
          <Link
            href="/admin/dashboard"
            className="inline-flex items-center justify-center px-8 py-3.5 rounded-2xl text-sm font-bold text-foreground bg-card border border-border shadow-sm transition-all hover:bg-accent/50 hover:scale-[1.02]"
          >
            Admin Panel →
          </Link>
        </div>

        <div className="mt-10 flex items-center justify-center gap-6 text-[11px] font-semibold tracking-wider text-muted-foreground uppercase">
          <span className="flex items-center gap-1.5">
            <span className="h-2 w-2 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.5)]" />
            Secure
          </span>
          <span className="flex items-center gap-1.5">
            <span className="h-2 w-2 rounded-full bg-blue-500 shadow-[0_0_8px_rgba(59,130,246,0.5)]" />
            Roles
          </span>
          <span className="flex items-center gap-1.5">
            <span className="h-2 w-2 rounded-full bg-amber-500 shadow-[0_0_8px_rgba(245,158,11,0.5)]" />
            Audit
          </span>
        </div>
      </div>

      <p className="mt-16 text-xs text-muted-foreground font-medium z-10">
        &copy; {new Date().getFullYear()} Gandhinagar University · All rights reserved
      </p>
    </div>
  );
}
