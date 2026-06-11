"use client";

import { formatINR } from "@/lib/utils/currency";
import { Button } from "@/components/ui/button";

type SlipData = {
  institutionName: string;
  monthYear: string;
  employee: { id: number; name: string; designation: string; department: string };
  earnings: Array<{ columnIdentifier: string; effectiveValue: string; formulaPreview?: string }>;
  deductions: Array<{ columnIdentifier: string; effectiveValue: string; formulaPreview?: string }>;
  grossPay: number;
  totalDeductions: number;
  netPay: number;
};

const LABELS: Record<string, string> = {
  basic: "Basic",
  dearness_pay: "Dearness Pay",
  new_basic: "New Basic",
  dearness_allowance: "Dearness Allowance",
  house_rent_allowance: "House Rent Allowance",
  city_compensatory_allowance: "City Compensatory Allowance",
  medical_allowance: "Medical Allowance",
  travel_allowance: "Travel Allowance",
  academic_grade_pay: "Academic Grade Pay",
  special_allowance: "Special Allowance",
  other_allowance: "Other Allowance",
  gratuity: "Gratuity",
  provident_fund: "Provident Fund",
  professional_tax: "Professional Tax",
  tax_deducted_at_source: "Tax Deducted at Source",
  tax_deducted_at_source_against_proof: "TDS Against Proof",
  other_deductions: "Other Deductions",
};

function label(id: string) {
  return LABELS[id] ?? id.replace(/_/g, " ");
}

export function SalarySlip({ data, onPrint }: { data: SlipData; onPrint?: () => void }) {
  return (
    <div className="max-w-2xl mx-auto bg-white p-8 border rounded-lg shadow-sm print:shadow-none print:border-0" id="salary-slip">
      <div className="text-center border-b pb-4 mb-4">
        <h1 className="text-lg font-bold text-slate-800">{data.institutionName}</h1>
        <h2 className="text-base font-semibold text-slate-600 mt-1">Salary Slip — {data.monthYear}</h2>
      </div>

      <div className="grid grid-cols-2 gap-2 text-sm mb-6">
        <div><span className="text-slate-500">Employee:</span> {data.employee.name}</div>
        <div><span className="text-slate-500">Employee ID:</span> {data.employee.id}</div>
        <div><span className="text-slate-500">Designation:</span> {data.employee.designation}</div>
        <div><span className="text-slate-500">Department:</span> {data.employee.department}</div>
      </div>

      <div className="grid grid-cols-2 gap-6">
        <div>
          <h3 className="font-semibold text-sm mb-2 text-emerald-700">Earnings</h3>
          <table className="w-full text-sm">
            <tbody>
              {data.earnings.map((e) => (
                <tr key={e.columnIdentifier} className="border-b border-slate-100">
                  <td className="py-1">{label(e.columnIdentifier)}</td>
                  <td className="py-1 text-right">{formatINR(e.effectiveValue)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div>
          <h3 className="font-semibold text-sm mb-2 text-rose-700">Deductions</h3>
          <table className="w-full text-sm">
            <tbody>
              {data.deductions.map((d) => (
                <tr key={d.columnIdentifier} className="border-b border-slate-100">
                  <td className="py-1">{label(d.columnIdentifier)}</td>
                  <td className="py-1 text-right">{formatINR(d.effectiveValue)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <div className="mt-6 border-t pt-4 space-y-1 text-sm">
        <div className="flex justify-between"><span>Gross Pay</span><span>{formatINR(data.grossPay)}</span></div>
        <div className="flex justify-between"><span>Total Deductions</span><span>{formatINR(data.totalDeductions)}</span></div>
        <div className="flex justify-between font-bold text-base"><span>Net Pay</span><span>{formatINR(data.netPay)}</span></div>
      </div>

      {onPrint && (
        <div className="mt-6 print:hidden">
          <Button onClick={onPrint}>Export / Print PDF</Button>
        </div>
      )}
    </div>
  );
}
