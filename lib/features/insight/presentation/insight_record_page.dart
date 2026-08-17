import 'package:ai_life_partner/features/insight/domain/models/insight_entry.dart';
import 'package:ai_life_partner/features/insight/domain/repositories/insight_repository.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:flutter/material.dart';

/// ひとつの振り返りから、Humanが気づきを残す画面。
///
/// 聞くのはひとつだけ。
/// 「この振り返りから、あなたにとって大切だと思う気づきはありますか？」。
///
/// 正しい教訓を求めない。改善点も、次に直すことも尋ねない。
/// 何を書くか、そもそも書くかどうかを決めるのはHumanである。
///
/// 「気づきを残す」を押したときだけInsightEntryを保存する。
/// キャンセルや戻る操作では何も記録しない。
///
/// 気づきを残せるのは自分自身の振り返りだけで、
/// 別のHumanの振り返りに対しては入力そのものを始められない。
class InsightRecordPage extends StatefulWidget {
  const InsightRecordPage({
    super.key,
    required this.repository,
    required this.humanId,
    required this.reflectionEntry,
  });

  final InsightRepository repository;

  final String humanId;

  /// 気づきのもとになる振り返り。この画面では読むだけで、書き換えない。
  final ReflectionEntry reflectionEntry;

  @override
  State<InsightRecordPage> createState() => _InsightRecordPageState();
}

class _InsightRecordPageState extends State<InsightRecordPage> {
  /// 同じマイクロ秒に残してもIDが重複しないようにする。
  static int _idSequence = 0;

  final TextEditingController _insightController = TextEditingController();

  bool _isSaving = false;

  String? _inputErrorMessage;
  String? _saveErrorMessage;

  /// この画面で作ろうとしている気づきの、変わらない部分。
  ///
  /// 最初の保存を試みたときに決めて、そのあとは作り直さない。
  /// 保存が届いたかどうか分からないまま再試行しても、
  /// 同じ気づきのやり直しとして扱われるようにするため。
  String? _entryId;
  DateTime? _discoveredAt;

  /// この振り返りから気づきを残せるHumanかどうか。
  ///
  /// 別のHumanの振り返りに気づきを結び付けないための境界。
  /// assertではなく通常の分岐で確かめ、リリースビルドでも働くようにする。
  bool get _canRecord {
    return widget.reflectionEntry.humanId == widget.humanId;
  }

  @override
  void dispose() {
    _insightController.dispose();

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
        'insight-${DateTime.now().microsecondsSinceEpoch}-$_idSequence';

    _entryId = generated;

    return generated;
  }

  /// 気づきを見つけた日時も、最初の一回だけ決める。
  DateTime _resolveDiscoveredAt() {
    return _discoveredAt ??= DateTime.now();
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
    if (!_canRecord) {
      return;
    }

    // 保存する内容は、この時点で確定させる。
    final insightText = _insightController.text.trim();

    if (insightText.isEmpty) {
      // 書けないことを責めない。書いたときだけ残せることを伝える。
      setState(() {
        _inputErrorMessage = '残したい気づきを、ひとこと書いてください。';
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
    final discoveredAt = _resolveDiscoveredAt();

    try {
      final entry = InsightEntry(
        id: _resolveEntryId(),
        humanId: widget.humanId,
        reflectionEntryId: widget.reflectionEntry.id,
        insightText: insightText,
        discoveredAt: discoveredAt,
        createdAt: discoveredAt,
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
        _saveErrorMessage = '気づきを保存できませんでした。もう一度お試しください。';
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

  /// もとになる振り返りを、そのまま読めるように置く。
  ///
  /// ここでは編集させない。評価も付けない。
  Widget _buildReflectionSummary() {
    final entry = widget.reflectionEntry;

    return Card(
      key: const Key('insight_record_reflection_summary'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '元の振り返り',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (entry.hasFeelingText) ...[
              const SizedBox(height: 14),
              _buildLabelledText('感じたこと', entry.feelingText!),
            ],
            if (entry.hasNoticedText) ...[
              const SizedBox(height: 14),
              _buildLabelledText('気づいたこと', entry.noticedText!),
            ],
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

  /// 自分の振り返りではない場合の画面。
  ///
  /// 入力欄も保存操作も出さないので、気づきを残し始めることそのものができない。
  /// 誰かを責める書き方はせず、できないことだけを静かに伝える。
  Widget _buildUnavailable() {
    return Column(
      key: const Key('insight_record_unavailable'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildErrorText('この振り返りから気づきを残すことはできません。'),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            key: const Key('insight_record_close_button'),
            onPressed: _cancel,
            child: const Text('戻る'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canRecord) {
      return Scaffold(
        appBar: AppBar(title: const Text('気づき')),
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
        appBar: AppBar(title: const Text('気づき')),
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
                      'この振り返りからの気づき',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'この振り返りを読み返して、'
                      'あなた自身が思ったことを、あなたの言葉のまま残せます。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.7),
                    ),
                    const SizedBox(height: 24),
                    _buildReflectionSummary(),
                    const SizedBox(height: 32),
                    Text(
                      'この振り返りから、あなたにとって大切だと思う気づきはありますか？',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('insight_record_text_field'),
                      controller: _insightController,
                      // 保存中は書き換えられないようにする。
                      enabled: !_isSaving,
                      minLines: 3,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '例：無理を続けるより、休むことも前に進むために必要。',
                      ),
                      onChanged: (_) {
                        _clearInputError();
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '今は残さなくても大丈夫です。',
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
                            key: const Key('insight_record_cancel_button'),
                            onPressed: _isSaving ? null : _cancel,
                            child: const Text('キャンセル'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('insight_record_save_button'),
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lightbulb_outline),
                            label: Text(_isSaving ? '保存しています…' : '気づきを残す'),
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
