import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          'Privacy Policy',
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
            onPressed: () => context.go('/termsofservice'),
            icon: const Icon(Icons.description_outlined, size: 16, color: goldColor),
            label: Text(
              'Terms of Service',
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
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header Banner
                  Container(
                    padding: const EdgeInsets.all(24),
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
                          blurRadius: 18,
                          offset: const Offset(0, 6),
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
                            'ENTERPRISE GOVERNANCE',
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
                          'Privacy Policy & Data Protection Governance for NB CRM, HRMS and ERP Platforms',
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

                  // Main Policy Card
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('1. Introduction & Scope', goldColor, textPrimary),
                        _bodyText(
                          'NB Infra Projects LTD. ("Company", "we", "us", or "our") is committed to protecting the privacy, security, and confidentiality of personal and operational information across our enterprise software ecosystem. This Privacy Policy outlines our procedures regarding the collection, transmission, processing, and safeguarding of data across the NB CRM, HRMS, and ERP suites, including web clients, mobile applications, APIs, and associated cloud services.',
                          textSecondary,
                        ),
                        _bodyText(
                          'This policy governs all authorized employees, corporate personnel, contractors, vendors, and enterprise clients accessing or using systems operated by NB Infra Projects LTD.',
                          textSecondary,
                        ),

                        const SizedBox(height: 20),
                        _sectionTitle('2. Categories of Information Collected', goldColor, textPrimary),
                        _bodyText('We process the following classifications of enterprise data:', textSecondary),
                        _bulletPoint('Personal & Profile Information', 'Legal full name, employee identifier, designation, department, reporting structure, and statutory identity documentation required for employment compliance.', textPrimary, textSecondary),
                        _bulletPoint('Commercial & Real Estate Records', 'Prospective client leads, project inquiries, quotation lifecycles, site visit logs, unit booking records, and financial ledger data.', textPrimary, textSecondary),
                        _bulletPoint('Geolocation & Attendance Telemetry', 'GPS coordinates, geofenced location punches, punch-in/out timestamps, and work-shift trajectory logs collected solely for workforce attendance and travel reimbursement audits.', textPrimary, textSecondary),
                        _bulletPoint('System & Device Telemetry', 'Operating system version, device identifier, network carrier, IP address, crash logs, and session diagnostic telemetry.', textPrimary, textSecondary),
                        _bulletPoint('Telephony & Communication Data', 'Telephony metadata (call duration, timestamp, agent attribution, recording audio where enabled for quality audits), customer follow-up notes, and support tickets.', textPrimary, textSecondary),

                        const SizedBox(height: 20),
                        _sectionTitle('3. Purpose & Legal Basis of Processing', goldColor, textPrimary),
                        _bodyText('Information is processed exclusively for legitimate corporate, contractual, and statutory functions:', textSecondary),
                        _bulletPoint('Enterprise ERP Operations', 'Facilitating construction workflows, contractor work orders, DPR logs, inventory management, and procurement.', textPrimary, textSecondary),
                        _bulletPoint('Workforce Administration', 'Validating geofenced workplace attendance, calculating monthly payroll, administering leave benefits, and access control.', textPrimary, textSecondary),
                        _bulletPoint('Security & Auditing', 'Preventing unauthorized access, detecting anomalous proxy or VPN activity, safeguarding digital assets, and preserving immutable audit trails.', textPrimary, textSecondary),
                        _bulletPoint('Regulatory Compliance', 'Adhering to statutory labor regulations, tax laws, commercial codes, and applicable Indian data protection frameworks.', textPrimary, textSecondary),

                        const SizedBox(height: 20),
                        _sectionTitle('4. Location Services & Field Tracking Policy', goldColor, textPrimary),
                        _bodyText(
                          'Our mobile applications may request foreground and background location permissions strictly to support geofenced attendance punches and route verification for field sales and site engineering personnel.',
                          textSecondary,
                        ),
                        _bulletPoint('Shift-Bound Operation', 'Location telemetry is recorded strictly during active duty hours or recorded field trips initiated by the user.', textPrimary, textSecondary),
                        _bulletPoint('No Commercial Monetization', 'Location data is never sold, leased, or shared with third-party advertisers or external data brokers.', textPrimary, textSecondary),
                        _bulletPoint('Access Restriction', 'Location history is restricted to authorized administrative personnel on a need-to-know basis.', textPrimary, textSecondary),

                        const SizedBox(height: 20),
                        _sectionTitle('5. Data Security & Storage Standards', goldColor, textPrimary),
                        _bodyText(
                          'NB Infra Projects LTD. implements multi-layer defense mechanisms to protect sensitive data:',
                          textSecondary,
                        ),
                        _bulletPoint('End-to-End Encryption', 'Network transactions utilize double AES-GCM cryptographic envelopes in tandem with TLS 1.3 / HTTPS transport encryption.', textPrimary, textSecondary),
                        _bulletPoint('Role-Based Access Control (RBAC)', 'Granular permissions ensure users only access resources strictly authorized for their organizational role.', textPrimary, textSecondary),
                        _bulletPoint('Database Isolation', 'Production data resides in hardened, encrypted relational and object storage architectures with automated backup routines.', textPrimary, textSecondary),

                        const SizedBox(height: 20),
                        _sectionTitle('6. Data Retention & Archival', goldColor, textPrimary),
                        _bodyText(
                          'Information is retained only for the duration necessary to satisfy operational needs, employment agreements, and statutory compliance periods. Upon cessation of employment or expiration of legal retention requirements, data is securely archived, anonymized, or destroyed.',
                          textSecondary,
                        ),

                        const SizedBox(height: 20),
                        _sectionTitle('7. Information Sharing & Third Parties', goldColor, textPrimary),
                        _bodyText(
                          'We do not sell personal data. Information is disclosed exclusively to authorized enterprise infrastructure providers (such as hosting, SMS/WhatsApp gateways, telephony providers, and mapping APIs) bound by strict confidentiality obligations, or to statutory authorities when mandated by applicable law.',
                          textSecondary,
                        ),

                        const SizedBox(height: 20),
                        _sectionTitle('8. Children\'s Privacy', goldColor, textPrimary),
                        _bodyText(
                          'Our enterprise applications and services are designated exclusively for authorized adults aged 18 years or older. We do not solicit or process information from minors.',
                          textSecondary,
                        ),

                        const SizedBox(height: 24),

                        // Exclusive Jurisdiction Callout Box
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: goldColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: goldColor.withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.gavel_rounded, color: goldColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '9. Governing Law & Exclusive Jurisdiction',
                                    style: GoogleFonts.sourceSans3(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'This Privacy Policy, all matters arising out of or relating to this Platform, its terms, data handling practices, and any related transactions or disputes shall be governed by, construed, and enforced in accordance with the laws of the Republic of India. Any legal dispute, controversy, claim, or proceeding arising under or in connection with this Policy or the services provided by NB Infra Projects LTD. shall be subject to the exclusive jurisdiction of the competent courts located in Ahmedabad, Gujarat, India.',
                                style: GoogleFonts.sourceSans3(
                                  fontSize: 13.5,
                                  color: textPrimary,
                                  height: 1.55,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        _sectionTitle('10. Policy Amendments', goldColor, textPrimary),
                        _bodyText(
                          'NB Infra Projects LTD. reserves the right to amend or update this Privacy Policy at any time. Continued utilization of our systems following publication of updates constitutes acknowledgment of the revised policy.',
                          textSecondary,
                        ),

                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Administrative Notice: In accordance with our corporate governance directives, all inquiries and administrative requests must be routed through internal enterprise administrative channels.',
                            style: GoogleFonts.sourceSans3(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Bottom Navigation
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
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
                      OutlinedButton.icon(
                        onPressed: () => context.go('/termsofservice'),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('Terms of Service'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => context.go('/contactus'),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: const Text('Contact Us'),
                        style: FilledButton.styleFrom(
                          backgroundColor: goldColor,
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  Widget _sectionTitle(String title, Color accentColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 18,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.sourceSans3(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bodyText(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.sourceSans3(
          fontSize: 13.5,
          color: textColor,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _bulletPoint(String title, String desc, Color titleColor, Color descColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: titleColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.sourceSans3(fontSize: 13.5, height: 1.5, color: descColor),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: TextStyle(fontWeight: FontWeight.w700, color: titleColor),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
