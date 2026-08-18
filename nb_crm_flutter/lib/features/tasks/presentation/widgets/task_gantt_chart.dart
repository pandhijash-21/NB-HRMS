import 'package:flutter/material.dart';

import '../../domain/task_models.dart';

const _labelWidth = 148.0;
const _avatarWidth = 44.0;
const _minDayWidth = 28.0;
const _weekHeaderH = 26.0;
const _dayLetterH = 20.0;
const _dayNumH = 22.0;
const _groupH = 30.0;
const _rowH = 34.0;

const _weekPalette = <Color>[
  Color(0xFF7ECDE0),
  Color(0xFF4BA8D4),
  Color(0xFF3B7FBF),
  Color(0xFF6B5B9A),
  Color(0xFF4A3B7A),
  Color(0xFF3A2A62),
];

const _navy = Color(0xFF1C3554);
const _labelFill = Color(0xFFE4EAF0);
const _labelText = Color(0xFF3A6B9A);
const _gridLine = Color(0xFFFFFFFF);
const _gold = Color(0xFFC5A059);
const _assignOrange = Color(0xFFE07A3D);

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class TaskGanttChart extends StatefulWidget {
  const TaskGanttChart({super.key, required this.tasks, this.onSelect});

  final List<WorkTask> tasks;
  final ValueChanged<WorkTask>? onSelect;

  @override
  State<TaskGanttChart> createState() => _TaskGanttChartState();
}

class _TaskGanttChartState extends State<TaskGanttChart> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  Future<void> _pickMonth() async {
    var year = _month.year;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Jump to month'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => setLocal(() => year--),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Text('$year', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        IconButton(
                          onPressed: () => setLocal(() => year++),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var m = 1; m <= 12; m++)
                          ChoiceChip(
                            label: Text(_monthShort[m - 1]),
                            selected: year == _month.year && m == _month.month,
                            onSelected: (_) => Navigator.pop(ctx, DateTime(year, m)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ],
            );
          },
        );
      },
    );
    if (picked != null && mounted) setState(() => _month = DateTime(picked.year, picked.month));
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _weeksForMonth(_month);
    final visible = widget.tasks.where((t) => _overlapsMonth(t, _month)).toList();
    final groups = _groupByAssignee(visible);
    final marks = _DayMarks.fromTasks(widget.tasks);
    final dayCount = weeks.fold<int>(0, (n, w) => n + w.days.length).clamp(1, 62);
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Timeline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            _MonthNav(
              month: _month,
              isCurrent: isCurrentMonth,
              onPrev: () => _shift(-1),
              onNext: () => _shift(1),
              onTitle: _pickMonth,
              onToday: () => setState(() => _month = DateTime(now.year, now.month)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Full month · workdays only. Gold = today, orange = assigned, navy = deadline.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        const _Legend(),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final available = (constraints.maxWidth - _labelWidth - _avatarWidth).clamp(80.0, 8000.0);
              final dayWidth = available / dayCount < _minDayWidth ? _minDayWidth : available / dayCount;
              final chartWidth = dayCount * dayWidth;
              final totalWidth = _labelWidth + chartWidth + _avatarWidth;
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDE3EA)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: totalWidth < constraints.maxWidth ? constraints.maxWidth : totalWidth,
                      child: Column(
                        children: [
                          _WeekHeader(weeks: weeks, month: _month, dayWidth: dayWidth),
                          _DayLetterHeader(weeks: weeks, month: _month, dayWidth: dayWidth),
                          _DayNumberHeader(weeks: weeks, month: _month, marks: marks, dayWidth: dayWidth),
                          Expanded(
                            child: groups.isEmpty
                                ? const _EmptyMonth()
                                : ListView(
                                    children: [
                                      for (var g = 0; g < groups.length; g++) ...[
                                        _GroupHeader(title: groups[g].title, chartWidth: chartWidth),
                                        for (final task in groups[g].tasks)
                                          _ActivityRow(
                                            task: task,
                                            weeks: weeks,
                                            month: _month,
                                            chartWidth: chartWidth,
                                            dayWidth: dayWidth,
                                            onTap: widget.onSelect == null ? null : () => widget.onSelect!(task),
                                          ),
                                      ],
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.month,
    required this.isCurrent,
    required this.onPrev,
    required this.onNext,
    required this.onTitle,
    required this.onToday,
  });

  final DateTime month;
  final bool isCurrent;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTitle;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        InkWell(
          onTap: onTitle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              '${_monthNames[month.month - 1]} ${month.year}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _navy),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        if (!isCurrent)
          TextButton(onPressed: onToday, child: const Text('Today')),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ],
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        item(_gold, 'Today'),
        item(_assignOrange, 'Assigned'),
        item(_navy, 'Deadline'),
        item(const Color(0xFF7ECDE0), 'In progress'),
      ],
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No tasks in this month. Switch months, or assign one.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ),
    );
  }
}

class _DayMarks {
  const _DayMarks({required this.busy, required this.assigned, required this.deadlines});

  final Set<DateTime> busy;
  final Set<DateTime> assigned;
  final Set<DateTime> deadlines;

