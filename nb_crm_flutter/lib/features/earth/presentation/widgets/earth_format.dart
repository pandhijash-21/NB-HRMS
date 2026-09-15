import 'dart:math' as math;

import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _inr2 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _compact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);

String earthMoney(num? value, {bool compact = false}) {
  if (value == null) return '—';
  if (compact && value.abs() >= 100000) return _compact.format(value);
  if (value % 1 == 0) return _inr.format(value);
  return _inr2.format(value);
}

String earthPct(num? value) {
  if (value == null) return '—';
  return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%';
}

String earthArea(num? value, String unit) {
  if (value == null) return '—';
  const labels = {
    'SQFT': 'sq.ft',
    'SQM': 'sq.m',
    'SQYD': 'sq.yd',
    'ACRE': 'acre',
    'GUNTHA': 'guntha',
    'HECTARE': 'ha',
  };
  return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} ${labels[unit] ?? unit.toLowerCase()}';
}

double earthHaversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(a.clamp(0, 1)));
}

double earthPolygonAreaKm2(List<(double lat, double lng)> pts) {
  if (pts.length < 3) return 0;
  const r = 6371.0;
  var sum = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    sum += _rad(b.$2 - a.$2) * (2 + math.sin(_rad(a.$1)) + math.sin(_rad(b.$1)));
  }
  return (sum.abs() * r * r / 2);
}

double _rad(double deg) => deg * math.pi / 180;
