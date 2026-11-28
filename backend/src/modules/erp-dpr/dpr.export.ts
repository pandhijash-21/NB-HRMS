import * as xlsx from 'xlsx';

/** Manpower trade columns matching September_DPR_NBLT_2026.xlsx */
export const DPR_MANPOWER_TRADES = [
  'Mason',
  'Labour',
  'Reinforcement',
  'Threading',
  'Shuttering',
  'Carpenter',
  'Plumber',
  'Polish',
  'Flooring',
  'Helper',
  'Fabrication',
  'Gypsum plaster',
  'Painter',
  'Water Proofing',
  'Electrician',
  'Aluminium',
] as const;

type Trade = (typeof DPR_MANPOWER_TRADES)[number];

const TRADE_ALIASES: Array<{ trade: Trade; match: RegExp }> = [
  { trade: 'Mason', match: /mason|mistry|brick/i },
  { trade: 'Reinforcement', match: /reinforc|steel\s*bind|re[- ]?bar|bar\s*bend|steel/i },
  { trade: 'Threading', match: /thread/i },
  { trade: 'Shuttering', match: /shutter|form\s*work|centering/i },
  { trade: 'Carpenter', match: /carpent|furniture/i },
  { trade: 'Plumber', match: /plumb|pipe\s*fit/i },
  { trade: 'Polish', match: /polish/i },
  { trade: 'Flooring', match: /floor|tiling|tile/i },
  { trade: 'Helper', match: /helper|unskilled|naka/i },
  { trade: 'Fabrication', match: /fabricat|welding/i },
  { trade: 'Gypsum plaster', match: /gypsum|ceiling|false\s*ceil/i },
  { trade: 'Painter', match: /paint|colour|color/i },
  { trade: 'Water Proofing', match: /water\s*proof|waterproof/i },
  { trade: 'Electrician', match: /electric|wiring|el\.?\s*work/i },
  { trade: 'Aluminium', match: /alumini|alu[- ]?work|glazing/i },
  { trade: 'Labour', match: /labour|labor|skilled|manpower|worker/i },
];

function mapLabourToTrade(name: string): Trade {
  const n = String(name || '').trim();
  if (!n) return 'Labour';
  for (const a of TRADE_ALIASES) {
    if (a.match.test(n)) return a.trade;
  }
  return 'Labour';
}

function emptyTrades(): Record<Trade, number> {
  const o = {} as Record<Trade, number>;
  for (const t of DPR_MANPOWER_TRADES) o[t] = 0;
  return o;
}

function blockLabel(line: {
  towerName?: string | null;
  floorNo?: number | null;
  unitLabel?: string | null;
}): string {
  const floorPart =
    line.floorNo === -1
      ? 'ALL Floors'
      : line.floorNo != null
        ? `Floor ${line.floorNo}`
        : null;
  const parts = [line.towerName, floorPart, line.unitLabel].filter(Boolean);
  return parts.length ? parts.join(' / ') : 'Site';
}

function workDetail(line: {
  taskName?: string | null;
  remarks?: string | null;
  unitCode?: string | null;
  consumedQty?: unknown;
  completionPct?: unknown;
  statusCode?: string | null;
  gradeCode?: string | null;
}): string {
  const bits: string[] = [];
  if (line.taskName) bits.push(String(line.taskName));
  if (line.remarks) bits.push(String(line.remarks));
  const qty = Number(line.consumedQty ?? 0);
  if (qty || line.unitCode) {
    bits.push(`Qty ${qty}${line.unitCode ? ` ${line.unitCode}` : ''}`);
  }
  if (line.completionPct != null && line.completionPct !== '') {
    bits.push(`Completion ${Number(line.completionPct)}%`);
  }
  if (line.gradeCode) bits.push(`Grade ${line.gradeCode}`);
  if (line.statusCode) bits.push(String(line.statusCode));
  return bits.join('\n');
}

function fmtDate(d: Date | string): string {
  const dt = d instanceof Date ? d : new Date(d);
  if (Number.isNaN(dt.getTime())) return '';
  const dd = String(dt.getUTCDate()).padStart(2, '0');
  const mm = String(dt.getUTCMonth() + 1).padStart(2, '0');
  const yyyy = dt.getUTCFullYear();
  return `${dd}-${mm}-${yyyy}`;
}

function sheetNameForDate(d: Date | string): string {
  const dt = d instanceof Date ? d : new Date(d);
  if (Number.isNaN(dt.getTime())) return 'DPR';
  return String(dt.getUTCDate()).padStart(2, '0');
}

