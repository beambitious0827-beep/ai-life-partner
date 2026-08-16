import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/repositories/journey_repository.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:ai_life_partner/features/reflection/domain/repositories/reflection_repository.dart';
import 'package:flutter/material.dart';

/// これまでの振り返りを、新しい順に並べて読み返す画面。
///
/// 良い振り返り・悪い振り返りという区別はしない。
/// 数や頻度も数えない。書かれた言葉をそのまま置いておく場所である。
class ReflectionPage extends StatefulWidget {
  const ReflectionPage({
    super.key,
    required this.reflectionRepository,
    required this.journeyRepository,
    required this.humanId,
  });

  final ReflectionRepository reflectionRepository;

  /// 振り返りの対象になった歩みを読むために使う。
  final JourneyRepository journeyRepository;

  final String humanId;

  /// v1で読み込む期間の長さ。
  static const Duration visibleRange = Duration(days: 365);

  @override
  State<ReflectionPage> createState() => _ReflectionPageState();
}

/// 振り返りと、その対象になった歩みの組。
///
/// 歩みが見つからないこともあるため、[journeyEntry] はnullを許す。
class _ReflectionListItem {
  const _ReflectionListItem({required this.reflection, this.journeyEntry});

  final ReflectionEntry reflection;
  final JourneyEntry? journeyEntry;
}

class _ReflectionPageState extends State<ReflectionPage> {
  List<_ReflectionListItem> _items = <_ReflectionListItem>[];

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

    try {
      final now = DateTime.now();

      final reflections = await widget.reflectionRepository.getEntries(
        humanId: widget.humanId,
        rangeStart: now.subtract(ReflectionPage.visibleRange),
        // 残した瞬間の振り返りも含めるため、少し先までを範囲にする。
        rangeEnd: now.add(const Duration(days: 1)),
      );

      final items = <_ReflectionListItem>[];

      for (final reflection in reflections) {
        items.add(
          _ReflectionListItem(
            reflection: reflection,
            journeyEntry: await _readJourneyEntry(reflection),
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
