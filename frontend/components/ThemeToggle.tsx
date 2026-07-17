"use client";

import { useTheme } from "next-themes";
import { useEffect, useState } from "react";
import { Moon, Sun, Monitor } from "lucide-react";

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  if (!mounted) {
    return <div className="w-10 h-10 rounded-full bg-muted animate-pulse" />;
  }

  const cycleTheme = () => {
    if (theme === "system") {
      setTheme("light");
    } else if (theme === "light") {
      setTheme("dark");
    } else {
      setTheme("system");
    }
  };

  return (
    <button
      onClick={cycleTheme}
      className="relative flex items-center justify-center w-10 h-10 rounded-full transition-all duration-300 hover:bg-muted focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 focus:ring-offset-background group"
      aria-label={`Current theme is ${theme}. Click to change.`}
    >
      <Sun 
        className={`absolute w-5 h-5 transition-all duration-500 ease-in-out ${
          theme === "light" ? "opacity-100 rotate-0 scale-100" : "opacity-0 -rotate-90 scale-0"
        } text-amber-500`} 
      />
      <Moon 
        className={`absolute w-5 h-5 transition-all duration-500 ease-in-out ${
          theme === "dark" ? "opacity-100 rotate-0 scale-100" : "opacity-0 rotate-90 scale-0"
        } text-indigo-400`} 
      />
      <Monitor 
        className={`absolute w-5 h-5 transition-all duration-500 ease-in-out ${
          theme === "system" ? "opacity-100 scale-100" : "opacity-0 scale-0"
        } text-slate-500 dark:text-slate-400`} 
      />
      <span className="sr-only">Toggle theme</span>
    </button>
  );
}
