import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/platform_file_picker.dart';
import '../../data/earth_repository.dart';
import '../../domain/earth_kinds.dart';
import '../../domain/earth_models.dart';
import 'earth_format.dart';
import 'earth_pin.dart';

Future<EarthProperty?> showEarthPropertySheet({
  required BuildContext context,
  required EarthRepository repository,
  required bool canWrite,
  EarthProperty? existing,
  double? latitude,
  double? longitude,
  EarthGeocodeHit? place,
}) {
  return showModalBottomSheet<EarthProperty>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _EarthPropertySheet(
      repository: repository,
      canWrite: canWrite,
      existing: existing,
      latitude: latitude ?? existing?.latitude,
      longitude: longitude ?? existing?.longitude,
      place: place,
    ),
  );
}

class _EarthPropertySheet extends StatefulWidget {
  const _EarthPropertySheet({
    required this.repository,
    required this.canWrite,
    this.existing,
    this.latitude,
    this.longitude,
    this.place,
  });

  final EarthRepository repository;
  final bool canWrite;
  final EarthProperty? existing;
  final double? latitude;
  final double? longitude;
  final EarthGeocodeHit? place;

  @override
  State<_EarthPropertySheet> createState() => _EarthPropertySheetState();
}

class _EarthPropertySheetState extends State<_EarthPropertySheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _customKind;
  late final TextEditingController _address;
  late final TextEditingController _locality;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _country;
  late final TextEditingController _pincode;
  late final TextEditingController _notes;
  late final TextEditingController _price;
  late final TextEditingController _priceNotes;
  late final TextEditingController _carpet;
  late final TextEditingController _builtUp;
  late final TextEditingController _plot;
  late final TextEditingController _bedrooms;
  late final TextEditingController _bathrooms;
  late final TextEditingController _floorNo;
  late final TextEditingController _totalFloors;
  late final TextEditingController _furnishing;
  late final TextEditingController _facing;
  late final TextEditingController _parking;
  late final TextEditingController _rera;
  late final TextEditingController _landType;
  late final TextEditingController _surveyNo;
  late final TextEditingController _khataNo;
  late final TextEditingController _length;
  late final TextEditingController _width;
  late final TextEditingController _roadWidth;
  late final TextEditingController _fsi;
  late final TextEditingController _zoning;
  late final TextEditingController _frontage;
  late final TextEditingController _powerLoad;
  late final TextEditingController _washrooms;

  late String _kind;
  late String _status;
  late String _areaUnit;
  String? _imageUrl;
  bool _editing = false;
  bool _saving = false;
  bool _updatingPrice = false;
  DateTime _effectiveFrom = DateTime.now();
  EarthProperty? _detail;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final specs = e?.specs ?? const <String, dynamic>{};
    _kind = e?.kind ?? 'FLAT';
    _status = e?.status ?? 'AVAILABLE';
    _areaUnit = e?.areaUnit ?? 'SQFT';
    _imageUrl = e?.imageUrl;
    _editing = e == null && widget.canWrite;
    _name = TextEditingController(text: e?.name ?? '');
    _customKind = TextEditingController(text: e?.customKind ?? '');
    _address = TextEditingController(text: e?.address ?? widget.place?.address ?? widget.place?.label ?? '');
    _locality = TextEditingController(text: e?.locality ?? widget.place?.locality ?? '');
    _city = TextEditingController(text: e?.city ?? widget.place?.city ?? '');
    _state = TextEditingController(text: e?.state ?? widget.place?.state ?? '');
    _country = TextEditingController(text: e?.country ?? widget.place?.country ?? 'India');
    _pincode = TextEditingController(text: e?.pincode ?? widget.place?.pincode ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _price = TextEditingController(text: e?.currentPrice?.toString() ?? '');
    _priceNotes = TextEditingController();
    _carpet = TextEditingController(text: e?.carpetArea?.toString() ?? '');
    _builtUp = TextEditingController(text: e?.builtUpArea?.toString() ?? '');
    _plot = TextEditingController(text: e?.plotArea?.toString() ?? '');
    _bedrooms = TextEditingController(text: e?.bedrooms?.toString() ?? '');
    _bathrooms = TextEditingController(text: e?.bathrooms?.toString() ?? '');
    _floorNo = TextEditingController(text: e?.floorNo?.toString() ?? '');
    _totalFloors = TextEditingController(text: e?.totalFloors?.toString() ?? '');
    _furnishing = TextEditingController(text: specs['furnishing']?.toString() ?? '');
    _facing = TextEditingController(text: specs['facing']?.toString() ?? '');
    _parking = TextEditingController(text: specs['parking']?.toString() ?? '');
    _rera = TextEditingController(text: specs['reraId']?.toString() ?? '');
    _landType = TextEditingController(text: specs['landType']?.toString() ?? '');
    _surveyNo = TextEditingController(text: specs['surveyNo']?.toString() ?? '');
    _khataNo = TextEditingController(text: specs['khataNo']?.toString() ?? '');
    _length = TextEditingController(text: specs['length']?.toString() ?? '');
    _width = TextEditingController(text: specs['width']?.toString() ?? '');
    _roadWidth = TextEditingController(text: specs['roadWidth']?.toString() ?? '');
    _fsi = TextEditingController(text: specs['fsi']?.toString() ?? '');
    _zoning = TextEditingController(text: specs['zoning']?.toString() ?? '');
    _frontage = TextEditingController(text: specs['frontage']?.toString() ?? '');
    _powerLoad = TextEditingController(text: specs['powerLoad']?.toString() ?? '');
    _washrooms = TextEditingController(text: specs['washrooms']?.toString() ?? '');
    _detail = e;
    if (e != null) _reload();
  }

  Future<void> _reload() async {
    final id = widget.existing?.id;
    if (id == null) return;
    try {
      final fresh = await widget.repository.getById(id);
      if (!mounted) return;
      setState(() => _detail = fresh);
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [
      _name, _customKind, _address, _locality, _city, _state, _country, _pincode, _notes, _price,
      _priceNotes, _carpet, _builtUp, _plot, _bedrooms, _bathrooms, _floorNo, _totalFloors,
      _furnishing, _facing, _parking, _rera, _landType, _surveyNo, _khataNo, _length, _width,
      _roadWidth, _fsi, _zoning, _frontage, _powerLoad, _washrooms,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  EarthSpecGroup get _group => earthKindOf(_kind).group;

  Map<String, dynamic> _specs() {
    return {
      if (_furnishing.text.trim().isNotEmpty) 'furnishing': _furnishing.text.trim(),
      if (_facing.text.trim().isNotEmpty) 'facing': _facing.text.trim(),
      if (_parking.text.trim().isNotEmpty) 'parking': _parking.text.trim(),
      if (_rera.text.trim().isNotEmpty) 'reraId': _rera.text.trim(),
      if (_landType.text.trim().isNotEmpty) 'landType': _landType.text.trim(),
      if (_surveyNo.text.trim().isNotEmpty) 'surveyNo': _surveyNo.text.trim(),
      if (_khataNo.text.trim().isNotEmpty) 'khataNo': _khataNo.text.trim(),
      if (_length.text.trim().isNotEmpty) 'length': _length.text.trim(),
      if (_width.text.trim().isNotEmpty) 'width': _width.text.trim(),
      if (_roadWidth.text.trim().isNotEmpty) 'roadWidth': _roadWidth.text.trim(),
      if (_fsi.text.trim().isNotEmpty) 'fsi': _fsi.text.trim(),
      if (_zoning.text.trim().isNotEmpty) 'zoning': _zoning.text.trim(),
      if (_frontage.text.trim().isNotEmpty) 'frontage': _frontage.text.trim(),
      if (_powerLoad.text.trim().isNotEmpty) 'powerLoad': _powerLoad.text.trim(),
      if (_washrooms.text.trim().isNotEmpty) 'washrooms': _washrooms.text.trim(),
    };
  }

  Map<String, dynamic> _body({bool includePrice = true}) {
    return {
      'name': _name.text.trim(),
      'kind': _kind,
      'customKind': _customKind.text.trim().isEmpty ? null : _customKind.text.trim(),
      'status': _status,
      'latitude': widget.latitude ?? widget.existing?.latitude,
      'longitude': widget.longitude ?? widget.existing?.longitude,
      'address': _address.text.trim(),
      'locality': _locality.text.trim(),
      'city': _city.text.trim(),
      'state': _state.text.trim(),
      'country': _country.text.trim(),
      'pincode': _pincode.text.trim(),
      'imageUrl': _imageUrl,
      'specs': _specs(),
      'carpetArea': double.tryParse(_carpet.text.trim()),
      'builtUpArea': double.tryParse(_builtUp.text.trim()),
      'plotArea': double.tryParse(_plot.text.trim()),
      'areaUnit': _areaUnit,
      'bedrooms': int.tryParse(_bedrooms.text.trim()),
      'bathrooms': int.tryParse(_bathrooms.text.trim()),
      'floorNo': int.tryParse(_floorNo.text.trim()),
      'totalFloors': int.tryParse(_totalFloors.text.trim()),
      if (includePrice) 'currentPrice': double.tryParse(_price.text.trim()),
      'currency': 'INR',
      'notes': _notes.text.trim(),
      if (includePrice) 'effectiveFrom': _effectiveFrom.toIso8601String(),
    };
  }

  Future<void> _pickImage() async {
    final picked = await pickFileFromDevice(imagesOnly: true);
    if (picked == null) return;
    setState(() => _saving = true);
    try {
      final up = await widget.repository.uploadImage(
        bytes: picked.bytes,
        filename: picked.name,
      );
      if (!mounted) return;
      setState(() => _imageUrl = up.url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final EarthProperty saved;
      if (widget.existing == null) {
        saved = await widget.repository.create(_body());
      } else {
        saved = await widget.repository.update(widget.existing!.id, _body(includePrice: false));
      }
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addPrice() async {
    final amount = double.tryParse(_price.text.trim());
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid price')));
      return;
    }
    setState(() => _updatingPrice = true);
    try {
      final saved = await widget.repository.addPrice(widget.existing!.id, {
        'amount': amount,
        'effectiveFrom': _effectiveFrom.toIso8601String(),
        'notes': _priceNotes.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _detail = saved;
        _priceNotes.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price recorded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _updatingPrice = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove property?'),
        content: const Text('It will be hidden from the globe. Price history is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.repository.remove(widget.existing!.id);
    if (!mounted) return;
    Navigator.pop(context, widget.existing!.copyHidden());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final property = _detail ?? widget.existing;
    final viewOnly = property != null && !_editing;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH, maxWidth: 720),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    EarthPropertyPin(kind: _kind, imageUrl: _imageUrl, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existing == null ? 'Add property' : (viewOnly ? property.name : 'Edit property'),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${(widget.latitude ?? property?.latitude)?.toStringAsFixed(5)}, '
                            '${(widget.longitude ?? property?.longitude)?.toStringAsFixed(5)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (widget.existing != null && widget.canWrite && viewOnly)
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () => setState(() => _editing = true),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      _imageBlock(viewOnly),
                      const SizedBox(height: 16),
                      if (viewOnly) ..._viewBlocks(property) else ..._formBlocks(),
                      if (property != null) ...[
                        const SizedBox(height: 20),
                        Text('Price history', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _priceHistory(property),
                        if (widget.canWrite) ...[
                          const SizedBox(height: 12),
                          _priceUpdateRow(),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              if (!viewOnly)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      if (widget.existing != null && widget.canWrite)
                        TextButton(
                          onPressed: _saving ? null : _delete,
                          child: const Text('Remove'),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(widget.existing == null ? 'Add to globe' : 'Save'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageBlock(bool viewOnly) {
    return GestureDetector(
      onTap: viewOnly || !widget.canWrite ? null : _pickImage,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          image: _imageUrl != null && _imageUrl!.isNotEmpty
              ? DecorationImage(image: NetworkImage(_imageUrl!), fit: BoxFit.cover)
              : null,
        ),
        child: _imageUrl == null || _imageUrl!.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(earthKindOf(_kind).icon, size: 36, color: earthKindOf(_kind).color),
                  const SizedBox(height: 8),
                  Text(viewOnly ? 'No photo yet' : 'Tap to upload circular pin photo'),
                ],
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Chip(
                    avatar: EarthPropertyPin(kind: _kind, imageUrl: _imageUrl, size: 22),
                    label: const Text('Globe pin'),
                  ),
                ),
              ),
      ),
    );
  }

  List<Widget> _viewBlocks(EarthProperty p) {
    final def = earthKindOf(p.kind);
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(avatar: Icon(def.icon, size: 16, color: def.color), label: Text(earthKindLabel(p.kind, custom: p.customKind))),
          Chip(
            avatar: Icon(Icons.circle, size: 10, color: earthStatusColor(p.status)),
            label: Text(earthStatusLabel(p.status)),
          ),
          if (p.currentPrice != null) Chip(label: Text(earthMoney(p.currentPrice))),
          if (p.displayArea != null) Chip(label: Text(earthArea(p.displayArea, p.areaUnit))),
        ],
      ),
      const SizedBox(height: 12),
      Text(p.locationLabel, style: Theme.of(context).textTheme.bodyMedium),
      if ((p.address ?? '').isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(p.address!, style: Theme.of(context).textTheme.bodySmall),
      ],
      const SizedBox(height: 12),
      _specGrid(p),
      if ((p.notes ?? '').isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(p.notes!),
      ],
    ];
  }

  Widget _specGrid(EarthProperty p) {
    final items = <(String, String)>[
      if (p.bedrooms != null) ('Bedrooms', '${p.bedrooms}'),
      if (p.bathrooms != null) ('Bathrooms', '${p.bathrooms}'),
      if (p.floorNo != null) ('Floor', '${p.floorNo}'),
      if (p.totalFloors != null) ('Total floors', '${p.totalFloors}'),
      if (p.carpetArea != null) ('Carpet', earthArea(p.carpetArea, p.areaUnit)),
      if (p.builtUpArea != null) ('Built-up', earthArea(p.builtUpArea, p.areaUnit)),
      if (p.plotArea != null) ('Plot', earthArea(p.plotArea, p.areaUnit)),
      ...p.specs.entries
          .where((e) => '${e.value}'.trim().isNotEmpty)
          .map((e) => (e.key, '${e.value}')),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.$1, style: Theme.of(context).textTheme.labelSmall),
                  Text(e.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  List<Widget> _formBlocks() {
    final group = _group;
    return [
      TextFormField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'Property name'),
        validator: (v) => (v ?? '').trim().isEmpty ? 'Name is required' : null,
      ),
      const SizedBox(height: 12),
      _dropdown(
        label: 'Type',
        value: _kind,
        items: {for (final k in earthKinds) k.code: k.label},
        onChanged: (v) => setState(() => _kind = v),
      ),
      if (_kind == 'OTHER') ...[
        const SizedBox(height: 12),
        TextFormField(controller: _customKind, decoration: const InputDecoration(labelText: 'Custom type')),
      ],
      const SizedBox(height: 12),
      _dropdown(
        label: 'Status',
        value: _status,
        items: earthStatuses,
        onChanged: (v) => setState(() => _status = v),
      ),
      const SizedBox(height: 16),
      Text('Specifications', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      _dropdown(
        label: 'Area unit',
        value: _areaUnit,
        items: earthAreaUnits,
        onChanged: (v) => setState(() => _areaUnit = v),
      ),
      const SizedBox(height: 8),
      if (group == EarthSpecGroup.land || group == EarthSpecGroup.mixed) ...[
        _numField(_plot, 'Plot / land area'),
        _text(_landType, 'Land type (NA / agricultural / residential / commercial)'),
        _text(_surveyNo, 'Survey no.'),
        _text(_khataNo, 'Khata / CTS no.'),
        Row(children: [
          Expanded(child: _text(_length, 'Length')),
          const SizedBox(width: 8),
          Expanded(child: _text(_width, 'Width')),
        ]),
        _text(_roadWidth, 'Road width'),
        _text(_fsi, 'FSI / FAR'),
        _text(_zoning, 'Zoning'),
        _text(_facing, 'Facing'),
      ],
      if (group == EarthSpecGroup.residential || group == EarthSpecGroup.mixed) ...[
        Row(children: [
          Expanded(child: _numField(_bedrooms, 'Bedrooms')),
          const SizedBox(width: 8),
          Expanded(child: _numField(_bathrooms, 'Bathrooms')),
        ]),
        Row(children: [
          Expanded(child: _numField(_floorNo, 'Floor no.')),
          const SizedBox(width: 8),
          Expanded(child: _numField(_totalFloors, 'Total floors')),
        ]),
        _numField(_carpet, 'Carpet area'),
        _numField(_builtUp, 'Built-up area'),
        _text(_furnishing, 'Furnishing'),
        _text(_facing, 'Facing'),
        _text(_parking, 'Parking'),
        _text(_rera, 'RERA / project id'),
      ],
      if (group == EarthSpecGroup.commercial || group == EarthSpecGroup.mixed) ...[
        _numField(_carpet, 'Carpet area'),
        _numField(_builtUp, 'Built-up / floor plate'),
        Row(children: [
          Expanded(child: _numField(_floorNo, 'Floor no.')),
          const SizedBox(width: 8),
          Expanded(child: _text(_washrooms, 'Washrooms')),
        ]),
        _text(_frontage, 'Frontage'),
        _text(_powerLoad, 'Power load'),
        _text(_parking, 'Parking'),
        _text(_facing, 'Facing'),
      ],
      const SizedBox(height: 12),
      if (widget.existing == null)
        TextFormField(
          controller: _price,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(labelText: 'Current price (₹)', prefixText: '₹ '),
        ),
      const SizedBox(height: 12),
      TextFormField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextFormField(controller: _locality, decoration: const InputDecoration(labelText: 'Locality'))),
        const SizedBox(width: 8),
        Expanded(child: TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'City'))),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextFormField(controller: _state, decoration: const InputDecoration(labelText: 'State'))),
        const SizedBox(width: 8),
        Expanded(child: TextFormField(controller: _pincode, decoration: const InputDecoration(labelText: 'Pincode'))),
      ]),
      const SizedBox(height: 8),
      TextFormField(controller: _country, decoration: const InputDecoration(labelText: 'Country')),
      const SizedBox(height: 8),
      TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
    ];
  }

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required void Function(String value) onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: items.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _text(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextFormField(controller: c, decoration: InputDecoration(labelText: label)),
    );
  }

  Widget _numField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _priceHistory(EarthProperty p) {
    final prices = [...p.prices]..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    if (prices.isEmpty) {
      return const Text('No price records yet.');
    }
    return Column(
      children: prices.map((pr) {
        final df = DateFormat('dd MMM yyyy');
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            pr.isCurrent ? Icons.trending_up : Icons.history,
            color: pr.isCurrent ? AppColors.success : null,
          ),
          title: Text(earthMoney(pr.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            '${df.format(pr.effectiveFrom)}'
            '${pr.effectiveTo != null ? ' → ${df.format(pr.effectiveTo!)}' : ' · current'}'
            '${pr.notes != null && pr.notes!.isNotEmpty ? ' · ${pr.notes}' : ''}',
          ),
          trailing: pr.pricePerArea != null
              ? Text('${earthMoney(pr.pricePerArea, compact: true)} / area', style: Theme.of(context).textTheme.labelSmall)
              : null,
        );
      }).toList(),
    );
  }

  Widget _priceUpdateRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Record a new price', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(labelText: 'New amount', prefixText: '₹ '),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _effectiveFrom,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _effectiveFrom = picked);
              },
              child: Text(DateFormat('dd MMM yyyy').format(_effectiveFrom)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(controller: _priceNotes, decoration: const InputDecoration(labelText: 'Reason / notes')),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(
            onPressed: _updatingPrice ? null : _addPrice,
            child: _updatingPrice
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save price'),
          ),
        ),
      ],
    );
  }
}

extension on EarthProperty {
  EarthProperty copyHidden() => EarthProperty(
        id: id,
        name: name,
        kind: kind,
        customKind: customKind,
        status: status,
        latitude: latitude,
        longitude: longitude,
        isActive: false,
      );
}
