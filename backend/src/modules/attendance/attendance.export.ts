import PDFDocument from 'pdfkit';
import * as xlsx from 'xlsx';

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

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

function formatMinutes(minutes: number): string {
  const m = Math.max(0, Math.round(minutes));
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
    return { fill: '#0D9488', text: '#FFFFFF' }; // Teal
  }
  if (s === 'PRESENT') {
    if (day.isHalfDay) return { fill: '#D97706', text: '#FFFFFF' }; // Amber for half day
    return { fill: '#16A34A', text: '#FFFFFF' }; // Green
  }
  if (s === 'LEAVE') {
    return { fill: '#2563EB', text: '#FFFFFF' }; // Blue
  }
  if (s === 'HOLIDAY') {
    return { fill: '#64748B', text: '#FFFFFF' }; // Slate
  }
  return { fill: '#DC2626', text: '#FFFFFF' }; // Red for absent
}

/**
 * Generates structured Excel workbook with summary KPI block and day-by-day table.
 */
export function buildAttendanceExcel(input: AttendanceReportExportInput): { buffer: Buffer; fileName: string } {
  const wb = xlsx.utils.book_new();
  const monthName = MONTH_NAMES[input.month - 1] || `Month ${input.month}`;
  const periodLabel = `${monthName} ${input.year}`;

  if (input.employees.length === 0) {
    const ws = xlsx.utils.aoa_to_sheet([
      ['NB HRMS - Attendance Report'],
      [`Period: ${periodLabel}`],
      ['No employee attendance records found for this period.']
    ]);
    xlsx.utils.book_append_sheet(wb, ws, 'Attendance');
    const buffer = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' }) as Buffer;
    return { buffer, fileName: `attendance_report_${input.year}-${String(input.month).padStart(2, '0')}.xlsx` };
  }

  // If multiple employees in EMPLOYEE_WISE mode, create a Master Summary sheet first
  if (input.mode === 'EMPLOYEE_WISE' && input.employees.length > 1) {
    const summaryRows: any[][] = [
      ['NB Since 1946 - Workforce Attendance Summary'],
      [`Report Period: ${periodLabel}`],
      [`Generated on: ${new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })}`],
      [],
      [
        'Employee Code',
        'Employee Name',
        'Designation',
        'Department',
        'Total Days',
        'Working Days',
        'Present Days',
        'WFH (Full)',
        'WFH (Half)',
        'Half Days',
        'Leaves',
        'Holidays',
        'Absent',
        'Total Work Duration',
        'Avg Hours/Day',
        'Late Marks'
      ]
    ];

    for (const emp of input.employees) {
      const s = emp.summary;
      summaryRows.push([
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
      ]);
    }

    const wsSummary = xlsx.utils.aoa_to_sheet(summaryRows);
    wsSummary['!cols'] = [
      { wch: 15 }, { wch: 26 }, { wch: 22 }, { wch: 20 },
      { wch: 12 }, { wch: 14 }, { wch: 14 }, { wch: 12 },
      { wch: 12 }, { wch: 12 }, { wch: 10 }, { wch: 10 },
      { wch: 10 }, { wch: 18 }, { wch: 16 }, { wch: 12 }
    ];
    xlsx.utils.book_append_sheet(wb, wsSummary, 'All Employees Summary');
  }

  // Create detailed sheet for each employee (or day-wise master)
  const isMultiEmployee = input.employees.length > 1;
  const maxTabs = isMultiEmployee ? Math.min(input.employees.length, 30) : 1;

  for (let idx = 0; idx < maxTabs; idx++) {
    const emp = input.employees[idx];
    const s = emp.summary;
    const safeName = (emp.employee.fullName || `Emp_${emp.employee.employeeId}`)
      .replace(/[\\/?*:[\]]/g, '')
      .substring(0, 25);
    const sheetName = isMultiEmployee ? `${emp.employee.employeeCode || emp.employee.employeeId} - ${safeName}` : 'Attendance Log';

    const sheetRows: any[][] = [
      ['NB Since 1946 - Employee Attendance Report'],
      [`Employee: ${emp.employee.fullName} (${emp.employee.employeeCode || `ID #${emp.employee.employeeId}`})`],
      [`Designation: ${emp.employee.designation || 'N/A'} | Department: ${emp.employee.department || 'N/A'}`],
      [`Shift Timing: ${emp.policy?.punchInTime || '10:00'} to ${emp.policy?.punchOutTime || '19:00'} (Buffer: ${emp.policy?.punchInBufferMinutes ?? 10}m)`],
      [`Period: ${periodLabel} | Generated: ${new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })}`],
      [],
      // KPI Summary Block
      ['ATTENDANCE METRICS SUMMARY'],
      [
        'Total Days', s.totalCalendarDays,
        'Working Days', s.totalWorkingDays,
        'Present Days', s.presentDays,
        'Total Work Time', formatMinutes(s.totalWorkedMinutes)
      ],
      [
        'Full WFH Days', s.wfhFullDays,
        'Half WFH Days', s.wfhHalfDays,
        'Half Days', s.halfDays,
        'Avg Hours/Day', formatMinutes(s.averageDailyMinutes)
      ],
      [
        'Approved Leaves', s.leaveDays,
        'Holidays & Offs', s.holidayDays,
        'Absent Days', s.absentDays,
        'Late Arrivals', `${s.lateCount} (Grace used: ${s.bufferGraceUsedCount})`
      ],
      [],
      // Day by Day Ledger
      [
        'Date',
        'Day',
        'Status',
        'Punch IN (IST)',
        'Punch OUT (IST)',
        'Duration',
        'Punctuality',
        'Punch Count',
        'Remarks'
      ]
    ];

    for (const d of emp.days) {
      let punctuality = 'On Time';
      if (d.isLate) punctuality = 'Late';
      else if (d.bufferGraceUsed) punctuality = 'Grace Buffer Used';

      let remarks = d.remarks || '';
      if (d.wfhDetails) {
        remarks = d.wfhDetails.isHalfDay
          ? `WFH Half Day (${d.wfhDetails.session || 'Morning'})`
          : 'Approved Work From Home';
      }

      sheetRows.push([
        d.date,
        d.dayName,
        formatStatusLabel(d),
        d.firstIn || '--',
        d.lastOut || '--',
        formatMinutes(d.totalMinutes),
        punctuality,
        d.punchCount,
        remarks
      ]);
    }

    const ws = xlsx.utils.aoa_to_sheet(sheetRows);
    ws['!cols'] = [
      { wch: 14 }, // Date
      { wch: 10 }, // Day
      { wch: 28 }, // Status
      { wch: 16 }, // In
      { wch: 16 }, // Out
      { wch: 14 }, // Duration
      { wch: 18 }, // Punctuality
      { wch: 12 }, // Punch Count
      { wch: 30 }  // Remarks
    ];

    xlsx.utils.book_append_sheet(wb, ws, sheetName.substring(0, 31));
  }

  const buffer = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' }) as Buffer;
  const fileName = input.employees.length === 1
    ? `attendance_${input.employees[0].employee.employeeCode || input.employees[0].employee.employeeId}_${input.year}-${String(input.month).padStart(2, '0')}.xlsx`
    : `attendance_summary_${input.year}-${String(input.month).padStart(2, '0')}.xlsx`;

  return { buffer, fileName };
}

/**
 * Generates vector PDF report using pdfkit.
 */
export async function buildAttendancePdf(input: AttendanceReportExportInput): Promise<{ buffer: Buffer; fileName: string }> {
  const fileName = input.employees.length === 1
    ? `attendance_${input.employees[0].employee.employeeCode || input.employees[0].employee.employeeId}_${input.year}-${String(input.month).padStart(2, '0')}.pdf`
    : `attendance_report_${input.year}-${String(input.month).padStart(2, '0')}.pdf`;

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

    // Loop through each employee and create their report pages
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
      const s = emp.summary;
      doc.addPage();

      // Top Header Banner
      doc.rect(30, 25, 535, 48).fill('#0F172A'); // Dark Navy Header
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

      doc.rect(30, tableY, 535, 20).fill('#0F766E'); // Teal Table Header
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
        // Page break if row exceeds page height
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
        doc.text(day.firstIn || '--', colX[3] + 2, tableY + 5);
        doc.text(day.lastOut || '--', colX[4] + 2, tableY + 5);
        doc.text(day.totalMinutes > 0 ? formatMinutes(day.totalMinutes) : '--', colX[5] + 2, tableY + 5);

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
          punctuality = '--';
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

        // Border line under row
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
