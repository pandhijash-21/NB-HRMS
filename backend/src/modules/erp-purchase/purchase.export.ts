import * as xlsx from 'xlsx';

/** Default PO Terms & Conditions matching PO.FORMAT_NEW.xlsx */
export const DEFAULT_PO_TERMS: string[] = [
  'Financial : 30-45 Days from the date of material received and Invoice date.',
  'General : Above mentioned AMOUNT is INCLUSIVE of GST, Loading & Unloading. Freight charge will be extra at actual. (Rate Validity 1-Years from the date of PO)',
  'General : Dispute if any, are subject to Ahmedabad Jurisdiction.',
  'General : NB Developer LLP reserves the right to terminate this PO without any prior notice and without assigning any reason thereof.',
  'Important Note : You have to get clearance for quality execution from NB Developer prior to dispatch of the container from the factory.',
  'Note : Please mention Purchase order Number in all transaction.',
  'Payment : Payment /Invoice amount shall be calculated as per actual qty received at site / measured by us / weighed at weigh bridge of our choice. ZERO qty tolerance',
  'Delivery - Place & Time : As per site requirement.',
  'Every Load should be Quality / Quantity checked.',
  'Rejection / Replacement : If the received material is in damaged/broken condition or not meeting the given specification then vendor have to take back the material at no extra cost for us.',
  'Safety Procedure : You shall be responsible for the safety of your as well as our workmen and machineries while unloading the mateial. Necessary safety gears to be provided by you for your unloading workmen.',
  'Specification : Specification shall be as per IS standards. - the material supplied gradation shall be as per IS specifications. The specification for each material shall be collected from the project office, if necessary.',
];

export function parseTerms(raw: unknown): string[] {
  if (Array.isArray(raw)) {
    return raw.map((t) => String(t ?? '').trim()).filter(Boolean);
  }
  if (typeof raw === 'string' && raw.trim()) {
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) {
        return parsed.map((t) => String(t ?? '').trim()).filter(Boolean);
      }
    } catch {
      return raw
        .split(/\r?\n/)
        .map((t) => t.trim())
        .filter(Boolean);
    }
  }
  return [...DEFAULT_PO_TERMS];
}

function fmtDate(d: Date | string | null | undefined): string {
  if (!d) return '';
  const dt = d instanceof Date ? d : new Date(d);
  if (Number.isNaN(dt.getTime())) return '';
  const dd = String(dt.getUTCDate()).padStart(2, '0');
  const mm = String(dt.getUTCMonth() + 1).padStart(2, '0');
  const yyyy = dt.getUTCFullYear();
  return `${dd}/${mm}/${yyyy}`;
}

function money(n: number): number {
  return Math.round(n * 100) / 100;
}

const ONES = [
  '',
  'One',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
  'Ten',
  'Eleven',
  'Twelve',
  'Thirteen',
  'Fourteen',
  'Fifteen',
  'Sixteen',
  'Seventeen',
  'Eighteen',
  'Nineteen',
];
const TENS = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

function twoDigits(n: number): string {
  if (n < 20) return ONES[n];
  const t = Math.floor(n / 10);
  const o = n % 10;
  return `${TENS[t]}${o ? ` ${ONES[o]}` : ''}`.trim();
}

function amountInWords(amount: number): string {
  if (!Number.isFinite(amount) || amount < 0) return '';
  const rupees = Math.floor(amount);
  const paise = Math.round((amount - rupees) * 100);
  if (rupees === 0 && paise === 0) return 'Rupees Zero Only';

  const parts: string[] = [];
  let n = rupees;
  const crore = Math.floor(n / 10000000);
  n %= 10000000;
  const lakh = Math.floor(n / 100000);
  n %= 100000;
  const thousand = Math.floor(n / 1000);
  n %= 1000;
  const hundred = Math.floor(n / 100);
  const rest = n % 100;

  if (crore) parts.push(`${twoDigits(crore)} Crore`);
  if (lakh) parts.push(`${twoDigits(lakh)} Lakh`);
  if (thousand) parts.push(`${twoDigits(thousand)} Thousand`);
  if (hundred) parts.push(`${ONES[hundred]} Hundred`);
  if (rest) parts.push(twoDigits(rest));

  let words = `Rupees ${parts.join(' ')}`;
  if (paise > 0) words += ` and ${twoDigits(paise)} Paise`;
  return `${words} Only`;
}

