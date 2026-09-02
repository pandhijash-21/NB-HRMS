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
    if (floorNos.length == 1) return floorLabelForNo(floorNos.first);
    return '${floorNos.length} Floors';
  }

  String unitLabel() {
    if (allUnits) return 'All Unit';
    if (unitIds.length == 1) return '1 Unit';
    return '${unitIds.length} Units';
  }
}

String floorLabelForNo(int floorNo) => floorLabel(floorNo);

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

  List<ErpProjectUnit> get _availableUnits {
    final units = <ErpProjectUnit>[];
    for (final t in _selectedTowers) {
      for (final u in t.units) {
        if (_floorNos.isEmpty || _floorNos.contains(u.floorNo)) {
          units.add(u);
        }
      }
    }
    units.sort((a, b) {
      final fc = a.floorNo.compareTo(b.floorNo);
      if (fc != 0) return fc;
      return a.unitNo.compareTo(b.unitNo);
    });
    return units;
  }

  Map<int, List<ErpProjectUnit>> get _unitsByFloor {
    final map = <int, List<ErpProjectUnit>>{};
    for (final u in _availableUnits) {
      map.putIfAbsent(u.floorNo, () => []).add(u);
    }
    return map;
  }

  void _selectAllFloors() {
    final floors = <int>{};
    for (final t in _selectedTowers) {
      floors.addAll(towerFloorNumbers(t));
    }
    setState(() {
      _floorNos = floors;
      _unitIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(['Select Block', 'Select Floor', 'Select Flat / Unit'][_step]),
      content: SizedBox(
        width: 460,
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
                floorNos: _floorNos.toList()..sort(),
                unitIds: _unitIds.toList(),
              ),
            ),
            child: const Text('Done'),
          ),
      ],
    );
  }

  Widget _buildTowerStep() {
    return SizedBox(
      height: 360,
      child: ListView(
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _towerIds = widget.towers.map((t) => t.id).toSet();
                  _floorNos.clear();
                  _unitIds.clear();
                }),
                child: const Text('Select All'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _towerIds.clear();
                  _floorNos.clear();
                  _unitIds.clear();
                }),
                child: const Text('Clear All'),
              ),
            ],
          ),
          CheckboxListTile(
            value: _towerIds.isEmpty,
            onChanged: (v) => setState(() {
              _towerIds.clear();
              _floorNos.clear();
              _unitIds.clear();
            }),
            title: const Text('All Blocks'),
            subtitle: const Text('Apply to every block in this project'),
          ),
          const Divider(),
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
                subtitle: Text(
                  '${towerFloorNumbers(t).length} floors · ${t.unitCount > 0 ? t.unitCount : t.units.length} flats',
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFloorStep() {
    final towers = _selectedTowers;
    if (towers.isEmpty) {
      return const Text('Select at least one block first.');
    }

    return SizedBox(
      height: 360,
      child: ListView(
        children: [
          Row(
            children: [
              TextButton(onPressed: _selectAllFloors, child: const Text('Select All')),
              TextButton(
                onPressed: () => setState(() {
                  _floorNos.clear();
                  _unitIds.clear();
                }),
                child: const Text('Clear All'),
              ),
            ],
          ),
          CheckboxListTile(
            value: _floorNos.isEmpty,
            onChanged: (v) => setState(() {
              _floorNos.clear();
              _unitIds.clear();
            }),
            title: const Text('All Floors'),
            subtitle: Text(
              towers.length == 1
                  ? 'Every floor in ${towers.first.name}'
                  : 'Every floor in selected blocks',
            ),
          ),
          const Divider(),
          for (final tower in towers) ...[
            if (towers.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  tower.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ...towerFloorNumbers(tower).map((f) => CheckboxListTile(
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
                  title: Text(floorLabel(f)),
                  subtitle: towers.length > 1 ? Text(tower.name) : null,
                  dense: towers.length > 1,
                )),
            if (towers.length > 1) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildUnitStep() {
    final units = _availableUnits;
    final byFloor = _unitsByFloor;
    final floorKeys = byFloor.keys.toList()..sort();

    if (units.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No flats found for the selected block/floor.'),
          const SizedBox(height: 8),
          Text(
            'Add flats in Project → Structure, or regenerate units for the block.',
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
          ),
        ],
      );
    }

    return SizedBox(
      height: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          CheckboxListTile(
            value: _unitIds.isEmpty,
            onChanged: (v) => setState(() => _unitIds.clear()),
            title: const Text('All Flats / Units'),
            subtitle: Text(
              _floorNos.isEmpty
                  ? 'Every flat on selected floor(s)'
                  : 'All flats on ${floorKeys.map(floorLabel).join(', ')}',
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                for (final floorNo in floorKeys) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                    child: Text(
                      floorLabel(floorNo),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  ...byFloor[floorNo]!.map((u) {
                    final tower = widget.towers.where((t) => t.id == u.towerId).firstOrNull;
                    return CheckboxListTile(
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
                      title: Text('Flat ${u.unitNo}'),
                      subtitle: tower != null && _selectedTowers.length > 1
                          ? Text('${tower.name} · ${floorLabel(u.floorNo)}')
                          : Text(floorLabel(u.floorNo)),
                      dense: true,
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
