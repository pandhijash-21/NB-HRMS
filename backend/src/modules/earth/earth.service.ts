import { prisma } from '../../config/prisma';
import { Prisma, type EarthMediaKind, type EarthPropertyKind, type EarthPropertyStatus } from '@prisma/client';

function str(v: unknown): string | null {
  if (v == null) return null;
  const s = String(v).trim();
  return s.length ? s : null;
}

function num(v: unknown): number | null {
  if (v == null || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function dec(v: unknown): Prisma.Decimal | null {
  const n = num(v);
  return n == null ? null : new Prisma.Decimal(n);
}

function int(v: unknown): number | null {
  const n = num(v);
  return n == null ? null : Math.trunc(n);
}

function dateVal(v: unknown): Date | null {
  const s = str(v);
  if (!s) return null;
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
}

function toNum(v: Prisma.Decimal | number | string | null | undefined): number | null {
  if (v == null) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

const KINDS = new Set<EarthPropertyKind>([
  'FLAT',
  'APARTMENT',
  'BUNGALOW',
  'VILLA',
  'PENTHOUSE',
  'ROW_HOUSE',
  'DUPLEX',
  'STUDIO',
  'SHOP',
  'OFFICE',
  'WAREHOUSE',
  'SHOWROOM',
  'LAND',
  'PLOT',
  'FARMHOUSE',
  'MIXED_USE',
  'OTHER',
]);

const STATUSES = new Set<EarthPropertyStatus>([
  'AVAILABLE',
  'UNDER_CONSTRUCTION',
  'RESERVED',
  'SOLD',
  'RENTED',
  'HOLD',
]);

function parseKind(v: unknown): EarthPropertyKind {
  const raw = str(v)?.toUpperCase().replace(/[\s-]+/g, '_') ?? '';
  if (KINDS.has(raw as EarthPropertyKind)) return raw as EarthPropertyKind;
  throw new Error('Invalid property type');
}

function parseStatus(v: unknown, fallback: EarthPropertyStatus = 'AVAILABLE'): EarthPropertyStatus {
  const raw = str(v)?.toUpperCase().replace(/[\s-]+/g, '_') ?? '';
  if (!raw) return fallback;
  if (STATUSES.has(raw as EarthPropertyStatus)) return raw as EarthPropertyStatus;
  throw new Error('Invalid property status');
}

function parseSpecs(v: unknown): Prisma.InputJsonValue | typeof Prisma.JsonNull | undefined {
  if (v == null) return undefined;
  if (typeof v === 'object') return v as Prisma.InputJsonValue;
  if (typeof v === 'string') {
    try {
      return JSON.parse(v) as Prisma.InputJsonValue;
    } catch {
      return undefined;
    }
  }
  return undefined;
}

function areaForRate(row: {
  carpetArea: Prisma.Decimal | null;
  builtUpArea: Prisma.Decimal | null;
  plotArea: Prisma.Decimal | null;
}): number | null {
  return toNum(row.carpetArea) ?? toNum(row.builtUpArea) ?? toNum(row.plotArea);
}

function pricePerArea(amount: number, area: number | null): Prisma.Decimal | null {
  if (!area || area <= 0) return null;
  return new Prisma.Decimal(Number((amount / area).toFixed(2)));
}

const listInclude = {
  prices: {
    where: { effectiveTo: null },
    orderBy: { effectiveFrom: 'desc' as const },
    take: 1,
  },
  media: {
    where: { kind: 'PHOTO' as EarthMediaKind },
    orderBy: [{ isPrimary: 'desc' as const }, { sortOrder: 'asc' as const }],
    take: 1,
  },
  _count: { select: { prices: true, media: true } },
};

const detailInclude = {
  prices: { orderBy: { effectiveFrom: 'desc' as const } },
  media: { orderBy: [{ isPrimary: 'desc' as const }, { sortOrder: 'asc' as const }, { createdAt: 'desc' as const }] },
};

function serializeProperty(
  row: Prisma.EarthPropertyGetPayload<{ include: typeof detailInclude }> | Prisma.EarthPropertyGetPayload<{ include: typeof listInclude }>,
) {
  const imageUrl = row.imageUrl || ('media' in row ? row.media[0]?.url ?? null : null);
  return {
    id: row.id,
    name: row.name,
    kind: row.kind,
    customKind: row.customKind,
    status: row.status,
    latitude: toNum(row.latitude),
    longitude: toNum(row.longitude),
    altitudeM: toNum(row.altitudeM),
    address: row.address,
    locality: row.locality,
    city: row.city,
    state: row.state,
    country: row.country,
    pincode: row.pincode,
    imageUrl,
    specs: row.specs,
    carpetArea: toNum(row.carpetArea),
    builtUpArea: toNum(row.builtUpArea),
    plotArea: toNum(row.plotArea),
    areaUnit: row.areaUnit ?? 'SQFT',
    bedrooms: row.bedrooms,
    bathrooms: row.bathrooms,
    floorNo: row.floorNo,
    totalFloors: row.totalFloors,
    currentPrice: toNum(row.currentPrice),
    currency: row.currency,
    notes: row.notes,
    isActive: row.isActive,
    createdBy: row.createdBy,
    updatedBy: row.updatedBy,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    prices: 'prices' in row
      ? row.prices.map((p) => ({
          id: p.id,
          propertyId: p.propertyId,
          amount: toNum(p.amount),
          currency: p.currency,
          pricePerArea: toNum(p.pricePerArea),
          effectiveFrom: p.effectiveFrom,
          effectiveTo: p.effectiveTo,
          notes: p.notes,
          createdBy: p.createdBy,
          createdAt: p.createdAt,
        }))
      : [],
    media: 'media' in row
      ? row.media.map((m) => ({
          id: m.id,
          propertyId: m.propertyId,
          url: m.url,
          kind: m.kind,
          isPrimary: m.isPrimary,
          fileName: m.fileName,
          mimeType: m.mimeType,
          fileSize: m.fileSize,
          sortOrder: m.sortOrder,
          createdAt: m.createdAt,
        }))
      : [],
    priceCount: '_count' in row ? row._count.prices : undefined,
    mediaCount: '_count' in row ? row._count.media : undefined,
  };
}

function mapBody(body: Record<string, unknown>) {
  const specs = parseSpecs(body.specs);
  return {
    name: str(body.name),
    kind: body.kind != null ? parseKind(body.kind) : undefined,
    customKind: str(body.customKind),
    status: body.status != null ? parseStatus(body.status) : undefined,
    latitude: dec(body.latitude),
    longitude: dec(body.longitude),
    altitudeM: dec(body.altitudeM),
    address: str(body.address),
    locality: str(body.locality),
    city: str(body.city),
    state: str(body.state),
    country: str(body.country),
    pincode: str(body.pincode),
    imageUrl: str(body.imageUrl),
    specs: specs === undefined ? undefined : specs,
    carpetArea: dec(body.carpetArea),
    builtUpArea: dec(body.builtUpArea),
    plotArea: dec(body.plotArea),
    areaUnit: str(body.areaUnit)?.toUpperCase() ?? undefined,
    bedrooms: int(body.bedrooms),
    bathrooms: int(body.bathrooms),
    floorNo: int(body.floorNo),
    totalFloors: int(body.totalFloors),
    currentPrice: dec(body.currentPrice ?? body.price),
    currency: str(body.currency)?.toUpperCase() ?? undefined,
    notes: str(body.notes),
  };
}

function assertLatLng(lat: Prisma.Decimal | null | undefined, lng: Prisma.Decimal | null | undefined) {
  const la = toNum(lat);
  const ln = toNum(lng);
  if (la == null || ln == null) throw new Error('Latitude and longitude are required');
  if (la < -90 || la > 90) throw new Error('Latitude must be between -90 and 90');
  if (ln < -180 || ln > 180) throw new Error('Longitude must be between -180 and 180');
}

export const earthService = {
  async list(opts?: { includeInactive?: boolean; kind?: string; status?: string; q?: string }) {
    const where: Prisma.EarthPropertyWhereInput = {};
    if (!opts?.includeInactive) where.isActive = true;
    if (opts?.kind) where.kind = parseKind(opts.kind);
    if (opts?.status) where.status = parseStatus(opts.status);
    const q = str(opts?.q);
    if (q) {
      where.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { city: { contains: q, mode: 'insensitive' } },
        { locality: { contains: q, mode: 'insensitive' } },
        { address: { contains: q, mode: 'insensitive' } },
        { customKind: { contains: q, mode: 'insensitive' } },
      ];
    }
    const rows = await prisma.earthProperty.findMany({
      where,
      include: listInclude,
      orderBy: { updatedAt: 'desc' },
    });
    return rows.map(serializeProperty);
  },

  async getById(id: string) {
    const row = await prisma.earthProperty.findUnique({ where: { id }, include: detailInclude });
    if (!row) throw new Error('Property not found');
    return serializeProperty(row);
  },

  async create(body: Record<string, unknown>, actorId: string) {
    const data = mapBody(body);
    if (!data.name) throw new Error('Property name is required');
    if (!data.kind) throw new Error('Property type is required');
    assertLatLng(data.latitude, data.longitude);

    const amount = toNum(data.currentPrice);
    const area = toNum(data.carpetArea) ?? toNum(data.builtUpArea) ?? toNum(data.plotArea);
    const effectiveFrom = dateVal(body.effectiveFrom) ?? new Date();

    const row = await prisma.earthProperty.create({
      data: {
        name: data.name,
        kind: data.kind,
        customKind: data.customKind,
        status: data.status ?? 'AVAILABLE',
        latitude: data.latitude!,
        longitude: data.longitude!,
        altitudeM: data.altitudeM,
        address: data.address,
        locality: data.locality,
        city: data.city,
        state: data.state,
        country: data.country ?? 'India',
        pincode: data.pincode,
        imageUrl: data.imageUrl,
        specs: data.specs === undefined ? undefined : data.specs,
        carpetArea: data.carpetArea,
        builtUpArea: data.builtUpArea,
        plotArea: data.plotArea,
        areaUnit: data.areaUnit ?? 'SQFT',
        bedrooms: data.bedrooms,
        bathrooms: data.bathrooms,
        floorNo: data.floorNo,
        totalFloors: data.totalFloors,
        currentPrice: data.currentPrice,
        currency: data.currency ?? 'INR',
        notes: data.notes,
        createdBy: actorId,
        updatedBy: actorId,
        prices:
          amount != null
            ? {
                create: {
                  amount: data.currentPrice!,
                  currency: data.currency ?? 'INR',
                  pricePerArea: pricePerArea(amount, area),
                  effectiveFrom,
                  notes: str(body.priceNotes),
                  createdBy: actorId,
                },
              }
            : undefined,
        media: data.imageUrl
          ? {
              create: {
                url: data.imageUrl,
                kind: 'PHOTO',
                isPrimary: true,
                fileName: str(body.imageFileName),
              },
            }
          : undefined,
      },
      include: detailInclude,
    });
    return serializeProperty(row);
  },

  async update(id: string, body: Record<string, unknown>, actorId: string) {
    const existing = await prisma.earthProperty.findUnique({ where: { id } });
    if (!existing) throw new Error('Property not found');
    const data = mapBody(body);
    if (data.latitude != null || data.longitude != null) {
      assertLatLng(data.latitude ?? existing.latitude, data.longitude ?? existing.longitude);
    }

    const row = await prisma.earthProperty.update({
      where: { id },
      data: {
        name: data.name ?? undefined,
        kind: data.kind,
        customKind: data.customKind === undefined ? undefined : data.customKind,
        status: data.status,
        latitude: data.latitude ?? undefined,
        longitude: data.longitude ?? undefined,
        altitudeM: data.altitudeM === undefined ? undefined : data.altitudeM,
        address: data.address === undefined ? undefined : data.address,
        locality: data.locality === undefined ? undefined : data.locality,
        city: data.city === undefined ? undefined : data.city,
        state: data.state === undefined ? undefined : data.state,
        country: data.country === undefined ? undefined : data.country,
        pincode: data.pincode === undefined ? undefined : data.pincode,
        imageUrl: data.imageUrl === undefined ? undefined : data.imageUrl,
        specs: data.specs === undefined ? undefined : data.specs,
        carpetArea: data.carpetArea === undefined ? undefined : data.carpetArea,
        builtUpArea: data.builtUpArea === undefined ? undefined : data.builtUpArea,
        plotArea: data.plotArea === undefined ? undefined : data.plotArea,
        areaUnit: data.areaUnit,
        bedrooms: data.bedrooms === undefined ? undefined : data.bedrooms,
        bathrooms: data.bathrooms === undefined ? undefined : data.bathrooms,
        floorNo: data.floorNo === undefined ? undefined : data.floorNo,
        totalFloors: data.totalFloors === undefined ? undefined : data.totalFloors,
        currency: data.currency,
        notes: data.notes === undefined ? undefined : data.notes,
        updatedBy: actorId,
      },
      include: detailInclude,
    });
    return serializeProperty(row);
  },

  async remove(id: string) {
    const existing = await prisma.earthProperty.findUnique({ where: { id }, select: { id: true } });
    if (!existing) throw new Error('Property not found');
    await prisma.earthProperty.update({
      where: { id },
      data: { isActive: false },
    });
    return { id, deleted: true };
  },

  async addPrice(id: string, body: Record<string, unknown>, actorId: string) {
    const existing = await prisma.earthProperty.findUnique({ where: { id } });
    if (!existing) throw new Error('Property not found');
    const amount = num(body.amount ?? body.price ?? body.currentPrice);
    if (amount == null || amount < 0) throw new Error('Price amount is required');
    const effectiveFrom = dateVal(body.effectiveFrom) ?? new Date();
    const area = areaForRate(existing);

    await prisma.$transaction(async (tx) => {
      await tx.earthPropertyPrice.updateMany({
        where: { propertyId: id, effectiveTo: null },
        data: { effectiveTo: effectiveFrom },
      });
      await tx.earthPropertyPrice.create({
        data: {
          propertyId: id,
          amount: new Prisma.Decimal(amount),
          currency: str(body.currency)?.toUpperCase() ?? existing.currency,
          pricePerArea: pricePerArea(amount, area),
          effectiveFrom,
          notes: str(body.notes),
          createdBy: actorId,
        },
      });
      await tx.earthProperty.update({
        where: { id },
        data: {
          currentPrice: new Prisma.Decimal(amount),
          currency: str(body.currency)?.toUpperCase() ?? existing.currency,
          updatedBy: actorId,
        },
      });
    });

    return this.getById(id);
  },

  async listPrices(id: string) {
    const existing = await prisma.earthProperty.findUnique({ where: { id }, select: { id: true } });
    if (!existing) throw new Error('Property not found');
    const rows = await prisma.earthPropertyPrice.findMany({
      where: { propertyId: id },
      orderBy: { effectiveFrom: 'desc' },
    });
    return rows.map((p) => ({
      id: p.id,
      propertyId: p.propertyId,
      amount: toNum(p.amount),
      currency: p.currency,
      pricePerArea: toNum(p.pricePerArea),
      effectiveFrom: p.effectiveFrom,
      effectiveTo: p.effectiveTo,
      notes: p.notes,
      createdBy: p.createdBy,
      createdAt: p.createdAt,
    }));
  },

  async dashboard() {
    const properties = await prisma.earthProperty.findMany({
      where: { isActive: true },
      include: {
        prices: { orderBy: { effectiveFrom: 'asc' } },
      },
    });

    const byKindMap = new Map<string, { kind: string; count: number; totalValue: number; priced: number }>();
    const byStatusMap = new Map<string, number>();
    const byCityMap = new Map<string, { city: string; count: number; totalValue: number; priced: number; appreciationSum: number; appreciationN: number }>();

    let totalValue = 0;
    let pricedCount = 0;
    let areaValueSum = 0;
    let areaValueN = 0;
    let appreciationSum = 0;
    let appreciationN = 0;
    const topAppreciation: Array<{
      id: string;
      name: string;
      kind: string;
      city: string | null;
      imageUrl: string | null;
      firstPrice: number;
      latestPrice: number;
      appreciationPct: number;
    }> = [];
    const recentPriceChanges: Array<{
      propertyId: string;
      name: string;
      kind: string;
      amount: number;
      previousAmount: number | null;
      changePct: number | null;
      effectiveFrom: Date;
      imageUrl: string | null;
    }> = [];
    const stalePricing: Array<{
      id: string;
      name: string;
      kind: string;
      currentPrice: number | null;
      daysSinceUpdate: number;
    }> = [];

    const now = Date.now();
    const staleMs = 180 * 24 * 60 * 60 * 1000;

    for (const p of properties) {
      const price = toNum(p.currentPrice);
      const kind = p.kind;
      const status = p.status;
      byStatusMap.set(status, (byStatusMap.get(status) ?? 0) + 1);
      const kindRow = byKindMap.get(kind) ?? { kind, count: 0, totalValue: 0, priced: 0 };
      kindRow.count += 1;
      if (price != null) {
        kindRow.totalValue += price;
        kindRow.priced += 1;
        totalValue += price;
        pricedCount += 1;
        const area = areaForRate(p);
        if (area && area > 0) {
          areaValueSum += price / area;
          areaValueN += 1;
        }
      }
      byKindMap.set(kind, kindRow);

      const city = (p.city || p.locality || 'Unspecified').trim() || 'Unspecified';
      const cityRow = byCityMap.get(city) ?? {
        city,
        count: 0,
        totalValue: 0,
        priced: 0,
        appreciationSum: 0,
        appreciationN: 0,
      };
      cityRow.count += 1;
      if (price != null) {
        cityRow.totalValue += price;
        cityRow.priced += 1;
      }

      const prices = p.prices;
      if (prices.length >= 1) {
        const first = toNum(prices[0].amount);
        const latest = toNum(prices[prices.length - 1].amount);
        if (first != null && latest != null && first > 0) {
          const pct = ((latest - first) / first) * 100;
          appreciationSum += pct;
          appreciationN += 1;
          cityRow.appreciationSum += pct;
          cityRow.appreciationN += 1;
          topAppreciation.push({
            id: p.id,
            name: p.name,
            kind: p.kind,
            city: p.city,
            imageUrl: p.imageUrl,
            firstPrice: first,
            latestPrice: latest,
            appreciationPct: Number(pct.toFixed(2)),
          });
        }
        const last = prices[prices.length - 1];
        const prev = prices.length > 1 ? prices[prices.length - 2] : null;
        const lastAmt = toNum(last.amount);
        const prevAmt = prev ? toNum(prev.amount) : null;
        if (lastAmt != null) {
          recentPriceChanges.push({
            propertyId: p.id,
            name: p.name,
            kind: p.kind,
            amount: lastAmt,
            previousAmount: prevAmt,
            changePct:
              prevAmt != null && prevAmt > 0
                ? Number((((lastAmt - prevAmt) / prevAmt) * 100).toFixed(2))
                : null,
            effectiveFrom: last.effectiveFrom,
            imageUrl: p.imageUrl,
          });
          const age = now - last.effectiveFrom.getTime();
          if (age >= staleMs) {
            stalePricing.push({
              id: p.id,
              name: p.name,
              kind: p.kind,
              currentPrice: lastAmt,
              daysSinceUpdate: Math.floor(age / (24 * 60 * 60 * 1000)),
            });
          }
        }
      }
      byCityMap.set(city, cityRow);
    }

    topAppreciation.sort((a, b) => b.appreciationPct - a.appreciationPct);
    recentPriceChanges.sort((a, b) => b.effectiveFrom.getTime() - a.effectiveFrom.getTime());
    stalePricing.sort((a, b) => b.daysSinceUpdate - a.daysSinceUpdate);

    const monthlyTrend: Array<{ month: string; avgPrice: number; count: number; avgPricePerArea: number | null }> = [];
    const months = 18;
    for (let i = months - 1; i >= 0; i--) {
      const end = new Date();
      end.setUTCDate(1);
      end.setUTCHours(0, 0, 0, 0);
      end.setUTCMonth(end.getUTCMonth() - i + 1);
      const monthStart = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth() - 1, 1));
      const label = `${monthStart.getUTCFullYear()}-${String(monthStart.getUTCMonth() + 1).padStart(2, '0')}`;
      let sum = 0;
      let count = 0;
      let ppaSum = 0;
      let ppaN = 0;
      for (const p of properties) {
        const effective = [...p.prices]
          .filter((pr) => pr.effectiveFrom.getTime() <= end.getTime() - 1)
          .pop();
        const amt = effective ? toNum(effective.amount) : null;
        if (amt == null) continue;
        sum += amt;
        count += 1;
        const area = areaForRate(p);
        if (area && area > 0) {
          ppaSum += amt / area;
          ppaN += 1;
        }
      }
      monthlyTrend.push({
        month: label,
        avgPrice: count ? Number((sum / count).toFixed(2)) : 0,
        count,
        avgPricePerArea: ppaN ? Number((ppaSum / ppaN).toFixed(2)) : null,
      });
    }

    const mom = monthlyTrend.length >= 2
      ? (() => {
          const prev = monthlyTrend[monthlyTrend.length - 2].avgPrice;
          const cur = monthlyTrend[monthlyTrend.length - 1].avgPrice;
          if (!prev) return null;
          return Number((((cur - prev) / prev) * 100).toFixed(2));
        })()
      : null;
    const yoy = monthlyTrend.length >= 13
      ? (() => {
          const prev = monthlyTrend[monthlyTrend.length - 13].avgPrice;
          const cur = monthlyTrend[monthlyTrend.length - 1].avgPrice;
          if (!prev) return null;
          return Number((((cur - prev) / prev) * 100).toFixed(2));
        })()
      : null;

    return {
      generatedAt: new Date().toISOString(),
      totals: {
        properties: properties.length,
        available: byStatusMap.get('AVAILABLE') ?? 0,
        sold: byStatusMap.get('SOLD') ?? 0,
        reserved: byStatusMap.get('RESERVED') ?? 0,
        underConstruction: byStatusMap.get('UNDER_CONSTRUCTION') ?? 0,
        rented: byStatusMap.get('RENTED') ?? 0,
        totalValue: Number(totalValue.toFixed(2)),
        avgPrice: pricedCount ? Number((totalValue / pricedCount).toFixed(2)) : 0,
        avgPricePerArea: areaValueN ? Number((areaValueSum / areaValueN).toFixed(2)) : null,
        avgAppreciationPct: appreciationN ? Number((appreciationSum / appreciationN).toFixed(2)) : null,
        pricedCount,
        momChangePct: mom,
        yoyChangePct: yoy,
      },
      byKind: [...byKindMap.values()]
        .map((r) => ({
          kind: r.kind,
          count: r.count,
          totalValue: Number(r.totalValue.toFixed(2)),
          avgPrice: r.priced ? Number((r.totalValue / r.priced).toFixed(2)) : 0,
        }))
        .sort((a, b) => b.count - a.count),
      byStatus: [...byStatusMap.entries()].map(([status, count]) => ({ status, count })),
      byCity: [...byCityMap.values()]
        .map((r) => ({
          city: r.city,
          count: r.count,
          avgPrice: r.priced ? Number((r.totalValue / r.priced).toFixed(2)) : 0,
          totalValue: Number(r.totalValue.toFixed(2)),
          avgAppreciationPct: r.appreciationN ? Number((r.appreciationSum / r.appreciationN).toFixed(2)) : null,
        }))
        .sort((a, b) => b.count - a.count),
      monthlyTrend,
      topAppreciation: topAppreciation.slice(0, 8),
      recentPriceChanges: recentPriceChanges.slice(0, 12),
      stalePricing: stalePricing.slice(0, 8),
    };
  },

  async geocode(query: string) {
    const q = query.trim();
    if (q.length < 2) return [];
    const url = `https://nominatim.openstreetmap.org/search?format=jsonv2&limit=8&addressdetails=1&q=${encodeURIComponent(q)}`;
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'NB-HRMS-Earth/1.0 (property-inventory)',
        Accept: 'application/json',
      },
    });
    if (!res.ok) throw new Error('Geocoding failed');
    const raw = (await res.json()) as Array<Record<string, unknown>>;
    return raw.map((r) => ({
      label: String(r.display_name ?? ''),
      latitude: Number(r.lat),
      longitude: Number(r.lon),
      type: String(r.type ?? r.class ?? ''),
    })).filter((r) => Number.isFinite(r.latitude) && Number.isFinite(r.longitude));
  },

  async reverse(lat: number, lng: number) {
    const url = `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lng}&addressdetails=1`;
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'NB-HRMS-Earth/1.0 (property-inventory)',
        Accept: 'application/json',
      },
    });
    if (!res.ok) throw new Error('Reverse geocoding failed');
    const raw = (await res.json()) as Record<string, unknown>;
    const addr = (raw.address ?? {}) as Record<string, unknown>;
    return {
      label: String(raw.display_name ?? ''),
      latitude: lat,
      longitude: lng,
      address: String(raw.display_name ?? ''),
      locality: String(addr.suburb ?? addr.neighbourhood ?? addr.village ?? addr.town ?? ''),
      city: String(addr.city ?? addr.town ?? addr.county ?? ''),
      state: String(addr.state ?? ''),
      country: String(addr.country ?? ''),
      pincode: String(addr.postcode ?? ''),
    };
  },
};
