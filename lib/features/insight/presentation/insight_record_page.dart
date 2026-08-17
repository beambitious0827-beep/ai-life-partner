import 'package:ai_life_partner/features/insight/domain/models/insight_entry.dart';
import 'package:ai_life_partner/features/insight/domain/models/reflection_thinking_request.dart';
import 'package:ai_life_partner/features/insight/domain/models/reflection_thinking_support.dart';
import 'package:ai_life_partner/features/insight/domain/repositories/insight_repository.dart';
import 'package:ai_life_partner/features/insight/domain/services/reflection_thinking_assistant.dart';
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
///
/// 望んだときだけ、AIと一緒に考えることもできる。
/// AIが返すのは考えるための材料であって、気づきそのものではない。
/// 使うかどうかはHumanが決めるし、使わなくても気づきは残せる。
class InsightRecordPage extends StatefulWidget {
  const InsightRecordPage({
    super.key,
    required this.repository,
    required this.thinkingAssistant,
    required this.humanId,
    required this.reflectionEntry,
  });

  final InsightRepository repository;

  /// Humanが望んだときだけ呼ぶ、考えるための材料の取り寄せ先。
  ///
  /// ここへ気づきを保存させない。保存先はあくまで [repository]。
  final ReflectionThinkingAssistant thinkingAssistant;

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

  /// AIと一緒に考えた結果。画面を離れれば消える、その場限りの手がかり。
  ///
  /// InsightEntryへは保存しない。Humanの言葉と混ぜない。
  ReflectionThinkingSupport? _thinkingSupport;

  bool _isThinking = false;
  String? _thinkingErrorMessage;

  /// 発行した「一緒に考える」の通し番号。あとから発行したものほど新しい。
  int _thinkingSequence = 0;

  /// いま画面が受け入れる番号。
  ///
  /// 頼んだ順に返ってくるとはかぎらないので、
  /// 古い結果や古い失敗で新しい結果を消さないための目印にする。
  int _thinkingRequestId = 0;

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

  /// Humanが「一緒に考える」を押したときだけ、考える材料を取り寄せる。
  ///
  /// 画面を開いただけ、入力しただけ、保存しただけでは呼ばない。
  /// 渡すのは、選ばれた振り返りの言葉だけ。
  ///
  /// 待っている間に新しく頼み直された場合、古い答えは捨てる。
  /// 成功でも失敗でも同じで、古い結果が新しい結果を消さないようにする。
  ///
  /// 気づきの保存中でも頼める。AIと一緒に考えることと、
  /// 気づきを残すことは別の操作なので、保存の状態では止めない。
  Future<void> _requestThinkingSupport() async {
    // ボタンは考えている間だけ無効になるが、無効になるのは次の描画からで、
    // 同じフレームのうちに二度押されると、古い操作がそのまま二度届く。
    // 見た目の無効化だけに頼らず、ここでも重ねての依頼を断る。
    if (_isThinking) {
      return;
    }

    // 別のHumanの振り返りをAIへ渡さない。
    if (!_canRecord) {
      return;
    }

    final requestId = ++_thinkingSequence;

    // setStateの中身はその場で実行されるので、
    // ここを抜けた時点で _isThinking はすでにtrueになっている。
    // 同じフレームの2回目は、上のguardで戻る。
    setState(() {
      _thinkingRequestId = requestId;
      _isThinking = true;
      _thinkingErrorMessage = null;
    });

    try {
      final support = await widget.thinkingAssistant.support(
        ReflectionThinkingRequest.fromReflection(widget.reflectionEntry),
      );

      if (!mounted || _thinkingRequestId != requestId) {
        return;
      }

      setState(() {
        _isThinking = false;
        _thinkingSupport = support;
        _thinkingErrorMessage = null;
      });
    } on Object catch (_) {
      if (!mounted || _thinkingRequestId != requestId) {
        return;
      }

      // AIと一緒に考えられないことは、気づきを残せないことではない。
      setState(() {
        _isThinking = false;
        _thinkingErrorMessage = '今はAIと一緒に考えることができませんでした。自分の言葉で気づきを残すことはできます。';
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

  Widget _buildThinkingLines(String label, List<String> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              line,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
      ],
    );
  }

  Widget _buildThinkingSupport(ReflectionThinkingSupport support) {
    return Column(
      key: const Key('insight_record_thinking_support'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '考えるためのヒント',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (support.questions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildThinkingLines('問い', support.questions),
        ],
        if (support.perspectives.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildThinkingLines('別の見方', support.perspectives),
        ],
        if (support.possibilities.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildThinkingLines('可能性', support.possibilities),
        ],
      ],
    );
  }

  /// AIと一緒に考えるための、控えめな入り口。
  ///
  /// 主役はあくまでHuman自身の気づきなので、ここは補助として置く。
  /// 使わなくても、この下の入力欄だけで気づきは残せる。
  Widget _buildThinkingSection() {
    final support = _thinkingSupport;
    final errorMessage = _thinkingErrorMessage;

    return Card(
      key: const Key('insight_record_thinking_section'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.forum_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'AIと一緒に考える',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (widget.thinkingAssistant.isDemo) ...[
              const SizedBox(height: 8),
              Text(
                'AI思考サポート デモ',
                key: const Key('insight_record_thinking_demo_notice'),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(height: 1.5),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '答えではなく、考えるためのヒントです。今は使わなくても大丈夫です。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
            if (support != null) ...[
              const SizedBox(height: 16),
              _buildThinkingSupport(support),
            ],
            if (errorMessage != null) _buildErrorText(errorMessage),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('insight_record_thinking_button'),
                // 考えている間は押せないようにして、頼み直しを重ねさせない。
                onPressed: _isThinking ? null : _requestThinkingSupport,
                icon: _isThinking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.forum_outlined),
                label: Text(_thinkingButtonLabel()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _thinkingButtonLabel() {
    if (_isThinking) {
      return '一緒に考えています…';
    }

    if (_thinkingSupport != null || _thinkingErrorMessage != null) {
      return 'もう一度一緒に考える';
    }

    return '一緒に考える';
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
                    const SizedBox(height: 24),
                    _buildThinkingSection(),
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