export type DprMaterialReportRow = {
  srNo: number;
  date: string;
  site: string;
  supplierName: string;
  challanNumber: string | null;
  material: string;
  detailGrade: string;
  vehicleNo: string | null;
  time: string | null;
  qtyReceived?: number;
  qtyAccepted?: number;
  unitCode?: string | null;
  poNumber?: string | null;
  qcStatus?: string;
};

type DprExportSource = {
  dprNo: string;
  reportDate: Date;
  createdByName?: string | null;
  remarks?: string | null;
  project?: { name?: string | null; projectNo?: number | null } | null;
  materialReport?: {
    rows?: DprMaterialReportRow[];
    receiveByMaterial?: Record<string, number>;
  } | null;
  lines: Array<{
    contractorName?: string | null;
    activityName?: string | null;
    taskName?: string | null;
    towerName?: string | null;
    floorNo?: number | null;
    unitLabel?: string | null;
    unitCode?: string | null;
    consumedQty?: unknown;
    completionPct?: unknown;
    statusCode?: string | null;
    gradeCode?: string | null;
    remarks?: string | null;
    labour?: Array<{ name?: string | null; consumedQty?: unknown }>;
    materials?: Array<{
      itemName?: string | null;
      brand?: string | null;
      size?: string | null;
      unitCode?: string | null;
      consumedQty?: unknown;
      remarks?: string | null;
    }>;
    machines?: Array<{
      itemName?: string | null;
      brand?: string | null;
      unitCode?: string | null;
      size?: string | null;
      consumedQty?: unknown;
      remarks?: string | null;
    }>;
  }>;
};

/**
 * Build an .xlsx Daily Report matching the legacy September_DPR_NBLT layout.
 */