  factory _DayMarks.fromTasks(List<WorkTask> tasks) {
    final busy = <DateTime>{};
    final assigned = <DateTime>{};
    final deadlines = <DateTime>{};
    for (final t in tasks) {
      final start = _dateOnly(t.createdAt);
      final end = _dateOnly(t.deadline);
      assigned.add(start);
      deadlines.add(end);
      var d = start;
      while (!d.isAfter(end)) {
        if (!_isWeekend(d)) busy.add(d);
        d = d.add(const Duration(days: 1));
      }
    }
    return _DayMarks(busy: busy, assigned: assigned, deadlines: deadlines);
  }
}

class _AssigneeGroup {
  const _AssigneeGroup({required this.title, required this.tasks});
  final String title;
  final List<WorkTask> tasks;
}

List<_AssigneeGroup> _groupByAssignee(List<WorkTask> tasks) {
  final order = <String>[];
  final map = <String, List<WorkTask>>{};
  for (final t in tasks) {
    final key = t.assignee.id.isEmpty ? t.assignee.name : t.assignee.id;
    if (!map.containsKey(key)) {
      order.add(key);
      map[key] = [];
    }
    map[key]!.add(t);
  }
  return [
    for (var i = 0; i < order.length; i++)
      _AssigneeGroup(
        title: 'Task ${i + 1}  ·  ${map[order[i]]!.first.assignee.name}',
        tasks: map[order[i]]!,
      ),
  ];
}

class _Week {
  const _Week({required this.days, required this.color});
  final List<DateTime> days;
  final Color color;
}

DateTime _dateOnly(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

DateTime _mondayOnOrBefore(DateTime d) {
  final x = _dateOnly(d);
  return x.subtract(Duration(days: x.weekday - DateTime.monday));
}

DateTime _fridayOnOrAfter(DateTime d) {
  final x = _dateOnly(d);
  if (x.weekday == DateTime.saturday) return x.add(const Duration(days: 6));
  if (x.weekday == DateTime.sunday) return x.add(const Duration(days: 5));
  return x.add(Duration(days: DateTime.friday - x.weekday));
}

bool _isWeekend(DateTime d) =>
    d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

bool _sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

bool _overlapsMonth(WorkTask t, DateTime month) {
  final start = _dateOnly(t.createdAt);
  final end = _dateOnly(t.deadline);
  final monthStart = DateTime(month.year, month.month, 1);
  final monthEnd = DateTime(month.year, month.month + 1, 0);
  return !end.isBefore(monthStart) && !start.isAfter(monthEnd);
}

List<_Week> _weeksForMonth(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final last = DateTime(month.year, month.month + 1, 0);
  var cursor = _mondayOnOrBefore(first);
  final end = _fridayOnOrAfter(last);
  final weeks = <_Week>[];
  var colorI = 0;
  while (!cursor.isAfter(end)) {
    final days = <DateTime>[];
    for (var i = 0; i < 7; i++) {
      final d = cursor.add(Duration(days: i));
      if (!d.isAfter(end) && !_isWeekend(d)) days.add(d);
    }
    if (days.isNotEmpty) {
      weeks.add(_Week(days: days, color: _weekPalette[colorI % _weekPalette.length]));
      colorI++;
    }
    cursor = cursor.add(const Duration(days: 7));
  }
  return weeks;
}

String _weekLabel(List<DateTime> days, DateTime month) {
  final inMonth = days.where((d) => _sameMonth(d, month)).toList();
  final use = inMonth.isEmpty ? days : inMonth;
  final a = use.first;
  final b = use.last;
  if (a.month == b.month) return '${_monthShort[a.month - 1]} ${a.day}–${b.day}';
  return '${_monthShort[a.month - 1]} ${a.day}–${_monthShort[b.month - 1]} ${b.day}';
}

const _dayLetters = {1: 'M', 2: 'T', 3: 'W', 4: 'T', 5: 'F'};

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final s = parts.first;
    return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.weeks, required this.month, required this.dayWidth});
  final List<_Week> weeks;
  final DateTime month;
  final double dayWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _weekHeaderH,
      child: Row(
        children: [
          const SizedBox(width: _labelWidth),
          ...weeks.map(
            (w) => Container(
              width: w.days.length * dayWidth,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE9EDF1),
                border: Border(
                  bottom: BorderSide(color: w.color, width: 3),
                  right: const BorderSide(color: Colors.white, width: 2),
                ),
              ),
              child: Text(
                _weekLabel(w.days, month),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4A5563)),
              ),
            ),
          ),
          const SizedBox(width: _avatarWidth),
        ],
      ),
    );
  }
}

