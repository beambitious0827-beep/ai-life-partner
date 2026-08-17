import 'package:ai_life_partner/features/insight/domain/models/insight_entry.dart';
import 'package:ai_life_partner/features/insight/domain/repositories/insight_repository.dart';
import 'package:ai_life_partner/features/insight/presentation/insight_record_page.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/repositories/journey_repository.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:ai_life_partner/features/reflection/domain/repositories/reflection_repository.dart';
import 'package:flutter/material.dart';

/// これまでの振り返りを、新しい順に並べて読み返す画面。
///
/// 良い振り返り・悪い振り返りという区別はしない。
/// 数や頻度も数えない。書かれた言葉をそのまま置いておく場所である。
///
/// 気づきを残したくなった振り返りがあれば、ここから始められる。
/// ただし残すかどうかを決めるのはHumanで、ここでは促さない。
class ReflectionPage extends StatefulWidget {
  const ReflectionPage({
    super.key,
    required this.reflectionRepository,
    required this.journeyRepository,
    required this.insightRepository,
    required this.humanId,
  });

  final ReflectionRepository reflectionRepository;

  /// 振り返りの対象になった歩みを読むために使う。
  final JourneyRepository journeyRepository;

  /// 振り返りごとに気づきが残っているかを確かめ、新しい気づきを保存する先。
  final InsightRepository insightRepository;

  final String humanId;

  /// v1で読み込む期間の長さ。
  static const Duration visibleRange = Duration(days: 365);

  @override
  State<ReflectionPage> createState() => _ReflectionPageState();
}

/// ひとつの振り返りについて、気づきがどうなっているか。
///
/// 「まだ残していない」と「確かめられなかった」は違う。
/// 確かめられていないのに気づきを促すと、
/// すでに残した気づきをもう一度書かせてしまうため、区別して扱う。
enum _InsightStatus { none, present, unknown }

/// 振り返りと、その対象になった歩み、そして気づきの状態の組。
///
/// 歩みが見つからないこともあるため、[journeyEntry] はnullを許す。
class _ReflectionListItem {
  const _ReflectionListItem({
    required this.reflection,
    required this.insightStatus,
    this.journeyEntry,
  });

  final ReflectionEntry reflection;
  final JourneyEntry? journeyEntry;
  final _InsightStatus insightStatus;
}

class _ReflectionPageState extends State<ReflectionPage> {
  List<_ReflectionListItem> _items = <_ReflectionListItem>[];

  bool _isLoading = true;
  Object? _loadError;

  /// 発行した確認の通し番号。あとから発行したものほど新しい。
  int _requestSequence = 0;

  /// いま画面が受け入れる、全体の読み込みの番号。
  int _loadRequestId = 0;

  /// 振り返りIDごとに、いま受け入れる気づき確認の番号。
  ///
  /// 確認は頼んだ順に返ってくるとはかぎらない。
  /// 古い確認の結果が新しい状態を上書きしないよう、最新の番号だけを覚えておく。
  final Map<String, int> _insightRequestIds = <String, int>{};

  /// いま気づきの状態を確認し直している振り返り。
  final Set<String> _recheckingReflectionIds = <String>{};

  @override
  void initState() {
    super.initState();

    _loadItems();
  }

