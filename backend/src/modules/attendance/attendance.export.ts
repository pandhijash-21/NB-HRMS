import PDFDocument from 'pdfkit';
import ExcelJS from 'exceljs';
// @ts-ignore
import * as archiverModule from 'archiver';

function initZipArchive(options: any = { zlib: { level: 9 } }): any {
  const mod: any = archiverModule;
  if (mod.ZipArchive) return new mod.ZipArchive(options);
  if (mod.default?.ZipArchive) return new mod.default.ZipArchive(options);
  if (typeof mod.default === 'function') return mod.default('zip', options);
  if (typeof mod === 'function') return mod('zip', options);
  try {
    const directReq = require('archiver');
    if (directReq.ZipArchive) return new directReq.ZipArchive(options);
    if (directReq.default?.ZipArchive) return new directReq.default.ZipArchive(options);
    if (typeof directReq === 'function') return directReq('zip', options);
    if (typeof directReq.default === 'function') return directReq.default('zip', options);
  } catch (_) {}
  throw new Error('Unable to initialize zip archive generator');
}

export type EmployeeAttendanceExportData = {
  employee: {
    employeeId: number;
    fullName: string;
    employeeCode: string | null;
    designation: string | null;
    department: string | null;
  };
  policy?: {
    punchInTime?: string | null;
    punchOutTime?: string | null;
    punchInBufferMinutes?: number | null;
  };
  period: {
    year: number;
    month: number;
    from: string;
    to: string;
  };
  summary: {
    totalCalendarDays: number;
    totalWorkingDays: number;
    presentDays: number;
    wfhFullDays: number;
    wfhHalfDays: number;
    halfDays: number;
    leaveDays: number;
    holidayDays: number;
    absentDays: number;
    totalWorkedMinutes: number;
    averageDailyMinutes: number;
    lateCount: number;
    bufferGraceUsedCount: number;
  };
  days: Array<{
    date: string;
    dayName: string;
    firstIn: string | null;
    lastOut: string | null;
    totalMinutes: number;
    dayStatus: string;
    isLate: boolean;
    isHalfDay: boolean;
    bufferGraceUsed: boolean;
    meetsPunchOut: boolean;
    punchCount: number;
    wfhDetails?: {
      isHalfDay: boolean;
      session: string | null;
    } | null;
    remarks?: string | null;
  }>;
};

export type AttendanceReportExportInput = {
  mode: 'DAY_WISE_MONTHLY' | 'EMPLOYEE_WISE';
  year: number;
  month: number;
  employees: EmployeeAttendanceExportData[];
};

export const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

export function sanitizeFileName(name: string): string {
  return (name || '')
    .trim()
    .replace(/[^\w\d-_]/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '');
}

export function getEmployeeReportFileName(
  emp: any,
  year: number,
  month: number,
  ext: 'xlsx' | 'pdf'
): string {
  const monthName = MONTH_NAMES[month - 1] || `Month_${month}`;
  const employeeInfo = emp?.employee || emp || {};
  const rawName = employeeInfo.fullName || (employeeInfo.employeeId ? `Employee_${employeeInfo.employeeId}` : 'Employee');
  const rawCode = employeeInfo.employeeCode || (employeeInfo.employeeId ? `${employeeInfo.employeeId}` : '');
  const empName = sanitizeFileName(rawName);
  const code = sanitizeFileName(rawCode);
  const codePart = code ? `_${code}` : '';
  return `Attendance_Report_${empName}${codePart}_${monthName}_${year}.${ext}`;
}

export function getBatchReportFileName(
  year: number,
  month: number,
  ext: 'xlsx' | 'pdf' | 'zip',
  mode: 'single' | 'separate' | 'zip' = 'single'
): string {
  const monthName = MONTH_NAMES[month - 1] || `Month_${month}`;
  if (ext === 'zip' || mode === 'zip' || mode === 'separate') {
    return `Attendance_Reports_Separate_${monthName}_${year}.zip`;
  }
  return `Attendance_Report_All_Employees_${monthName}_${year}.${ext}`;
}

export async function buildAttendanceZip(
  files: Array<{ fileName: string; buffer: Buffer }>
): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const archive = initZipArchive({ zlib: { level: 9 } });
    const chunks: Buffer[] = [];
    archive.on('data', (chunk: any) => chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)));
    archive.on('end', () => resolve(Buffer.concat(chunks)));
    archive.on('error', (err: any) => reject(err));

    for (const file of files) {
      archive.append(file.buffer, { name: file.fileName });
    }
    archive.finalize();
  });
}

function formatMinutes(minutes: number): string {
  const m = Math.max(0, Math.round(Number(minutes) || 0));
  const h = Math.floor(m / 60);
  const rem = m % 60;
  return `${h}h ${String(rem).padStart(2, '0')}m`;
}

function formatStatusLabel(day: EmployeeAttendanceExportData['days'][0]): string {
  const s = (day.dayStatus || '').toUpperCase();
  if (s === 'WFH') {
    if (day.wfhDetails?.isHalfDay) {
      return `WFH (Half Day - ${day.wfhDetails.session || 'Morning'})`;
    }
    return 'Work From Home (WFH)';
  }
  if (s === 'WFH_HALF_DAY') {
    return `WFH (Half Day - ${day.wfhDetails?.session || 'Morning'})`;
  }
  if (s === 'PRESENT') {
    if (day.isHalfDay) return 'Present (Half Day)';
    return 'Present';
  }
  if (s === 'LEAVE') return 'On Leave';
  if (s === 'HOLIDAY') return 'Holiday / Week Off';
  if (s === 'ABSENT') return 'Absent';
  return s || 'Absent';
}

