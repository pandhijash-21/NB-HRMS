import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vector icon that does not use the Material icon font.
///
/// Flutter web subsets `MaterialIcons`, so many `Icon(Icons.*)` calls render as
/// empty boxes (Chat, Meet, Reimbursements, Recruitment, sidebar Profile/Tree).
/// These are painted with [Canvas] so they always show.
class NbIcon extends StatelessWidget {
  const NbIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.textDirection,
    this.shadows,
    this.applyTextScaling,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final TextDirection? textDirection;
  final List<Shadow>? shadows;
  final bool? applyTextScaling;

  static IconData data(IconData icon) => icon;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24;
    final resolvedColor = color ?? iconTheme.color ?? const Color(0xFF111111);
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: resolvedSize,
        height: resolvedSize,
        child: CustomPaint(
          painter: _NbGlyphPainter(icon: icon, color: resolvedColor),
        ),
      ),
    );
  }
}

class _NbGlyphPainter extends CustomPainter {
  const _NbGlyphPainter({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final key = _key(icon);
    switch (key) {
      case 'home':
        _home(canvas, fill);
      case 'tree':
        _tree(canvas, fill);
      case 'person':
        _person(canvas, fill);
      case 'people':
        _people(canvas, fill);
      case 'task':
        _task(canvas, fill);
      case 'chat':
        _chat(canvas, fill);
      case 'video':
        _video(canvas, fill);
      case 'calendar':
        _calendar(canvas, fill);
      case 'finger':
        _finger(canvas, stroke);
      case 'receipt':
        _receipt(canvas, fill);
      case 'work':
        _work(canvas, fill);
      case 'folder':
        _folder(canvas, fill);
      case 'pay':
        _pay(canvas, fill);
      case 'dash':
        _dash(canvas, fill);
      case 'accounts':
        _accounts(canvas, fill);
      case 'shield':
        _shield(canvas, fill);
      case 'tune':
        _tune(canvas, fill);
      case 'history':
        _history(canvas, stroke, fill);
      case 'search':
        _search(canvas, stroke);
      case 'clear':
        _clear(canvas, stroke);
      case 'arrow':
        _arrow(canvas, fill);
      case 'logout':
        _logout(canvas, stroke);
      case 'sun':
        _sun(canvas, fill, stroke);
      case 'moon':
        _moon(canvas, fill);
      case 'location':
        _pin(canvas, fill);
      case 'route':
        _route(canvas, stroke, fill);
      case 'insights':
        _insights(canvas, fill);
      case 'building':
        _building(canvas, fill);
      case 'settings':
        _settings(canvas, fill);
      case 'apps':
        _apps(canvas, fill);
      case 'close':
        _clear(canvas, stroke);
      case 'check':
        _check(canvas, stroke);
      case 'send':
        _send(canvas, fill);
      case 'call':
        _call(canvas, fill);
      case 'phone':
        _call(canvas, fill);
      case 'add':
        _add(canvas, stroke);
      case 'back':
        _back(canvas, fill);
      case 'menu':
        _menu(canvas, stroke);
      default:
        _fallback(canvas, fill, key);
    }
    canvas.restore();
  }

  String _key(IconData icon) {
    bool hit(List<IconData> icons) =>
        icons.any((e) => e.codePoint == icon.codePoint);
    if (hit(const [Icons.home, Icons.home_outlined, Icons.home_rounded])) {
      return 'home';
    }
    if (hit(const [
      Icons.account_tree,
      Icons.account_tree_outlined,
      Icons.account_tree_rounded,
    ])) {
      return 'tree';
    }
    if (hit(const [
      Icons.person,
      Icons.person_outline,
      Icons.person_rounded,
    ])) {
      return 'person';
    }
    if (hit(const [
      Icons.people,
      Icons.people_outline,
      Icons.people_rounded,
      Icons.groups,
      Icons.groups_rounded,
    ])) {
      return 'people';
    }
    if (hit(const [
      Icons.task_alt,
      Icons.task_alt_outlined,
      Icons.task_alt_rounded,
      Icons.check_circle,
      Icons.check_circle_rounded,
      Icons.assignment_turned_in,
      Icons.assignment_turned_in_outlined,
      Icons.assignment_turned_in_rounded,
    ])) {
      return 'task';
    }
    if (hit(const [
      Icons.chat_bubble,
      Icons.chat_bubble_outline,
      Icons.chat_bubble_rounded,
      Icons.chat_bubble_outline_rounded,
    ])) {
      return 'chat';
    }
    if (hit(const [
      Icons.videocam,
      Icons.videocam_outlined,
      Icons.videocam_rounded,
      Icons.videocam_off_outlined,
      Icons.videocam_off_rounded,
    ])) {
      return 'video';
    }
    if (hit(const [
      Icons.event_available,
      Icons.event_available_outlined,
      Icons.event_available_rounded,
      Icons.calendar_today,
      Icons.calendar_today_rounded,
      Icons.calendar_month_rounded,
      Icons.event,
      Icons.event_rounded,
    ])) {
      return 'calendar';
    }
    if (hit(const [
      Icons.fingerprint,
      Icons.fingerprint_outlined,
      Icons.fingerprint_rounded,
    ])) {
      return 'finger';
    }
    if (hit(const [Icons.receipt_long, Icons.receipt_long_outlined, Icons.receipt_long_rounded])) {
      return 'receipt';
    }
    if (hit(const [Icons.work_outline, Icons.work_outline_rounded, Icons.work_rounded])) {
      return 'work';
    }
    if (hit(const [Icons.folder_shared_rounded, Icons.folder_open_rounded])) {
      return 'folder';
    }
    if (hit(const [Icons.payments_rounded, Icons.payments_outlined])) {
      return 'pay';
    }
    if (hit(const [Icons.dashboard, Icons.dashboard_outlined, Icons.dashboard_rounded])) {
      return 'dash';
    }
    if (hit(const [
      Icons.manage_accounts,
      Icons.manage_accounts_outlined,
      Icons.manage_accounts_rounded,
    ])) {
      return 'accounts';
    }
    if (hit(const [Icons.shield, Icons.shield_outlined, Icons.shield_rounded])) {
      return 'shield';
    }
    if (hit(const [Icons.tune_rounded, Icons.tune])) {
      return 'tune';
    }
    if (hit(const [
      Icons.history_edu_rounded,
      Icons.history_edu_outlined,
      Icons.history_rounded,
      Icons.history,
    ])) {
      return 'history';
    }
    if (hit(const [Icons.search, Icons.search_rounded, Icons.search_off_rounded])) {
      return 'search';
    }
    if (hit(const [Icons.clear, Icons.clear_rounded, Icons.close, Icons.close_rounded])) {
      return 'clear';
    }
    if (hit(const [Icons.arrow_forward_rounded, Icons.chevron_right, Icons.chevron_right_rounded])) {
      return 'arrow';
    }
    if (hit(const [Icons.logout, Icons.logout_rounded])) {
      return 'logout';
    }
    if (hit(const [Icons.light_mode, Icons.light_mode_rounded])) {
      return 'sun';
    }
    if (hit(const [Icons.dark_mode, Icons.dark_mode_rounded])) {
      return 'moon';
    }
    if (hit(const [Icons.location_on, Icons.location_on_outlined])) {
      return 'location';
    }
    if (hit(const [Icons.route, Icons.route_outlined])) {
      return 'route';
    }
    if (hit(const [Icons.insights, Icons.insights_outlined])) {
      return 'insights';
    }
    if (hit(const [Icons.apartment, Icons.apartment_outlined, Icons.apartment_rounded])) {
      return 'building';
    }
    if (hit(const [Icons.settings, Icons.settings_outlined, Icons.settings_rounded])) {
      return 'settings';
    }
    if (hit(const [Icons.apps_rounded])) {
      return 'apps';
    }
    if (hit(const [Icons.check_rounded, Icons.done, Icons.done_all])) {
      return 'check';
    }
    if (hit(const [Icons.send, Icons.send_rounded])) {
      return 'send';
    }
    if (hit(const [Icons.call, Icons.call_rounded, Icons.phone, Icons.phone_rounded])) {
      return 'call';
    }
    if (hit(const [Icons.add, Icons.add_rounded, Icons.add_circle_outline_rounded])) {
      return 'add';
    }
    if (hit(const [Icons.arrow_back, Icons.arrow_back_rounded, Icons.chevron_left, Icons.chevron_left_rounded])) {
      return 'back';
    }
    if (hit(const [Icons.menu_rounded, Icons.menu_open_rounded])) {
      return 'menu';
    }
    return 'fallback';
  }

  void _home(Canvas c, Paint p) {
    final path = Path()
      ..moveTo(12, 3)
      ..lineTo(3, 12)
      ..lineTo(6, 12)
      ..lineTo(6, 20)
      ..lineTo(10, 20)
      ..lineTo(10, 14)
      ..lineTo(14, 14)
      ..lineTo(14, 20)
      ..lineTo(18, 20)
      ..lineTo(18, 12)
      ..lineTo(21, 12)
      ..close();
    c.drawPath(path, p);
  }

  void _tree(Canvas c, Paint p) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, 3, 6, 5), const Radius.circular(1.2)), p);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(15, 3, 6, 5), const Radius.circular(1.2)), p);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(9, 16, 6, 5), const Radius.circular(1.2)), p);
    final s = Paint()
      ..color = p.color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(6, 8), const Offset(6, 11), s);
    c.drawLine(const Offset(18, 8), const Offset(18, 11), s);
    c.drawLine(const Offset(6, 11), const Offset(18, 11), s);
    c.drawLine(const Offset(12, 11), const Offset(12, 16), s);
  }

  void _person(Canvas c, Paint p) {
    c.drawCircle(const Offset(12, 8), 3.6, p);
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(5, 13.5, 14, 7.5), const Radius.circular(6)),
      p,
    );
  }

  void _people(Canvas c, Paint p) {
    c.drawCircle(const Offset(8, 8), 2.6, p);
    c.drawCircle(const Offset(16, 8), 2.6, p);
    c.drawCircle(const Offset(12, 14.5), 2.8, p);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3.5, 17.2, 9, 4.2), const Radius.circular(4)), p);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(11.5, 17.2, 9, 4.2), const Radius.circular(4)), p);
  }

  void _task(Canvas c, Paint p) {
    final ring = Paint()
      ..color = p.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..isAntiAlias = true;
    c.drawCircle(const Offset(12, 12), 8.2, ring);
    final check = Paint()
      ..color = p.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
      Path()
        ..moveTo(7.6, 12.2)
        ..lineTo(10.6, 15.3)
        ..lineTo(16.8, 8.6),
      check,
    );
  }

  void _chat(Canvas c, Paint p) {
    final bubble = Path()
      ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, 3.5, 18, 13), const Radius.circular(4)))
      ..moveTo(7, 16.5)
      ..lineTo(7, 21)
      ..lineTo(12, 16.5)
      ..close();
    c.drawPath(bubble, p);
  }

  void _video(Canvas c, Paint p) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(2.5, 7, 13.5, 10), const Radius.circular(2.2)), p);
    final lens = Path()
      ..moveTo(16, 9.5)
      ..lineTo(21.5, 7)
      ..lineTo(21.5, 17)
      ..lineTo(16, 14.5)
      ..close();
    c.drawPath(lens, p);
  }

  void _calendar(Canvas c, Paint p) {
    final s = Paint()
      ..color = p.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(4, 5.5, 16, 14.5), const Radius.circular(2.5)), s);
    c.drawLine(const Offset(4, 10), const Offset(20, 10), s);
    c.drawRRect(RRect.fromLTRBR(7, 3, 9, 7.5, const Radius.circular(0.8)), p);
    c.drawRRect(RRect.fromLTRBR(15, 3, 17, 7.5, const Radius.circular(0.8)), p);
    c.drawCircle(const Offset(9, 14.5), 1.2, p);
    c.drawCircle(const Offset(15, 14.5), 1.2, p);
  }

  void _finger(Canvas c, Paint s) {
    c.drawArc(const Rect.fromLTWH(7, 6, 10, 12), -3.2, 3.6, false, s);
    c.drawArc(const Rect.fromLTWH(8.5, 8, 7, 10), -3.0, 3.4, false, s);
    c.drawArc(const Rect.fromLTWH(10, 10, 4, 8), -2.8, 3.1, false, s);
  }

  void _receipt(Canvas c, Paint fill) {
    final s = Paint()
      ..color = fill.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    final body = Path()
      ..moveTo(7, 3.5)
      ..lineTo(17, 3.5)
      ..lineTo(17, 20.5)
      ..lineTo(15.4, 19)
      ..lineTo(13.8, 20.5)
      ..lineTo(12, 19)
      ..lineTo(10.2, 20.5)
      ..lineTo(8.6, 19)
      ..lineTo(7, 20.5)
      ..close();
    c.drawPath(body, s);
    c.drawLine(const Offset(9, 8), const Offset(15, 8), s);
    c.drawLine(const Offset(9, 11), const Offset(15, 11), s);
    c.drawLine(const Offset(9, 14), const Offset(13.5, 14), s);
  }

  void _work(Canvas c, Paint p) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, 9, 18, 11), const Radius.circular(2)), p);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(9, 5, 6, 4), const Radius.circular(1.2)), p);
  }

  void _folder(Canvas c, Paint p) {
    final path = Path()
      ..moveTo(3, 7)
      ..lineTo(9, 7)
      ..lineTo(11, 9)
      ..lineTo(21, 9)
      ..lineTo(21, 19)
      ..lineTo(3, 19)
      ..close();
    c.drawPath(path, p);
  }

  void _pay(Canvas c, Paint p) {
    final s = Paint()
      ..color = p.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, 6, 18, 12), const Radius.circular(2)), s);
    c.drawCircle(const Offset(12, 12), 2.3, s);
  }

  void _dash(Canvas c, Paint p) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, 3, 8, 8), const Radius.circular(1.5)), p);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(13, 3, 8, 5), const Radius.circular(1.5)), p);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, 13, 8, 8), const Radius.circular(1.5)), p);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(13, 10, 8, 11), const Radius.circular(1.5)), p);
  }

  void _accounts(Canvas c, Paint p) {
    _person(c, p);
    c.drawCircle(const Offset(18, 17), 3.4, p);
  }

  void _shield(Canvas c, Paint p) {
    final path = Path()
      ..moveTo(12, 3)
      ..lineTo(5, 6)
      ..lineTo(5, 12)
      ..quadraticBezierTo(5, 18, 12, 21)
      ..quadraticBezierTo(19, 18, 19, 12)
      ..lineTo(19, 6)
      ..close();
    c.drawPath(path, p);
  }

  void _tune(Canvas c, Paint p) {
    c.drawRRect(RRect.fromLTRBR(4, 6, 20, 8.2, const Radius.circular(1)), p);
    c.drawRRect(RRect.fromLTRBR(4, 11, 20, 13.2, const Radius.circular(1)), p);
    c.drawRRect(RRect.fromLTRBR(4, 16, 20, 18.2, const Radius.circular(1)), p);
    c.drawCircle(const Offset(9, 7.1), 2.1, p);
    c.drawCircle(const Offset(15, 12.1), 2.1, p);
    c.drawCircle(const Offset(11, 17.1), 2.1, p);
  }

  void _history(Canvas c, Paint stroke, Paint fill) {
    c.drawCircle(const Offset(12, 13), 7.5, stroke);
    c.drawLine(const Offset(12, 13), const Offset(12, 9), stroke);
    c.drawLine(const Offset(12, 13), const Offset(15.5, 15), stroke);
    c.drawRRect(RRect.fromLTRBR(8, 3.5, 16, 6, const Radius.circular(1)), fill);
  }

  void _search(Canvas c, Paint s) {
    c.drawCircle(const Offset(10.5, 10.5), 5.5, s);
    c.drawLine(const Offset(14.8, 14.8), const Offset(20, 20), s);
  }

  void _clear(Canvas c, Paint s) {
    c.drawLine(const Offset(7, 7), const Offset(17, 17), s);
    c.drawLine(const Offset(17, 7), const Offset(7, 17), s);
  }

  void _arrow(Canvas c, Paint p) {
    final path = Path()
      ..moveTo(8, 5)
      ..lineTo(16, 12)
      ..lineTo(8, 19)
      ..lineTo(8, 15)
      ..lineTo(4, 15)
      ..lineTo(4, 9)
      ..lineTo(8, 9)
      ..close();
    c.drawPath(path, p);
  }

  void _logout(Canvas c, Paint s) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, 5, 10, 14), const Radius.circular(1.5)), s);
    c.drawLine(const Offset(12, 12), const Offset(21, 12), s);
    final head = Path()
      ..moveTo(17.5, 8)
      ..lineTo(21.5, 12)
      ..lineTo(17.5, 16);
    c.drawPath(head, s);
  }

  void _sun(Canvas c, Paint fill, Paint stroke) {
    c.drawCircle(const Offset(12, 12), 4, fill);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawLine(
        Offset(12 + math.cos(a) * 6.5, 12 + math.sin(a) * 6.5),
        Offset(12 + math.cos(a) * 9.5, 12 + math.sin(a) * 9.5),
        stroke,
      );
    }
  }

  void _moon(Canvas c, Paint p) {
    final path = Path()
      ..addOval(const Rect.fromLTWH(6, 4.5, 13, 15))
      ..addOval(const Rect.fromLTWH(10.5, 4, 11, 13));
    path.fillType = PathFillType.evenOdd;
    c.drawPath(path, p);
  }

  void _pin(Canvas c, Paint p) {
    final path = Path()
      ..moveTo(12, 21)
      ..quadraticBezierTo(6, 14, 6, 10)
      ..arcToPoint(const Offset(18, 10), radius: const Radius.circular(6), clockwise: true)
      ..quadraticBezierTo(18, 14, 12, 21);
    path.fillType = PathFillType.evenOdd;
    path.addOval(const Rect.fromLTWH(9.6, 7.6, 4.8, 4.8));
    c.drawPath(path, p);
  }

  void _route(Canvas c, Paint s, Paint fill) {
    c.drawCircle(const Offset(7, 7), 2.2, fill);
    c.drawCircle(const Offset(17, 17), 2.2, fill);
    c.drawLine(const Offset(8.5, 8.5), const Offset(15.5, 15.5), s);
  }

  void _insights(Canvas c, Paint p) {
    c.drawRRect(RRect.fromLTRBR(4, 14, 8, 20, const Radius.circular(1)), p);
    c.drawRRect(RRect.fromLTRBR(10, 10, 14, 20, const Radius.circular(1)), p);
    c.drawRRect(RRect.fromLTRBR(16, 6, 20, 20, const Radius.circular(1)), p);
  }

  void _building(Canvas c, Paint p) {
    final s = Paint()
      ..color = p.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    c.drawRRect(RRect.fromLTRBR(5, 4, 19, 21, const Radius.circular(1.2)), s);
    for (final x in [8.0, 12.0, 16.0]) {
      for (final y in [8.0, 12.0, 16.0]) {
        c.drawRect(Rect.fromCenter(center: Offset(x, y), width: 1.8, height: 2.2), p);
      }
    }
  }

  void _settings(Canvas c, Paint p) {
    c.drawCircle(const Offset(12, 12), 3.2, p);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      c.save();
      c.translate(12, 12);
      c.rotate(a);
      c.drawRRect(RRect.fromLTRBR(-1.4, -10, 1.4, -5.5, const Radius.circular(0.6)), p);
      c.restore();
    }
  }

  void _apps(Canvas c, Paint p) {
    for (final x in [4.0, 10.5, 17.0]) {
      for (final y in [4.0, 10.5, 17.0]) {
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 4.2, 4.2), const Radius.circular(1)),
          p,
        );
      }
    }
  }

  void _check(Canvas c, Paint s) {
    final path = Path()
      ..moveTo(5, 12)
      ..lineTo(10, 17)
      ..lineTo(19, 7);
    c.drawPath(path, s);
  }

  void _send(Canvas c, Paint p) {
    final path = Path()
      ..moveTo(3, 21)
      ..lineTo(21, 12)
      ..lineTo(3, 3)
      ..lineTo(3, 10)
      ..lineTo(15, 12)
      ..lineTo(3, 14)
      ..close();
    c.drawPath(path, p);
  }

  void _call(Canvas c, Paint p) {
    final path = Path()
      ..moveTo(6.5, 3.5)
      ..lineTo(9.5, 3.5)
      ..lineTo(10.8, 8)
      ..lineTo(8.8, 9.2)
      ..quadraticBezierTo(10.5, 13, 14.5, 14.8)
      ..lineTo(15.8, 12.8)
      ..lineTo(20.5, 14.2)
      ..lineTo(20.5, 17.2)
      ..quadraticBezierTo(10, 22, 4.5, 10.5)
      ..close();
    c.drawPath(path, p);
  }

  void _add(Canvas c, Paint s) {
    c.drawLine(const Offset(12, 5), const Offset(12, 19), s);
    c.drawLine(const Offset(5, 12), const Offset(19, 12), s);
  }

  void _back(Canvas c, Paint p) {
    final path = Path()
      ..moveTo(16, 5)
      ..lineTo(8, 12)
      ..lineTo(16, 19)
      ..lineTo(16, 15)
      ..lineTo(20, 15)
      ..lineTo(20, 9)
      ..lineTo(16, 9)
      ..close();
    c.drawPath(path, p);
  }

  void _menu(Canvas c, Paint s) {
    c.drawLine(const Offset(5, 7), const Offset(19, 7), s);
    c.drawLine(const Offset(5, 12), const Offset(19, 12), s);
    c.drawLine(const Offset(5, 17), const Offset(19, 17), s);
  }

  void _fallback(Canvas c, Paint p, String key) {
    final s = Paint()
      ..color = p.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(4, 4, 16, 16), const Radius.circular(4)), s);
    c.drawLine(const Offset(8, 12), const Offset(16, 12), s);
  }

  @override
  bool shouldRepaint(covariant _NbGlyphPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;
}
