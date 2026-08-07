import 'package:ai_life_partner/features/calendar/domain/models/ai_visibility.dart';
import 'package:ai_life_partner/features/calendar/domain/models/calendar_event.dart';
import 'package:ai_life_partner/features/calendar/domain/models/calendar_source.dart';
import 'package:ai_life_partner/features/calendar/domain/models/event_category.dart';
import 'package:ai_life_partner/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/presentation/event_schedule_input.dart';
import 'package:flutter/material.dart';

/// Event Editorで利用者が確定した操作。
enum EventEditorAction { saved, deleted }

/// Event Editorの結果。
///
/// 保存と削除を呼び出し側で区別できるようにするために使用する。
class EventEditorResult {
  const EventEditorResult({required this.action, required this.event});

  const EventEditorResult.saved(CalendarEvent event)
    : this(action: EventEditorAction.saved, event: event);

  const EventEditorResult.deleted(CalendarEvent event)
    : this(action: EventEditorAction.deleted, event: event);

  final EventEditorAction action;

  /// 保存後、または削除した予定。
  final CalendarEvent event;

  bool get isSaved => action == EventEditorAction.saved;

  bool get isDeleted => action == EventEditorAction.deleted;
}

/// 予定を新しく登録する画面、および既存の予定を編集する画面。
///
/// [initialEvent] を渡すと編集モードになり、渡さない場合は新規登録モードになる。
///
/// 利用者が保存または削除を確定した場合のみ [EventEditorResult] を返して閉じる。
/// キャンセルや戻る操作の場合はnullを返し、何も保存・削除しない。
class EventEditorPage extends StatefulWidget {
  const EventEditorPage({
    super.key,
    required this.repository,
    required this.humanId,
    required this.initialDate,
    this.initialEvent,
  });

  final CalendarRepository repository;

  /// CalendarPageから渡されるHuman ID。
  final String humanId;

  /// CalendarPageで選択していた日付。新規登録モードの初期日付になる。
  final DateTime initialDate;

  /// 編集する既存の予定。nullの場合は新規登録モードになる。
  final CalendarEvent? initialEvent;

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

  /// 既存の予定を受け取っている場合は編集モードになる。
  bool get _isEditing => widget.initialEvent != null;

  @override
  void initState() {
    super.initState();

    final initialEvent = widget.initialEvent;

    if (initialEvent == null) {
      _date = DateTime(
        widget.initialDate.year,
        widget.initialDate.month,
        widget.initialDate.day,
      );

      return;
    }

    // 編集モードでは、既存の予定の内容をそのまま初期値にする。
    // 画面を開いただけでは、どの値も変更しない。
    _titleController.text = initialEvent.title;
    _descriptionController.text = initialEvent.description;

    _date = DateTime(
      initialEvent.startAt.year,
      initialEvent.startAt.month,
      initialEvent.startAt.day,
    );

    _isAllDay = initialEvent.isAllDay;

    if (!initialEvent.isAllDay) {
      // 終日予定は時刻を持たないため、既定の時刻を残しておく。
      // 終日をOFFに切り替えたときに、そのまま使える初期値になる。
      _startTime = TimeOfDay.fromDateTime(initialEvent.startAt);
      _endTime = TimeOfDay.fromDateTime(initialEvent.endAt);
    }

    _category = initialEvent.category;
    _aiVisibility = initialEvent.aiVisibility;
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
      final event = _buildEvent(schedule: schedule, savedAt: savedAt);

      await widget.repository.saveEvent(event);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(EventEditorResult.saved(event));
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

  /// 入力内容から保存するCalendarEventを組み立てる。
  ///
  /// 編集モードでは、既存の予定のid、humanId、createdAt、lifeProjectId、
  /// sourceを維持し、updatedAtだけを保存時点の日時へ更新する。
  CalendarEvent _buildEvent({
    required EventScheduleInput schedule,
    required DateTime savedAt,
  }) {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    final initialEvent = widget.initialEvent;

    if (initialEvent != null) {
      return initialEvent.copyWith(
        title: title,
        description: description,
        startAt: schedule.startAt,
        endAt: schedule.endAt,
        isAllDay: _isAllDay,
        category: _category,
        aiVisibility: _aiVisibility,
        updatedAt: savedAt,
      );
    }

    return CalendarEvent(
      id: _generateEventId(),
      humanId: widget.humanId,
      title: title,
      description: description,
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
  }

  /// 削除は、利用者が確認ダイアログで明示的に選択した場合のみ実行する。
  ///
  /// ダイアログを閉じただけ、背景をタップしただけでは削除しない。
  Future<void> _confirmDelete() async {
    final initialEvent = widget.initialEvent;

    if (initialEvent == null || _isSaving) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('この予定を削除しますか？'),
          content: Text(
            '「${initialEvent.title}」をカレンダーから削除します。\n'
            '削除した予定は元に戻せません。',
          ),
          actions: [
            TextButton(
              key: const Key('event_editor_delete_cancel_button'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('event_editor_delete_confirm_button'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('削除する'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    setState(() {
      _isSaving = true;
      _scheduleErrorMessage = null;
      _saveErrorMessage = null;
    });

    try {
      await widget.repository.deleteEvent(initialEvent.id);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(EventEditorResult.deleted(initialEvent));
    } on Object catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _saveErrorMessage = '予定を削除できませんでした。もう一度お試しください。';
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
          key: Key('event_editor_category_${category.name}'),
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
            key: Key('event_editor_ai_visibility_${visibility.name}'),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
        ),
        // 削除は既存の予定にだけ用意する。押しただけでは削除せず、確認を挟む。
        if (_isEditing) ...[
          const SizedBox(height: 24),
          TextButton.icon(
            key: const Key('event_editor_delete_button'),
            onPressed: _isSaving ? null : _confirmDelete,
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            icon: const Icon(Icons.delete_outline),
            label: const Text('この予定を削除する'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '予定を編集' : '予定を登録')),
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
                      _isEditing ? '予定を見直す' : '予定を書き留める',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isEditing
                          ? '内容を変更しても、保存するまでカレンダーは変わりません。'
                                '戻る操作では、変更は保存されません。'
                          : '登録した予定は、あなたのカレンダーに保存されます。'
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
