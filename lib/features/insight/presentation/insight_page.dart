import 'package:ai_life_partner/features/insight/domain/models/insight_entry.dart';
import 'package:ai_life_partner/features/insight/domain/repositories/insight_repository.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:ai_life_partner/features/reflection/domain/repositories/reflection_repository.dart';
import 'package:flutter/material.dart';

/// これまでの気づきを、新しい順に並べて読み返す画面。
///
/// 気づきの深さや正しさを測らない。段階にも点数にもしない。
/// Humanが自分で見つけた言葉を、そのまま置いておく場所である。
class InsightPage extends StatefulWidget {
  const InsightPage({
    super.key,
    required this.insightRepository,
    required this.reflectionRepository,
    required this.humanId,
  });

  final InsightRepository insightRepository;

  /// 気づきのもとになった振り返りを読むために使う。
  final ReflectionRepository reflectionRepository;

  final String humanId;

  /// v1で読み込む期間の長さ。
  static const Duration visibleRange = Duration(days: 365);

  @override
  State<InsightPage> createState() => _InsightPageState();
}

/// 気づきと、そのもとになった振り返りの組。
///
/// 振り返りが読めないこともあるため、[reflectionEntry] はnullを許す。
class _InsightListItem {
  const _InsightListItem({required this.insight, this.reflectionEntry});

  final InsightEntry insight;
  final ReflectionEntry? reflectionEntry;
}

class _InsightPageState extends State<InsightPage> {
  List<_InsightListItem> _items = <_InsightListItem>[];

  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();

    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final List<InsightEntry> insights;

    // 気づきは主たる記録なので、その取得だけを分けて扱う。
    try {
      final now = DateTime.now();

      insights = await widget.insightRepository.getEntries(
        humanId: widget.humanId,
        rangeStart: now.subtract(InsightPage.visibleRange),
        // 残した瞬間の気づきも含めるため、少し先までを範囲にする。
        rangeEnd: now.add(const Duration(days: 1)),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error;
        _isLoading = false;
      });

      return;
    }

    // 振り返りは気づきに添える手がかりなので、
    // ここで何が起きても気づきそのものは必ず表示する。
    final items = <_InsightListItem>[];

    for (final insight in insights) {
      items.add(
        _InsightListItem(
          insight: insight,
          reflectionEntry: await _readReflectionEntry(insight),
        ),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  /// 気づきのもとになった振り返りを読む。
  ///
  /// 読めなかった場合も、別のHumanの振り返りだった場合もnullを返し、
  /// Human本人が書いた気づきのほうは必ず残す。
  Future<ReflectionEntry?> _readReflectionEntry(InsightEntry insight) async {
    final reflectionEntry = await _findReflectionEntry(
      insight.reflectionEntryId,
    );

    if (reflectionEntry == null) {
      return null;
    }

    // 別のHumanの振り返りの内容は、けっして表示しない。
    // Repositoryが返してきたとしても、ここで境界を確かめる。
    if (reflectionEntry.humanId != insight.humanId) {
      return null;
    }

    return reflectionEntry;
  }

  /// 振り返りを1件だけ読む。読めなかった場合は見つからなかったものとして扱う。
  Future<ReflectionEntry?> _findReflectionEntry(
    String reflectionEntryId,
  ) async {
    try {
      return await widget.reflectionRepository.getEntryById(reflectionEntryId);
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

  Widget _buildReflectionContext(ReflectionEntry? reflectionEntry) {
    if (reflectionEntry == null) {
      // 手がかりが添えられないことだけを伝える。
      // Humanが書いた気づきはこの上にそのまま残っている。
      return Text(
        '元の振り返りを確認できませんでした。',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reflectionEntry.hasFeelingText)
          _buildLabelledText('感じたこと', reflectionEntry.feelingText!),
        if (reflectionEntry.hasFeelingText && reflectionEntry.hasNoticedText)
          const SizedBox(height: 14),
        if (reflectionEntry.hasNoticedText)
          _buildLabelledText('気づいたこと', reflectionEntry.noticedText!),
      ],
    );
  }

  Widget _buildItemCard(_InsightListItem item) {
    final insight = item.insight;

    return Card(
      key: Key('insight_entry_${insight.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(insight.discoveredAt),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildLabelledText('見つけた気づき', insight.insightText),
            const SizedBox(height: 16),
            _buildReflectionContext(item.reflectionEntry),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      key: const Key('insight_empty_state'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.lightbulb_outline, size: 48),
            const SizedBox(height: 16),
            Text('まだ気づきはありません。', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              '残したくなったときに、振り返りから気づきを残せます。',
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
          const Text('気づきを読み込めませんでした。'),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _loadItems, child: const Text('もう一度読み込む')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('気づき')),
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
                    'これまでの気づき',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'あなた自身が見つけた言葉を、そのまま残しています。',
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
