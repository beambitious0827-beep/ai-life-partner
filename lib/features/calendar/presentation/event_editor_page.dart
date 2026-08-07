import 'package:ai_life_partner/features/calendar/domain/models/ai_visibility.dart';
import 'package:ai_life_partner/features/calendar/domain/models/calendar_event.dart';
import 'package:ai_life_partner/features/calendar/domain/models/calendar_source.dart';
import 'package:ai_life_partner/features/calendar/domain/models/event_category.dart';
import 'package:ai_life_partner/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/presentation/event_schedule_input.dart';
import 'package:flutter/material.dart';

/// 予定を新しく登録するための画面。
///
/// 保存に成功した場合は、登録したCalendarEventを返して閉じる。
/// キャンセルや戻る操作の場合はnullを返し、何も保存しない。
class EventEditorPage extends StatefulWidget {
  const EventEditorPage({
    super.key,
    required this.repository,
    required this.humanId,
    required this.initialDate,
  });

  final CalendarRepository repository;

  /// CalendarPageから渡されるHuman ID。
  final String humanId;

  /// CalendarPageで選択していた日付。
  final DateTime initialDate;

  @override
  State<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends State<EventEditorPage> {
  /// 同じマイクロ秒に複数の予定を作成しても、IDが重複しないようにする。
  static int _idSequence = 0;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  late DateTime _date;

  bool _isAllDay = false;

  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  EventCategory _category = EventCategory.other;

  /// 初期値は、内容をAIへ渡さない安全な設定にする。
  /// AIへ詳細を見せるかどうかは、利用者自身が選ぶ。
  AiVisibility _aiVisibility = AiVisibility.busyOnly;

  bool _isSaving = false;

  String? _scheduleErrorMessage;
  String? _saveErrorMessage;

  @override
  void initState() {
    super.initState();

    _date = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  EventScheduleInput get _schedule {
    return EventScheduleInput(
      date: _date,
      isAllDay: _isAllDay,
      startTime: _startTime,
      endTime: _endTime,
    );
  }

  String _generateEventId() {
    _idSequence += 1;

    return 'event-${DateTime.now().microsecondsSinceEpoch}-$_idSequence';
  }

  String _formatDate(DateTime date) {
    const weekdays = <String>['月', '火', '水', '木', '金', '土', '日'];

    final weekday = weekdays[date.weekday - 1];

    return '${date.year}年${date.month}月${date.day}日（$weekday）';
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 5),
      lastDate: DateTime(_date.year + 5, 12, 31),
      helpText: '予定の日付を選ぶ',
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    setState(() {
      _date = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

      _scheduleErrorMessage = null;
    });
  }

  Future<void> _pickStartTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: '開始時刻を選ぶ',
    );

    if (!mounted || selectedTime == null) {
      return;
    }

    setState(() {
      _startTime = selectedTime;

      _scheduleErrorMessage = null;
    });
  }

  Future<void> _pickEndTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _endTime,
      helpText: '終了時刻を選ぶ',
    );

    if (!mounted || selectedTime == null) {
      return;
    }

    setState(() {
      _endTime = selectedTime;

      _scheduleErrorMessage = null;
    });
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final formState = _formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    final schedule = _schedule;

    final scheduleErrorMessage = schedule.validationMessage;

    if (scheduleErrorMessage != null) {
      setState(() {
        _scheduleErrorMessage = scheduleErrorMessage;
        _saveErrorMessage = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(scheduleErrorMessage)));

      return;
    }

    setState(() {
      _isSaving = true;
      _scheduleErrorMessage = null;
      _saveErrorMessage = null;
    });

    final savedAt = DateTime.now();

    try {
      final event = CalendarEvent(
        id: _generateEventId(),
        humanId: widget.humanId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        startAt: schedule.startAt,
        endAt: schedule.endAt,
        isAllDay: _isAllDay,
        category: _category,
        // Life Projectの正式なIDモデルが決まるまで、関連付けは行わない。
        lifeProjectId: null,
        aiVisibility: _aiVisibility,
        source: CalendarSource.internal,
        createdAt: savedAt,
        updatedAt: savedAt,
      );

      await widget.repository.saveEvent(event);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(event);
    } on Object catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _saveErrorMessage = '予定を保存できませんでした。もう一度お試しください。';
      });
    }
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      key: const Key('event_editor_title_field'),
      controller: _titleController,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: '予定名',
        hintText: '例：数学の模試、胸トレーニング',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '予定名を入力してください。';
        }

        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      key: const Key('event_editor_description_field'),
      controller: _descriptionController,
      minLines: 3,
      maxLines: 5,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: '詳細（任意）',
        hintText: '場所、持ち物、覚えておきたいことなど',
      ),
    );
  }

  Widget _buildScheduleSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                key: const Key('event_editor_date_tile'),
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('日付'),
                subtitle: Text(_formatDate(_date)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _pickDate,
              ),
              const Divider(height: 1),
              SwitchListTile(
                key: const Key('event_editor_all_day_switch'),
                secondary: const Icon(Icons.today_outlined),
                title: const Text('終日の予定にする'),
                subtitle: const Text('時刻を決めずに、その日いっぱいの予定として登録します。'),
                value: _isAllDay,
                onChanged: (value) {
                  setState(() {
                    _isAllDay = value;

                    _scheduleErrorMessage = null;
                  });
                },
              ),
              if (!_isAllDay) ...[
                const Divider(height: 1),
                ListTile(
                  key: const Key('event_editor_start_time_tile'),
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('開始時刻'),
                  subtitle: Text(_startTime.format(context)),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _pickStartTime,
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('event_editor_end_time_tile'),
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('終了時刻'),
                  subtitle: Text(_endTime.format(context)),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _pickEndTime,
                ),
              ],
            ],
          ),
        ),
        if (_scheduleErrorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 20, color: colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _scheduleErrorMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: EventCategory.values.map((category) {
        return ChoiceChip(
          label: Text(category.label),
          selected: _category == category,
          onSelected: (isSelected) {
            if (!isSelected) {
              return;
            }

            setState(() {
              _category = category;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildAiVisibilitySelector() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'この予定をAIがどこまで参照できるかは、あなたが決めます。'
          'あとから変更することもできます。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
        const SizedBox(height: 12),
        ...AiVisibility.values.map((visibility) {
          final isSelected = _aiVisibility == visibility;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: isSelected ? colorScheme.primaryContainer : null,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _aiVisibility = visibility;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outline,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visibility.label,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            visibility.description,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const Key('event_editor_cancel_button'),
            onPressed: _isSaving ? null : _cancel,
            child: const Text('キャンセル'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            key: const Key('event_editor_save_button'),
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('この予定を保存する'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('予定を登録')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '予定を書き留める',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '登録した予定は、あなたのカレンダーに保存されます。'
                      '保存するまで、何も記録されません。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.7),
                    ),
                    const SizedBox(height: 28),
                    _buildSection(title: '予定名', child: _buildTitleField()),
                    _buildSection(title: '詳細', child: _buildDescriptionField()),
                    _buildSection(title: '日時', child: _buildScheduleSection()),
                    _buildSection(
                      title: 'カテゴリー',
                      child: _buildCategorySelector(),
                    ),
                    _buildSection(
                      title: 'AIが参照できる範囲',
                      child: _buildAiVisibilitySelector(),
                    ),
                    if (_saveErrorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 20,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _saveErrorMessage!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: colorScheme.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
