import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_outcome.dart';
import 'package:ai_life_partner/features/journey/domain/repositories/journey_repository.dart';
import 'package:flutter/material.dart';

/// その日の一歩について、実際に何が起きたかをHumanが残す画面。
///
/// 保存を押したときだけJourneyEntryを作成する。
/// キャンセルや戻る操作では何も記録しない。
///
/// ここでは振り返りを求めない。何が起きたかを残すだけにする。
class JourneyRecordPage extends StatefulWidget {
  const JourneyRecordPage({
    super.key,
    required this.repository,
    required this.humanId,
    required this.plannedActionText,
    this.plannedDuration,
    this.sourceCalendarEventId,
  });

  final JourneyRepository repository;

  final String humanId;

  /// 記録のもとになる「今日の一歩」。
  final String plannedActionText;

  /// もとの一歩に長さの情報があれば、その写し。評価には使わない。
  final Duration? plannedDuration;

  /// もとの一歩をカレンダーへ登録していた場合の予定ID。
  final String? sourceCalendarEventId;

  @override
  State<JourneyRecordPage> createState() => _JourneyRecordPageState();
}

class _JourneyRecordPageState extends State<JourneyRecordPage> {
  /// 同じマイクロ秒に記録してもIDが重複しないようにする。
  static int _idSequence = 0;

  final TextEditingController _actualActionController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  JourneyOutcome? _outcome;

  bool _isSaving = false;

  String? _actualActionErrorMessage;
  String? _saveErrorMessage;

  @override
  void dispose() {
    _actualActionController.dispose();
    _noteController.dispose();

    super.dispose();
  }

  String _generateEntryId() {
    _idSequence += 1;

    return 'journey-${DateTime.now().microsecondsSinceEpoch}-$_idSequence';
  }

  void _selectOutcome(JourneyOutcome outcome) {
    setState(() {
      _outcome = outcome;

      _actualActionErrorMessage = null;
      _saveErrorMessage = null;
    });
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final outcome = _outcome;

    if (outcome == null) {
      setState(() {
        _saveErrorMessage = 'その後どうだったかを、ひとつ選んでください。';
      });

      return;
    }

    // 実際の一歩は「別の一歩になった」を選んでいるときだけ画面に出ている。
    // 他の結果へ切り替えたあとにControllerへ残っている値は、
    // Humanが保存時に確認できていないので保存しない。
    // 保存する内容は、いま選ばれている結果と必ず一致させる。
    final actualActionText = outcome.requiresActualActionText
        ? _trimmedOrNull(_actualActionController.text)
        : null;

    if (outcome.requiresActualActionText && actualActionText == null) {
      // 責めるのではなく、何が起きた日だったかを残せるように促す。
      setState(() {
        _actualActionErrorMessage = '実際にどんな一歩になったか、ひとこと教えてください。';
        _saveErrorMessage = null;
      });

      return;
    }

    setState(() {
      _isSaving = true;
      _actualActionErrorMessage = null;
      _saveErrorMessage = null;
    });

    final recordedAt = DateTime.now();

    try {
      final entry = JourneyEntry(
        id: _generateEntryId(),
        humanId: widget.humanId,
        plannedActionText: widget.plannedActionText,
        outcome: outcome,
        actualActionText: actualActionText,
        note: _trimmedOrNull(_noteController.text),
        plannedDuration: widget.plannedDuration,
        sourceCalendarEventId: widget.sourceCalendarEventId,
        // v1では記録した時点を、その歩みが起きた日時として扱う。
        occurredAt: recordedAt,
        createdAt: recordedAt,
        updatedAt: recordedAt,
      );

      await widget.repository.saveEntry(entry);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(entry);
    } on Object catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _saveErrorMessage = '歩みを保存できませんでした。もう一度お試しください。';
      });
    }
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  Widget _buildOutcomeCard(JourneyOutcome outcome) {
    final selected = _outcome == outcome;
    final colorScheme = Theme.of(context).colorScheme;

    // どの結果も同じ形・同じアイコンで並べる。
    // 上下関係や成功・失敗を感じさせる表現は使わない。
    return Card(
      key: Key('journey_record_outcome_${outcome.name}'),
      margin: const EdgeInsets.only(bottom: 10),
      color: selected ? colorScheme.primaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // 保存中は内容を変えられないようにする。
        // Humanが最後に確認した内容と、保存される内容をずらさないため。
        onTap: _isSaving
            ? null
            : () {
                _selectOutcome(outcome);
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? colorScheme.primary : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outcome.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(outcome.description),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlannedAction() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日の一歩',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.plannedActionText,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorText(String message) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsActualAction = _outcome?.requiresActualActionText ?? false;

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(title: const Text('歩みとして残す')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'その後、どうでしたか？',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'どの結果も、その日の大切な歩みです。'
                      '取り組んだ日も、別のことを選んだ日も、休んだ日も、'
                      'すべてあなたが歩いた道のりです。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.7),
                    ),
                    const SizedBox(height: 24),
                    _buildPlannedAction(),
                    const SizedBox(height: 28),
                    ...JourneyOutcome.values.map(_buildOutcomeCard),
                    if (needsActualAction) ...[
                      const SizedBox(height: 18),
                      TextField(
                        key: const Key('journey_record_actual_action_field'),
                        controller: _actualActionController,
                        // 保存中は書き換えられないようにする。
                        enabled: !_isSaving,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'どんな一歩になりましたか？',
                          hintText: '例：家族との時間を優先した／散歩に変更した',
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) {
                          if (_actualActionErrorMessage == null) {
                            return;
                          }

                          setState(() {
                            _actualActionErrorMessage = null;
                          });
                        },
                      ),
                      if (_actualActionErrorMessage != null)
                        _buildErrorText(_actualActionErrorMessage!),
                    ],
                    const SizedBox(height: 24),
                    TextField(
                      key: const Key('journey_record_note_field'),
                      controller: _noteController,
                      // 保存中は書き換えられないようにする。
                      enabled: !_isSaving,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'ひとこと残す（任意）',
                        hintText: '例：思ったより疲れていた／10分だけでも始められた',
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_saveErrorMessage != null)
                      _buildErrorText(_saveErrorMessage!),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('journey_record_cancel_button'),
                            onPressed: _isSaving ? null : _cancel,
                            child: const Text('キャンセル'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('journey_record_save_button'),
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.route_outlined),
                            label: Text(_isSaving ? '保存しています…' : '歩みとして残す'),
                          ),
                        ),
                      ],
                    ),
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