function colWidths(widths: number[]) {
  return widths.map((wch) => ({ wch }));
}

export type CsExportInput = {
  purchaseRequest: {
    prNumber: string;
    status: string;
    projectName?: string | null;
    lines: Array<{
      id?: string | null;
      itemName: string;
      unitCode?: string | null;
      qty: number;
      brand?: string | null;
      size?: string | null;
    }>;
  };
  quotations: Array<{
    quotationNo: string;
    vendorName: string;
    status: string;
    totalAmount: number;
    gstNo?: string | null;
    lines: Array<{
      purchaseRequestLineId?: string | null;
      itemName: string;
      materialId?: string | null;
      qty: number;
      rate: number;
      amount: number;
      unitCode?: string | null;
    }>;
  }>;
};

export function buildComparisonSheetXlsx(input: CsExportInput): { buffer: Buffer; fileName: string } {
  const { purchaseRequest: pr, quotations } = input;
  const lineKeys: string[] = [];
  const lineLabels: Record<string, string> = {};

  for (const q of quotations) {
    for (const l of q.lines) {
      const key = l.purchaseRequestLineId || `${l.itemName}|${l.materialId ?? ''}`;
      if (!lineKeys.includes(key)) {
        lineKeys.push(key);
        lineLabels[key] =
          `${l.itemName}${l.unitCode ? ` (${l.unitCode})` : ''} · Qty ${l.qty}`;
      }
    }
  }
  // Prefer PR line order when available
  if (pr.lines.length) {
    const ordered: string[] = [];
    for (const l of pr.lines) {
      const key = l.id || `${l.itemName}|`;
      if (!ordered.includes(key)) {
        ordered.push(key);
        if (!lineLabels[key]) {
          lineLabels[key] =
            `${l.itemName}${l.unitCode ? ` (${l.unitCode})` : ''} · Qty ${l.qty}`;
        }
      }
    }
    for (const k of lineKeys) {
      if (!ordered.includes(k)) ordered.push(k);
    }
    lineKeys.length = 0;
    lineKeys.push(...ordered);
  }

  const header = [
    'Item / Qty',
    ...quotations.map((q) => `${q.vendorName} (${q.quotationNo})`),
  ];
  const aoa: (string | number)[][] = [
    ['COMPARISON SHEET'],
    [`PR No.: ${pr.prNumber}`, `Status: ${pr.status}`, pr.projectName ? `Project: ${pr.projectName}` : ''],
    [],
    header,
  ];

  for (const key of lineKeys) {
    const row: (string | number)[] = [lineLabels[key] ?? key];
    for (const q of quotations) {
      const line = q.lines.find(
        (l) => (l.purchaseRequestLineId || `${l.itemName}|${l.materialId ?? ''}`) === key,
      );
      row.push(line ? money(Number(line.rate)) : '');
    }
    aoa.push(row);
  }

  aoa.push([]);
  const totalRow: (string | number)[] = ['TOTAL'];
  for (const q of quotations) {
    totalRow.push(money(Number(q.totalAmount)));
  }
  aoa.push(totalRow);

  const statusRow: (string | number)[] = ['Status'];
  for (const q of quotations) statusRow.push(q.status);
  aoa.push(statusRow);

  const gstRow: (string | number)[] = ['GST No.'];
  for (const q of quotations) gstRow.push(q.gstNo ?? '');
  aoa.push(gstRow);

  const ws = xlsx.utils.aoa_to_sheet(aoa);
  ws['!cols'] = colWidths([40, ...quotations.map(() => 22)]);
  const wb = xlsx.utils.book_new();
  xlsx.utils.book_append_sheet(wb, ws, 'Comparison Sheet');
  const buffer = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' }) as Buffer;
  const safePr = pr.prNumber.replace(/[^\w.-]+/g, '_');
  return { buffer, fileName: `CS_${safePr}.xlsx` };
}

