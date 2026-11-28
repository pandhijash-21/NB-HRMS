import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/app_config.dart';

/// Public vendor portal: email OTP → view PR items/qty → submit quotation.
class VendorQuotationPortalScreen extends StatefulWidget {
  const VendorQuotationPortalScreen({super.key, required this.token});

  final String token;

  @override
  State<VendorQuotationPortalScreen> createState() => _VendorQuotationPortalScreenState();
}

class _VendorQuotationPortalScreenState extends State<VendorQuotationPortalScreen> {
  final _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api/?$'), ''),
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ),
  );

  int _step = 0; // 0 email, 1 otp, 2 form, 3 done
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _summary;

  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String? _sessionToken;
  Map<String, dynamic>? _session;

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gstNoCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _cgstCtrl = TextEditingController(text: '2.5');
  final _sgstCtrl = TextEditingController(text: '2.5');
  final _igstCtrl = TextEditingController(text: '5');
  final _freightCtrl = TextEditingController();
  final _deliveryCtrl = TextEditingController();
  final _ratingCtrl = TextEditingController();

  String _gstMode = 'INCLUSIVE';
  String _gstTaxType = 'CGST_SGST';
  String _freightMode = 'INCLUSIVE';
  String? _paymentTerms;
  String? _vendorStateCode;
  final Map<String, TextEditingController> _rateCtrls = {};
  String? _submittedNo;
  bool _busy = false;

  String get _api => '/api/purchase-portal/${widget.token}';

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _gstNoCtrl.dispose();
    _panCtrl.dispose();
    _remarksCtrl.dispose();
    _cgstCtrl.dispose();
    _sgstCtrl.dispose();
    _igstCtrl.dispose();
    _freightCtrl.dispose();
    _deliveryCtrl.dispose();
    _ratingCtrl.dispose();
    for (final c in _rateCtrls.values) {
      c.dispose();
    }
    _dio.close();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _dio.get(_api);
      final data = _unwrap(res.data);
      setState(() {
        _summary = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = _err(e);
      });
    }
  }

  Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is Map && raw['success'] == true && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }
    if (raw is Map && raw['error'] != null) {
      throw Exception(raw['error'].toString());
    }
    throw Exception('Unexpected response');
  }

  String _err(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
      return e.message ?? 'Request failed';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _sendOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _dio.post('$_api/otp/send', data: {'email': _emailCtrl.text.trim()});
      setState(() {
        _busy = false;
        _step = 1;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = _err(e);
      });
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await _dio.post(
        '$_api/otp/verify',
        data: {'email': _emailCtrl.text.trim(), 'otp': _otpCtrl.text.trim()},
      );
      final data = _unwrap(res.data);
      final lines = (data['lines'] as List? ?? const []);
      for (final l in lines) {
        final m = Map<String, dynamic>.from(l as Map);
        final id = m['id']?.toString() ?? '';
        _rateCtrls[id] = TextEditingController();
      }
      final vendor = data['vendor'];
      if (vendor is Map) {
        _nameCtrl.text = vendor['name']?.toString() ?? '';
        _addressCtrl.text = vendor['address']?.toString() ?? '';
        _gstNoCtrl.text = vendor['gstNo']?.toString() ?? '';
        _panCtrl.text = vendor['panNo']?.toString() ?? '';
        _vendorStateCode = vendor['stateCode']?.toString();
        final state = (_vendorStateCode ?? '').toUpperCase();
        if (state.isNotEmpty) {
          _gstTaxType = state == 'GUJARAT' ? 'CGST_SGST' : 'IGST';
        }
        if (vendor['paymentTerms'] != null) {
          _paymentTerms = vendor['paymentTerms']?.toString();
        }
      }
      setState(() {
        _session = data;
        _sessionToken = data['sessionToken']?.toString();
        _busy = false;
        _step = 2;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = _err(e);
      });
    }
  }

  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  double get _subtotal {
    final lines = (_session?['lines'] as List? ?? const []);
    var s = 0.0;
    for (final l in lines) {
      final m = Map<String, dynamic>.from(l as Map);
      final id = m['id']?.toString() ?? '';
      final qty = double.tryParse('${m['qty']}') ?? 0;
      final rate = _d(_rateCtrls[id] ?? TextEditingController());
      s += qty * rate;
    }
    return double.parse(s.toStringAsFixed(2));
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Company name is required');
      return;
    }
    final lines = (_session?['lines'] as List? ?? const []);
    final payloadLines = <Map<String, dynamic>>[];
    for (final l in lines) {
      final m = Map<String, dynamic>.from(l as Map);
      final id = m['id']?.toString() ?? '';
      final rate = _d(_rateCtrls[id]!);
      if (rate <= 0) {
        setState(() => _error = 'Enter rate for ${m['itemName']}');
        return;
      }
      final qty = double.tryParse('${m['qty']}') ?? 0;
      payloadLines.add({
        'purchaseRequestLineId': id,
        'materialId': m['materialId'],
        'itemCode': m['itemCode'],
        'brand': m['brand'],
        'itemName': m['itemName'],
        'unitCode': m['unitCode'],
        'size': m['size'],
        'qty': qty,
        'rate': rate,
        'amount': double.parse((qty * rate).toStringAsFixed(2)),
      });
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await _dio.post(
        '$_api/submit',
        data: {
          'sessionToken': _sessionToken,
          'vendorName': _nameCtrl.text.trim(),
          'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          'gstNo': _gstNoCtrl.text.trim().isEmpty ? null : _gstNoCtrl.text.trim(),
          'panNo': _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
          'remarks': _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
          'gstMode': _gstMode,
          'gstTaxType': _gstMode == 'EXCLUSIVE' ? _gstTaxType : null,
          'vendorStateCode': _vendorStateCode,
          'cgstRate': _gstMode == 'EXCLUSIVE' && _gstTaxType == 'CGST_SGST' ? _d(_cgstCtrl) : null,
          'sgstRate': _gstMode == 'EXCLUSIVE' && _gstTaxType == 'CGST_SGST' ? _d(_sgstCtrl) : null,
          'igstRate': _gstMode == 'EXCLUSIVE' && _gstTaxType == 'IGST' ? _d(_igstCtrl) : null,
          'freightMode': _freightMode,
          'freightAmount': _d(_freightCtrl),
          'paymentTerms': _paymentTerms,
          'deliveryDays':
              _deliveryCtrl.text.trim().isEmpty ? null : int.tryParse(_deliveryCtrl.text.trim()),
          'rating': _ratingCtrl.text.trim().isEmpty ? null : double.tryParse(_ratingCtrl.text.trim()),
          'lines': payloadLines,
        },
        options: Options(headers: {'x-vendor-session': _sessionToken}),
      );
      final data = _unwrap(res.data);
      setState(() {
        _busy = false;
        _submittedNo = data['quotationNo']?.toString();
        _step = 3;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = _err(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Vendor quotation'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summary == null
              ? Center(child: Text(_error ?? 'Invite not found'))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _summary!['prNumber']?.toString() ?? 'PR',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                ),
                                if (_summary!['projectName'] != null)
                                  Text('Project: ${_summary!['projectName']}'),
                                const SizedBox(height: 8),
                                const Text('Required items', style: TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                for (final l in (_summary!['lines'] as List? ?? const []))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '• ${l['itemName']} — qty ${l['qty']}${l['unitCode'] != null ? ' ${l['unitCode']}' : ''}'
                                      '${l['brand'] != null ? ' · ${l['brand']}' : ''}',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(_error!, style: const TextStyle(color: Colors.red)),
                          ),
                        if (_step == 0) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('Verify your email to continue',
                                      style: TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _emailCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Email *',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: _busy ? null : _sendOtp,
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1e3a5f)),
                                    child: _busy
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Text('Send OTP'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_step == 1) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('OTP sent to ${_emailCtrl.text.trim()}',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _otpCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Enter OTP *',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: _busy ? null : _verifyOtp,
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1e3a5f)),
                                    child: const Text('Verify & continue'),
                                  ),
                                  TextButton(
                                    onPressed: _busy ? null : _sendOtp,
                                    child: const Text('Resend OTP'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_step == 2 && _session != null) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text('Your quotation', style: TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _nameCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Company name *',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _addressCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Address',
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _gstNoCtrl,
                                          decoration: const InputDecoration(
                                            labelText: 'GST No.',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _panCtrl,
                                          decoration: const InputDecoration(
                                            labelText: 'PAN',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  for (final l in (_session!['lines'] as List)) ...[
                                    Builder(builder: (_) {
                                      final m = Map<String, dynamic>.from(l as Map);
                                      final id = m['id']?.toString() ?? '';
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: TextField(
                                          controller: _rateCtrls[id],
                                          decoration: InputDecoration(
                                            labelText: 'Rate for ${m['itemName']} *',
                                            helperText:
                                                'Qty ${m['qty']}${m['unitCode'] != null ? ' ${m['unitCode']}' : ''}',
                                            border: const OutlineInputBorder(),
                                          ),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                          ],
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      );
                                    }),
                                  ],
                                  Text('Subtotal: ${money.format(_subtotal)}',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 12),
                                  const Text('GST', style: TextStyle(fontWeight: FontWeight.w700)),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Inclusive'),
                                        selected: _gstMode == 'INCLUSIVE',
                                        onSelected: (_) => setState(() => _gstMode = 'INCLUSIVE'),
                                      ),
                                      ChoiceChip(
                                        label: const Text('Exclusive'),
                                        selected: _gstMode == 'EXCLUSIVE',
                                        onSelected: (_) => setState(() => _gstMode = 'EXCLUSIVE'),
                                      ),
                                    ],
                                  ),
                                  if (_gstMode == 'EXCLUSIVE') ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        ChoiceChip(
                                          label: const Text('CGST+SGST'),
                                          selected: _gstTaxType == 'CGST_SGST',
                                          onSelected: (_) => setState(() => _gstTaxType = 'CGST_SGST'),
                                        ),
                                        ChoiceChip(
                                          label: const Text('IGST'),
                                          selected: _gstTaxType == 'IGST',
                                          onSelected: (_) => setState(() => _gstTaxType = 'IGST'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (_gstTaxType == 'CGST_SGST')
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _cgstCtrl,
                                              decoration: const InputDecoration(
                                                labelText: 'CGST %',
                                                border: OutlineInputBorder(),
                                              ),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              controller: _sgstCtrl,
                                              decoration: const InputDecoration(
                                                labelText: 'SGST %',
                                                border: OutlineInputBorder(),
                                              ),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      TextField(
                                        controller: _igstCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'IGST %',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      ),
                                  ],
                                  const SizedBox(height: 12),
                                  const Text('Freight', style: TextStyle(fontWeight: FontWeight.w700)),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Inclusive'),
                                        selected: _freightMode == 'INCLUSIVE',
                                        onSelected: (_) => setState(() => _freightMode = 'INCLUSIVE'),
                                      ),
                                      ChoiceChip(
                                        label: const Text('Exclusive'),
                                        selected: _freightMode == 'EXCLUSIVE',
                                        onSelected: (_) => setState(() => _freightMode = 'EXCLUSIVE'),
                                      ),
                                    ],
                                  ),
                                  if (_freightMode == 'EXCLUSIVE') ...[
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _freightCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Freight amount',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: () {
                                      final opts = (_session!['paymentTermsOptions'] as List? ?? const [])
                                          .map((e) => Map<String, dynamic>.from(e as Map))
                                          .toList();
                                      final codes = opts.map((o) => o['code']?.toString()).whereType<String>();
                                      if (_paymentTerms != null && codes.contains(_paymentTerms)) {
                                        return _paymentTerms;
                                      }
                                      return null;
                                    }(),
                                    decoration: const InputDecoration(
                                      labelText: 'Payment terms',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: [
                                      for (final o in (_session!['paymentTermsOptions'] as List? ?? const []))
                                        DropdownMenuItem(
                                          value: (o as Map)['code']?.toString(),
                                          child: Text(o['label']?.toString() ?? o['code']?.toString() ?? ''),
                                        ),
                                    ],
                                    onChanged: (v) => setState(() => _paymentTerms = v),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _deliveryCtrl,
                                          decoration: const InputDecoration(
                                            labelText: 'Delivery (days)',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _ratingCtrl,
                                          decoration: const InputDecoration(
                                            labelText: 'Rating (optional)',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _remarksCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Remarks',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: _busy ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF0f766e),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: _busy
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Text('Submit quotation'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_step == 3) ...[
                          Card(
                            color: const Color(0xFFECFDF5),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  const Icon(Icons.check_circle, color: Color(0xFF0f766e), size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Quotation ${_submittedNo ?? ''} submitted',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'A confirmation email has been sent to you. Our team will review it on the comparison sheet.',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }
}
