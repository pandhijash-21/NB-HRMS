import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_back_button.dart';
import '../../../erp/domain/project_models.dart';
import '../../../erp/domain/structure_models.dart';
import '../../../erp/presentation/project_providers.dart';
import '../crm_providers.dart';
import '../widgets/crm_scope_selector.dart';

class CrmVirtualBuildingScreen extends ConsumerStatefulWidget {
  const CrmVirtualBuildingScreen({super.key});

  @override
  ConsumerState<CrmVirtualBuildingScreen> createState() =>
      _CrmVirtualBuildingScreenState();
}

class _CrmVirtualBuildingScreenState
    extends ConsumerState<CrmVirtualBuildingScreen> {
  bool _isLoadingProjects = true;
  bool _isLoadingBuilding = false;
  String? _errorMessage;

  List<ErpProject> _projects = [];
  ErpProject? _selectedProject;

  List<ErpProjectTower> _towers = [];
  ErpProjectTower? _selectedTower;

  Map<String, dynamic>? _buildingData;
  String _statusFilter = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(projectRepositoryProvider);
      final list = await repo.list();
      if (!mounted) return;

      setState(() {
        _projects = list;
        _isLoadingProjects = false;
      });

      if (list.isNotEmpty) {
        _onSelectProject(list.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProjects = false;
        _errorMessage = 'Failed to load projects: $e';
      });
    }
  }

  Future<void> _onSelectProject(ErpProject project) async {
    setState(() {
      _selectedProject = project;
      _towers = [];
      _selectedTower = null;
      _buildingData = null;
      _isLoadingBuilding = true;
    });

    try {
      final repo = ref.read(projectRepositoryProvider);
      final twrs = await repo.listTowers(project.id);
      if (!mounted) return;

      setState(() {
        _towers = twrs;
      });

      if (twrs.isNotEmpty) {
        _onSelectTower(twrs.first);
      } else {
        setState(() {
          _isLoadingBuilding = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBuilding = false;
        _errorMessage = 'Failed to load towers: $e';
      });
    }
  }

  Future<void> _onSelectTower(ErpProjectTower tower) async {
    setState(() {
      _selectedTower = tower;
      _isLoadingBuilding = true;
      _errorMessage = null;
    });

    await _fetchVirtualBuilding();
  }

  Future<void> _fetchVirtualBuilding() async {
    if (_selectedProject == null || _selectedTower == null) return;

    setState(() {
      _isLoadingBuilding = true;
      _errorMessage = null;
    });

    try {
      final crmRepo = ref.read(crmRepositoryProvider);
      final data = await crmRepo.getVirtualBuilding(
        projectId: _selectedProject!.id,
        towerId: _selectedTower!.id,
      );

      if (!mounted) return;
      setState(() {
        _buildingData = data;
        _isLoadingBuilding = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingBuilding = false;
        _errorMessage = 'Failed to fetch virtual building: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141210) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Virtual Building & Inventory Matrix'),
        leading: const AppBackButton(fallbackLocation: '/crm/dashboard'),
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          CrmScopeSelectorWidget(
            onScopeChanged: () => _fetchVirtualBuilding(),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh Building Elevation',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchVirtualBuilding,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(context, isDark, isWide),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark, bool isWide) {
    if (_isLoadingProjects) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFC5A059)),
        ),
      );
    }

    if (_projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.apartment_rounded, size: 54, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No ERP Projects Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('Please configure projects & towers in ERP first.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadProjects,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final summary = (_buildingData?['summary'] as Map<String, dynamic>?) ?? {};
    final floors = (_buildingData?['floors'] as List<dynamic>?) ?? [];

    return Column(
      children: [
        // Top Project & Tower Selection Bar
        _buildSelectionHeader(context, isDark, isWide),

        // KPI Summary Cards
        if (_buildingData != null) _buildKpiSummaryBar(summary, isDark, isWide),

        // Filter & Search Controls
        _buildFilterBar(isDark),

        // Main Elevation Grid Area
        Expanded(
          child: _isLoadingBuilding
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFC5A059)),
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(_errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _fetchVirtualBuilding,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try Again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : floors.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.domain_disabled_rounded,
                                  size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                _selectedTower == null
                                    ? 'Select a Tower to display virtual elevation'
                                    : 'No units configured for ${_selectedTower!.name}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      : _buildElevationGrid(floors, isDark),
        ),
      ],
    );
  }

  Widget _buildSelectionHeader(
      BuildContext context, bool isDark, bool isWide) {
    final cardBg = isDark ? const Color(0xFF1E1B18) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFFC5A059).withValues(alpha: 0.18)
        : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.apartment_rounded,
                    color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Building Elevation',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500)),
                  Text(
                    '${_selectedProject?.name ?? "--"} • ${_selectedTower?.name ?? "--"}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),

          // Dropdowns
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              // Project Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF26211A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ErpProject>(
                    value: _selectedProject,
                    hint: const Text('Select Project'),
                    items: _projects
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (p) {
                      if (p != null) _onSelectProject(p);
                    },
                  ),
                ),
              ),

              // Tower Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF26211A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ErpProjectTower>(
                    value: _selectedTower,
                    hint: const Text('Select Tower'),
                    items: _towers
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                  '${t.name} (${t.floorCount} Fl, ${t.flatsPerFloor} Flats)',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (t) {
                      if (t != null) _onSelectTower(t);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryBar(
      Map<String, dynamic> summary, bool isDark, bool isWide) {
    final totalUnits = summary['totalUnits'] ?? 0;
    final available = summary['availableCount'] ?? 0;
    final hold = summary['holdCount'] ?? 0;
    final booked = summary['bookedCount'] ?? 0;
    final duplex = summary['duplexCount'] ?? 0;
    final totalVisits = summary['totalVisits'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1816) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _kpiChip('Total Units', '$totalUnits', Icons.domain,
                const Color(0xFF64748B)),
            const SizedBox(width: 10),
            _kpiChip('Available', '$available', Icons.check_circle_outline,
                const Color(0xFF10B981)),
            const SizedBox(width: 10),
            _kpiChip('On Hold', '$hold', Icons.lock_clock_outlined,
                const Color(0xFFF59E0B)),
            const SizedBox(width: 10),
            _kpiChip('Booked / Sold', '$booked', Icons.verified_user_outlined,
                const Color(0xFFEF4444)),
            const SizedBox(width: 10),
            if (duplex > 0) ...[
              _kpiChip('Duplex Units', '$duplex', Icons.layers_outlined,
                  const Color(0xFF8B5CF6)),
              const SizedBox(width: 10),
            ],
            _kpiChip('Total Site Visits', '$totalVisits', Icons.groups_outlined,
                const Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }

  Widget _kpiChip(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B18) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Filter Chips
          Wrap(
            spacing: 6,
            children: [
              _filterChoiceChip('ALL', 'All Units'),
              _filterChoiceChip('AVAILABLE', 'Available',
                  activeColor: const Color(0xFF10B981)),
              _filterChoiceChip('HOLD', 'On Hold',
                  activeColor: const Color(0xFFF59E0B)),
              _filterChoiceChip('BOOKED', 'Booked',
                  activeColor: const Color(0xFFEF4444)),
              _filterChoiceChip('VISITED', 'With Visits',
                  activeColor: const Color(0xFF2563EB)),
            ],
          ),

          // Quick Search Box
          SizedBox(
            width: 220,
            height: 36,
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search Unit No...',
                prefixIcon:
                    const Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF26211A)
                    : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChoiceChip(String key, String label, {Color? activeColor}) {
    final selected = _statusFilter == key;
    final color = activeColor ?? const Color(0xFF2563EB);

    return InkWell(
      onTap: () => setState(() => _statusFilter = key),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? color : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? color : Colors.grey,
          ),
        ),
      ),
    );
  }

  List<_FloorTier> _computeFloorTiers(List<dynamic> rawFloors) {
    final tiers = <_FloorTier>[];
    final visitedIndices = <int>{};

    for (int i = 0; i < rawFloors.length; i++) {
      if (visitedIndices.contains(i)) continue;

      final currFloor = rawFloors[i] as Map<String, dynamic>;
      final currFloorNo = currFloor['floorNo'] as int? ?? 0;
      final currUnits = (currFloor['units'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];

      // Check if there is a next floor below this one (i + 1)
      if (i + 1 < rawFloors.length) {
        final nextFloor = rawFloors[i + 1] as Map<String, dynamic>;
        final nextFloorNo = nextFloor['floorNo'] as int? ?? 0;
        final nextUnits = (nextFloor['units'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];

        // Are currFloor and nextFloor consecutive? (currFloorNo == nextFloorNo + 1)
        if (currFloorNo == nextFloorNo + 1) {
          final pairs = <_DuplexPair>[];
          final matchedUpperIds = <String>{};
          final matchedBaseIds = <String>{};

          for (final uUnit in currUnits) {
            final uNo = (uUnit['unitNo'] ?? '').toString();
            final isDuplex = uUnit['isDuplex'] == true;
            if (!isDuplex) continue;

            final isUpper = uNo.endsWith('-2') ||
                (uUnit['remarks']?.toString().toLowerCase().contains('upper') ?? false);
            if (!isUpper) continue;

            final expectedBaseNo =
                uNo.endsWith('-2') ? uNo.substring(0, uNo.length - 2) : uNo;

            final bUnit = nextUnits.firstWhere(
              (b) =>
                  b['isDuplex'] == true &&
                  b['unitNo']?.toString().toUpperCase() == expectedBaseNo.toUpperCase(),
              orElse: () => <String, dynamic>{},
            );

            if (bUnit.isNotEmpty) {
              final uVisits = uUnit['visitorCount'] as int? ?? 0;
              final bVisits = bUnit['visitorCount'] as int? ?? 0;
              pairs.add(_DuplexPair(
                baseUnit: bUnit,
                upperUnit: uUnit,
                duplexNo: expectedBaseNo,
                unitType: bUnit['unitTypeCode']?.toString() ??
                    uUnit['unitTypeCode']?.toString() ??
                    'Duplex',
                visitorCount: (uVisits > bVisits ? uVisits : bVisits),
              ));
              matchedUpperIds.add(uUnit['id']?.toString() ?? '');
              matchedBaseIds.add(bUnit['id']?.toString() ?? '');
            }
          }

          if (pairs.isNotEmpty) {
            visitedIndices.add(i);
            visitedIndices.add(i + 1);

            final remainingUpper = currUnits
                .where((u) => !matchedUpperIds.contains(u['id']?.toString() ?? ''))
                .toList();
            final remainingLower = nextUnits
                .where((b) => !matchedBaseIds.contains(b['id']?.toString() ?? ''))
                .toList();

            tiers.add(_FloorTier(
              isDuplexTier: true,
              tierLabel: 'Floor $nextFloorNo & $currFloorNo',
              upperFloorNo: currFloorNo,
              lowerFloorNo: nextFloorNo,
              duplexPairs: pairs,
              singleUnits: [...remainingUpper, ...remainingLower],
            ));
            continue;
          }
        }
      }

      // Standard single-floor tier
      visitedIndices.add(i);
      final floorLabel =
          currFloor['floorLabel']?.toString() ?? 'Floor $currFloorNo';
      tiers.add(_FloorTier(
        isDuplexTier: false,
        tierLabel: floorLabel,
        singleUnits: currUnits,
      ));
    }

    return tiers;
  }

  Widget _buildElevationGrid(List<dynamic> floors, bool isDark) {
    final tiers = _computeFloorTiers(floors);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: tiers.length,
      itemBuilder: (context, index) {
        final tier = tiers[index];

        if (tier.isDuplexTier) {
          // Filter duplex pairs
          final filteredPairs = tier.duplexPairs.where((pair) {
            final dNo = pair.duplexNo.toLowerCase();
            final status = (pair.baseUnit['statusCode'] ?? 'AVAILABLE').toString();
            final visitCount = pair.visitorCount;

            if (_searchQuery.isNotEmpty && !dNo.contains(_searchQuery)) {
              return false;
            }

            if (_statusFilter == 'AVAILABLE' && status != 'AVAILABLE') return false;
            if (_statusFilter == 'HOLD' && status != 'HOLD') return false;
            if (_statusFilter == 'BOOKED' && status != 'BOOKED' && status != 'SOLD') {
              return false;
            }
            if (_statusFilter == 'VISITED' && visitCount == 0) return false;

            return true;
          }).toList();

          // Filter any remaining single units on these floors
          final filteredSingles = tier.singleUnits.where((u) {
            final uNo = (u['unitNo'] ?? '').toString().toLowerCase();
            final status = (u['statusCode'] ?? 'AVAILABLE').toString();
            final visitCount = u['visitorCount'] as int? ?? 0;

            if (_searchQuery.isNotEmpty && !uNo.contains(_searchQuery)) {
              return false;
            }
            if (_statusFilter == 'AVAILABLE' && status != 'AVAILABLE') return false;
            if (_statusFilter == 'HOLD' && status != 'HOLD') return false;
            if (_statusFilter == 'BOOKED' && status != 'BOOKED' && status != 'SOLD') {
              return false;
            }
            if (_statusFilter == 'VISITED' && visitCount == 0) return false;
            return true;
          }).toList();

          if (filteredPairs.isEmpty &&
              filteredSingles.isEmpty &&
              (_statusFilter != 'ALL' || _searchQuery.isNotEmpty)) {
            return const SizedBox.shrink();
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B18) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.35 : 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.15 : 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Combined Duplex Tier Floor Badge
                Container(
                  width: 96,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF26211A) : const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Floor ${tier.upperFloorNo}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stairs_rounded, size: 12, color: Color(0xFF8B5CF6)),
                            SizedBox(width: 3),
                            Text(
                              'DUPLEX',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF8B5CF6),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Floor ${tier.lowerFloorNo}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${filteredPairs.length} Duplexes',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF8B5CF6),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Unified Duplex Cards Row
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ...filteredPairs.map((pair) =>
                          _buildUnifiedDuplexCard(context, pair, isDark)),
                      ...filteredSingles.map((u) =>
                          _buildUnitBlock(context, u, isDark)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Standard single-floor tier
        final filteredUnits = tier.singleUnits.where((u) {
          final uNo = (u['unitNo'] ?? '').toString().toLowerCase();
          final status = (u['statusCode'] ?? 'AVAILABLE').toString();
          final visitCount = u['visitorCount'] as int? ?? 0;

          if (_searchQuery.isNotEmpty && !uNo.contains(_searchQuery)) {
            return false;
          }

          if (_statusFilter == 'AVAILABLE' && status != 'AVAILABLE') return false;
          if (_statusFilter == 'HOLD' && status != 'HOLD') return false;
          if (_statusFilter == 'BOOKED' && status != 'BOOKED' && status != 'SOLD') {
            return false;
          }
          if (_statusFilter == 'VISITED' && visitCount == 0) return false;

          return true;
        }).toList();

        if (filteredUnits.isEmpty && (_statusFilter != 'ALL' || _searchQuery.isNotEmpty)) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B18) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFC5A059).withValues(alpha: 0.15)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Single Floor Badge Indicator
              Container(
                width: 96,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF26211A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tier.tierLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${filteredUnits.length} Flats',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Blocks Row
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: filteredUnits
                      .map((u) => _buildUnitBlock(context, u, isDark))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Unified 2-Storey Duplex Elevation Card (Combining Level 1 and Level 2)
  // ---------------------------------------------------------------------------
  Widget _buildUnifiedDuplexCard(
      BuildContext context, _DuplexPair pair, bool isDark) {
    final statusCode = pair.baseUnit['statusCode']?.toString() ?? 'AVAILABLE';
    final totalValueNum =
        num.tryParse(pair.baseUnit['totalValue']?.toString() ?? '0') ?? 0;
    final totalValueStr = NumberFormat('#,##,###').format(totalValueNum);

    // Status colors
    Color baseColor;
    String statusLabel;
    if (statusCode == 'HOLD') {
      baseColor = const Color(0xFFF59E0B);
      statusLabel = 'HOLD';
    } else if (statusCode == 'BOOKED' || statusCode == 'SOLD') {
      baseColor = const Color(0xFFEF4444);
      statusLabel = 'BOOKED';
    } else {
      baseColor = const Color(0xFF10B981);
      statusLabel = 'AVAILABLE';
    }

    final blockBg = isDark
        ? baseColor.withValues(alpha: 0.12)
        : baseColor.withValues(alpha: 0.08);
    final borderColor = baseColor.withValues(alpha: 0.45);

    return Tooltip(
      richMessage: _buildDuplexTooltipSpan(pair),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 150),
      showDuration: const Duration(seconds: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showUnitActionDialog(context, pair.baseUnit),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: blockBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: isDark ? 0.15 : 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: Duplex Unit Name + Badge + Status Dot
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pair.duplexNo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stairs_rounded,
                              size: 10, color: Color(0xFF8B5CF6)),
                          SizedBox(width: 2),
                          Text(
                            '2-STOREY',
                            style: TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: baseColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Subtitle: Duplex Type
                Text(
                  pair.unitType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),

                // Level 2 Box (Upper Deck)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF26211A).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'FL ${pair.upperUnit['floorNo']} • Upper Deck',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        pair.upperUnit['unitNo'] ?? '',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                ),

                // Interconnected Staircase Connector Bridge
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_vert_rounded,
                                size: 10, color: Color(0xFF8B5CF6)),
                            SizedBox(width: 3),
                            Text(
                              'Internal Stairs',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),

                // Level 1 Box (Main Living & Entry)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF26211A).withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'FL ${pair.baseUnit['floorNo']} • Main Entry',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${pair.baseUnit['carpetArea'] ?? "--"} sq.ft',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Bottom: Status, Price & Visitor Footfalls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: baseColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: baseColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    // Visitor Footfall Pill
                    if (pair.visitorCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.group,
                                size: 10, color: Color(0xFF2563EB)),
                            const SizedBox(width: 2),
                            Text(
                              '${pair.visitorCount}',
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Estimated Value
                if (totalValueNum > 0)
                  Text(
                    '₹ $totalValueStr',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFF34D399)
                          : const Color(0xFF059669),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Duplex Tooltip Rich Text Builder
  // ---------------------------------------------------------------------------
  InlineSpan _buildDuplexTooltipSpan(_DuplexPair pair) {
    final duplexNo = pair.duplexNo;
    final unitType = pair.unitType;
    final statusCode =
        pair.baseUnit['statusCode']?.toString() ?? 'AVAILABLE';
    final carpetArea = pair.baseUnit['carpetArea']?.toString() ?? '--';
    final superBuiltUp = pair.baseUnit['superBuiltUp']?.toString() ?? '--';
    final totalValueNum =
        num.tryParse(pair.baseUnit['totalValue']?.toString() ?? '0') ?? 0;
    final totalValueStr = NumberFormat('#,##,###').format(totalValueNum);

    final visitors = (pair.baseUnit['visitors'] as List<dynamic>?) ??
        (pair.upperUnit['visitors'] as List<dynamic>?) ??
        [];
    final heldBy = pair.baseUnit['heldBy'] as Map<String, dynamic>? ??
        pair.upperUnit['heldBy'] as Map<String, dynamic>?;
    final bookedBy = pair.baseUnit['bookedBy'] as Map<String, dynamic>? ??
        pair.upperUnit['bookedBy'] as Map<String, dynamic>?;

    final children = <InlineSpan>[
      // Header: Unit & Duplex Badge
      TextSpan(
        text: 'Unit $duplexNo  •  $unitType (2-Storey Duplex)\n',
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
      ),
      TextSpan(
        text: 'STATUS: $statusCode  •  2 LEVELS CONNECTED\n',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: statusCode == 'HOLD'
              ? const Color(0xFFFBBF24)
              : (statusCode == 'BOOKED' || statusCode == 'SOLD'
                  ? const Color(0xFFF87171)
                  : const Color(0xFF34D399)),
        ),
      ),
      const TextSpan(
        text: '──────────────────────────────\n',
        style: TextStyle(color: Colors.white24, fontSize: 10),
      ),

      // Duplex Floor Span
      TextSpan(
        text: 'Floor Span: Floor ${pair.baseUnit['floorNo']} (Level 1: ${pair.baseUnit['unitNo']}) + Floor ${pair.upperUnit['floorNo']} (Level 2: ${pair.upperUnit['unitNo']})\n'
            'Carpet: $carpetArea sq.ft  |  Super Built-up: $superBuiltUp sq.ft\n'
            'Total Value: ₹ $totalValueStr\n',
        style: const TextStyle(
            fontSize: 11, color: Color(0xFFCBD5E1), height: 1.4),
      ),

      const TextSpan(
        text: '──────────────────────────────\n',
        style: TextStyle(color: Colors.white24, fontSize: 10),
      ),
    ];

    // Hold Details
    if (statusCode == 'HOLD' && heldBy != null) {
      children.add(
        TextSpan(
          text: '🔒 ON HOLD DETAILS:\n'
              'Held For: ${heldBy['name']} ${heldBy['phone'] != null && heldBy['phone'].isNotEmpty ? "(${heldBy['phone']})" : ""}\n'
              '${heldBy['expiryAt'] != null ? "Expiry: ${heldBy['expiryAt']}\n" : ""}'
              '${heldBy['notes'] != null ? "Notes: ${heldBy['notes']}\n" : ""}',
          style: const TextStyle(
              fontSize: 11, color: Color(0xFFFCD34D), height: 1.3),
        ),
      );
      children.add(const TextSpan(
        text: '──────────────────────────────\n',
        style: TextStyle(color: Colors.white24, fontSize: 10),
      ));
    }

    // Booking Details
    if ((statusCode == 'BOOKED' || statusCode == 'SOLD') && bookedBy != null) {
      children.add(
        TextSpan(
          text: '🎉 BOOKING / OWNER DETAILS:\n'
              'Owner: ${bookedBy['name']} ${bookedBy['phone'] != null && bookedBy['phone'].isNotEmpty ? "(${bookedBy['phone']})" : ""}\n'
              '${bookedBy['bookedAt'] != null ? "Booked On: ${bookedBy['bookedAt'].toString().split('T').first}\n" : ""}',
          style: const TextStyle(
              fontSize: 11, color: Color(0xFFFCA5A5), height: 1.3),
        ),
      );
      children.add(const TextSpan(
        text: '──────────────────────────────\n',
        style: TextStyle(color: Colors.white24, fontSize: 10),
      ));
    }

    // Footfall & Visitor List
    if (visitors.isNotEmpty) {
      children.add(
        TextSpan(
          text: '👥 PROSPECT VISITS (${visitors.length} Persons Visited):\n',
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Color(0xFF93C5FD)),
        ),
      );

      for (int i = 0; i < visitors.length && i < 5; i++) {
        final v = visitors[i] as Map<String, dynamic>;
        final vName = v['leadName'] ?? 'Prospect';
        final vPhone = v['leadPhone'] ?? '';
        final vAgent = v['salesAgent'] ?? '';
        children.add(
          TextSpan(
            text: '• $vName ($vPhone)  [Shown by: $vAgent]\n',
            style: const TextStyle(
                fontSize: 10, color: Color(0xFFE2E8F0), height: 1.3),
          ),
        );
      }

      if (visitors.length > 5) {
        children.add(
          TextSpan(
            text: '+ ${visitors.length - 5} more prospects inspected this unit\n',
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
        );
      }
    } else {
      children.add(
        const TextSpan(
          text: '👥 No client visits recorded yet.\n',
          style: TextStyle(fontSize: 11, color: Colors.white60),
        ),
      );
    }

    children.add(
      const TextSpan(
        text: '\n💡 Click duplex card to manage hold, booking or view visitors',
        style: TextStyle(
            fontSize: 10,
            fontStyle: FontStyle.italic,
            color: Color(0xFF94A3B8)),
      ),
    );

    return TextSpan(children: children);
  }

  Widget _buildUnitBlock(
      BuildContext context, Map<String, dynamic> unit, bool isDark) {
    final unitNo = unit['unitNo']?.toString() ?? '--';
    final unitTypeCode = unit['unitTypeCode']?.toString() ?? 'Flat';
    final statusCode = unit['statusCode']?.toString() ?? 'AVAILABLE';
    final isDuplex = unit['isDuplex'] == true;
    final visitorCount = unit['visitorCount'] as int? ?? 0;

    // Status colors
    Color baseColor;
    String statusLabel;
    if (statusCode == 'HOLD') {
      baseColor = const Color(0xFFF59E0B);
      statusLabel = 'HOLD';
    } else if (statusCode == 'BOOKED' || statusCode == 'SOLD') {
      baseColor = const Color(0xFFEF4444);
      statusLabel = 'BOOKED';
    } else {
      baseColor = const Color(0xFF10B981);
      statusLabel = 'AVAILABLE';
    }

    final blockBg = isDark
        ? baseColor.withValues(alpha: 0.12)
        : baseColor.withValues(alpha: 0.08);
    final borderColor = baseColor.withValues(alpha: 0.4);

    return Tooltip(
      richMessage: _buildHoverTooltipSpan(unit),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 150),
      showDuration: const Duration(seconds: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showUnitActionDialog(context, unit),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 145,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: blockBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top: Unit Number & Status Dot
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        unitNo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: baseColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Subtitle: Unit Type
                Text(
                  unitTypeCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),

                // Bottom Badges: Status & Visitors
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: baseColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: baseColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    // Visitor Count Pill
                    if (visitorCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.group,
                                size: 10, color: Color(0xFF2563EB)),
                            const SizedBox(width: 2),
                            Text(
                              '$visitorCount',
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                if (isDuplex)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'DUPLEX',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hover Tooltip Rich Text Builder
  // ---------------------------------------------------------------------------
  InlineSpan _buildHoverTooltipSpan(Map<String, dynamic> unit) {
    final unitNo = unit['unitNo']?.toString() ?? '--';
    final unitTypeCode = unit['unitTypeCode']?.toString() ?? 'Flat';
    final statusCode = unit['statusCode']?.toString() ?? 'AVAILABLE';
    final floorNo = unit['floorNo']?.toString() ?? '--';
    final carpetArea = unit['carpetArea']?.toString() ?? '--';
    final superBuiltUp = unit['superBuiltUp']?.toString() ?? '--';
    final totalValueNum = num.tryParse(unit['totalValue']?.toString() ?? '0') ?? 0;
    final totalValueStr = NumberFormat('#,##,###').format(totalValueNum);

    final visitors = (unit['visitors'] as List<dynamic>?) ?? [];
    final heldBy = unit['heldBy'] as Map<String, dynamic>?;
    final bookedBy = unit['bookedBy'] as Map<String, dynamic>?;

    final children = <InlineSpan>[
      // Header: Unit & Status
      TextSpan(
        text: 'Unit $unitNo  •  $unitTypeCode\n',
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
      ),
      TextSpan(
        text: 'STATUS: $statusCode\n',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: statusCode == 'HOLD'
              ? const Color(0xFFFBBF24)
              : (statusCode == 'BOOKED' || statusCode == 'SOLD'
                  ? const Color(0xFFF87171)
                  : const Color(0xFF34D399)),
        ),
      ),
      const TextSpan(
        text: '──────────────────────────────\n',
        style: TextStyle(color: Colors.white24, fontSize: 10),
      ),

      // Specifications
      TextSpan(
        text: 'Floor: Floor $floorNo\n'
            'Carpet: $carpetArea sq.ft  |  Super Built-up: $superBuiltUp sq.ft\n'
            'Estimated Value: ₹ $totalValueStr\n',
        style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), height: 1.4),
      ),

      const TextSpan(
        text: '──────────────────────────────\n',
        style: TextStyle(color: Colors.white24, fontSize: 10),
      ),
    ];

    // Hold Details
    if (statusCode == 'HOLD' && heldBy != null) {
      children.add(
        TextSpan(
          text: '🔒 ON HOLD DETAILS:\n'
              'Held For: ${heldBy['name']} ${heldBy['phone'] != null && heldBy['phone'].isNotEmpty ? "(${heldBy['phone']})" : ""}\n'
              '${heldBy['expiryAt'] != null ? "Expiry: ${heldBy['expiryAt']}\n" : ""}'
              '${heldBy['notes'] != null ? "Notes: ${heldBy['notes']}\n" : ""}',
          style: const TextStyle(
              fontSize: 11, color: Color(0xFFFCD34D), height: 1.3),
        ),
      );
      children.add(const TextSpan(
        text: '──────────────────────────────\n',
        style: TextStyle(color: Colors.white24, fontSize: 10),
      ));
    }

    // Booking Details
    if ((statusCode == 'BOOKED' || statusCode == 'SOLD') && bookedBy != null) {
      children.add(
        TextSpan(
          text: '🎉 BOOKING / OWNER DETAILS:\n'
              'Owner: ${bookedBy['name']} ${bookedBy['phone'] != null && bookedBy['phone'].isNotEmpty ? "(${bookedBy['phone']})" : ""}\n'
              '${bookedBy['bookedAt'] != null ? "Booked On: ${bookedBy['bookedAt'].toString().split('T').first}\n" : ""}',
          style: const TextStyle(
              fontSize: 11, color: Color(0xFFFCA5A5), height: 1.3),
        ),
      );
      children.add(const TextSpan(
        text: '──────────────────────────────\n',
        style: TextStyle(color: Colors.white24, fontSize: 10),
      ));
    }

    // Footfall & Visitor List
    if (visitors.isNotEmpty) {
      children.add(
        TextSpan(
          text: '👥 PROSPECT VISITS (${visitors.length} Persons Visited):\n',
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Color(0xFF93C5FD)),
        ),
      );

      for (int i = 0; i < visitors.length && i < 5; i++) {
        final v = visitors[i] as Map<String, dynamic>;
        final vName = v['leadName'] ?? 'Prospect';
        final vPhone = v['leadPhone'] ?? '';
        final vAgent = v['salesAgent'] ?? '';
        children.add(
          TextSpan(
            text: '• $vName ($vPhone)  [Shown by: $vAgent]\n',
            style: const TextStyle(
                fontSize: 10, color: Color(0xFFE2E8F0), height: 1.3),
          ),
        );
      }

      if (visitors.length > 5) {
        children.add(
          TextSpan(
            text: '+ ${visitors.length - 5} more prospects inspected this unit\n',
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
        );
      }
    } else {
      children.add(
        const TextSpan(
          text: '👥 No client visits recorded yet.\n',
          style: TextStyle(fontSize: 11, color: Colors.white60),
        ),
      );
    }

    children.add(
      const TextSpan(
        text: '\n💡 Click unit block to manage hold, booking or view visitors',
        style: TextStyle(
            fontSize: 10,
            fontStyle: FontStyle.italic,
            color: Color(0xFF94A3B8)),
      ),
    );

    return TextSpan(children: children);
  }

  // ---------------------------------------------------------------------------
  // Action Modal on Unit Click
  // ---------------------------------------------------------------------------
  void _showUnitActionDialog(BuildContext context, Map<String, dynamic> unit) {
    final unitNo = unit['unitNo']?.toString() ?? '--';
    final unitId = unit['id']?.toString() ?? '';
    final statusCode = unit['statusCode']?.toString() ?? 'AVAILABLE';
    final visitors = (unit['visitors'] as List<dynamic>?) ?? [];
    final heldBy = unit['heldBy'] as Map<String, dynamic>?;
    final bookedBy = unit['bookedBy'] as Map<String, dynamic>?;

    final nameCtrl = TextEditingController(
      text: statusCode == 'HOLD'
          ? (heldBy?['name']?.toString() ?? '')
          : (bookedBy?['name']?.toString() ?? ''),
    );
    final phoneCtrl = TextEditingController(
      text: statusCode == 'HOLD'
          ? (heldBy?['phone']?.toString() ?? '')
          : (bookedBy?['phone']?.toString() ?? ''),
    );
    final expiryCtrl = TextEditingController(
      text: heldBy?['expiryAt']?.toString() ??
          DateFormat('yyyy-MM-dd').format(
            DateTime.now().add(const Duration(days: 3)),
          ),
    );
    final remarksCtrl = TextEditingController(
      text: unit['remarks']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.apartment_rounded, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Unit $unitNo Details & Actions',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                width: double.maxFinite,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Specifications Snapshot
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Type: ${unit['unitTypeCode'] ?? "Flat"}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Floor: ${unit['floorNo']}',
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Carpet: ${unit['carpetArea'] ?? "--"} sq.ft',
                                  style: const TextStyle(fontSize: 12)),
                              Text(
                                'Value: ₹ ${NumberFormat("#,##,###").format(num.tryParse(unit["totalValue"]?.toString() ?? "0") ?? 0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Visitors list
                    Text(
                      '👥 Prospect Footfalls & Visits (${visitors.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    if (visitors.isEmpty)
                      const Text(
                        'No leads have been recorded as having visited this flat yet.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 140),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: visitors.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (c, i) {
                            final v = visitors[i] as Map<String, dynamic>;
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                '${v["leadName"] ?? "Prospect"} (${v["leadPhone"] ?? "--"})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              subtitle: Text(
                                'Shown by ${v["salesAgent"] ?? "Agent"}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 10),

                    const Text('Change Unit Status / Hold / Booking',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),

                    // Name of prospect / owner
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Prospect or Buyer Name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Phone
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Hold Expiry Date (if on hold)
                    TextField(
                      controller: expiryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Hold Expiry Date (YYYY-MM-DD)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Remarks
                    TextField(
                      controller: remarksCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Remarks & Notes',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              // Button 1: Mark Available
              if (statusCode != 'AVAILABLE')
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981)),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    await _executeUnitAction(unitId, 'AVAILABLE', {});
                  },
                  child: const Text('Mark Available'),
                ),

              // Button 2: Put on Hold
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B)),
                icon: const Icon(Icons.lock_clock, size: 16),
                label: const Text('Put On Hold'),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter name of prospect holding unit')),
                    );
                    return;
                  }
                  Navigator.pop(dialogCtx);
                  await _executeUnitAction(unitId, 'HOLD', {
                    'heldByName': nameCtrl.text.trim(),
                    'heldByPhone': phoneCtrl.text.trim(),
                    'holdExpiryDate': expiryCtrl.text.trim(),
                    'remarks': remarksCtrl.text.trim(),
                  });
                },
              ),

              // Button 3: Book / Sell
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444)),
                icon: const Icon(Icons.verified, size: 16),
                label: const Text('Confirm Booking'),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter buyer / owner name')),
                    );
                    return;
                  }
                  Navigator.pop(dialogCtx);
                  await _executeUnitAction(unitId, 'BOOKED', {
                    'ownerName': nameCtrl.text.trim(),
                    'ownerPhone': phoneCtrl.text.trim(),
                    'remarks': remarksCtrl.text.trim(),
                  });
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeUnitAction(
      String unitId, String newStatus, Map<String, dynamic> extra) async {
    try {
      final crmRepo = ref.read(crmRepositoryProvider);
      await crmRepo.updateVirtualBuildingUnit({
        'unitId': unitId,
        'statusCode': newStatus,
        ...extra,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unit status updated to $newStatus'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );

      // Refresh elevation data
      await _fetchVirtualBuilding();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update unit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _DuplexPair {
  final Map<String, dynamic> baseUnit;
  final Map<String, dynamic> upperUnit;
  final String duplexNo;
  final String unitType;
  final int visitorCount;

  _DuplexPair({
    required this.baseUnit,
    required this.upperUnit,
    required this.duplexNo,
    required this.unitType,
    required this.visitorCount,
  });
}

class _FloorTier {
  final bool isDuplexTier;
  final String tierLabel;
  final int? upperFloorNo;
  final int? lowerFloorNo;
  final List<_DuplexPair> duplexPairs;
  final List<Map<String, dynamic>> singleUnits;

  _FloorTier({
    required this.isDuplexTier,
    required this.tierLabel,
    this.upperFloorNo,
    this.lowerFloorNo,
    this.duplexPairs = const [],
    this.singleUnits = const [],
  });
}

