import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/boq_repository.dart';
import '../../domain/resource_models.dart';

/// Inward/outward (stock & consumption) history for a material — same UX as Store.
void showMaterialStockLogsSheet(BuildContext context, ErpMaterial material) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => MaterialStockLogsSheet(material: material),
  );
}

class MaterialStockLogsSheet extends StatefulWidget {
  const MaterialStockLogsSheet({super.key, required this.material});

  final ErpMaterial material;

  @override
  State<MaterialStockLogsSheet> createState() => _MaterialStockLogsSheetState();
}

class _MaterialStockLogsSheetState extends State<MaterialStockLogsSheet> {
  bool _showConsumptionOnly = false;
  late Future<List<ErpMaterialStockLog>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = context.read<BoqRepository>().getMaterialLogs(widget.material.id);
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d-$m-$y $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.material.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.material.brand != null && widget.material.brand!.isNotEmpty)
                      Text(
                        'Brand: ${widget.material.brand}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Avail: ${widget.material.qtyAvailable} ${widget.material.unitCode ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D9488),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Stock & Consumption Logs',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              FilterChip(
                label: const Text('Contractors Only', style: TextStyle(fontSize: 12)),
                selected: _showConsumptionOnly,
                onSelected: (v) => setState(() => _showConsumptionOnly = v),
                selectedColor: const Color(0xFFEA580C).withValues(alpha: 0.2),
                checkmarkColor: const Color(0xFFEA580C),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<ErpMaterialStockLog>>(
              future: _logsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Failed to load logs: ${snapshot.error}'));
                }
                final logs = snapshot.data ?? [];
                final filtered = _showConsumptionOnly
                    ? logs.where((l) => l.logType == 'CONSUMPTION').toList()
                    : logs;

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _showConsumptionOnly
                            ? 'No consumption logs recorded by contractors yet.'
                            : 'No logs recorded for this material.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final log = filtered[i];
                    final isConsumption = log.logType == 'CONSUMPTION';
                    final isPurchase = log.logType == 'PURCHASE';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: isConsumption
                            ? const Color(0xFFEA580C).withValues(alpha: 0.12)
                            : isPurchase
                                ? const Color(0xFF0D9488).withValues(alpha: 0.12)
                                : Colors.blue.withValues(alpha: 0.12),
                        child: Icon(
                          isConsumption
                              ? Icons.output_rounded
                              : isPurchase
                                  ? Icons.add_shopping_cart_rounded
                                  : Icons.info_outline,
                          size: 18,
                          color: isConsumption
                              ? const Color(0xFFEA580C)
                              : isPurchase
                                  ? const Color(0xFF0D9488)
                                  : Colors.blue,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            isConsumption ? 'Consumed by: ' : 'Log: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              isConsumption
                                  ? (log.contractorName ?? 'Contractor')
                                  : log.logType,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isConsumption ? const Color(0xFFEA580C) : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (log.remarks != null && log.remarks!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Remarks: ${log.remarks}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(log.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        '${isConsumption ? '-' : '+'}${log.quantity} ${widget.material.unitCode ?? ''}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isConsumption
                              ? const Color(0xFFEA580C)
                              : const Color(0xFF0D9488),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
