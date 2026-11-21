import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/app_config.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _subjectController = TextEditingController(text: 'General Inquiry');
  final _messageController = TextEditingController();

  bool _isSubmitting = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 25),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final baseUrl = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/api/?$'), '');
      final endpoint = '$baseUrl/api/contactus';

      final response = await dio.post(
        endpoint,
        data: {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'subject': _subjectController.text.trim(),
          'message': _messageController.text.trim(),
        },
      );

      final data = response.data;
      if (response.statusCode == 200 && (data is Map && data['success'] == true)) {
        setState(() {
          _successMessage =
              'Thank you for contacting NB Infra Projects LTD.! Your message has been sent to our IT team at it.nbdeveloper@gmail.com. We will get back to you shortly.';
          _nameController.clear();
          _emailController.clear();
          _phoneController.clear();
          _subjectController.text = 'General Inquiry';
          _messageController.clear();
        });
      } else {
        final err = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Unable to submit your message. Please try again.';
        setState(() => _errorMessage = err);
      }
    } catch (e) {
      String msg = 'Failed to send message. Please check your internet connection.';
      if (e is DioException) {
        if (e.response?.data is Map && e.response?.data['error'] != null) {
          msg = e.response!.data['error'].toString();
        } else if (e.message != null && e.message!.isNotEmpty) {
          msg = e.message!;
        }
      }
      setState(() => _errorMessage = msg);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    const goldColor = Color(0xFFD4AF37);
    const goldLight = Color(0xFFF7E7A9);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Contact Us',
          style: GoogleFonts.sourceSans3(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/privacypolicy'),
            icon: const Icon(Icons.shield_outlined, size: 16, color: goldColor),
            label: Text(
              'Privacy Policy',
              style: GoogleFonts.sourceSans3(
                fontWeight: FontWeight.w700,
                color: goldColor,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Banner
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: goldColor.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: goldColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: goldColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'COMMUNICATION DESK',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: goldLight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'NB INFRA PROJECTS LTD.',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Send your inquiry or support request. Submissions are delivered to our IT team at it.nbdeveloper@gmail.com.',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 13.5,
                            color: const Color(0xFF94A3B8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Contact Form Card
                  Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_successMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF10B981), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _successMessage!,
                                      style: GoogleFonts.sourceSans3(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Color(0xFFEF4444), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.sourceSans3(
                                        fontSize: 13.5,
                                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          _fieldLabel('Full Name', true, textSecondary),
                          TextFormField(
                            controller: _nameController,
                            style: GoogleFonts.sourceSans3(color: textPrimary, fontSize: 14.5),
                            decoration: _inputDecoration('Enter your full name', Icons.person_outline_rounded, borderColor, isDark),
                            validator: (v) => (v == null || v.trim().length < 2) ? 'Name is required (at least 2 characters)' : null,
                          ),

                          const SizedBox(height: 16),
                          _fieldLabel('Email Address', true, textSecondary),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.sourceSans3(color: textPrimary, fontSize: 14.5),
                            decoration: _inputDecoration('name@company.com', Icons.email_outlined, borderColor, isDark),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email address is required';
                              if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email address';
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),
                          _fieldLabel('Phone Number', false, textSecondary),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: GoogleFonts.sourceSans3(color: textPrimary, fontSize: 14.5),
                            decoration: _inputDecoration('+91 98765 43210', Icons.phone_outlined, borderColor, isDark),
                          ),

                          const SizedBox(height: 16),
                          _fieldLabel('Subject', true, textSecondary),
                          TextFormField(
                            controller: _subjectController,
                            style: GoogleFonts.sourceSans3(color: textPrimary, fontSize: 14.5),
                            decoration: _inputDecoration('Subject of inquiry', Icons.subject_rounded, borderColor, isDark),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Subject is required' : null,
                          ),

                          const SizedBox(height: 16),
                          _fieldLabel('Message', true, textSecondary),
                          TextFormField(
                            controller: _messageController,
                            maxLines: 4,
                            style: GoogleFonts.sourceSans3(color: textPrimary, fontSize: 14.5),
                            decoration: _inputDecoration('Write your message or inquiry here...', Icons.message_outlined, borderColor, isDark),
                            validator: (v) => (v == null || v.trim().length < 5) ? 'Message is required (at least 5 characters)' : null,
                          ),

                          const SizedBox(height: 24),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: _isSubmitting ? null : _submitForm,
                              style: FilledButton.styleFrom(
                                backgroundColor: goldColor,
                                foregroundColor: const Color(0xFF0F172A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF0F172A)),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.send_rounded, size: 17),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Send Message',
                                          style: GoogleFonts.sourceSans3(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bottom Navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => context.go('/login'),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Back to Login'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/privacypolicy'),
                        icon: const Icon(Icons.shield_outlined, size: 16),
                        label: const Text('Privacy Policy'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Text(
                    '© 2026 NB Infra Projects LTD. All rights reserved.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label, bool isRequired, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.sourceSans3(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          if (isRequired) ...[
            const SizedBox(width: 3),
            const Text('*', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, Color borderColor, bool isDark) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: GoogleFonts.sourceSans3(
        fontSize: 13.5,
        color: const Color(0xFF94A3B8).withValues(alpha: 0.7),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.6),
      ),
    );
  }
}
