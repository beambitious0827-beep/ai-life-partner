import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_outcome.dart';
import 'package:ai_life_partner/features/journey/domain/repositories/journey_repository.dart';
import 'package:flutter/material.dart';

/// これまでの歩みを、新しい順に並べて見る画面。
///
/// 達成率、成功数、連続記録のような集計は表示しない。
/// 歩みは測るものではなく、読み返すものとして扱う。
class JourneyPage extends StatefulWidget {
  const JourneyPage({
    super.key,
    required this.repository,
    required this.humanId,
  });

  final JourneyRepository repository;
  final String humanId;

  /// v1で読み込む期間の長さ。
  static const Duration visibleRange = Duration(days: 365);

  @override
  State<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends State<JourneyPage> {
  List<JourneyEntry> _entries = <JourneyEntry>[];

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

    try {
      final now = DateTime.now();

      final entries = await widget.repository.getEntries(
        humanId: widget.humanId,
        rangeStart: now.subtract(JourneyPage.visibleRange),
        // 記録した瞬間の歩みも含めるため、少し先までを範囲にする。
        rangeEnd: now.add(const Duration(days: 1)),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _entries = entries;
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
