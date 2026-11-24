import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../data/work_order_repository.dart';
import '../../domain/contractor_lookup_keys.dart';
import '../../domain/work_order_models.dart';

/// Quick-add Vendor dialog (same core fields as Configurations → Vendors).
Future<ErpContractor?> showQuickCreateVendorDialog(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final mobileCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final altMobileCtrl = TextEditingController();
  final bankCtrl = TextEditingController();
  final branchCtrl = TextEditingController();
  final ifscCtrl = TextEditingController();
  final accountCtrl = TextEditingController();
  final paymentCtrl = TextEditingController();
  String? tdsCode;
  String? contractorTypeCode;
  var saving = false;
  String? error;

  final result = await showDialog<ErpContractor>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          InputDecoration dec(String label, {bool required = false}) {
            return InputDecoration(
              labelText: required ? '$label *' : label,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            );
          }

          return AlertDialog(
            title: const Text('Add vendor'),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Creates a vendor in Configurations → Vendors so you can keep working on this form.',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: dec('Vendor name', required: true),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: mobileCtrl,
                        decoration: dec('Mobile', required: true),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) =>
                            (v == null || v.trim().length < 10) ? 'Valid mobile required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: emailCtrl,
                        decoration: dec('Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: altMobileCtrl,
                        decoration: dec('Alternate mobile'),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                      const SizedBox(height: 10),
                      lookupDropdown(
                        context: ctx,
                        category: kContractorType,
                        label: 'Vendor type',
                        value: contractorTypeCode,
                        onChanged: (v) => setLocal(() => contractorTypeCode = v),
                      ),
                      const SizedBox(height: 10),
                      lookupDropdown(
                        context: ctx,
                        category: kContractorTds,
                        label: 'TDS',
                        value: tdsCode,
                        onChanged: (v) => setLocal(() => tdsCode = v),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: bankCtrl,
                        decoration: dec('Bank name'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: branchCtrl,
                        decoration: dec('Branch'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: ifscCtrl,
                        decoration: dec('IFSC'),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: accountCtrl,
                        decoration: dec('Account no'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: paymentCtrl,
                        decoration: dec('Payment terms'),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        setLocal(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final created =
                              await ctx.read<WorkOrderRepository>().createContractor({
                            'name': nameCtrl.text.trim(),
                            'mobileNo': mobileCtrl.text.trim(),
                            'email': emailCtrl.text.trim().isEmpty
                                ? null
                                : emailCtrl.text.trim(),
                            'alternateMobileNo': altMobileCtrl.text.trim().isEmpty
                                ? null
                                : altMobileCtrl.text.trim(),
                            'tdsCode': tdsCode,
                            'contractorTypeCode': contractorTypeCode,
                            'bankName':
                                bankCtrl.text.trim().isEmpty ? null : bankCtrl.text.trim(),
                            'branchName': branchCtrl.text.trim().isEmpty
                                ? null
                                : branchCtrl.text.trim(),
                            'ifscCode':
                                ifscCtrl.text.trim().isEmpty ? null : ifscCtrl.text.trim(),
                            'accountNo': accountCtrl.text.trim().isEmpty
                                ? null
                                : accountCtrl.text.trim(),
                            'paymentTerms': paymentCtrl.text.trim().isEmpty
                                ? null
                                : paymentCtrl.text.trim(),
                            'isActive': true,
                            'contacts': [
                              {
                                'name': nameCtrl.text.trim(),
                                'mobileNo': mobileCtrl.text.trim(),
                                'email': emailCtrl.text.trim().isEmpty
                                    ? null
                                    : emailCtrl.text.trim(),
                              },
                            ],
                          });
                          if (ctx.mounted) Navigator.pop(ctx, created);
                        } catch (e) {
                          setLocal(() {
                            saving = false;
                            error = e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add vendor'),
              ),
            ],
          );
        },
      );
    },
  );

  for (final c in [
    nameCtrl,
    mobileCtrl,
    emailCtrl,
    altMobileCtrl,
    bankCtrl,
    branchCtrl,
    ifscCtrl,
    accountCtrl,
    paymentCtrl,
  ]) {
    c.dispose();
  }
  return result;
}

/// Vendor dropdown with inline (+) quick-create.
class VendorDropdownWithCreate extends StatelessWidget {
  const VendorDropdownWithCreate({
    super.key,
    required this.value,
    required this.vendors,
    required this.onChanged,
    required this.onVendorCreated,
    this.decoration,
    this.required = false,
    this.enabled = true,
    this.includeNullOption = false,
    this.nullLabel = 'Select vendor',
    this.hint,
  });

  final String? value;
  final List<ErpContractor> vendors;
  final ValueChanged<String?> onChanged;
  final ValueChanged<ErpContractor> onVendorCreated;
  final InputDecoration? decoration;
  final bool required;
  final bool enabled;
  final bool includeNullOption;
  final String nullLabel;
  final Widget? hint;

  @override
  Widget build(BuildContext context) {
    final active = vendors.where((c) => c.isActive).toList();
    final items = <DropdownMenuItem<String?>>[
      if (includeNullOption)
        DropdownMenuItem<String?>(value: null, child: Text(nullLabel)),
      for (final c in active)
        DropdownMenuItem<String?>(
          value: c.id,
          child: Text(c.name, overflow: TextOverflow.ellipsis),
        ),
    ];
    // Keep selected value visible even if inactive
    if (value != null && !active.any((c) => c.id == value)) {
      final match = vendors.where((c) => c.id == value).firstOrNull;
      if (match != null) {
        items.insert(
          includeNullOption ? 1 : 0,
          DropdownMenuItem<String?>(value: match.id, child: Text(match.name)),
        );
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String?>(
            key: ValueKey('vendor-dd-$value-${vendors.length}'),
            isExpanded: true,
            initialValue: value,
            hint: hint,
            decoration: decoration ??
                InputDecoration(
                  labelText: required ? 'Vendor *' : 'Vendor',
                  hintText: 'Select vendor',
                  border: const OutlineInputBorder(),
                ),
            items: items,
            onChanged: enabled ? onChanged : null,
            validator: required
                ? (v) => (v == null || v.isEmpty) ? 'Vendor is required' : null
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 6),
          child: IconButton(
            tooltip: 'Add new vendor',
            onPressed: !enabled
                ? null
                : () async {
                    final created = await showQuickCreateVendorDialog(context);
                    if (created == null) return;
                    onVendorCreated(created);
                  },
            icon: const Icon(Icons.add_circle_outline),
          ),
        ),
      ],
    );
  }
}
