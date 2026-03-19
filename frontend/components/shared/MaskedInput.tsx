"use client";

import { useState } from "react";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";

interface MaskedInputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  maskedValue?: string;
  isEditing?: boolean;
}

export function MaskedInput({
  maskedValue,
  isEditing,
  className,
  ...props
}: MaskedInputProps) {
  const [show, setShow] = useState(false);

  if (!isEditing && maskedValue) {
    return (
      <div className="flex items-center gap-2">
        <span className={cn("font-mono text-sm text-slate-700", className)}>
          {show ? props.value ?? maskedValue : maskedValue}
        </span>
        <button
          type="button"
          onClick={() => setShow((s) => !s)}
          className="text-xs text-[#1d3459] underline"
        >
          {show ? "Hide" : "Show"}
        </button>
      </div>
    );
  }

  return <Input className={cn("font-mono", className)} {...props} />;
}