function getStatusBadgeColor(day: EmployeeAttendanceExportData['days'][0]): { fill: string; text: string } {
  const s = (day.dayStatus || '').toUpperCase();
  if (s === 'WFH' || s === 'WFH_HALF_DAY') {
    return { fill: '#0D9488', text: '#FFFFFF' };
  }
  if (s === 'PRESENT') {
    if (day.isHalfDay) return { fill: '#D97706', text: '#FFFFFF' };
    return { fill: '#16A34A', text: '#FFFFFF' };
  }
  if (s === 'LEAVE') {
    return { fill: '#2563EB', text: '#FFFFFF' };
  }
  if (s === 'HOLIDAY') {
    return { fill: '#64748B', text: '#FFFFFF' };
  }
  return { fill: '#DC2626', text: '#FFFFFF' };
}

// ---------------------------------------------------------------------------
// ExcelJS Styling Palettes & Borders
// ---------------------------------------------------------------------------

const borderThin = {
  top: { style: 'thin' as const, color: { argb: 'FFCBD5E1' } },
  left: { style: 'thin' as const, color: { argb: 'FFCBD5E1' } },
  bottom: { style: 'thin' as const, color: { argb: 'FFCBD5E1' } },
  right: { style: 'thin' as const, color: { argb: 'FFCBD5E1' } },
};

const borderMedium = {
  top: { style: 'medium' as const, color: { argb: 'FF94A3B8' } },
  left: { style: 'medium' as const, color: { argb: 'FF94A3B8' } },
  bottom: { style: 'medium' as const, color: { argb: 'FF94A3B8' } },
  right: { style: 'medium' as const, color: { argb: 'FF94A3B8' } },
};

function applyCellBorder(cell: ExcelJS.Cell, border = borderThin) {
  cell.border = border;
}

function applyRangeBorder(ws: ExcelJS.Worksheet, startCol: number, startRow: number, endCol: number, endRow: number) {
  for (let r = startRow; r <= endRow; r++) {
    for (let c = startCol; c <= endCol; c++) {
      ws.getCell(r, c).border = borderThin;
    }
  }
}

/**
 * Generates structured, professional Excel workbook with rich corporate colors,
 * borders, KPI cards, and day-by-day table using ExcelJS.
 */
