import 'package:flutter/material.dart';

import '../../domain/structure_models.dart';

class LocationSelection {
  const LocationSelection({
    this.towerIds = const [],
    this.floorNos = const [],
    this.unitIds = const [],
  });

  final List<String> towerIds;
  final List<int> floorNos;
  final List<String> unitIds;

  bool get allTowers => towerIds.isEmpty;
  bool get allFloors => floorNos.isEmpty;
  bool get allUnits => unitIds.isEmpty;

  String towerLabel(List<ErpProjectTower> towers) {
    if (allTowers) return 'All Block';
    if (towerIds.length == 1) {
      final t = towers.where((x) => x.id == towerIds.first).firstOrNull;
      return t?.name ?? '1 Block';
    }
    return '${towerIds.length} Blocks';
  }

  String floorLabel() {
    if (allFloors) return 'All Floor';
    if (floorNos.length == 1) return 'Floor ${floorNos.first}';
    return '${floorNos.length} Floors';
  }

  String unitLabel() {
    if (allUnits) return 'All Unit';
    if (unitIds.length == 1) return '1 Unit';
    return '${unitIds.length} Units';
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

Future<LocationSelection?> showWorkOrderLocationPicker({
  required BuildContext context,
  required List<ErpProjectTower> towers,
  required LocationSelection initial,
}) {
  return showDialog<LocationSelection>(
    context: context,
    builder: (ctx) => _LocationPickerDialog(towers: towers, initial: initial),
  );
}

class _LocationPickerDialog extends StatefulWidget {
  const _LocationPickerDialog({required this.towers, required this.initial});

  final List<ErpProjectTower> towers;
  final LocationSelection initial;

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  late Set<String> _towerIds;
  late Set<int> _floorNos;
  late Set<String> _unitIds;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _towerIds = widget.initial.towerIds.toSet();
    _floorNos = widget.initial.floorNos.toSet();
    _unitIds = widget.initial.unitIds.toSet();
  }

  List<ErpProjectTower> get _selectedTowers {
    if (_towerIds.isEmpty) return widget.towers;
    return widget.towers.where((t) => _towerIds.contains(t.id)).toList();
  }

  List<int> get _availableFloors {
    final floors = <int>{};
    for (final t in _selectedTowers) {
      for (final u in t.units) {
        floors.add(u.floorNo);
      }
    }
    return floors.toList()..sort();
  }

  List<ErpProjectUnit> get _availableUnits {
    final towers = _selectedTowers;
    final units = <ErpProjectUnit>[];
    for (final t in towers) {
      for (final u in t.units) {
        if (_floorNos.isEmpty || _floorNos.contains(u.floorNo)) {
          units.add(u);
        }
      }
    }
    return units;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(['Select Block', 'Select Floor', 'Select Unit'][_step]),
      content: SizedBox(
        width: 420,
        child: _step == 0
            ? _buildTowerStep()
            : _step == 1
                ? _buildFloorStep()
                : _buildUnitStep(),
      ),
      actions: [
        if (_step > 0)
          TextButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        if (_step < 2)
          FilledButton(
            onPressed: () => setState(() => _step++),
            child: const Text('Next'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              LocationSelection(
                towerIds: _towerIds.toList(),
                floorNos: _floorNos.toList(),
                unitIds: _unitIds.toList(),
              ),
            ),
            child: const Text('Done'),
          ),
      ],
    );
  }

  Widget _buildTowerStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _towerIds = widget.towers.map((t) => t.id).toSet()),
              child: const Text('Select All'),
            ),
            TextButton(
              onPressed: () => setState(() => _towerIds.clear()),
              child: const Text('Clear All'),
            ),
          ],
        ),
        ...widget.towers.map((t) => CheckboxListTile(
              value: _towerIds.isEmpty ? false : _towerIds.contains(t.id),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _towerIds.add(t.id);
                  } else {
                    _towerIds.remove(t.id);
                  }
                  _floorNos.clear();
                  _unitIds.clear();
                });
              },
              title: Text(t.name),
              subtitle: const Text('Block / Tower'),
            )),
        CheckboxListTile(
          value: _towerIds.isEmpty,
          onChanged: (v) => setState(() {
            _towerIds.clear();
            _floorNos.clear();
            _unitIds.clear();
          }),
          title: const Text('All Blocks'),
        ),
      ],
    );
  }

  Widget _buildFloorStep() {
    final floors = _availableFloors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _floorNos = floors.toSet()),
              child: const Text('Select All'),
            ),
            TextButton(
              onPressed: () => setState(() => _floorNos.clear()),
              child: const Text('Clear All'),
            ),
          ],
        ),
        ...floors.map((f) => CheckboxListTile(
              value: _floorNos.isEmpty ? false : _floorNos.contains(f),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _floorNos.add(f);
                  } else {
                    _floorNos.remove(f);
                  }
                  _unitIds.clear();
                });
              },
              title: Text('Floor $f'),
            )),
        CheckboxListTile(
          value: _floorNos.isEmpty,
          onChanged: (v) => setState(() {
            _floorNos.clear();
            _unitIds.clear();
          }),
          title: const Text('All Floors'),
        ),
      ],
    );
  }

  Widget _buildUnitStep() {
    final units = _availableUnits;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _unitIds = units.map((u) => u.id).toSet()),
              child: const Text('Select All'),
            ),
            TextButton(
              onPressed: () => setState(() => _unitIds.clear()),
              child: const Text('Clear All'),
            ),
          ],
        ),
        SizedBox(
          height: 280,
          child: ListView(
            children: units
                .map((u) => CheckboxListTile(
                      value: _unitIds.isEmpty ? false : _unitIds.contains(u.id),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _unitIds.add(u.id);
                          } else {
                            _unitIds.remove(u.id);
                          }
                        });
                      },
                      title: Text('Unit ${u.unitNo} (Fl ${u.floorNo})'),
                    ))
                .toList(),
          ),
        ),
        CheckboxListTile(
          value: _unitIds.isEmpty,
          onChanged: (v) => setState(() => _unitIds.clear()),
          title: const Text('All Units'),
        ),
      ],
    );
  }
}
