import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_outcome.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:ai_life_partner/features/reflection/domain/repositories/reflection_repository.dart';
import 'package:flutter/material.dart';

/// ひとつの歩みについて、Humanが振り返りを残す画面。
///
/// ここで聞くのは二つだけ。
/// 「今、どんな感じですか？」と「何か気づいたことはありますか？」。
///
/// できたかどうかを問わない。理由や原因も尋ねない。
/// 休んだ日も、別の一歩になった日も、同じ問いで振り返る。
///
/// 「振り返りを残す」を押したときだけReflectionEntryを保存する。
/// キャンセルや戻る操作では何も記録しない。
///
/// 振り返れるのは自分自身の歩みだけで、
/// 別のHumanの歩みに対しては入力そのものを始められない。
class ReflectionRecordPage extends StatefulWidget {
  const ReflectionRecordPage({
    super.key,
    required this.repository,
    required this.humanId,
    required this.journeyEntry,
  });

  final ReflectionRepository repository;

  final String humanId;

  /// 振り返りの対象になる歩み。この画面では読むだけで、書き換えない。
  final JourneyEntry journeyEntry;

  @override
  State<ReflectionRecordPage> createState() => _ReflectionRecordPageState();
}

class _ReflectionRecordPageState extends State<ReflectionRecordPage> {
  /// 同じマイクロ秒に残してもIDが重複しないようにする。
  static int _idSequence = 0;

  final TextEditingController _feelingController = TextEditingController();
  final TextEditingController _noticedController = TextEditingController();

  bool _isSaving = false;

  String? _inputErrorMessage;
  String? _saveErrorMessage;

  /// この画面で作ろうとしている振り返りの、変わらない部分。
  ///
  /// 最初の保存を試みたときに決めて、そのあとは作り直さない。
  /// 保存が届いたかどうか分からないまま再試行しても、
  /// 同じ振り返りのやり直しとして扱われるようにするため。
  String? _entryId;
  DateTime? _reflectedAt;

  /// この歩みを振り返れるHumanかどうか。
  ///
  /// 別のHumanの歩みに振り返りを残さないための境界。
  /// assertではなく通常の分岐で確かめ、リリースビルドでも働くようにする。
  bool get _canReflect {
    return widget.journeyEntry.humanId == widget.humanId;
  }

  @override
  void dispose() {
    _feelingController.dispose();
    _noticedController.dispose();

    super.dispose();
  }

  /// 保存に使うIDを、最初の一回だけ決める。
  String _resolveEntryId() {
    final entryId = _entryId;

    if (entryId != null) {
      return entryId;
    }

    _idSequence += 1;

    final generated =
        'reflection-${DateTime.now().microsecondsSinceEpoch}-$_idSequence';

    _entryId = generated;

    return generated;
  }

  /// 振り返った日時も、最初の一回だけ決める。
  DateTime _resolveReflectedAt() {
    return _reflectedAt ??= DateTime.now();
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  void _clearInputError() {
    if (_inputErrorMessage == null) {
      return;
    }

    setState(() {
      _inputErrorMessage = null;
    });
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    // 画面を組み立てる時点で入力欄を出していないが、
    // 保存経路そのものにも境界を置いて、二重に守る。
    if (!_canReflect) {
      return;
    }

    final feelingText = _trimmedOrNull(_feelingController.text);
    final noticedText = _trimmedOrNull(_noticedController.text);

    if (feelingText == null && noticedText == null) {
      // 書けないことを責めない。どちらか一つで足りることをもう一度伝える。
      setState(() {
        _inputErrorMessage = '感じたことか気づいたことか、どちらかを残してください。';
        _saveErrorMessage = null;
      });

      return;
    }

    setState(() {
      _isSaving = true;
      _inputErrorMessage = null;
      _saveErrorMessage = null;
    });

    // 作成の身元は最初の試行で決めたものを使い、書き直しの時刻だけ新しくする。
    final reflectedAt = _resolveReflectedAt();

    try {
      final entry = ReflectionEntry(
        id: _resolveEntryId(),
        humanId: widget.humanId,
        journeyEntryId: widget.journeyEntry.id,
        feelingText: feelingText,
        noticedText: noticedText,
        reflectedAt: reflectedAt,
        createdAt: reflectedAt,
        updatedAt: DateTime.now(),
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
        _saveErrorMessage = '振り返りを保存できませんでした。もう一度お試しください。';
      });
    }
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  Widget _buildLabelledText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
      ],
    );
  }

  /// 振り返る対象の歩みを、そのまま読めるように置く。
  ///
  /// ここでは編集させない。評価も付けない。
  Widget _buildJourneySummary() {
    final entry = widget.journeyEntry;

    return Card(
      key: const Key('reflection_record_journey_summary'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabelledText('今日の一歩', entry.plannedActionText),
            const SizedBox(height: 14),
            _buildLabelledText('歩み', entry.outcome.label),
            if (entry.hasActualActionText) ...[
              const SizedBox(height: 14),
              _buildLabelledText('実際の一歩', entry.actualActionText!),
            ],
            if (entry.hasNote) ...[
              const SizedBox(height: 14),
              _buildLabelledText('ひとこと', entry.note!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(String question) {
    return Text(
      question,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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

  /// 自分の歩みではない場合の画面。
  ///
  /// 入力欄も保存操作も出さないので、振り返りを始めることそのものができない。
  /// 誰かを責める書き方はせず、できないことだけを静かに伝える。
  Widget _buildUnavailable() {
    return Column(
      key: const Key('reflection_record_unavailable'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildErrorText('この歩みを振り返ることができません。'),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            key: const Key('reflection_record_close_button'),
            onPressed: _cancel,
            child: const Text('戻る'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canReflect) {
      return Scaffold(
        appBar: AppBar(title: const Text('振り返り')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _buildUnavailable(),
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      // 保存中は戻れないようにする。
      // 保存が終わる前に画面を離れると、残したはずの言葉の行方が分からなくなる。
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(title: const Text('振り返り')),
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
                      'この歩みを振り返る',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'この歩みについて、いま感じていることや、'
                      '気づいたことを、あなたの言葉のまま残せます。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.7),
                    ),
                    const SizedBox(height: 24),
                    _buildJourneySummary(),
                    const SizedBox(height: 32),
                    _buildQuestion('今、どんな感じですか？'),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('reflection_record_feeling_field'),
                      controller: _feelingController,
                      // 保存中は書き換えられないようにする。
                      enabled: !_isSaving,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '例：少し肩の力が抜けた／まだ落ち着かない',
                      ),
                      onChanged: (_) {
                        _clearInputError();
                      },
                    ),
                    const SizedBox(height: 26),
                    _buildQuestion('この歩みから、何か気づいたことはありますか？'),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('reflection_record_noticed_field'),
                      controller: _noticedController,
                      // 保存中は書き換えられないようにする。
                      enabled: !_isSaving,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '例：朝のほうが動きやすいみたいだ',
                      ),
                      onChanged: (_) {
                        _clearInputError();
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'どちらか一つだけでも残せます。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                    if (_inputErrorMessage != null)
                      _buildErrorText(_inputErrorMessage!),
                    if (_saveErrorMessage != null)
                      _buildErrorText(_saveErrorMessage!),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('reflection_record_cancel_button'),
                            onPressed: _isSaving ? null : _cancel,
                            child: const Text('キャンセル'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('reflection_record_save_button'),
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_stories_outlined),
                            label: Text(_isSaving ? '保存しています…' : '振り返りを残す'),
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
