import 'package:ai_life_partner/features/calendar/domain/models/calendar_event.dart';
import 'package:ai_life_partner/features/calendar/domain/models/event_category.dart';
import 'package:ai_life_partner/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:flutter/material.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.repository,
    required this.humanId,
  });

  final CalendarRepository repository;
  final String humanId;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  List<CalendarEvent> _monthEvents = <CalendarEvent>[];

  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _visibleMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);

    _loadMonthEvents();
  }

  Future<void> _loadMonthEvents() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final monthEnd = DateTime(_visibleMonth.year, _visibleMonth.month + 1);

      final events = await widget.repository.getEvents(
        humanId: widget.humanId,
        rangeStart: _visibleMonth,
        rangeEnd: monthEnd,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _monthEvents = events;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  List<CalendarEvent> _eventsForDay(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);

    final dayEnd = DateTime(date.year, date.month, date.day + 1);

    return _monthEvents.where((event) {
        return event.overlaps(rangeStart: dayStart, rangeEnd: dayEnd);
      }).toList()
      ..sort((first, second) => first.startAt.compareTo(second.startAt));
  }

  Future<void> _moveMonth(int difference) async {
    final newMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + difference,
    );

    setState(() {
      _visibleMonth = newMonth;
      _selectedDate = DateTime(newMonth.year, newMonth.month, 1);
    });

    await _loadMonthEvents();
  }

  Future<void> _moveToToday() async {
    final now = DateTime.now();

    setState(() {
      _visibleMonth = DateTime(now.year, now.month);

      _selectedDate = DateTime(now.year, now.month, now.day);
    });

    await _loadMonthEvents();
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _formatSelectedDate(DateTime date) {
    const weekdays = <String>['月', '火', '水', '木', '金', '土', '日'];

    final weekday = weekdays[date.weekday - 1];

    return '${date.year}年${date.month}月${date.day}日（$weekday）';
  }

  String _formatEventTime(CalendarEvent event) {
    if (event.isAllDay) {
      return '終日';
    }

    final start =
        '${_twoDigits(event.startAt.hour)}:${_twoDigits(event.startAt.minute)}';

    final end =
        '${_twoDigits(event.endAt.hour)}:${_twoDigits(event.endAt.minute)}';

    return '$start - $end';
  }

  void _showEventEditorComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_selectedDate.month}月${_selectedDate.day}日の予定登録画面は、'
          '次の工程で追加します',
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      children: [
        IconButton(
          tooltip: '前の月',
          onPressed: () {
            _moveMonth(-1);
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            '${_visibleMonth.year}年${_visibleMonth.month}月',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          tooltip: '次の月',
          onPressed: () {
            _moveMonth(1);
          },
          icon: const Icon(Icons.chevron_right),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: _moveToToday, child: const Text('今日')),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    const weekdays = <String>['日', '月', '火', '水', '木', '金', '土'];

    return Row(
      children: weekdays.map((weekday) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              weekday,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month);

    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;

    final leadingEmptyCells = firstDay.weekday % 7;

    final usedCells = leadingEmptyCells + daysInMonth;

    final totalCells = ((usedCells + 6) ~/ 7) * 7;

    final today = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.1,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        final dayNumber = index - leadingEmptyCells + 1;

        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(
          _visibleMonth.year,
          _visibleMonth.month,
          dayNumber,
        );

        final isSelected = _isSameDate(date, _selectedDate);

        final isToday = _isSameDate(date, today);

        final hasEvents = _eventsForDay(date).isNotEmpty;

        return Material(
          color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _selectDate(date);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToday
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  width: isToday ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      '$dayNumber',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected || isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (hasEvents)
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          const Text('予定を読み込めませんでした。'),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loadMonthEvents,
            child: const Text('もう一度読み込む'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayEvents() {
    final events = _eventsForDay(_selectedDate);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatSelectedDate(_selectedDate),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _showEventEditorComingSoon,
                  icon: const Icon(Icons.add),
                  label: const Text('予定を追加'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(Icons.event_available_outlined, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'この日の予定はありません。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '空いている時間を、次の一歩に活用できます。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            else
              ...events.map((event) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: Text(
                      event.aiVisibility.name == 'busyOnly'
                          ? '予定あり'
                          : event.title,
                    ),
                    subtitle: Text(
                      '${_formatEventTime(event)}\n'
                      '${event.category.label}',
                    ),
                    isThreeLine: true,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('予定の編集画面は次の工程で追加します')),
                      );
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンダー'),
        actions: [
          IconButton(
            tooltip: '予定を追加',
            onPressed: _showEventEditorComingSoon,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '予定と時間を確認する',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '生活の予定とLife Projectをつなぎ、'
                    '実行できる次の一歩を考えるためのカレンダーです。',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildMonthHeader(),
                          const SizedBox(height: 12),
                          _buildWeekdayHeader(),
                          if (_isLoading)
                            _buildLoadingState()
                          else if (_loadError != null)
                            _buildErrorState()
                          else
                            _buildCalendarGrid(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!_isLoading && _loadError == null)
                    _buildSelectedDayEvents(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