export type PoExportInput = {
  po: {
    poNumber: string;
    orderDate: Date | string;
    vendorName: string;
    totalAmount?: number | null;
    remarks?: string | null;
    cgstRate?: number | null;
    sgstRate?: number | null;
    termsAndConditions?: unknown;
  };
  quotation?: {
    quotationNo?: string | null;
    quotationDate?: Date | string | null;
    address?: string | null;
    gstNo?: string | null;
    vendorName?: string | null;
  } | null;
  vendor?: {
    name?: string | null;
    contactPerson?: string | null;
    phone?: string | null;
    mobileNo?: string | null;
    address?: string | null;
    gstNo?: string | null;
  } | null;
  project?: { name?: string | null; address?: string | null } | null;
  purchaseRequest?: {
    prNumber?: string | null;
    prDate?: Date | string | null;
  } | null;
  organization?: {
    name?: string | null;
    address1?: string | null;
    address2?: string | null;
    city?: string | null;
    state?: string | null;
    pinCode?: string | null;
    gstNo?: string | null;
  } | null;
  items: Array<{
    itemName: string;
    brand?: string | null;
    size?: string | null;
    hsnCode?: string | null;
    unitCode?: string | null;
    orderedQty: number;
    rate?: number | null;
    amount?: number | null;
  }>;
};

function orgAddress(org: PoExportInput['organization']): string {
  if (!org) return '';
  return [
    org.address1,
    org.address2,
    [org.city, org.state, org.pinCode].filter(Boolean).join(' '),
  ]
    .filter(Boolean)
    .join(', ');
}

/**
 * Build Purchase Order .xlsx matching PO.FORMAT_NEW.xlsx (PO_Format) layout.
 */
