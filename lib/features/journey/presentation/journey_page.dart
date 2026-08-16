import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_outcome.dart';
import 'package:ai_life_partner/features/journey/domain/repositories/journey_repository.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:ai_life_partner/features/reflection/domain/repositories/reflection_repository.dart';
import 'package:ai_life_partner/features/reflection/presentation/reflection_record_page.dart';
import 'package:flutter/material.dart';

/// これまでの歩みを、新しい順に並べて見る画面。
///
/// 達成率、成功数、連続記録のような集計は表示しない。
/// 歩みは測るものではなく、読み返すものとして扱う。
///
/// 振り返りたくなった歩みがあれば、ここから振り返りを始められる。
/// ただし振り返るかどうかを決めるのはHumanで、ここでは促さない。
class JourneyPage extends StatefulWidget {
  const JourneyPage({
    super.key,
    required this.repository,
    required this.reflectionRepository,
    required this.humanId,
  });

  final JourneyRepository repository;

  /// 歩みごとに振り返りが残っているかを確かめ、新しい振り返りを保存する先。
  final ReflectionRepository reflectionRepository;

  final String humanId;

  /// v1で読み込む期間の長さ。
  static const Duration visibleRange = Duration(days: 365);

  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

/// ひとつの歩みについて、振り返りがどうなっているか。
///
/// 「まだ振り返っていない」と「確かめられなかった」は違う。
/// 確かめられていないのに振り返りを促すと、
/// すでに残した振り返りをもう一度書かせてしまうため、区別して扱う。
enum _ReflectionStatus { none, present, unknown }

class _JourneyPageState extends State<JourneyPage> {
  List<JourneyEntry> _entries = <JourneyEntry>[];

  /// 歩みのIDごとの、振り返りの状態。
  ///
  /// 画面内のフラグではなくRepositoryから読み直した内容を正とする。
  Map<String, _ReflectionStatus> _reflectionStatuses =
      <String, _ReflectionStatus>{};

  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();

    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final List<JourneyEntry> entries;

