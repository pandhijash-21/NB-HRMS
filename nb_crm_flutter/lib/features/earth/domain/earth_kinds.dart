import 'package:flutter/material.dart';

enum EarthSpecGroup { residential, land, commercial, mixed }

class EarthKindDef {
  const EarthKindDef({
    required this.code,
    required this.label,
    required this.group,
    required this.icon,
    required this.color,
  });

  final String code;
  final String label;
  final EarthSpecGroup group;
  final IconData icon;
  final Color color;
}

const earthKinds = <EarthKindDef>[
  EarthKindDef(code: 'FLAT', label: 'Flat', group: EarthSpecGroup.residential, icon: Icons.apartment_outlined, color: Color(0xFF2563EB)),
  EarthKindDef(code: 'APARTMENT', label: 'Apartment', group: EarthSpecGroup.residential, icon: Icons.location_city_outlined, color: Color(0xFF1D4ED8)),
  EarthKindDef(code: 'BUNGALOW', label: 'Bungalow', group: EarthSpecGroup.residential, icon: Icons.home_outlined, color: Color(0xFF0EA5E9)),
  EarthKindDef(code: 'VILLA', label: 'Villa', group: EarthSpecGroup.residential, icon: Icons.villa_outlined, color: Color(0xFF0284C7)),
  EarthKindDef(code: 'PENTHOUSE', label: 'Penthouse', group: EarthSpecGroup.residential, icon: Icons.domain_outlined, color: Color(0xFF7C3AED)),
  EarthKindDef(code: 'ROW_HOUSE', label: 'Row house', group: EarthSpecGroup.residential, icon: Icons.holiday_village_outlined, color: Color(0xFF4F46E5)),
  EarthKindDef(code: 'DUPLEX', label: 'Duplex', group: EarthSpecGroup.residential, icon: Icons.maps_home_work_outlined, color: Color(0xFF6366F1)),
  EarthKindDef(code: 'STUDIO', label: 'Studio', group: EarthSpecGroup.residential, icon: Icons.weekend_outlined, color: Color(0xFF8B5CF6)),
  EarthKindDef(code: 'SHOP', label: 'Shop', group: EarthSpecGroup.commercial, icon: Icons.storefront_outlined, color: Color(0xFFF59E0B)),
  EarthKindDef(code: 'OFFICE', label: 'Office', group: EarthSpecGroup.commercial, icon: Icons.business_outlined, color: Color(0xFFD97706)),
  EarthKindDef(code: 'WAREHOUSE', label: 'Warehouse', group: EarthSpecGroup.commercial, icon: Icons.warehouse_outlined, color: Color(0xFFB45309)),
  EarthKindDef(code: 'SHOWROOM', label: 'Showroom', group: EarthSpecGroup.commercial, icon: Icons.store_mall_directory_outlined, color: Color(0xFFCA8A04)),
  EarthKindDef(code: 'LAND', label: 'Land', group: EarthSpecGroup.land, icon: Icons.landscape_outlined, color: Color(0xFF16A34A)),
  EarthKindDef(code: 'PLOT', label: 'Plot', group: EarthSpecGroup.land, icon: Icons.grid_on_outlined, color: Color(0xFF15803D)),
  EarthKindDef(code: 'FARMHOUSE', label: 'Farmhouse', group: EarthSpecGroup.land, icon: Icons.agriculture_outlined, color: Color(0xFF65A30D)),
  EarthKindDef(code: 'MIXED_USE', label: 'Mixed use', group: EarthSpecGroup.mixed, icon: Icons.account_balance_outlined, color: Color(0xFFDB2777)),
  EarthKindDef(code: 'OTHER', label: 'Other', group: EarthSpecGroup.mixed, icon: Icons.place_outlined, color: Color(0xFF64748B)),
];

const earthStatuses = <String, String>{
  'AVAILABLE': 'Available',
  'UNDER_CONSTRUCTION': 'Under construction',
  'RESERVED': 'Reserved',
  'SOLD': 'Sold',
  'RENTED': 'Rented',
  'HOLD': 'On hold',
};

const earthAreaUnits = <String, String>{
  'SQFT': 'Sq. ft',
  'SQM': 'Sq. m',
  'SQYD': 'Sq. yd',
  'ACRE': 'Acre',
  'GUNTHA': 'Guntha',
  'HECTARE': 'Hectare',
};

EarthKindDef earthKindOf(String? code) {
  final k = (code ?? '').toUpperCase();
  return earthKinds.firstWhere(
    (e) => e.code == k,
    orElse: () => earthKinds.last,
  );
}

String earthKindLabel(String? code, {String? custom}) {
  if ((code ?? '').toUpperCase() == 'OTHER' && (custom ?? '').trim().isNotEmpty) {
    return custom!.trim();
  }
  return earthKindOf(code).label;
}

String earthStatusLabel(String? code) =>
    earthStatuses[(code ?? '').toUpperCase()] ?? (code ?? 'Available');

Color earthStatusColor(String? code) {
  switch ((code ?? '').toUpperCase()) {
    case 'AVAILABLE':
      return const Color(0xFF16A34A);
    case 'UNDER_CONSTRUCTION':
      return const Color(0xFF2563EB);
    case 'RESERVED':
      return const Color(0xFFF59E0B);
    case 'SOLD':
      return const Color(0xFFDC2626);
    case 'RENTED':
      return const Color(0xFF7C3AED);
    case 'HOLD':
      return const Color(0xFF64748B);
    default:
      return const Color(0xFF64748B);
  }
}