  Future<void> _loadItems() async {
    final requestId = ++_requestSequence;

    setState(() {
      _loadRequestId = requestId;

      // 読み直しを始めた時点で、走っている個別の確認はすべて古くなる。
      // あとから返ってきても、この読み込みの結果を書き換えさせない。
      _insightRequestIds.clear();
      _recheckingReflectionIds.clear();

      _isLoading = true;
      _loadError = null;
    });

    final List<ReflectionEntry> reflections;

    // 振り返りは主たる記録なので、その取得だけを分けて扱う。
    try {
      final now = DateTime.now();

      reflections = await widget.reflectionRepository.getEntries(
        humanId: widget.humanId,
        rangeStart: now.subtract(ReflectionPage.visibleRange),
        // 残した瞬間の振り返りも含めるため、少し先までを範囲にする。
        rangeEnd: now.add(const Duration(days: 1)),
      );
    } on Object catch (error) {
      // 待っている間に新しい読み込みが始まっていたら、この結果はもう古い。
      if (!mounted || _loadRequestId != requestId) {
        return;
      }

      setState(() {
        _loadError = error;
        _isLoading = false;
      });

      return;
    }

    // 歩みも気づきも、振り返りに付く任意の情報でしかない。
    // ここで何が起きても振り返りそのものは必ず表示する。
    final items = <_ReflectionListItem>[];

    for (final reflection in reflections) {
      // この読み込みが、その振り返りの最新の確認であることを記録する。
      _insightRequestIds[reflection.id] = requestId;

      items.add(
        _ReflectionListItem(
          reflection: reflection,
          journeyEntry: await _readJourneyEntry(reflection),
          insightStatus: await _readInsightStatus(reflection),
        ),
      );
    }

    if (!mounted || _loadRequestId != requestId) {
      return;
    }

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  /// ひとつの振り返りについて、気づきの状態を確かめる。
  ///
  /// 1件確かめられなくても、他の振り返りの状態には影響させない。
  Future<_InsightStatus> _readInsightStatus(ReflectionEntry reflection) async {
    try {
      final insight = await widget.insightRepository.getEntryForReflection(
        humanId: widget.humanId,
        reflectionEntryId: reflection.id,
      );

      return insight == null ? _InsightStatus.none : _InsightStatus.present;
    } on Object catch (_) {
      // 気づきがあるともないとも言えない。分からないままにしておく。
      return _InsightStatus.unknown;
    }
  }

  /// ひとつの振り返りについてだけ、気づきの状態を確かめ直す。
  ///
  /// 同じ振り返りの確認を重ねて増やさない。
  /// また、待っている間に新しい確認や読み直しが始まっていた場合は、
  /// 成功でも失敗でもこの結果を捨てる。古い答えで新しい状態を戻さないため。
  Future<void> _recheckInsightStatus(ReflectionEntry reflection) async {
    if (_isLoading || _recheckingReflectionIds.contains(reflection.id)) {
      return;
    }

    final requestId = ++_requestSequence;

    setState(() {
      _insightRequestIds[reflection.id] = requestId;
      _recheckingReflectionIds.add(reflection.id);
    });

    final status = await _readInsightStatus(reflection);

    if (!mounted || _insightRequestIds[reflection.id] != requestId) {
      return;
    }

    setState(() {
      _recheckingReflectionIds.remove(reflection.id);

      _items = _items.map((item) {
        if (item.reflection.id != reflection.id) {
          return item;
        }

        return _ReflectionListItem(
          reflection: item.reflection,
          journeyEntry: item.journeyEntry,
          insightStatus: status,
        );
      }).toList();
    });
  }

  /// ひとつの振り返りについて、気づきを残す画面を開く。
  ///
  /// ここではInsightEntryを作らない。
  /// 気づきの画面でHumanが「気づきを残す」を押したときだけ保存される。
  Future<void> _openInsightRecord(ReflectionEntry reflection) async {
    final saved = await Navigator.of(context).push<InsightEntry>(
      MaterialPageRoute<InsightEntry>(
        builder: (context) => InsightRecordPage(
          repository: widget.insightRepository,
          humanId: widget.humanId,
          reflectionEntry: reflection,
        ),
      ),
    );

    if (!mounted || saved == null) {
      return;
    }

    // 保存された事実は画面のフラグではなくRepositoryから読み直す。
    await _loadItems();
  }

  /// 振り返りのもとになった歩みを読む。
  ///
  /// 歩みは、振り返りに添える手がかりでしかない。
  /// 読めなかった場合も、別のHumanの歩みだった場合もnullを返し、
  /// Human本人が書いた言葉のほうは必ず残す。
  Future<JourneyEntry?> _readJourneyEntry(ReflectionEntry reflection) async {
    final journeyEntry = await _findJourneyEntry(reflection.journeyEntryId);

    if (journeyEntry == null) {
      return null;
    }

    // 別のHumanの歩みの内容は、けっして表示しない。
    // Repositoryが返してきたとしても、ここで境界を確かめる。
    if (journeyEntry.humanId != reflection.humanId) {
      return null;
    }

    return journeyEntry;
  }

  /// 歩みを1件だけ読む。読めなかった場合は見つからなかったものとして扱う。
  Future<JourneyEntry?> _findJourneyEntry(String journeyEntryId) async {
    try {
      return await widget.journeyRepository.getEntryById(journeyEntryId);
    } on Object catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime date) {
    const weekdays = <String>['月', '火', '水', '木', '金', '土', '日'];

    final weekday = weekdays[date.weekday - 1];

    return '${date.year}年${date.month}月${date.day}日（$weekday）';
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

  /// 気づきが残っていることの、控えめな表示。
  Widget _buildInsightRecordedLabel(ReflectionEntry reflection) {
    return Row(
      key: Key('reflection_insight_recorded_${reflection.id}'),
      children: [
        Icon(
          Icons.lightbulb_outline,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text('気づきを残しました', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  /// 気づきの状態が確かめられなかったときの表示。
  ///
  /// ここでは「この振り返りから気づきを残す」を出さない。
  /// すでに残した気づきがあるかどうか分からないまま書き始めると、
  /// 同じ振り返りへ二つ目の気づきを作らせてしまうため。
  Widget _buildInsightUnknown(ReflectionEntry reflection) {
    final isRechecking = _recheckingReflectionIds.contains(reflection.id);

    return Column(
      key: Key('reflection_insight_unknown_${reflection.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '気づきの状態を確認できませんでした。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: Key('reflection_insight_recheck_button_${reflection.id}'),
          // 確認中は押せないようにして、同じ確認をいくつも走らせない。
          onPressed: isRechecking
              ? null
              : () {
                  _recheckInsightStatus(reflection);
                },
          child: Text(isRechecking ? '確認しています…' : 'もう一度確認する'),
        ),
      ],
    );
  }

  /// 気づきへの入り口。
  ///
  /// 「まだ気づきを残していない」ことを欠けている状態として見せない。
  Widget _buildInsightAction(_ReflectionListItem item) {
    final reflection = item.reflection;

    switch (item.insightStatus) {
      case _InsightStatus.present:
        return _buildInsightRecordedLabel(reflection);
      case _InsightStatus.unknown:
        return _buildInsightUnknown(reflection);
      case _InsightStatus.none:
        return Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: Key('reflection_insight_button_${reflection.id}'),
            onPressed: () {
              _openInsightRecord(reflection);
            },
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('この振り返りから気づきを残す'),
          ),
        );
    }
  }

  Widget _buildItemCard(_ReflectionListItem item) {
    final reflection = item.reflection;
    final journeyEntry = item.journeyEntry;

    return Card(
      key: Key('reflection_entry_${reflection.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(reflection.reflectedAt),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (journeyEntry != null) ...[
              const SizedBox(height: 16),
              _buildLabelledText('振り返った歩み', journeyEntry.plannedActionText),
            ] else ...[
              const SizedBox(height: 16),
              // 手がかりが添えられないことだけを伝える。
              // Humanが書いた言葉はこの下にそのまま残っている。
              Text(
                '元の歩みを確認できませんでした。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (reflection.hasFeelingText) ...[
              const SizedBox(height: 16),
              _buildLabelledText('感じたこと', reflection.feelingText!),
            ],
            if (reflection.hasNoticedText) ...[
              const SizedBox(height: 16),
              _buildLabelledText('気づいたこと', reflection.noticedText!),
            ],
            const SizedBox(height: 20),
            _buildInsightAction(item),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      key: const Key('reflection_empty_state'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.auto_stories_outlined, size: 48),
            const SizedBox(height: 16),
            Text('まだ振り返りはありません。', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              '残したくなったときに、歩みを振り返ることができます。',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          const Text('振り返りを読み込めませんでした。'),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _loadItems, child: const Text('もう一度読み込む')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('振り返り')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'これまでの振り返り',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'あなたが感じたことや、気づいたことを、そのまま残しています。',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 28),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_loadError != null)
                    _buildErrorState()
                  else if (_items.isEmpty)
                    _buildEmptyState()
                  else
                    ..._items.map(_buildItemCard),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