export async function buildAttendanceExcel(
  input: AttendanceReportExportInput
): Promise<{ buffer: Buffer; fileName: string }> {
  const wb = new ExcelJS.Workbook();
  wb.creator = 'NB Since 1946';
  wb.lastModifiedBy = 'NB HRMS';
  wb.created = new Date();
  wb.modified = new Date();

  const monthName = MONTH_NAMES[input.month - 1] || `Month ${input.month}`;
  const periodLabel = `${monthName} ${input.year}`;

  const fileName = input.employees.length === 1
    ? getEmployeeReportFileName(input.employees[0], input.year, input.month, 'xlsx')
    : getBatchReportFileName(input.year, input.month, 'xlsx', 'single');

  if (input.employees.length === 0) {
    const ws = wb.addWorksheet('Attendance');
    ws.views = [{ showGridLines: true }];
    ws.mergeCells('A1:G1');
    const titleCell = ws.getCell('A1');
    titleCell.value = 'NB Since 1946 - Attendance Report';
    titleCell.font = { name: 'Segoe UI', size: 14, bold: true, color: { argb: 'FFFFFFFF' } };
    titleCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF0F172A' } };
    titleCell.alignment = { horizontal: 'center', vertical: 'middle' };

    ws.getCell('A3').value = `Period: ${periodLabel}`;
    ws.getCell('A4').value = 'No employee attendance records found for this period.';
    const rawBuffer = await wb.xlsx.writeBuffer();
    const buffer = Buffer.from(rawBuffer);
    return { buffer, fileName };
  }

  // 1. If multiple employees in EMPLOYEE_WISE mode, create a Master Summary Sheet first
  if (input.mode === 'EMPLOYEE_WISE' && input.employees.length > 1) {
    const wsSummary = wb.addWorksheet('Summary Overview', {
      views: [{ showGridLines: true }],
    });

    // Title Banner
    wsSummary.mergeCells('A1:P1');
    const banner = wsSummary.getCell('A1');
    banner.value = 'NB SINCE 1946 — WORKFORCE ATTENDANCE SUMMARY';
    banner.font = { name: 'Segoe UI', size: 13, bold: true, color: { argb: 'FFFFD700' } };
    banner.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF0F172A' } };
    banner.alignment = { horizontal: 'center', vertical: 'middle' };
    wsSummary.getRow(1).height = 32;

    wsSummary.mergeCells('A2:P2');
    const subBanner = wsSummary.getCell('A2');
    subBanner.value = `Period: ${periodLabel} | Generated: ${new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })}`;
    subBanner.font = { name: 'Segoe UI', size: 9, italic: true, color: { argb: 'FF94A3B8' } };
    subBanner.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1E293B' } };
    subBanner.alignment = { horizontal: 'center', vertical: 'middle' };
    wsSummary.getRow(2).height = 20;

    // Table Headers
    const summaryHeaders = [
      'Emp Code', 'Employee Name', 'Designation', 'Department',
      'Total Days', 'Working Days', 'Present Days', 'WFH (Full)',
      'WFH (Half)', 'Half Days', 'Leaves', 'Holidays',
      'Absent', 'Total Work Duration', 'Avg Hours/Day', 'Late Marks'
    ];

    const hRow = wsSummary.getRow(4);
    hRow.height = 26;
    summaryHeaders.forEach((h, idx) => {
      const cell = hRow.getCell(idx + 1);
      cell.value = h;
      cell.font = { name: 'Segoe UI', size: 9.5, bold: true, color: { argb: 'FFFFFFFF' } };
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF0F766E' } };
      cell.alignment = { horizontal: 'center', vertical: 'middle' };
      cell.border = borderThin;
    });

    let sRowIdx = 5;
    for (const emp of input.employees) {
      const s = emp.summary || ({} as any);
      const r = wsSummary.getRow(sRowIdx);
      r.height = 21;
      const isEven = sRowIdx % 2 === 0;
      const rowFill: ExcelJS.Fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: isEven ? 'FFFFFFFF' : 'FFF8FAFC' }
      };

      const values = [
        emp.employee.employeeCode || `ID #${emp.employee.employeeId}`,
        emp.employee.fullName,
        emp.employee.designation || 'N/A',
        emp.employee.department || 'N/A',
        s.totalCalendarDays,
        s.totalWorkingDays,
        s.presentDays,
        s.wfhFullDays,
        s.wfhHalfDays,
        s.halfDays,
        s.leaveDays,
        s.holidayDays,
        s.absentDays,
        formatMinutes(s.totalWorkedMinutes),
        formatMinutes(s.averageDailyMinutes),
        s.lateCount
      ];

      values.forEach((v, idx) => {
        const cell = r.getCell(idx + 1);
        cell.value = v;
        cell.font = { name: 'Segoe UI', size: 9.5, color: { argb: 'FF0F172A' } };
        cell.fill = rowFill;
        cell.border = borderThin;

        // Alignments & status highlights
        if (idx === 0 || idx === 4 || idx === 5 || idx === 11) {
          cell.alignment = { horizontal: 'center', vertical: 'middle' };
        } else if (idx === 1 || idx === 2 || idx === 3) {
          cell.alignment = { horizontal: 'left', vertical: 'middle' };
          if (idx === 1) cell.font = { name: 'Segoe UI', size: 9.5, bold: true, color: { argb: 'FF0F172A' } };
        } else if (idx === 6) {
          // Present
          cell.alignment = { horizontal: 'center', vertical: 'middle' };
          cell.font = { name: 'Segoe UI', size: 9.5, bold: true, color: { argb: 'FF15803D' } };
        } else if (idx === 7 || idx === 8) {
          // WFH
          cell.alignment = { horizontal: 'center', vertical: 'middle' };
          cell.font = { name: 'Segoe UI', size: 9.5, bold: true, color: { argb: 'FF0F766E' } };
        } else if (idx === 12) {
          // Absent
          cell.alignment = { horizontal: 'center', vertical: 'middle' };
          if (Number(v) > 0) {
            cell.font = { name: 'Segoe UI', size: 9.5, bold: true, color: { argb: 'FFDC2626' } };
          }
        } else {
          cell.alignment = { horizontal: 'center', vertical: 'middle' };
        }
      });

      sRowIdx++;
    }

    wsSummary.columns = [
      { width: 14 }, { width: 24 }, { width: 20 }, { width: 18 },
      { width: 12 }, { width: 13 }, { width: 13 }, { width: 12 },
      { width: 12 }, { width: 11 }, { width: 10 }, { width: 10 },
      { width: 10 }, { width: 18 }, { width: 15 }, { width: 12 }
    ];
  }

  // 2. Individual Sheets for Each Employee
  const isMultiEmployee = input.employees.length > 1;
  const maxTabs = isMultiEmployee ? Math.min(input.employees.length, 30) : 1;

  for (let idx = 0; idx < maxTabs; idx++) {
    const emp = input.employees[idx];
    const s = emp.summary || ({} as any);
    const safeName = (emp.employee.fullName || `Emp_${emp.employee.employeeId}`)
      .replace(/[\\/?*:[\]]/g, '')
      .substring(0, 22);
    const code = emp.employee.employeeCode || emp.employee.employeeId;
    const sheetName = isMultiEmployee ? `${code} - ${safeName}`.substring(0, 31) : 'Attendance Log';

    const ws = wb.addWorksheet(sheetName, {
      views: [{ showGridLines: true }],
      pageSetup: { orientation: 'landscape', fitToPage: true, fitToWidth: 1 }
    });

    // -------------------------------------------------------------
    // TOP BANNER (Rows 1-2)
    // -------------------------------------------------------------
    ws.mergeCells('A1:I1');
    const bannerCell = ws.getCell('A1');
    bannerCell.value = 'NB SINCE 1946 — EMPLOYEE ATTENDANCE REPORT';
    bannerCell.font = { name: 'Segoe UI', size: 14, bold: true, color: { argb: 'FFFFD700' } };
    bannerCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF0F172A' } };
    bannerCell.alignment = { horizontal: 'center', vertical: 'middle' };
    ws.getRow(1).height = 32;

    ws.mergeCells('A2:I2');
    const periodCell = ws.getCell('A2');
    periodCell.value = `Period: ${periodLabel} | Generated: ${new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })} IST`;
    periodCell.font = { name: 'Segoe UI', size: 9, italic: true, color: { argb: 'FF94A3B8' } };
    periodCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1E293B' } };
    periodCell.alignment = { horizontal: 'center', vertical: 'middle' };
    ws.getRow(2).height = 20;

    // -------------------------------------------------------------
    // EMPLOYEE DETAILS CARD (Rows 4-6)
    // -------------------------------------------------------------
    ws.mergeCells('A4:I4');
    const empHeader = ws.getCell('A4');
    empHeader.value = 'EMPLOYEE PROFILE & WORK SCHEDULE';
    empHeader.font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FF0F172A' } };
    empHeader.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE2E8F0' } };
    empHeader.alignment = { horizontal: 'left', vertical: 'middle', indent: 1 };
    ws.getRow(4).height = 24;

    // Row 5
    const r5 = ws.getRow(5);
    r5.height = 22;
    r5.getCell(1).value = 'Employee Name:';
    r5.getCell(1).font = { name: 'Segoe UI', size: 9, bold: true, color: { argb: 'FF475569' } };
    r5.getCell(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF1F5F9' } };
    ws.mergeCells('B5:C5');
    r5.getCell(2).value = emp.employee.fullName;
    r5.getCell(2).font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FF0F172A' } };

    r5.getCell(4).value = 'Employee Code:';
    r5.getCell(4).font = { name: 'Segoe UI', size: 9, bold: true, color: { argb: 'FF475569' } };
    r5.getCell(4).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF1F5F9' } };
    r5.getCell(5).value = emp.employee.employeeCode || `ID #${emp.employee.employeeId}`;
    r5.getCell(5).font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FF0D9488' } };

    r5.getCell(6).value = 'Department:';
    r5.getCell(6).font = { name: 'Segoe UI', size: 9, bold: true, color: { argb: 'FF475569' } };
    r5.getCell(6).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF1F5F9' } };
    ws.mergeCells('G5:I5');
    r5.getCell(7).value = emp.employee.department || 'N/A';
    r5.getCell(7).font = { name: 'Segoe UI', size: 9.5, color: { argb: 'FF0F172A' } };

    // Row 6
    const r6 = ws.getRow(6);
    r6.height = 22;
    r6.getCell(1).value = 'Designation:';
    r6.getCell(1).font = { name: 'Segoe UI', size: 9, bold: true, color: { argb: 'FF475569' } };
    r6.getCell(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF1F5F9' } };
    ws.mergeCells('B6:C6');
    r6.getCell(2).value = emp.employee.designation || 'N/A';
    r6.getCell(2).font = { name: 'Segoe UI', size: 9.5, color: { argb: 'FF0F172A' } };

    r6.getCell(4).value = 'Shift Timing:';
    r6.getCell(4).font = { name: 'Segoe UI', size: 9, bold: true, color: { argb: 'FF475569' } };
    r6.getCell(4).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF1F5F9' } };
    r6.getCell(5).value = `${emp.policy?.punchInTime || '10:00'} - ${emp.policy?.punchOutTime || '19:00'}`;
    r6.getCell(5).font = { name: 'Segoe UI', size: 9.5, color: { argb: 'FF0F172A' } };

    r6.getCell(6).value = 'Grace Buffer:';
    r6.getCell(6).font = { name: 'Segoe UI', size: 9, bold: true, color: { argb: 'FF475569' } };
    r6.getCell(6).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF1F5F9' } };
    ws.mergeCells('G6:I6');
    r6.getCell(7).value = `${emp.policy?.punchInBufferMinutes ?? 10} minutes`;
    r6.getCell(7).font = { name: 'Segoe UI', size: 9.5, color: { argb: 'FF0F172A' } };

    applyRangeBorder(ws, 1, 4, 9, 6);

    // -------------------------------------------------------------
    // ATTENDANCE METRICS SUMMARY (Rows 8-11)
    // -------------------------------------------------------------
    ws.mergeCells('A8:I8');
    const metricHeader = ws.getCell('A8');
    metricHeader.value = 'MONTHLY ATTENDANCE METRICS SUMMARY';
    metricHeader.font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FF0F172A' } };
    metricHeader.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE2E8F0' } };
    metricHeader.alignment = { horizontal: 'left', vertical: 'middle', indent: 1 };
    ws.getRow(8).height = 24;

    // Metrics Row 9
    const r9 = ws.getRow(9);
    r9.height = 22;
    r9.getCell(1).value = 'Total Calendar Days';
    r9.getCell(1).font = { name: 'Segoe UI', size: 8.5, bold: true, color: { argb: 'FF475569' } };
    r9.getCell(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF8FAFC' } };
    r9.getCell(2).value = s.totalCalendarDays;
    r9.getCell(2).font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FF0F172A' } };
    r9.getCell(2).alignment = { horizontal: 'center', vertical: 'middle' };

    r9.getCell(3).value = 'Working Days';
    r9.getCell(3).font = { name: 'Segoe UI', size: 8.5, bold: true, color: { argb: 'FF475569' } };
    r9.getCell(3).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF8FAFC' } };
    r9.getCell(4).value = s.totalWorkingDays;
    r9.getCell(4).font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FF0F172A' } };
    r9.getCell(4).alignment = { horizontal: 'center', vertical: 'middle' };

    r9.getCell(5).value = 'Present in Office';
    r9.getCell(5).font = { name: 'Segoe UI', size: 8.5, bold: true, color: { argb: 'FF16A34A' } };
    r9.getCell(5).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFDCFCE7' } };
    r9.getCell(6).value = `${s.presentDays} days`;
    r9.getCell(6).font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FF15803D' } };
    r9.getCell(6).alignment = { horizontal: 'center', vertical: 'middle' };

    r9.getCell(7).value = 'Total Work Hours';
    r9.getCell(7).font = { name: 'Segoe UI', size: 8.5, bold: true, color: { argb: 'FF2563EB' } };
    r9.getCell(7).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFEFF6FF' } };
    ws.mergeCells('H9:I9');
    r9.getCell(8).value = formatMinutes(s.totalWorkedMinutes);
    r9.getCell(8).font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FF1D4ED8' } };
    r9.getCell(8).alignment = { horizontal: 'center', vertical: 'middle' };

    // Metrics Row 10
    const r10 = ws.getRow(10);
    r10.height = 22;
    r10.getCell(1).value = 'Work From Home (Full)';
    r10.getCell(1).font = { name: 'Segoe UI', size: 8.5, bold: true, color: { argb: 'FF0F766E' } };
    r10.getCell(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFCCFBF1' } };
    r10.getCell(2).value = `${s.wfhFullDays} days`;
    r10.getCell(2).font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FF0F766E' } };
    r10.getCell(2).alignment = { horizontal: 'center', vertical: 'middle' };

    r10.getCell(3).value = 'Work From Home (Half)';
    r10.getCell(3).font = { name: 'Segoe UI', size: 8.5, bold: true, color: { argb: 'FF0F766E' } };
    r10.getCell(3).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFCCFBF1' } };
    r10.getCell(4).value = `${s.wfhHalfDays} days`;
    r10.getCell(4).font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FF0F766E' } };
    r10.getCell(4).alignment = { horizontal: 'center', vertical: 'middle' };

    r10.getCell(5).value = 'Office Half Days';
    r10.getCell(5).font = { name: 'Segoe UI', size: 8.5, bold: true, color: { argb: 'FFD97706' } };
    r10.getCell(5).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFEF3C7' } };
    r10.getCell(6).value = `${s.halfDays} days`;
    r10.getCell(6).font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FFB45309' } };
    r10.getCell(6).alignment = { horizontal: 'center', vertical: 'middle' };

    r10.getCell(7).value = 'Avg Hours / Day';
    r10.getCell(7).font = { name: 'Segoe UI', size: 8.5, bold: true, color: { argb: 'FF475569' } };
    r10.getCell(7).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF8FAFC' } };
    ws.mergeCells('H10:I10');
    r10.getCell(8).value = formatMinutes(s.averageDailyMinutes);
    r10.getCell(8).font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FF0F172A' } };
    r10.getCell(8).alignment = { horizontal: 'center', vertical: 'middle' };

    // Metrics Row 11
    const r11 = ws.getRow(11);
    r11.height = 22;
    r11.getCell(1).value = 'Approved Leaves';
    r11.getCell(1).font = { name: 'Segoe UI', size: 8.5, bold: true, color: { argb: 'FFD97706' } };
    r11.getCell(1).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFEF3C7' } };
    r11.getCell(2).value = `${s.leaveDays} days`;
    r11.getCell(2).font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FFB45309' } };
    r11.getCell(2).alignment = { horizontal: 'center', vertical: 'middle' };

    r11.getCell(3).value = 'Holidays & Offs';
    r11.getCell(3).font = { name: 'Segoe UI', size: 8.5, bold: true, color: { argb: 'FF64748B' } };
    r11.getCell(3).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF1F5F9' } };
    r11.getCell(4).value = `${s.holidayDays} days`;
    r11.getCell(4).font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FF475569' } };
    r11.getCell(4).alignment = { horizontal: 'center', vertical: 'middle' };

    r11.getCell(5).value = 'Absent Days';
    r11.getCell(5).font = { name: 'Segoe UI', size: 8.5, bold: true, color: { argb: 'FFDC2626' } };
    r11.getCell(5).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFEE2E2' } };
    r11.getCell(6).value = `${s.absentDays} days`;
    r11.getCell(6).font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: 'FFBE123C' } };
    r11.getCell(6).alignment = { horizontal: 'center', vertical: 'middle' };

    r11.getCell(7).value = 'Late Arrivals';
    r11.getCell(7).font = { name: 'Segoe UI', size: 8.5, bold: true, color: { argb: 'FFEA580C' } };
    r11.getCell(7).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFEDD5' } };
    ws.mergeCells('H11:I11');
    r11.getCell(8).value = `${s.lateCount} (Grace used: ${s.bufferGraceUsedCount})`;
    r11.getCell(8).font = { name: 'Segoe UI', size: 9.5, bold: true, color: { argb: 'FFC2410C' } };
    r11.getCell(8).alignment = { horizontal: 'center', vertical: 'middle' };

    applyRangeBorder(ws, 1, 8, 9, 11);

    // -------------------------------------------------------------
    // DAY-BY-DAY ATTENDANCE LEDGER TABLE (Row 13+)
    // -------------------------------------------------------------
    const tableHeaderRow = ws.getRow(13);
    tableHeaderRow.height = 26;
    const tableHeaders = [
      'Date',
      'Day',
      'Attendance Status',
      'Punch IN (IST)',
      'Punch OUT (IST)',
      'Work Duration',
      'Punctuality',
      'Punch Count',
      'Remarks / Approval Notes'
    ];

    tableHeaders.forEach((th, tIdx) => {
      const cell = tableHeaderRow.getCell(tIdx + 1);
      cell.value = th;
      cell.font = { name: 'Segoe UI', size: 9.5, bold: true, color: { argb: 'FFFFFFFF' } };
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF0F766E' } };
      cell.alignment = { horizontal: 'center', vertical: 'middle' };
      cell.border = borderMedium;
    });

    let rowIdx = 14;
    for (const d of emp.days) {
      const row = ws.getRow(rowIdx);
      row.height = 22;
      const isEven = rowIdx % 2 === 0;
      const baseFill: ExcelJS.Fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: isEven ? 'FFFFFFFF' : 'FFF8FAFC' }
      };

      let punctuality = 'On Time';
      let punctColor = 'FF16A34A';
      if (d.isLate) {
        punctuality = 'Late';
        punctColor = 'FFDC2626';
      } else if (d.bufferGraceUsed) {
        punctuality = 'Grace Buffer Used';
        punctColor = 'FFD97706';
      } else if (d.totalMinutes === 0) {
        punctuality = '—';
        punctColor = 'FF94A3B8';
      }

      let remarks = d.remarks || '';
      if (d.wfhDetails) {
        remarks = d.wfhDetails.isHalfDay
          ? `WFH Half Day (${d.wfhDetails.session || 'Morning'})`
          : 'Approved Work From Home';
      } else if (d.dayStatus === 'HOLIDAY') {
        remarks = 'Company Holiday';
      }

      const statusLabel = formatStatusLabel(d);
      const sUpper = (d.dayStatus || '').toUpperCase();

      // Col 1: Date
      const cDate = row.getCell(1);
      cDate.value = d.date;
      cDate.font = { name: 'Segoe UI', size: 9.5, color: { argb: 'FF0F172A' } };
      cDate.fill = baseFill;
      cDate.alignment = { horizontal: 'center', vertical: 'middle' };
      cDate.border = borderThin;

      // Col 2: Day
      const cDay = row.getCell(2);
      cDay.value = d.dayName;
      cDay.font = { name: 'Segoe UI', size: 9.5, color: { argb: 'FF475569' } };
      cDay.fill = baseFill;
      cDay.alignment = { horizontal: 'center', vertical: 'middle' };
      cDay.border = borderThin;

      // Col 3: Status
      const cStatus = row.getCell(3);
      cStatus.value = statusLabel;
      cStatus.alignment = { horizontal: 'center', vertical: 'middle' };
      cStatus.border = borderThin;

      if (sUpper === 'PRESENT') {
        cStatus.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFDCFCE7' } };
        cStatus.font = { name: 'Segoe UI', size: 9.5, bold: true, color: { argb: 'FF15803D' } };
      } else if (sUpper === 'WFH' || sUpper === 'WFH_HALF_DAY') {
        cStatus.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFCCFBF1' } };
        cStatus.font = { name: 'Segoe UI', size: 9.5, bold: true, color: { argb: 'FF0F766E' } };
      } else if (sUpper === 'LEAVE') {
        cStatus.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFEF3C7' } };
        cStatus.font = { name: 'Segoe UI', size: 9.5, bold: true, color: { argb: 'FFB45309' } };
      } else if (sUpper === 'HOLIDAY') {
        cStatus.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF1F5F9' } };
        cStatus.font = { name: 'Segoe UI', size: 9.5, italic: true, color: { argb: 'FF475569' } };
      } else {
        cStatus.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFE4E6' } };
        cStatus.font = { name: 'Segoe UI', size: 9.5, bold: true, color: { argb: 'FFBE123C' } };
      }

      // Col 4: Punch IN
      const cIn = row.getCell(4);
      cIn.value = d.firstIn || '—';
      cIn.font = { name: 'Segoe UI', size: 9.5, color: { argb: 'FF0F172A' } };
      cIn.fill = baseFill;
      cIn.alignment = { horizontal: 'center', vertical: 'middle' };
      cIn.border = borderThin;

      // Col 5: Punch OUT
      const cOut = row.getCell(5);
      cOut.value = d.lastOut || '—';
      cOut.font = { name: 'Segoe UI', size: 9.5, color: { argb: 'FF0F172A' } };
      cOut.fill = baseFill;
      cOut.alignment = { horizontal: 'center', vertical: 'middle' };
      cOut.border = borderThin;

      // Col 6: Duration
      const cDur = row.getCell(6);
      cDur.value = d.totalMinutes > 0 ? formatMinutes(d.totalMinutes) : '—';
      cDur.font = { name: 'Segoe UI', size: 9.5, bold: d.totalMinutes > 0, color: { argb: 'FF0F172A' } };
      cDur.fill = baseFill;
      cDur.alignment = { horizontal: 'center', vertical: 'middle' };
      cDur.border = borderThin;

      // Col 7: Punctuality
      const cPunct = row.getCell(7);
      cPunct.value = punctuality;
      cPunct.font = { name: 'Segoe UI', size: 9.5, bold: true, color: { argb: punctColor } };
      cPunct.fill = baseFill;
      cPunct.alignment = { horizontal: 'center', vertical: 'middle' };
      cPunct.border = borderThin;

      // Col 8: Punch Count
      const cCount = row.getCell(8);
      cCount.value = d.punchCount;
      cCount.font = { name: 'Segoe UI', size: 9.5, color: { argb: 'FF475569' } };
      cCount.fill = baseFill;
      cCount.alignment = { horizontal: 'center', vertical: 'middle' };
      cCount.border = borderThin;

      // Col 9: Remarks
      const cRem = row.getCell(9);
      cRem.value = remarks || '—';
      cRem.font = { name: 'Segoe UI', size: 9, color: { argb: 'FF64748B' } };
      cRem.fill = baseFill;
      cRem.alignment = { horizontal: 'left', vertical: 'middle', indent: 1 };
      cRem.border = borderThin;

      rowIdx++;
    }

    ws.columns = [
      { width: 14 }, // Date
      { width: 10 }, // Day
      { width: 28 }, // Status
      { width: 16 }, // In
      { width: 16 }, // Out
      { width: 16 }, // Duration
      { width: 20 }, // Punctuality
      { width: 14 }, // Punch Count
      { width: 34 }  // Remarks
    ];
  }

  const rawBuffer = await wb.xlsx.writeBuffer();
  const buffer = Buffer.from(rawBuffer);
  return { buffer, fileName };
}

