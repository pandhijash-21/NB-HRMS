import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/bloc/load_status.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../auth/domain/permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/attendance_repository.dart';
import '../../domain/attendance_models.dart';
import '../../../leave/presentation/widgets/leave_shared_widgets.dart';
import '../bloc/attendance_bloc.dart';
import '../geofenced_punch_service.dart';
import '../web_attendance_gate.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final empId = auth.user?.employeeId;

    return BlocProvider(
      create: (context) => AttendanceBloc(
        attendanceRepository: context.read<AttendanceRepository>(),
        dioClient: context.read<DioClient>(),
      )..add(AttendanceLoadRequested(employeeId: empId)),
      child: const _AttendanceView(),
    );
  }
}

class _AttendanceView extends StatelessWidget {
  const _AttendanceView();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final state = context.watch<AttendanceBloc>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final webGate = state.webGate;
    final webAllowed = !kIsWeb || (webGate?.allowed == true);
    final canAdmin = Permissions.canAdminAttendance(
      auth.permissions,
      auth.user?.role ?? '',
    );

    // Punch In/Out is only for the current calendar day (IST).
    final todayYmd = _attendanceTodayYmdIst();
    final canPunchSelectedDay = state.selectedDate == todayYmd;

    final year = state.year == 0 ? DateTime.now().year : state.year;
    final month = state.month == 0 ? DateTime.now().month : state.month;

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1816) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Attendance',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF212F3D),
            letterSpacing: -0.5,
          ),
        ),
        leading: const AppBackButton(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.5),
          child: Container(
            color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
            height: 1.5,
          ),
        ),
      ),
      floatingActionButton: webAllowed
          ? FloatingActionButton.extended(
        onPressed: () async {
          if (kIsWeb) {
            final gate = state.webGate ?? await WebAttendanceGate.evaluate();
            if (!gate.allowed) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(gate.message ?? 'Web attendance is not allowed on this browser.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
          }

          if (!canPunchSelectedDay) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.selectedDate.isEmpty
                      ? 'Select today ($todayYmd) to punch in/out.'
                      : 'Punch in/out is only allowed for today ($todayYmd). Past or future days are view-only.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          final empId = auth.user?.employeeId;
          if (empId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Employee ID not found in session.'), backgroundColor: Colors.red),
            );
            return;
          }

          // Check if biometrics is registered
          final settings = state.settings;
          if (settings == null || settings.biometricToken == null || settings.biometricToken!.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  kIsWeb
                      ? 'Register Safari first (Attendance → Register Safari).'
                      : 'Fingerprint/Face ID not registered. Please register it first.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          final hasLocal = state.hasLocalToken;
          if (!hasLocal) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  kIsWeb
                      ? 'Safari is not linked yet. Tap “Register Safari” first.'
                      : 'Fingerprint not set on this device. Please register it first.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          final currentDayData = state.dayDetail;
          if (currentDayData != null) {
            if (currentDayData.punches.length >= 2) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Maximum 2 punches allowed per day (1 In, 1 Out).'), backgroundColor: Colors.orange),
              );
              return;
            }

            if (currentDayData.punches.isNotEmpty) {
              final lastPunch = currentDayData.punches.last;
              final lastPunchTime = DateTime.parse(lastPunch.punchAt);
              final diff = DateTime.now().difference(lastPunchTime);
              if (diff.inMinutes < 20) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please wait ${20 - diff.inMinutes} minutes before punching again.'), backgroundColor: Colors.orange),
                );
                return;
              }
            }

            if (currentDayData.punches.length == 1) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Punch Out'),
                  content: const Text('Are you sure you want to punch out for the day?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC5A059),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Punch Out'),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;
            }
          }

          final dio = context.read<DioClient>();
          final svc = GeofencedPunchService(dio);
          if (context.mounted) {
            await svc.executePunch(context, empId);
            if (context.mounted) {
              context.read<AttendanceBloc>().add(AttendanceRefreshRequested(employeeId: empId));
            }
          }
        },
        backgroundColor:
            canPunchSelectedDay ? const Color(0xFFC5A059) : Colors.grey.shade500,
        icon: const Icon(Icons.fingerprint_rounded, color: Colors.white),
        label: Text(
          kIsWeb
              ? (canPunchSelectedDay ? 'Punch (iOS Safari)' : 'Today only')
              : (canPunchSelectedDay ? 'Punch In/Out' : 'Today only'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      )
          : null,
      body: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0.0, 35.0 * (1.0 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            if (kIsWeb && webGate != null) ...[
              if (!webGate.allowed)
                Card(
                  color: isDark ? const Color(0xFF2A1A1A) : Colors.red.shade50,
                  margin: const EdgeInsets.only(bottom: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark ? Colors.red.shade300.withValues(alpha: 0.35) : Colors.red.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.block_rounded, color: isDark ? Colors.red.shade300 : Colors.red.shade800, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Browser attendance not available',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          webGate.message ??
                              'Web attendance is only allowed in Safari on iPhone/iPad. Use the mobile app on other devices.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF4A5568),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Detected: ${webGate.deviceLabel} · ${webGate.browserLabel}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            WebAttendanceGate.reevaluate();
                            final empId = auth.user?.employeeId;
                            if (empId != null) {
                              context.read<AttendanceBloc>().add(AttendanceSettingsReloadRequested(empId));
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh Status'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  color: isDark ? const Color(0xFF1A2430) : const Color(0xFFEFF6FF),
                  margin: const EdgeInsets.only(bottom: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                          : const Color(0xFF93C5FD),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.phone_iphone_rounded,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Attendance from iOS browser',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'You are punching from Safari on an iPhone/iPad (${webGate.deviceLabel}). '
                          'Before each punch, your location is checked and must be inside an allowed attendance zone. '
                          'Other browsers and desktop devices cannot mark attendance here — use the mobile app instead.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF4A5568),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            // Biometric Registration Card
            if (auth.user?.employeeId != null && webAllowed) ...[
              _buildBiometricCard(context, state, auth, isDark),
            ],
            if (canAdmin) ...[
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5A059),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Attendance Workspace',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AttendanceWorkspaceTile(
                icon: Icons.admin_panel_settings_rounded,
                title: 'Manage Attendance',
                subtitle: 'Policy, manual punches & all employees',
                color: const Color(0xFF16a34a),
                onTap: () => context.go('/admin/attendance'),
              ),
              const SizedBox(height: 10),
              _AttendanceWorkspaceTile(
                icon: Icons.fingerprint_rounded,
                title: 'Device Attendance',
                subtitle: 'Raw biometric data & sync into calendar',
                color: const Color(0xFF2563eb),
                onTap: () => context.go('/admin/attendance/device'),
              ),
              const SizedBox(height: 10),
              _AttendanceWorkspaceTile(
                icon: Icons.map_rounded,
                title: 'Manage Geofenced Zones',
                subtitle: 'Set attendance areas on the map',
                color: const Color(0xFFC5A059),
                onTap: () => context.go('/admin/attendance/locations'),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC5A059),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'My Attendance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            // Month Navigator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1B18) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () =>
                        context.read<AttendanceBloc>().add(const AttendancePreviousMonthRequested()),
                    icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFFC5A059)),
                  ),
                  Text(
                    '${_monthName(month)} $year',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        context.read<AttendanceBloc>().add(const AttendanceNextMonthRequested()),
                    icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFFC5A059)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (state.status == LoadStatus.loading && state.calendar.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                ),
              )
            else if (state.status == LoadStatus.failure && state.calendar.isEmpty)
              Column(
                children: [
                  Text(
                    state.errorMessage ?? 'Error loading calendar',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      final empId = auth.user?.employeeId;
                      context.read<AttendanceBloc>().add(AttendanceRefreshRequested(employeeId: empId));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              )
            else
              _CalendarGrid(
                daysInMonth: daysInMonth,
                firstWeekday: firstWeekday,
                year: year,
                month: month,
                calendar: state.calendar,
                selectedDate: state.selectedDate,
                onSelect: (date) =>
                    context.read<AttendanceBloc>().add(AttendanceDateSelected(date)),
              ),
            const SizedBox(height: 36),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC5A059),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Day Detail · ${state.selectedDate.isEmpty ? '—' : state.selectedDate}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF212F3D),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.isDayLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: Color(0xFFC5A059)),
                ),
              )
            else if (state.dayDetail != null)
              _DayDetail(day: state.dayDetail!)
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No attendance logs recorded for this day.',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricCard(
    BuildContext context,
    AttendanceState state,
    AuthState auth,
    bool isDark,
  ) {
    final settings = state.settings;
    if (settings == null) return const SizedBox.shrink();

    final isRegisteredOnServer = settings.biometricToken != null && settings.biometricToken!.isNotEmpty;
    final hasLocalToken = state.hasLocalToken;

    // Case C: Registered on server AND found locally on device
    if (isRegisteredOnServer && hasLocalToken) {
      return const SizedBox.shrink();
    }

    // Case B: Registered on server BUT NOT found locally on this device (reinstall/device change)
    if (isRegisteredOnServer && !hasLocalToken) {
      return Card(
        color: isDark ? const Color(0xFF2A2318) : Colors.orange.shade50,
        margin: const EdgeInsets.only(bottom: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.3) : Colors.orange.shade300,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: isDark ? const Color(0xFFC5A059) : Colors.orange.shade800, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Biometric Verification Mismatch',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                kIsWeb
                    ? 'Attendance is registered for another device. On iPhone/iPad Safari you can link this browser after Admin/HR resets your registration (this replaces the previous token).'
                    : 'Your fingerprint/Face ID is registered on the server, but not found on this device. '
                        'If you reinstalled the app or switched phones, re-register here or ask Admin/HR to reset.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF4A5568),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final dio = context.read<DioClient>();
                    final svc = GeofencedPunchService(dio);
                    final empId = auth.user?.employeeId;
                    if (empId != null) {
                      try {
                        await svc.registerBiometrics(context, empId);
                        if (context.mounted) {
                          context.read<AttendanceBloc>().add(AttendanceSettingsReloadRequested(empId));
                        }
                      } catch (_) {}
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC5A059),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(kIsWeb ? Icons.link_rounded : Icons.fingerprint_rounded),
                  label: const Text(
                    kIsWeb ? 'Link Safari' : 'Re-register on this device',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final empId = auth.user?.employeeId;
                    if (empId != null) {
                      context.read<AttendanceBloc>().add(AttendanceSettingsReloadRequested(empId));
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC5A059),
                    side: const BorderSide(color: Color(0xFFC5A059)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh Status', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Case A: Not registered on server at all
    return Card(
      color: isDark ? const Color(0xFF2A2318) : Colors.amber.shade50,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.3) : Colors.amber.shade200,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: isDark ? const Color(0xFFC5A059) : Colors.amber.shade800, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    kIsWeb ? 'Safari Setup Required' : 'Fingerprint/Face ID Setup Required',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF212F3D),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              kIsWeb
                  ? 'Register Safari once on this iPhone/iPad to enable geofenced punch in/out from the browser. Other browsers are blocked.'
                  : 'To mark your attendance using the mobile app, you must first register your fingerprint or Face ID.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF4A5568),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final dio = context.read<DioClient>();
                  final svc = GeofencedPunchService(dio);
                  final empId = auth.user?.employeeId;
                  if (empId != null) {
                    try {
                      await svc.registerBiometrics(context, empId);
                      if (context.mounted) {
                        context.read<AttendanceBloc>().add(AttendanceSettingsReloadRequested(empId));
                      }
                    } catch (e) {
                      // Handled inside registerBiometrics
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A059),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(kIsWeb ? Icons.verified_user_rounded : Icons.fingerprint_rounded),
                label: const Text(
                  kIsWeb ? 'Register Safari' : 'Set Fingerprint/Face ID Now',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    if (month < 1 || month > 12) return '';
    return names[month - 1];
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.daysInMonth,
    required this.firstWeekday,
    required this.year,
    required this.month,
    required this.calendar,
    required this.selectedDate,
    required this.onSelect,
  });

  final int daysInMonth;
  final int firstWeekday;
  final int year;
  final int month;
  final Map<String, AttendanceCalendarDay> calendar;
  final String? selectedDate;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const headers = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cells = <Widget>[
      for (final h in headers)
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              h,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF607D8B),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
    ];

    for (var i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final key = formatDateYmd(date);
      final summary = calendar[key];
      final selected = key == selectedDate;
      final hasPunches = summary != null && summary.count > 0;
      final isLeave = summary?.isLeave ?? false;
      final isHoliday = summary?.isHoliday ?? false;
      final isAbsent = summary?.isAbsent ?? false;

      Widget cellContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: selected
                  ? (isDark ? const Color(0xFF1A1816) : Colors.white)
                  : (isDark ? Colors.white : const Color(0xFF212F3D)),
            ),
          ),
          if (hasPunches) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: selected
                    ? (isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.2))
                    : (isDark ? const Color(0xFF2B2722) : const Color(0xFFECEFF1)),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : (isDark ? const Color(0xFFC5A059).withValues(alpha: 0.3) : const Color(0xFFCFD8DC)),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fingerprint_rounded,
                    size: 9,
                    color: selected
                        ? (isDark ? const Color(0xFF1A1816) : Colors.white)
                        : const Color(0xFFC5A059),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${summary.count}',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? (isDark ? const Color(0xFF1A1816) : Colors.white)
                          : (isDark ? Colors.white70 : const Color(0xFF263238)),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isLeave || isHoliday || isAbsent) ...[
            const SizedBox(height: 2),
            Text(
              isHoliday ? 'Holiday' : (isLeave ? 'Leave' : 'Absent'),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: selected
                    ? (isDark ? const Color(0xFF1A1816) : Colors.white)
                    : (isHoliday
                        ? Colors.purple.shade400
                        : isLeave
                            ? Colors.blue.shade400
                            : Colors.grey.shade600),
              ),
            ),
          ],
        ],
      );

      cells.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: InkWell(
            onTap: () => onSelect(key),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: selected
                    ? (isDark ? const Color(0xFFC5A059) : const Color(0xFF263238))
                    : (hasPunches
                        ? (isDark ? const Color(0xFF1E1B18) : Colors.white)
                        : isLeave
                            ? (isDark ? const Color(0xFF1A2233) : const Color(0xFFE3F2FD))
                            : isHoliday
                                ? (isDark ? const Color(0xFF221A30) : const Color(0xFFF3E5F5))
                                : isAbsent
                                    ? (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5))
                                    : (isDark ? const Color(0xFF151311) : const Color(0xFFF1F5F9))),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? (isDark ? const Color(0xFFC5A059) : const Color(0xFF263238))
                      : (hasPunches
                          ? (isDark ? const Color(0xFFC5A059).withValues(alpha: 0.2) : const Color(0xFFCFD8DC))
                          : isLeave
                              ? (isDark ? Colors.blue.withValues(alpha: 0.25) : Colors.blue.shade200)
                              : isHoliday
                                  ? (isDark ? Colors.purple.withValues(alpha: 0.25) : Colors.purple.shade100)
                                  : isAbsent
                                      ? (isDark ? Colors.grey.withValues(alpha: 0.25) : Colors.grey.shade300)
                                      : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03))),
                  width: selected ? 2.0 : 1.2,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: (isDark ? const Color(0xFFC5A059) : const Color(0xFF263238)).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: cellContent,
            ),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final gridWidth = screenWidth > 800 ? 800.0 : (screenWidth - 48).clamp(0.0, double.infinity);
    final cellWidth = gridWidth / 7;
    final targetHeight = cellWidth < 58.0 ? 58.0 : (cellWidth < 65.0 ? cellWidth : 65.0);
    final aspectRatio = cellWidth > 0 && targetHeight > 0 ? (cellWidth / targetHeight) : 1.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: aspectRatio,
          children: cells,
        ),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.day});

  final AttendanceMyDay day;

  @override
  Widget build(BuildContext context) {
    final summary = day.summary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLeave = summary.isLeave;
    final isHoliday = summary.isHoliday;
    final isAbsent = summary.isAbsent && !isLeave;

    // Convert total minutes to hours & minutes format
    final int hours = summary.totalMinutes ~/ 60;
    final int minutes = summary.totalMinutes % 60;
    final durationStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    // Compliance evaluation status flags (only meaningful when punched in)
    final isLate = summary.evaluation?.isLate ?? false;
    final isHalfDay = summary.evaluation?.isHalfDay ?? false;
    final meetsPunchOut = summary.evaluation?.meetsPunchOut ?? false;
    final leave = summary.leave;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? const Color(0xFF1E1B18) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFFC5A059).withValues(alpha: 0.15) : const Color(0xFFCFD8DC),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First In & Last Out split grid
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151311) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.login_rounded, size: 14, color: isLate ? Colors.orange : Colors.green),
                            const SizedBox(width: 6),
                            const Text(
                              'FIRST IN',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          summary.firstIn != null ? '${formatIsoTime(summary.firstIn)} IST' : '—',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF212F3D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151311) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 14, color: meetsPunchOut ? const Color(0xFFC5A059) : Colors.orange),
                            const SizedBox(width: 6),
                            const Text(
                              'LAST OUT',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          summary.lastOut != null ? '${formatIsoTime(summary.lastOut)} IST' : '—',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF212F3D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Duration metrics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Working Duration',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                  ),
                ),
                Text(
                  '$durationStr (${summary.totalMinutes} mins)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFC5A059) : const Color(0xFF263238),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 16),
            if (isHoliday) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade300, width: 1.2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.celebration_rounded, size: 18, color: Colors.purple.shade300),
                    const SizedBox(width: 8),
                    Text(
                      'HOLIDAY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.purple.shade300,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isLeave) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade400, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.beach_access_rounded, size: 18, color: Colors.blue.shade400),
                        const SizedBox(width: 8),
                        Text(
                          'ON APPROVED LEAVE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.blue.shade400,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    if (leave?.leaveTypeName != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        leave!.leaveTypeName!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF212F3D),
                        ),
                      ),
                    ],
                    if (leave?.applicationNo != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Application ${leave!.applicationNo}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (isAbsent) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.grey, width: 1.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'ABSENT (NO PUNCH)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white54 : Colors.grey.shade700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ] else ...[
            // Evaluation Status Pill tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Late Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLate ? Colors.red.withValues(alpha: 0.12) : Colors.green.withValues(alpha: 0.12),
                    border: Border.all(color: isLate ? Colors.red : Colors.green, width: 1.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    isLate ? 'LATE IN' : 'ON TIME',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isLate ? Colors.red : Colors.green,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Half Day Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHalfDay ? Colors.orange.withValues(alpha: 0.12) : Colors.green.withValues(alpha: 0.12),
                    border: Border.all(color: isHalfDay ? Colors.orange : Colors.green, width: 1.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    isHalfDay ? 'HALF DAY' : 'FULL DAY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isHalfDay ? Colors.orange : Colors.green,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // meetsPunchOut Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: meetsPunchOut ? Colors.green.withValues(alpha: 0.12) : Colors.amber.withValues(alpha: 0.12),
                    border: Border.all(color: meetsPunchOut ? Colors.green : Colors.amber, width: 1.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    meetsPunchOut ? 'OUT PUNCH COMPLIANT' : 'MISSING OUT PUNCH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: meetsPunchOut ? Colors.green : Colors.amber,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            ],
            const SizedBox(height: 24),
            Text(
              'PUNCH HISTORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            if (day.punches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  isLeave
                      ? 'No punches — marked as approved leave.'
                      : 'No punches recorded for this day.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white30 : const Color(0xFF607D8B).withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              ...day.punches.map(
                (p) {
                  final type = p.punchType?.toUpperCase() ?? 'IN';
                  final isOut = type == 'OUT';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151311) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(
                          color: isOut ? const Color(0xFFC5A059) : Colors.green,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.fingerprint_rounded,
                          color: isOut ? const Color(0xFFC5A059) : Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${formatIsoTime(p.punchAt)} IST',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : const Color(0xFF212F3D),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [p.punchType, p.terminalId, p.source]
                                    .whereType<String>()
                                    .where((s) => s.isNotEmpty)
                                    .join(' • '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                                ),
                              ),
                              if (p.reason != null && p.reason!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Reason: ${p.reason}',
                                    style: TextStyle(
                                      color: isDark ? Colors.orange.shade300 : Colors.deepOrange.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (p.latitude != null && p.longitude != null)
                          IconButton(
                            icon: const Icon(Icons.map_rounded, color: Colors.blue),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => _PunchMapDialog(punch: p, employeeName: 'Me'),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceWorkspaceTile extends StatelessWidget {
  const _AttendanceWorkspaceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B18) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFC5A059).withValues(alpha: 0.15)
                  : const Color(0xFFCFD8DC),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF212F3D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF607D8B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PunchMapDialog extends StatelessWidget {
  final AttendancePunch punch;
  final String employeeName;

  const _PunchMapDialog({required this.punch, required this.employeeName});

  @override
  Widget build(BuildContext context) {
    final lat = punch.latitude!;
    final lng = punch.longitude!;
    final locRadius = punch.location != null ? (punch.location!['radiusKm'] * 1000).toDouble() : 100.0;
    final locLat = punch.location != null ? punch.location!['latitude'] : lat;
    final locLng = punch.location != null ? punch.location!['longitude'] : lng;

    return AlertDialog(
      title: Text('Punch Location: $employeeName'),
      content: SizedBox(
        width: 400,
        height: 300,
        child: RepaintBoundary(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(lat, lng),
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.nbdeveloper.hrms',
              ),
              if (punch.location != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(locLat, locLng),
                      color: Colors.blue.withValues(alpha: 0.3),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                      useRadiusInMeter: true,
                      radius: locRadius,
                    )
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(lat, lng),
                    width: 60,
                    height: 60,
                    child: const Column(
                      children: [
                        Icon(Icons.person_pin_circle_rounded, color: Colors.red, size: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Today's date as `YYYY-MM-DD` in IST (Asia/Kolkata).
String _attendanceTodayYmdIst() {
  final ist = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  return formatDateYmd(DateTime(ist.year, ist.month, ist.day));
}