    // 歩みは主たる記録なので、その取得だけを分けて扱う。
    try {
      final now = DateTime.now();

      entries = await widget.repository.getEntries(
        humanId: widget.humanId,
        rangeStart: now.subtract(JourneyPage.visibleRange),
        // 記録した瞬間の歩みも含めるため、少し先までを範囲にする。
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

    // 振り返りは歩みに付く任意の情報なので、
    // ここで何が起きても歩みそのものは必ず表示する。
    final statuses = await _readReflectionStatuses(entries);

    if (!mounted) {
      return;
    }

    setState(() {
      _entries = entries;
      _reflectionStatuses = statuses;
      _isLoading = false;
    });
  }

  /// それぞれの歩みについて、振り返りの状態を歩みごとに確かめる。
  ///
  /// 1件確かめられなくても、他の歩みの状態には影響させない。
  Future<Map<String, _ReflectionStatus>> _readReflectionStatuses(
    List<JourneyEntry> entries,
  ) async {
    final statuses = <String, _ReflectionStatus>{};

    for (final entry in entries) {
      statuses[entry.id] = await _readReflectionStatus(entry);
    }

    return statuses;
  }

  Future<_ReflectionStatus> _readReflectionStatus(JourneyEntry entry) async {
    try {
      final reflection = await widget.reflectionRepository.getEntryForJourney(
        humanId: widget.humanId,
        journeyEntryId: entry.id,
      );

      return reflection == null
          ? _ReflectionStatus.none
          : _ReflectionStatus.present;
    } on Object catch (_) {
      // 振り返りがあるともないとも言えない。分からないままにしておく。
      return _ReflectionStatus.unknown;
    }
  }

  /// ひとつの歩みについてだけ、振り返りの状態を確かめ直す。
  Future<void> _recheckReflectionStatus(JourneyEntry entry) async {
    final status = await _readReflectionStatus(entry);

    if (!mounted) {
      return;
    }

    setState(() {
      _reflectionStatuses = <String, _ReflectionStatus>{
        ..._reflectionStatuses,
        entry.id: status,
      };
    });
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

  /// ひとつの歩みについて、振り返りを残す画面を開く。
  ///
  /// ここではReflectionEntryを作らない。
  /// 振り返り画面でHumanが「振り返りを残す」を押したときだけ保存される。
  Future<void> _openReflectionRecord(JourneyEntry entry) async {
    final saved = await Navigator.of(context).push<ReflectionEntry>(
      MaterialPageRoute<ReflectionEntry>(
        builder: (context) => ReflectionRecordPage(
          repository: widget.reflectionRepository,
          humanId: widget.humanId,
          journeyEntry: entry,
        ),
      ),
    );

    if (!mounted || saved == null) {
      return;
    }

    // 保存された事実は画面のフラグではなくRepositoryから読み直す。
    await _loadEntries();
  }

  /// 振り返りが残っていることの、控えめな表示。
  Widget _buildReflectedLabel(JourneyEntry entry) {
    return Row(
      key: Key('journey_reflected_label_${entry.id}'),
      children: [
        Icon(
          Icons.auto_stories_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text('振り返りを残しました', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  /// 振り返りの状態が確かめられなかったときの表示。
  ///
  /// ここでは「この歩みを振り返る」を出さない。
  /// すでに残した振り返りがあるかどうか分からないまま書き始めると、
  /// 同じ歩みへ二つ目の振り返りを作らせてしまうため。
  Widget _buildReflectionUnknown(JourneyEntry entry) {
    return Column(
      key: Key('journey_reflection_unknown_${entry.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '振り返りの状態を確認できませんでした。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: Key('journey_reflection_recheck_button_${entry.id}'),
          onPressed: () {
            _recheckReflectionStatus(entry);
          },
          child: const Text('もう一度確認する'),
        ),
      ],
    );
  }

  /// 振り返りへの入り口。
  ///
  /// 「まだ振り返っていない」ことを欠けている状態として見せない。
  Widget _buildReflectionAction(JourneyEntry entry) {
    final status = _reflectionStatuses[entry.id] ?? _ReflectionStatus.unknown;

    switch (status) {
      case _ReflectionStatus.present:
        return _buildReflectedLabel(entry);
      case _ReflectionStatus.unknown:
        return _buildReflectionUnknown(entry);
      case _ReflectionStatus.none:
        return Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: Key('journey_reflect_button_${entry.id}'),
            onPressed: () {
              _openReflectionRecord(entry);
            },
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text('この歩みを振り返る'),
          ),
        );
    }
  }

  Widget _buildEntryCard(JourneyEntry entry) {
    return Card(
      key: Key('journey_entry_${entry.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(entry.occurredAt),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildLabelledText('今日の一歩', entry.plannedActionText),
            const SizedBox(height: 16),
            _buildLabelledText('歩み', entry.outcome.label),
            if (entry.hasActualActionText) ...[
              const SizedBox(height: 16),
              _buildLabelledText('実際の一歩', entry.actualActionText!),
            ],
            if (entry.hasNote) ...[
              const SizedBox(height: 16),
              _buildLabelledText('ひとこと', entry.note!),
            ],
            const SizedBox(height: 20),
            _buildReflectionAction(entry),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      key: const Key('journey_empty_state'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.route_outlined, size: 48),
            const SizedBox(height: 16),
            Text('まだ歩みはありません。', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              'これからの一歩が、少しずつここに残っていきます。',
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
          const Text('歩みを読み込めませんでした。'),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loadEntries,
            child: const Text('もう一度読み込む'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('歩み')),
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
                    'これまでの歩み',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '取り組んだ日も、別のことを選んだ日も、休んだ日も、'
                    'すべてあなたが歩いた道のりです。',
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
                  else if (_entries.isEmpty)
                    _buildEmptyState()
                  else
                    ..._entries.map(_buildEntryCard),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
