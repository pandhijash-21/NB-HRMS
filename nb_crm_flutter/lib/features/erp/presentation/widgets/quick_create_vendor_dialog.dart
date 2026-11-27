import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/realtime/app_event_bus.dart';
import '../../../../core/services/form_draft_service.dart';
import '../../../../core/widgets/form_draft_banner.dart';
import '../../../lookups/presentation/lookup_dropdown.dart';
import '../../data/work_order_repository.dart';
import '../../domain/contractor_lookup_keys.dart';
import '../../domain/work_order_models.dart';

/// Quick-add Vendor dialog (same core fields as Configurations → Vendors).
Future<ErpContractor?> showQuickCreateVendorDialog(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final contactPersonCtrl = TextEditingController();
  final mobileCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final altMobileCtrl = TextEditingController();
  final panCtrl = TextEditingController();
  final gstCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final stateCtrl = TextEditingController();
  final pincodeCtrl = TextEditingController();
  final bankCtrl = TextEditingController();
  final branchCtrl = TextEditingController();
  final ifscCtrl = TextEditingController();
  final accountCtrl = TextEditingController();
  final paymentCtrl = TextEditingController();
  String? tdsCode;
  String? contractorTypeCode;
  var saving = false;
  String? error;

  const draftKey = 'erp_quick_create_vendor';
  final draft = await FormDraftService.instance.loadDraftInfo(draftKey);
  DateTime? draftTime;
  if (draft != null) {
    draftTime = draft.savedAt;
    final d = draft.data;
    if (d['name'] != null) nameCtrl.text = d['name'].toString();
    if (d['contactPerson'] != null) contactPersonCtrl.text = d['contactPerson'].toString();
    if (d['mobile'] != null) mobileCtrl.text = d['mobile'].toString();
    if (d['email'] != null) emailCtrl.text = d['email'].toString();
    if (d['altMobile'] != null) altMobileCtrl.text = d['altMobile'].toString();
    if (d['pan'] != null) panCtrl.text = d['pan'].toString();
    if (d['gst'] != null) gstCtrl.text = d['gst'].toString();
    if (d['address'] != null) addressCtrl.text = d['address'].toString();
    if (d['city'] != null) cityCtrl.text = d['city'].toString();
    if (d['state'] != null) stateCtrl.text = d['state'].toString();
    if (d['pincode'] != null) pincodeCtrl.text = d['pincode'].toString();
    if (d['bank'] != null) bankCtrl.text = d['bank'].toString();
    if (d['branch'] != null) branchCtrl.text = d['branch'].toString();
    if (d['ifsc'] != null) ifscCtrl.text = d['ifsc'].toString();
    if (d['account'] != null) accountCtrl.text = d['account'].toString();
    if (d['payment'] != null) paymentCtrl.text = d['payment'].toString();
    if (d['tdsCode'] != null) tdsCode = d['tdsCode'].toString();
    if (d['contractorTypeCode'] != null) contractorTypeCode = d['contractorTypeCode'].toString();
  }

  void autoSave({bool immediate = false}) {
    FormDraftService.instance.autoSave(
      formId: draftKey,
      data: {
        'name': nameCtrl.text,
        'contactPerson': contactPersonCtrl.text,
        'mobile': mobileCtrl.text,
        'email': emailCtrl.text,
        'altMobile': altMobileCtrl.text,
        'pan': panCtrl.text,
        'gst': gstCtrl.text,
        'address': addressCtrl.text,
        'city': cityCtrl.text,
        'state': stateCtrl.text,
        'pincode': pincodeCtrl.text,
        'bank': bankCtrl.text,
        'branch': branchCtrl.text,
        'ifsc': ifscCtrl.text,
        'account': accountCtrl.text,
        'payment': paymentCtrl.text,
        'tdsCode': tdsCode,
        'contractorTypeCode': contractorTypeCode,
      },
      immediate: immediate,
    );
  }

  nameCtrl.addListener(autoSave);
  contactPersonCtrl.addListener(autoSave);
  mobileCtrl.addListener(autoSave);
  emailCtrl.addListener(autoSave);
  altMobileCtrl.addListener(autoSave);
  panCtrl.addListener(autoSave);
  gstCtrl.addListener(autoSave);
  addressCtrl.addListener(autoSave);
  cityCtrl.addListener(autoSave);
  stateCtrl.addListener(autoSave);
  pincodeCtrl.addListener(autoSave);
  bankCtrl.addListener(autoSave);
  branchCtrl.addListener(autoSave);
  ifscCtrl.addListener(autoSave);
  accountCtrl.addListener(autoSave);
  paymentCtrl.addListener(autoSave);

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

          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) autoSave(immediate: true);
            },
            child: AlertDialog(
            title: const Text('Add vendor'),
            content: SizedBox(
              width: 560,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (draftTime != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FormDraftBanner(
                            savedAt: draftTime!,
                            onDiscard: () async {
                              await FormDraftService.instance.clearDraft(draftKey);
                              setLocal(() {
                                draftTime = null;
                                nameCtrl.clear();
                                contactPersonCtrl.clear();
                                mobileCtrl.clear();
                                emailCtrl.clear();
                                altMobileCtrl.clear();
                                panCtrl.clear();
                                gstCtrl.clear();
                                addressCtrl.clear();
                                cityCtrl.clear();
                                stateCtrl.clear();
                                pincodeCtrl.clear();
                                bankCtrl.clear();
                                branchCtrl.clear();
                                ifscCtrl.clear();
                                accountCtrl.clear();
                                paymentCtrl.clear();
                                tdsCode = null;
                                contractorTypeCode = null;
                              });
                            },
                          ),
                        ),
                      Text(
                        'Creates a vendor in Configurations → Vendors with tax, address, and banking details.',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: dec('Vendor / Company name', required: true),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: contactPersonCtrl,
                        decoration: dec('Contact person name'),
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
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: panCtrl,
                              decoration: dec('PAN No.'),
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: gstCtrl,
                              decoration: dec('GSTIN'),
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
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
                        controller: addressCtrl,
                        decoration: dec('Address'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: cityCtrl,
                              decoration: dec('City'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: stateCtrl,
                              decoration: dec('State'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: pincodeCtrl,
                              decoration: dec('Pincode'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: bankCtrl,
                              decoration: dec('Bank name'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: branchCtrl,
                              decoration: dec('Branch'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: ifscCtrl,
                              decoration: dec('IFSC'),
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: accountCtrl,
                              decoration: dec('Account no'),
                            ),
                          ),
                        ],
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
                            if (contactPersonCtrl.text.trim().isNotEmpty)
                              'contactPerson': contactPersonCtrl.text.trim(),
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
                                'name': contactPersonCtrl.text.trim().isNotEmpty
                                    ? contactPersonCtrl.text.trim()
                                    : nameCtrl.text.trim(),
                                'mobileNo': mobileCtrl.text.trim(),
                                'email': emailCtrl.text.trim().isEmpty
                                    ? null
                                    : emailCtrl.text.trim(),
                              },
                            ],
                            'locations': [
                              if (addressCtrl.text.trim().isNotEmpty ||
                                  cityCtrl.text.trim().isNotEmpty ||
                                  panCtrl.text.trim().isNotEmpty ||
                                  gstCtrl.text.trim().isNotEmpty)
                                {
                                  'address1': addressCtrl.text.trim().isNotEmpty
                                      ? addressCtrl.text.trim()
                                      : null,
                                  'cityCode': cityCtrl.text.trim().isNotEmpty
                                      ? cityCtrl.text.trim()
                                      : null,
                                  'stateCode': stateCtrl.text.trim().isNotEmpty
                                      ? stateCtrl.text.trim()
                                      : null,
                                  'postCode': pincodeCtrl.text.trim().isNotEmpty
                                      ? pincodeCtrl.text.trim()
                                      : null,
                                  'panNo': panCtrl.text.trim().isNotEmpty
                                      ? panCtrl.text.trim()
                                      : null,
                                  'gstNo': gstCtrl.text.trim().isNotEmpty
                                      ? gstCtrl.text.trim()
                                      : null,
                                },
                            ],
                          });
                          AppEventBus.instance.fireErpMutated(
                            module: 'contractors',
                            entityId: created.id,
                            action: 'created',
                          );
                          await FormDraftService.instance.clearDraft(draftKey);
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
          ),
          );
        },
      );
    },
  );

  for (final c in [
    nameCtrl,
    contactPersonCtrl,
    mobileCtrl,
    emailCtrl,
    altMobileCtrl,
    panCtrl,
    gstCtrl,
    addressCtrl,
    cityCtrl,
    stateCtrl,
    pincodeCtrl,
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
                    onChanged(created.id);
                  },
            icon: const Icon(Icons.add_circle_outline),
          ),
        ),
      ],
    );
  }
}