export function buildPurchaseOrderXlsx(input: PoExportInput): { buffer: Buffer; fileName: string } {
  const { po, items } = input;
  const org = input.organization;
  const companyName = org?.name || 'NB Developer LLP';
  const companyAddr = orgAddress(org);
  const companyGst = org?.gstNo ?? '';
  const cgstRate = Number(po.cgstRate ?? 9);
  const sgstRate = Number(po.sgstRate ?? 9);

  const subtotal = money(
    items.reduce((s, it) => {
      const amt =
        it.amount != null
          ? Number(it.amount)
          : Number(it.orderedQty || 0) * Number(it.rate || 0);
      return s + amt;
    }, 0),
  );
  const cgst = money((subtotal * cgstRate) / 100);
  const sgst = money((subtotal * sgstRate) / 100);
  const grand = money(subtotal + cgst + sgst);

  const vendorName = input.vendor?.name || po.vendorName;
  const vendorAddr =
    input.vendor?.address || input.quotation?.address || '';
  const vendorGst = input.vendor?.gstNo || input.quotation?.gstNo || '';
  const contactPerson = input.vendor?.contactPerson || '';
  const contactNumber = input.vendor?.mobileNo || input.vendor?.phone || '';
  const shipTo = input.project?.address || input.project?.name || '';
  const terms = parseTerms(po.termsAndConditions);

  // Build as sparse sheet matching sample columns A–J
  const ws: xlsx.WorkSheet = {};
  const set = (addr: string, v: string | number) => {
    ws[addr] = { t: typeof v === 'number' ? 'n' : 's', v };
  };

  set('B9', `Address:  ${companyAddr}`);
  set('B10', `GST No :  ${companyGst}`);
  set('B11', 'PURCHASE ORDER');
  set('I12', 'Page : 1/1');
  set('B13', `Project Name  :  ${input.project?.name ?? ''}`);
  set('B14', `P.O. No. : ${po.poNumber}`);
  set('I14', `Date : ${fmtDate(po.orderDate)}`);
  set('B16', "VENDOR'S NAME & ADDRESS :");
  set('C16', `${vendorName}${vendorAddr ? `\n${vendorAddr}` : ''}`);
  set('F16', 'Work place & Delivery address/Ship to :');
  set('F17', shipTo);
  set('I16', `Quot No. : ${input.quotation?.quotationNo ?? ''}`);
  set('I18', `Quot Dt. : ${fmtDate(input.quotation?.quotationDate)}`);
  set('F19', `Contact Person : ${contactPerson}`);
  set('F20', `Contact Number : ${contactNumber}`);
  set('B21', `GST IN : ${vendorGst}`);
  set('B22', `Contact Person : ${contactPerson}`);
  set('B23', `Contact Number :  ${contactNumber}`);
  set('I22', `Ind Ref.  : ${input.purchaseRequest?.prNumber ?? ''}`);
  set('I23', `Ind Ref.dt. : ${fmtDate(input.purchaseRequest?.prDate)}`);
  set(
    'B24',
    'We are pleased to inform you that your offer has been accepted to the extent indicated below and as per terms & conditions mentioned herein.',
  );

  // Header row 26
  set('B26', 'SR. NO.');
  set('C26', 'MATERIAL DESCRIPTION');
  set('F26', 'HSN Code');
  set('G26', 'UNIT');
  set('H26', 'QTY.');
  set('I26', 'UNIT PRICE               Rs.');
  set('J26', 'TOTAL VALUE                  Rs.          Ps.');

  const itemStart = 27; // 1-based excel row
  items.forEach((it, idx) => {
    const r = itemStart + idx;
    const desc = [it.itemName, it.brand, it.size].filter(Boolean).join(' / ');
    const qty = Number(it.orderedQty || 0);
    const rate = Number(it.rate || 0);
    const amt = it.amount != null ? Number(it.amount) : money(qty * rate);
    set(`B${r}`, idx + 1);
    set(`C${r}`, desc);
    set(`F${r}`, it.hsnCode ?? '');
    set(`G${r}`, it.unitCode ?? '');
    set(`H${r}`, qty);
    set(`I${r}`, rate);
    set(`J${r}`, money(amt));
  });

  const afterItems = itemStart + Math.max(items.length, 1);
  const noteRow = afterItems + 1;
  const totalRow = noteRow + 2;
  const cgstRow = totalRow + 1;
  const sgstRow = totalRow + 2;
  const grandRow = totalRow + 3;
  const rupeesRow = grandRow + 1;
  const tncHeader = rupeesRow + 1;
  const tncStart = tncHeader + 1;

  set(`B${noteRow}`, 'Note');
  set(`C${noteRow}`, 'Please Mention Our PO Number In Your Invoice ( Bill ) Copy .');
  set(
    `B${totalRow}`,
    `Billing Name: ${companyName}${companyAddr ? ` -   ${companyAddr}` : ''}${companyGst ? ` - GSTIN: ${companyGst}` : ''}`,
  );
  set(`I${totalRow}`, 'Total');
  set(`J${totalRow}`, subtotal);
  set(`I${cgstRow}`, `CGST@ ${cgstRate}%`);
  set(`J${cgstRow}`, cgst);
  set(`I${sgstRow}`, `SGST@ ${sgstRate}%`);
  set(`J${sgstRow}`, sgst);
  set(`I${grandRow}`, 'Total in Rs.');
  set(`J${grandRow}`, grand);
  set(`B${rupeesRow}`, `Rupees : ${amountInWords(grand)}`);
  set(`B${tncHeader}`, 'Terms & Conditions :');

  terms.forEach((t, i) => {
    const r = tncStart + i;
    set(`B${r}`, i + 1);
    set(`C${r}`, t);
  });

  const signRow = tncStart + terms.length + 1;
  set(`B${signRow}`, 'Prepared/Checked By');
  set(`H${signRow}`, '       Approved by Purchase Manager');

  const lastRow = signRow;
  ws['!ref'] = `A1:J${lastRow}`;
  ws['!cols'] = colWidths([3, 12, 48, 8, 8, 12, 10, 10, 18, 18]);

  const wb = xlsx.utils.book_new();
  xlsx.utils.book_append_sheet(wb, ws, 'PO_Format');
  const buffer = xlsx.write(wb, { type: 'buffer', bookType: 'xlsx' }) as Buffer;
  const safePo = po.poNumber.replace(/[^\w.-]+/g, '_');
  return { buffer, fileName: `PO_${safePo}.xlsx` };
}