class _DayLetterHeader extends StatelessWidget {
  const _DayLetterHeader({required this.weeks, required this.month, required this.dayWidth});
  final List<_Week> weeks;
  final DateTime month;
  final double dayWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _dayLetterH,
      child: Row(
        children: [
          const SizedBox(width: _labelWidth),
          ...weeks.expand(
            (w) => w.days.map((d) {
              final inMonth = _sameMonth(d, month);
              return Container(
                width: dayWidth,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: w.color.withValues(alpha: inMonth ? 0.55 : 0.18),
                  border: const Border(right: BorderSide(color: _gridLine, width: 1)),
                ),
                child: Text(
                  _dayLetters[d.weekday] ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: inMonth ? _navy : _navy.withValues(alpha: 0.35),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(width: _avatarWidth),
        ],
      ),
    );
  }
}

class _DayNumberHeader extends StatelessWidget {
  const _DayNumberHeader({required this.weeks, required this.month, required this.marks, required this.dayWidth});

  final List<_Week> weeks;
  final DateTime month;
  final _DayMarks marks;
  final double dayWidth;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    return SizedBox(
      height: _dayNumH,
      child: Row(
        children: [
          const SizedBox(width: _labelWidth),
          ...weeks.expand(
            (w) => w.days.map((d) {
              final inMonth = _sameMonth(d, month);
              final isToday = d == today;
              final isAssigned = marks.assigned.contains(d);
              final isDeadline = marks.deadlines.contains(d);
              final isBusy = marks.busy.contains(d);
              Color bg = Colors.white;
              Color fg = inMonth ? const Color(0xFF334155) : const Color(0xFF94A3B8);
              if (isBusy && inMonth) bg = w.color.withValues(alpha: 0.22);
              if (isAssigned) {
                bg = _assignOrange.withValues(alpha: 0.22);
                fg = const Color(0xFF9A3412);
              }
              if (isDeadline) {
                bg = _navy.withValues(alpha: 0.16);
                fg = _navy;
              }
              if (isToday) {
                bg = _gold.withValues(alpha: 0.35);
                fg = const Color(0xFF7A5A20);
              }
              return Container(
                width: dayWidth,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  border: Border(
                    right: const BorderSide(color: _gridLine, width: 1),
                    bottom: BorderSide(color: isToday ? _gold : const Color(0xFFE8EEF4), width: isToday ? 2 : 1),
                  ),
                ),
                child: Text(
                  '${d.day}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isToday || isAssigned || isDeadline ? FontWeight.w900 : FontWeight.w700,
                    color: fg.withValues(alpha: inMonth ? 1 : 0.4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(width: _avatarWidth),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.chartWidth});

  final String title;
  final double chartWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _groupH,
      child: Row(
        children: [
          Container(
            width: _labelWidth,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: _navy,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          SizedBox(width: chartWidth, height: _groupH, child: CustomPaint(painter: _GridPainter())),
          const SizedBox(width: _avatarWidth),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.task,
    required this.weeks,
    required this.month,
    required this.chartWidth,
    required this.dayWidth,
    this.onTap,
  });

  final WorkTask task;
  final List<_Week> weeks;
  final DateTime month;
  final double chartWidth;
  final double dayWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _rowH,
        child: Row(
          children: [
            SizedBox(
              width: _labelWidth,
              child: Container(
                margin: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(color: _labelFill, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: _labelText,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: chartWidth,
              height: _rowH,
              child: CustomPaint(painter: _BarPainter(task: task, weeks: weeks, month: month, dayWidth: dayWidth)),
            ),
            SizedBox(
              width: _avatarWidth,
              child: Center(
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: _assignOrange,
                  child: Text(
                    _initials(task.assignee.name),
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF2F4F7));
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.task, required this.weeks, required this.month, required this.dayWidth});

  final WorkTask task;
  final List<_Week> weeks;
  final DateTime month;
  final double dayWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEEF1F5));

    final days = weeks.expand((w) => w.days).toList();
    final start = _dateOnly(task.createdAt);
    final end = _dateOnly(task.deadline);
    const barTop = 8.0;
    final barBottom = size.height - 8;
    final today = _dateOnly(DateTime.now());

    var x = 0.0;
    for (final week in weeks) {
      for (var i = 0; i < week.days.length; i++) {
        final day = week.days[i];
        final inMonth = _sameMonth(day, month);
        final cell = Rect.fromLTWH(x, 0, dayWidth, size.height);
        if (!inMonth) {
          canvas.drawRect(cell, Paint()..color = const Color(0xFFF7F8FA));
        }
        canvas.drawLine(
          cell.topRight,
          cell.bottomRight,
          Paint()
            ..color = _gridLine
            ..strokeWidth = i == week.days.length - 1 ? 2 : 1,
        );

        if (inMonth && !day.isBefore(start) && !day.isAfter(end)) {
          final isStart = day == start;
          final isEnd = day == end;
          canvas.drawRect(
            Rect.fromLTRB(x, barTop, x + dayWidth, barBottom),
            Paint()..color = isStart ? _assignOrange : (isEnd ? _navy : week.color),
          );
        }
        x += dayWidth;
      }
    }

    x = 0;
    for (final day in days) {
      if (day == today) {
        canvas.drawLine(
          Offset(x + dayWidth / 2, 2),
          Offset(x + dayWidth / 2, size.height - 2),
          Paint()
            ..color = _gold
            ..strokeWidth = 1.6,
        );
        break;
      }
      x += dayWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) => true;
}