export function buildDprDailyReportXlsx(dpr: DprExportSource): { buffer: Buffer; fileName: string } {
  const projectName = dpr.project?.name || 'Project';
  const rows: any[][] = [];

  // Row 1–2 header
  rows.push([projectName]);
  rows.push([` DAILY REPORT  —  ${fmtDate(dpr.reportDate)}  —  ${dpr.dprNo}`]);

  // Row 3 headers
  const header = [
    'BLOCK\n NO.',
    'CONTRACTOR \nNAME',
    'ACTIVITY',
    'WORK DETAIL',
    '',
    '',
    ...DPR_MANPOWER_TRADES,
  ];
  rows.push(header);

  const totals = emptyTrades();

  for (const line of dpr.lines || []) {
    const trades = emptyTrades();
    for (const lb of line.labour || []) {
      const qty = Number(lb.consumedQty ?? 0);
      if (!qty) continue;
      const trade = mapLabourToTrade(String(lb.name || ''));
      trades[trade] += qty;
      totals[trade] += qty;
    }
    rows.push([
      blockLabel(line),
      line.contractorName || '',
      line.activityName || '',
      workDetail(line),
      '',
      '',
      ...DPR_MANPOWER_TRADES.map((t) => (trades[t] ? trades[t] : '')),
    ]);
  }

  const totalManpower = Object.values(totals).reduce((s, n) => s + n, 0);

  rows.push([
    `${projectName.toUpperCase()}`,
    '',
    '',
    ' Total Manpower',
    '',
    totalManpower,
    ...DPR_MANPOWER_TRADES.map((t) => totals[t] || 0),
  ]);

  rows.push([]);
  rows.push(['MATERIAL CONSUMPTION']);
  rows.push([
    'MATERIAL',
    'DISCRIPTION',
    'OPENING STOCK',
    'TODAY\n RECEIVE',
    'DAILY\nCONSUMPTION',
    'CLOSING\nSTOCK',
    'UNIT',
    '',
    '',
    '',
    '',
    'REMARKS',
  ]);

  // Material consumption = DPR-logged usage only (not Store inward / challan qty)
  type MatAgg = {
    itemName: string;
    description: string;
    unit: string;
    consumed: number;
    remarks: string;
  };
  const matMap = new Map<string, MatAgg>();

  for (const line of dpr.lines || []) {
    for (const m of line.materials || []) {
      const name = String(m.itemName || '').trim();
      if (!name) continue;
      const key = name.toLowerCase();
      const desc = [m.brand, m.size].filter(Boolean).join(' / ');
      const existing = matMap.get(key);
      const qty = Number(m.consumedQty ?? 0);
      if (existing) {
        existing.consumed += qty;
        if (!existing.description && desc) existing.description = desc;
        if (!existing.unit && m.unitCode) existing.unit = String(m.unitCode);
        if (m.remarks) {
          existing.remarks = existing.remarks
            ? `${existing.remarks}; ${m.remarks}`
            : String(m.remarks);
        }
      } else {
        matMap.set(key, {
          itemName: name,
          description: desc,
          unit: String(m.unitCode || ''),
          consumed: qty,
          remarks: String(m.remarks || ''),
        });
      }
    }
  }

  if (matMap.size === 0) {
    rows.push(['—', 'No materials logged on this DPR', '', '', '', '', '', '', '', '', '', '']);
  } else {
    for (const m of matMap.values()) {
      rows.push([
        m.itemName,
        m.description,
        '', // opening
        '', // today receive — Store inward is listed separately under MATERIAL REPORT
        m.consumed || '',
        '', // closing
        m.unit,
        '',
        '',
        '',
        '',
        m.remarks,
      ]);
    }
  }

  rows.push(['MACHINARY']);
  type MacAgg = { itemName: string; unit: string; hours: number; remarks: string };
  const macMap = new Map<string, MacAgg>();
  for (const line of dpr.lines || []) {
    for (const m of line.machines || []) {
      const name = String(m.itemName || '').trim();
      if (!name) continue;
      const key = name.toLowerCase();
      const qty = Number(m.consumedQty ?? 0);
      const unit = String(m.unitCode || 'Hour');
      const existing = macMap.get(key);
      if (existing) {
        existing.hours += qty;
      } else {
        macMap.set(key, {
          itemName: name,
          unit,
          hours: qty,
          remarks: [m.brand, m.size, m.remarks].filter(Boolean).join(' / '),
        });
      }
    }
  }

  if (macMap.size === 0) {
    rows.push(['—', '', '', '', '', '', 'Hour']);
  } else {
    for (const m of macMap.values()) {
      rows.push([m.itemName, m.remarks, '', '', m.hours || '', '', m.unit]);
    }
  }

  rows.push([]);
  rows.push([
    'STORE  INCHARGE : ',
    '',
    '',
    '',
    '',
    'ENGINEER ( E ) : ',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    'ENGINEER ( E ) : ',
  ]);

  // MATERIAL REPORT — Store inward challans for this date/project
  rows.push([]);
  rows.push(['MATERIAL REPORT']);
  rows.push([
    'SR.\nNO.',
    'DATE',
    'SITE',
    'NAME OF SUPPLIER',
    '',
    'CHALLAN\nBILL NO.',
    'MATERIAL',
    '',
    '',
    '',
    '',
    '',
    '',
    'DETAIL/\nGRADE',
    '',
    '',
    'VEHICLE NO.',
    '',
    '',
    'TIME',
    'QTY',
    'UNIT',
  ]);

  const challanRows = dpr.materialReport?.rows || [];
  if (!challanRows.length) {
    rows.push(['—', '', '', 'No store inwards / challans for this date', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']);
  } else {
    for (const r of challanRows) {
      rows.push([
        r.srNo,
        r.date,
        r.site,
        r.supplierName,
        '',
        r.challanNumber || '',
        r.material,
        '',
        '',
        '',
        '',
        '',
        '',
        r.detailGrade || '',
        '',
        '',
        r.vehicleNo || '',
        '',
        '',
        r.time || '',
        r.qtyAccepted ?? r.qtyReceived ?? '',
        r.unitCode || '',
      ]);
    }
  }

  rows.push([]);
  rows.push([
    'STORE  INCHARGE : ',
    '',
    '',
    '',
    '',
    'ENGINEER ( E ) : ',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    'ENGINEER ( E ) : ',
  ]);

  if (dpr.remarks) {
    rows.push([]);
    rows.push(['REMARKS', dpr.remarks]);
  }

  rows.push([]);
  rows.push([`Generated from ERP DPR ${dpr.dprNo}`, `By ${dpr.createdByName || '—'}`]);

  const ws = xlsx.utils.aoa_to_sheet(rows);

  // Column widths roughly matching site sheet
  ws['!cols'] = [
    { wch: 18 }, // block
    { wch: 18 }, // contractor
    { wch: 18 }, // activity
    { wch: 40 }, // work detail
    { wch: 3 },
    { wch: 3 },
    ...DPR_MANPOWER_TRADES.map(() => ({ wch: 10 })),
  ];

  // Merge title-ish cells lightly
  ws['!merges'] = [
    { s: { r: 0, c: 0 }, e: { r: 0, c: 5 } },
    { s: { r: 1, c: 0 }, e: { r: 1, c: 10 } },
  ];

  const wb = xlsx.utils.book_new();
  const sn = sheetNameForDate(dpr.reportDate);
  xlsx.utils.book_append_sheet(wb, ws, sn);

  const buffer = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' }) as Buffer;
  const safeProject = projectName.replace(/[^a-zA-Z0-9_\- ]/g, '').trim().replace(/\s+/g, '_');
  const fileName = `DPR_${safeProject || 'Project'}_${fmtDate(dpr.reportDate).replace(/-/g, '')}_${dpr.dprNo}.xlsx`;
  return { buffer, fileName };
}