/**
 * Generates vector PDF report using pdfkit.
 */
export async function buildAttendancePdf(
  input: AttendanceReportExportInput
): Promise<{ buffer: Buffer; fileName: string }> {
  const fileName = input.employees.length === 1
    ? getEmployeeReportFileName(input.employees[0], input.year, input.month, 'pdf')
    : getBatchReportFileName(input.year, input.month, 'pdf', 'single');

  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({
      size: 'A4',
      margin: 30,
      bufferPages: true,
      autoFirstPage: false
    });

    const chunks: Buffer[] = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => {
      const buffer = Buffer.concat(chunks);
      resolve({ buffer, fileName });
    });
    doc.on('error', reject);

    const monthName = MONTH_NAMES[input.month - 1] || `Month ${input.month}`;
    const periodLabel = `${monthName} ${input.year}`;

    const emps = input.employees.length > 0 ? input.employees : [];
    if (emps.length === 0) {
      doc.addPage();
      doc.fontSize(18).text('NB HRMS - Attendance Report', { align: 'center' });
      doc.moveDown();
      doc.fontSize(12).text(`Period: ${periodLabel}`, { align: 'center' });
      doc.moveDown();
      doc.text('No attendance records found.', { align: 'center' });
      doc.end();
      return;
    }

    for (let eIdx = 0; eIdx < emps.length; eIdx++) {
      const emp = emps[eIdx];
      const s = emp.summary || ({} as any);
      doc.addPage();

      // Top Header Banner
      doc.rect(30, 25, 535, 48).fill('#0F172A');
      doc.fillColor('#C5A059').fontSize(14).font('Helvetica-Bold')
         .text('NB SINCE 1946', 44, 34);
      doc.fillColor('#94A3B8').fontSize(9).font('Helvetica')
         .text('WORKFORCE MANAGEMENT & ATTENDANCE AUDIT REPORT', 44, 52);

      doc.fillColor('#FFFFFF').fontSize(10).font('Helvetica-Bold')
         .text(periodLabel.toUpperCase(), 400, 34, { width: 150, align: 'right' });
      doc.fillColor('#94A3B8').fontSize(8).font('Helvetica')
         .text(`Generated: ${new Date().toLocaleDateString('en-IN')}`, 400, 52, { width: 150, align: 'right' });

      // Employee Details Card
      const cardY = 82;
      doc.roundedRect(30, cardY, 535, 46, 6).lineWidth(1).strokeColor('#E2E8F0').fillAndStroke('#F8FAFC', '#E2E8F0');
      doc.fillColor('#0F172A').fontSize(12).font('Helvetica-Bold')
         .text(emp.employee.fullName, 42, cardY + 8);
      doc.fillColor('#0D9488').fontSize(9).font('Helvetica-Bold')
         .text(`EMP CODE: ${emp.employee.employeeCode || `ID #${emp.employee.employeeId}`}`, 42, cardY + 26);

      doc.fillColor('#475569').fontSize(9).font('Helvetica')
         .text(`Dept: ${emp.employee.department || 'N/A'}`, 240, cardY + 10)
         .text(`Designation: ${emp.employee.designation || 'N/A'}`, 240, cardY + 26);

      doc.fillColor('#475569').fontSize(9).font('Helvetica')
         .text(`Shift: ${emp.policy?.punchInTime || '10:00'} - ${emp.policy?.punchOutTime || '19:00'}`, 410, cardY + 10)
         .text(`Late Grace: ${emp.policy?.punchInBufferMinutes ?? 10} mins`, 410, cardY + 26);

      // KPI Metric Cards Grid (2 rows x 4 cols)
      const kpiY = 136;
      const kpiW = 127;
      const kpiH = 34;
      const kpis = [
        { label: 'Total Working Days', value: `${s.totalWorkingDays} days`, color: '#0F172A' },
        { label: 'Present in Office', value: `${s.presentDays} days`, color: '#16A34A' },
        { label: 'Work From Home', value: `${s.wfhFullDays + (s.wfhHalfDays * 0.5)} days`, color: '#0D9488' },
        { label: 'Total Work Hours', value: formatMinutes(s.totalWorkedMinutes), color: '#2563EB' },
        { label: 'Approved Leaves', value: `${s.leaveDays} days`, color: '#D97706' },
        { label: 'Holidays & Offs', value: `${s.holidayDays} days`, color: '#64748B' },
        { label: 'Absent Days', value: `${s.absentDays} days`, color: '#DC2626' },
        { label: 'Late Arrivals', value: `${s.lateCount} (${s.bufferGraceUsedCount} grace)`, color: '#EA580C' },
      ];

      kpis.forEach((kpi, idx) => {
        const col = idx % 4;
        const row = Math.floor(idx / 4);
        const x = 30 + (col * (kpiW + 9));
        const y = kpiY + (row * (kpiH + 6));

        doc.roundedRect(x, y, kpiW, kpiH, 4).fillAndStroke('#FFFFFF', '#E2E8F0');
        doc.fillColor('#64748B').fontSize(7.5).font('Helvetica')
           .text(kpi.label.toUpperCase(), x + 6, y + 5);
        doc.fillColor(kpi.color).fontSize(10.5).font('Helvetica-Bold')
           .text(kpi.value, x + 6, y + 17);
      });

      // Attendance Ledger Table Header
      let tableY = 222;
      const colX = [30, 95, 135, 235, 290, 345, 405, 475];
      const colW = [65, 40, 100, 55, 55, 60, 70, 90];

      doc.rect(30, tableY, 535, 20).fill('#0F766E');
      doc.fillColor('#FFFFFF').fontSize(8).font('Helvetica-Bold');
      doc.text('Date', colX[0] + 4, tableY + 6);
      doc.text('Day', colX[1] + 2, tableY + 6);
      doc.text('Attendance Status', colX[2] + 4, tableY + 6);
      doc.text('Punch IN', colX[3] + 2, tableY + 6);
      doc.text('Punch OUT', colX[4] + 2, tableY + 6);
      doc.text('Duration', colX[5] + 2, tableY + 6);
      doc.text('Punctuality', colX[6] + 2, tableY + 6);
      doc.text('Remarks', colX[7] + 2, tableY + 6);

      tableY += 20;

      // Table Rows
      emp.days.forEach((day, rIdx) => {
        if (tableY > 780) {
          doc.addPage();
          tableY = 40;
          doc.rect(30, tableY, 535, 20).fill('#0F766E');
          doc.fillColor('#FFFFFF').fontSize(8).font('Helvetica-Bold');
          doc.text('Date', colX[0] + 4, tableY + 6);
          doc.text('Day', colX[1] + 2, tableY + 6);
          doc.text('Attendance Status', colX[2] + 4, tableY + 6);
          doc.text('Punch IN', colX[3] + 2, tableY + 6);
          doc.text('Punch OUT', colX[4] + 2, tableY + 6);
          doc.text('Duration', colX[5] + 2, tableY + 6);
          doc.text('Punctuality', colX[6] + 2, tableY + 6);
          doc.text('Remarks', colX[7] + 2, tableY + 6);
          tableY += 20;
        }

        const isEven = rIdx % 2 === 0;
        doc.rect(30, tableY, 535, 17).fill(isEven ? '#FFFFFF' : '#F8FAFC');

        // Status Badge
        const badge = getStatusBadgeColor(day);
        const statusText = formatStatusLabel(day);
        doc.roundedRect(colX[2] + 2, tableY + 2.5, 95, 12, 3).fill(badge.fill);
        doc.fillColor(badge.text).fontSize(6.5).font('Helvetica-Bold')
           .text(statusText.substring(0, 22), colX[2] + 4, tableY + 5, { width: 91, align: 'center' });

        // Row Text Values
        doc.fillColor('#0F172A').fontSize(7.5).font('Helvetica');
        doc.text(day.date, colX[0] + 4, tableY + 5);
        doc.text(day.dayName, colX[1] + 2, tableY + 5);
        doc.text(day.firstIn || '—', colX[3] + 2, tableY + 5);
        doc.text(day.lastOut || '—', colX[4] + 2, tableY + 5);
        doc.text(day.totalMinutes > 0 ? formatMinutes(day.totalMinutes) : '—', colX[5] + 2, tableY + 5);

        // Punctuality
        let punctuality = 'On Time';
        let punctColor = '#16A34A';
        if (day.isLate) {
          punctuality = 'Late';
          punctColor = '#DC2626';
        } else if (day.bufferGraceUsed) {
          punctuality = 'Grace Buffer';
          punctColor = '#D97706';
        } else if (day.totalMinutes === 0) {
          punctuality = '—';
          punctColor = '#94A3B8';
        }
        doc.fillColor(punctColor).font('Helvetica-Bold').text(punctuality, colX[6] + 2, tableY + 5);

        // Remarks
        let remark = day.remarks || '';
        if (day.wfhDetails) {
          remark = day.wfhDetails.isHalfDay ? `WFH (${day.wfhDetails.session || 'Morning'})` : 'WFH (Full Day)';
        } else if (day.dayStatus === 'HOLIDAY') {
          remark = 'Company Holiday';
        }
        doc.fillColor('#64748B').font('Helvetica').text(remark.substring(0, 20), colX[7] + 2, tableY + 5);

        doc.rect(30, tableY + 17, 535, 0.5).fill('#E2E8F0');
        tableY += 17.5;
      });
    }

    // Add Page Numbers and Footer on all pages
    const range = doc.bufferedPageRange();
    for (let p = range.start; p < range.start + range.count; p++) {
      doc.switchToPage(p);
      doc.rect(30, 805, 535, 0.5).fill('#CBD5E1');
      doc.fillColor('#94A3B8').fontSize(7.5).font('Helvetica')
         .text('NB HRMS • Official Attendance Record • Strictly Confidential', 30, 812);
      doc.text(`Page ${p + 1} of ${range.count}`, 450, 812, { width: 115, align: 'right' });
    }

    doc.end();
  });
}
