import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../../core/services/form_draft_service.dart';
import '../../../../core/widgets/form_draft_banner.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../data/project_repository.dart';
import '../../domain/structure_models.dart';

class TowerFormScreen extends StatefulWidget {
  const TowerFormScreen({
    super.key,
    required this.projectId,
    this.towerId,
  });

  final String projectId;
  final String? towerId;

  @override
  State<TowerFormScreen> createState() => _TowerFormScreenState();
}

class _TowerFormScreenState extends State<TowerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phase = TextEditingController();
  final _basements = TextEditingController(text: '0');
  final _floors = TextEditingController();
  final _flats = TextEditingController();
  final _sequence = TextEditingController(text: '0');
  final _remarks = TextEditingController();
  bool _hasGround = false;
  String? _statusCode = 'ACTIVE';
  bool _saving = false;
  bool _hydrated = false;
  FormDraftInfo? _draftInfo;

  bool get _isEdit => widget.towerId != null;

  @override
  void initState() {
    super.initState();
    _name.addListener(_autoSaveDraft);
    _phase.addListener(_autoSaveDraft);
    _basements.addListener(_autoSaveDraft);
    _floors.addListener(_autoSaveDraft);
    _flats.addListener(_autoSaveDraft);
    _sequence.addListener(_autoSaveDraft);
    _remarks.addListener(_autoSaveDraft);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isEdit) {
        _loadTower();
      } else {
        _restoreDraftIfAny();
      }
    });
  }

  void _autoSaveDraft() {
    if (_saving) return;
    final data = {
      'name': _name.text.trim(),
      'phase': _phase.text.trim(),
      'basements': _basements.text.trim(),
      'floors': _floors.text.trim(),
      'flats': _flats.text.trim(),
      'sequence': _sequence.text.trim(),
      'remarks': _remarks.text.trim(),
      'hasGround': _hasGround,
      'statusCode': _statusCode,
    };
    FormDraftService.instance.autoSave(
      formId: 'erp_tower_${widget.projectId}',
      entityId: widget.towerId,
      data: data,
    );
  }

  Future<void> _restoreDraftIfAny() async {
    if (_isEdit) return;
    final draft = await FormDraftService.instance.loadDraftInfo(
      'erp_tower_${widget.projectId}',
    );
    if (draft != null && mounted) {
      setState(() {
        _draftInfo = draft;
        final d = draft.data;
        if ((d['name'] as String?)?.isNotEmpty == true) _name.text = d['name'];
        if ((d['phase'] as String?)?.isNotEmpty == true) _phase.text = d['phase'];
        if ((d['basements'] as String?)?.isNotEmpty == true) _basements.text = d['basements'];
        if ((d['floors'] as String?)?.isNotEmpty == true) _floors.text = d['floors'];
        if ((d['flats'] as String?)?.isNotEmpty == true) _flats.text = d['flats'];
        if ((d['sequence'] as String?)?.isNotEmpty == true) _sequence.text = d['sequence'];
        if ((d['remarks'] as String?)?.isNotEmpty == true) _remarks.text = d['remarks'];
        if (d['hasGround'] != null) _hasGround = d['hasGround'] == true;
        if (d['statusCode'] != null) _statusCode = d['statusCode'];
      });
    }
  }

  void _discardDraft() {
    FormDraftService.instance.clearDraft(
      'erp_tower_${widget.projectId}',
      entityId: widget.towerId,
    );
    setState(() {
      _draftInfo = null;
      _name.clear();
      _phase.clear();
      _basements.text = '0';
      _floors.clear();
      _flats.clear();
      _sequence.text = '0';
      _remarks.clear();
      _hasGround = false;
    });
  }

  Future<void> _loadTower() async {
    try {
      final tower = await context
          .read<ProjectRepository>()
          .getTower(widget.projectId, widget.towerId!);
      if (mounted) {
        setState(() => _hydrate(tower));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phase.dispose();
    _basements.dispose();
    _floors.dispose();
    _flats.dispose();
    _sequence.dispose();
    _remarks.dispose();
    super.dispose();
  }

  void _hydrate(ErpProjectTower t) {
    if (_hydrated) return;
    _hydrated = true;
    _name.text = t.name;
    _phase.text = t.phase ?? '';
    _basements.text = '${t.basementCount}';
    _floors.text = '${t.floorCount}';
    _flats.text = '${t.flatsPerFloor}';
    _sequence.text = '${t.sequence}';
    _remarks.text = t.remarks ?? '';
    _hasGround = t.hasGround;
    _statusCode = t.statusCode ?? 'ACTIVE';
  }

  InputDecoration _dec(String label, {bool required = false, String? hint}) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }

  Widget _hasGroundField() {
    const tip =
        'On: ground floor has flats. Unit numbering starts at 0 (Ground, then 1, 2, …).\n'
        'Off: ground floor is parking. Flats start from floor 1.';
    return InputDecorator(
      decoration: _dec('Has ground floor flats?'),
      child: Row(
        children: [
          Expanded(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(_hasGround ? 'Flats on ground (floor 0)' : 'Parking on ground'),
              value: _hasGround,
              onChanged: (v) => setState(() => _hasGround = v),
            ),
          ),
          const Tooltip(
            message: tip,
            waitDuration: Duration(milliseconds: 200),
            child: Icon(Icons.info_outline, size: 20, color: Color(0xFF2563eb)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'name': _name.text.trim(),
      'phase': _phase.text.trim(),
      'basementCount': int.tryParse(_basements.text.trim()) ?? 0,
      'floorCount': int.tryParse(_floors.text.trim()),
      'flatsPerFloor': int.tryParse(_flats.text.trim()),
      'hasGround': _hasGround,
      'sequence': int.tryParse(_sequence.text.trim()) ?? 0,
      'statusCode': _statusCode,
      'remarks': _remarks.text.trim(),
    };
    try {
      final repo = context.read<ProjectRepository>();
      if (_isEdit) {
        await repo.updateTower(widget.projectId, widget.towerId!, body);
      } else {
        await repo.createTower(widget.projectId, body);
      }
      await FormDraftService.instance.clearDraft(
        'erp_tower_${widget.projectId}',
        entityId: widget.towerId,
      );
      if (!mounted) return;
      context.go('/erp/structure/${widget.projectId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final floors = int.tryParse(_floors.text.trim()) ?? 0;
    final flats = int.tryParse(_flats.text.trim()) ?? 0;
    final total = floors > 0 && flats > 0 ? floors * flats : 0;
    final floorRange = floors < 1
        ? ''
        : _hasGround
            ? 'floors 0–${floors - 1}'
            : 'floors 1–$floors';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        title: Text(_isEdit ? 'Edit Tower' : 'Add Tower'),
        leading: AppBackButton(fallbackLocation: '/erp/structure/${widget.projectId}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Save' : 'Add Tower'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            FormDraftBanner(
              formId: 'erp_tower_${widget.projectId}',
              entityId: widget.towerId,
              draftInfo: _draftInfo,
              onDiscard: _draftInfo != null ? _discardDraft : null,
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFFC5A059).withValues(alpha: 0.15)
                      : const Color(0xFFCFD8DC),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tower / Block details',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    total > 0
                        ? 'This will create $total units ($floors × $flats) on $floorRange. Duplex units (occupying 2 floors) and floor-wise units can be customized under Manage Tower.'
                        : 'Total units = number of floors × flats per floor. Duplex units and floor-wise customizations can be configured under Manage Tower.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 820
                          ? 3
                          : constraints.maxWidth >= 520
                              ? 2
                              : 1;
                      const gap = 12.0;
                      final w = (constraints.maxWidth - gap * (cols - 1)) / cols;
                      Widget cell(Widget child) => SizedBox(width: w, child: child);
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          cell(
                            TextFormField(
                              controller: _name,
                              decoration: _dec('Tower / Block Name', required: true),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          cell(
                            TextFormField(
                              controller: _phase,
                              decoration: _dec('Phase', hint: 'e.g. Phase 1'),
                            ),
                          ),
                          cell(
                            TextFormField(
                              controller: _basements,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _dec('Number of Basements', required: true),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          cell(
                            TextFormField(
                              controller: _floors,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _dec(
                                'Number of Floors',
                                required: true,
                                hint: _hasGround
                                    ? 'Includes ground as floor 0'
                                    : 'Residential floors above parking GF',
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n < 1) return 'Enter at least 1';
                                return null;
                              },
                            ),
                          ),
                          cell(
                            TextFormField(
                              controller: _flats,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _dec('Number of Flats in a floor', required: true),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n < 1) return 'Enter at least 1';
                                return null;
                              },
                            ),
                          ),
                          cell(
                            TextFormField(
                              controller: _sequence,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _dec('Sequence'),
                            ),
                          ),
                          cell(
                            lookupDropdown(
                              context: context,
                              category: 'PROJECT_TOWER_STATUS',
                              label: 'Status',
                              value: _statusCode,
                              required: true,
                              onChanged: (v) => setState(() => _statusCode = v),
                            ),
                          ),
                          cell(_hasGroundField()),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _remarks,
                    maxLines: 3,
                    decoration: _dec('Remarks'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
