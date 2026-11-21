import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
          'Terms of Service',
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
                          'Terms of Service & Enterprise User Agreement for NB CRM, HRMS and ERP Platforms',
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

                  // Main Terms Card
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
                        _sectionTitle('1. Acceptance of Terms & Enterprise Scope', goldColor, textPrimary),
                        _bodyText(
                          'Welcome to the enterprise applications and software platforms provided by NB Infra Projects LTD. ("Company", "we", "us", or "our"). These Terms of Service ("Terms") constitute a legally binding agreement between NB Infra Projects LTD. and authorized personnel, corporate employees, contractors, field representatives, vendors, and clients ("Users" or "you") accessing or utilizing the NB CRM, HRMS, and ERP ecosystem, including mobile applications, web portals, APIs, and associated cloud services.',
                          textSecondary,
                        ),
                        _bodyText(
                          'By installing, accessing, or using any part of this platform, you acknowledge that you have read, understood, and agree to be bound by these Terms and our companion Privacy Policy. If you do not agree to these Terms, you must not access or use the platform.',
                          textSecondary,
                        ),

                        const SizedBox(height: 20),
                        _sectionTitle('2. User Accounts, Access Credentials & Security', goldColor, textPrimary),
                        _bodyText('Access to this enterprise platform is strictly restricted to authenticated and authorized personnel:', textSecondary),
                        _bulletPoint('Corporate Authentication', 'Accounts are provisioned by enterprise administration. Users must log in using designated official credentials and comply with mandatory password resets and security verifications.', textPrimary, textSecondary),
                        _bulletPoint('Credential Confidentiality', 'You are solely responsible for maintaining the confidentiality of your authentication credentials. Sharing login information, multi-factor tokens, or accounts across individuals is strictly prohibited.', textPrimary, textSecondary),
                        _bulletPoint('Immediate Breach Reporting', 'You agree to immediately notify corporate IT and security administration of any unauthorized access, compromised device, or suspected security breach.', textPrimary, textSecondary),

                        const SizedBox(height: 20),
                        _sectionTitle('3. Permitted Enterprise Use & Code of Conduct', goldColor, textPrimary),
                        _bodyText('The platform is designed exclusively for authorized corporate and business operations of NB Infra Projects LTD. Users agree to refrain from:', textSecondary),
                        _bulletPoint('Unauthorized Data Extraction', 'Scraping, crawling, reverse engineering, decompiling, or attempting to extract source code or underlying database schemas.', textPrimary, textSecondary),
                        _bulletPoint('Falsification of Operational Records', 'Submitting fraudulent attendance records, fabricated daily progress reports (DPR), altered site visit logs, or deceptive commercial leads.', textPrimary, textSecondary),
                        _bulletPoint('Circumventing Security Controls', 'Bypassing geofencing boundaries, spoofing GPS coordinates, deploying mocking mock locations, or utilizing unauthorized VPNs or proxies.', textPrimary, textSecondary),
                        _bulletPoint('Disruptive Activities', 'Introducing malicious code, viruses, automated bots, or executing denial-of-service tests against enterprise servers or APIs.', textPrimary, textSecondary),

                        const SizedBox(height: 20),
                        _sectionTitle('4. Proprietary Rights & Intellectual Property', goldColor, textPrimary),
                        _bodyText(
                          'All software code, visual designs, trademarks, trade secrets, project schemas, blueprints, customer data architectures, and documentation associated with the NB CRM, HRMS, and ERP ecosystem are the exclusive intellectual property of NB Infra Projects LTD.',
                          textSecondary,
                        ),
                        _bodyText(
                          'Users are granted a limited, revocable, non-exclusive, non-transferable internal license solely to utilize the platform in connection with their authorized duties for the Company.',
                          textSecondary,
                        ),

                        const SizedBox(height: 20),
                        _sectionTitle('5. Geolocation, Telemetry & Attendance Verification', goldColor, textPrimary),
                        _bodyText(
                          'Certain modules of the platform (including workforce attendance, field sales tracking, and site inspection features) utilize device geolocation telemetry:',
                          textSecondary,
                        ),
                        _bulletPoint('Workplace Duty Verification', 'Location coordinates are recorded strictly in relation to active work shifts, scheduled customer visits, and approved travel reimbursement tracking.', textPrimary, textSecondary),
                        _bulletPoint('Anti-Spoofing & Compliance', 'Tampering with device hardware, spoofing GPS coordinates, or using unauthorized emulation environments constitutes gross misconduct and grounds for immediate disciplinary action.', textPrimary, textSecondary),

                        const SizedBox(height: 20),
                        _sectionTitle('6. Data Confidentiality & Trade Secrets', goldColor, textPrimary),
                        _bodyText(
                          'All customer information, project pricing, financial ledgers, vendor contracts, employee directories, and architectural layouts accessible through this platform are strictly confidential trade secrets of NB Infra Projects LTD. Users shall preserve total confidentiality during and following their association with the Company.',
                          textSecondary,
                        ),

                        const SizedBox(height: 20),
                        _sectionTitle('7. Platform Availability, Maintenance & Disclaimers', goldColor, textPrimary),
                        _bodyText(
                          'While we strive to ensure continuous availability and high uptime, the platform is provided on an "as is" and "as available" basis. NB Infra Projects LTD. reserves the right to perform scheduled or emergency maintenance, deploy software upgrades, and modify features without prior notice.',
                          textSecondary,
                        ),

                        const SizedBox(height: 20),
                        _sectionTitle('8. Account Suspension & Revocation', goldColor, textPrimary),
                        _bodyText(
                          'NB Infra Projects LTD. reserves the unreserved right to suspend, terminate, or revoke user access to the platform immediately and without notice upon cessation of employment, contract expiration, breach of these Terms, or suspected corporate malfeasance.',
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
                                'These Terms of Service, their interpretation, validity, performance, and any disputes or claims arising out of or relating to this Platform, its use, or transactions conducted through it shall be governed by, construed, and enforced in accordance with the laws of the Republic of India. Any legal dispute, controversy, claim, or proceeding arising under or in connection with these Terms or the services of NB Infra Projects LTD. shall be subject to the exclusive jurisdiction of the competent courts located in Ahmedabad, Gujarat, India.',
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
                        _sectionTitle('10. Modifications to Terms', goldColor, textPrimary),
                        _bodyText(
                          'NB Infra Projects LTD. reserves the right to update or amend these Terms of Service at any time. Continued access or use of the platform after revised terms are posted constitutes your binding agreement to such revisions.',
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
                            'Administrative Notice: In accordance with corporate policy, internal governance inquiries or questions regarding enterprise access should be routed through designated management or IT administration.',
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
