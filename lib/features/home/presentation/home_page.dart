import 'package:ai_life_partner/features/calendar/data/in_memory_calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:ai_life_partner/features/calendar/presentation/calendar_page.dart';
import 'package:ai_life_partner/features/next_step/presentation/next_step_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.selectedAreas,
    required this.goals,
    required this.supportPreferences,
    this.displayName,
  });

  final String? displayName;
  final List<String> selectedAreas;
  final Map<String, String> goals;
  final List<String> supportPreferences;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _humanId = 'local-human';

  final CalendarRepository _calendarRepository = InMemoryCalendarRepository();

  String? _todayAction;

  String get _name {
    final name = widget.displayName?.trim();

    if (name == null || name.isEmpty) {
      return 'あなた';
    }

    return name;
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openNextStep() async {
    final action = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => NextStepPage(
          displayName: widget.displayName,
          selectedAreas: widget.selectedAreas,
          goals: widget.goals,
        ),
      ),
    );

    if (!mounted || action == null || action.trim().isEmpty) {
      return;
    }

    setState(() {
      _todayAction = action.trim();
    });
  }

  Future<void> _openCalendar() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            CalendarPage(repository: _calendarRepository, humanId: _humanId),
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedAreas(BuildContext context) {
    if (widget.selectedAreas.isEmpty) {
      return Text(
        '取り組むことは、これから一緒に考えられます。',
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.selectedAreas
          .map((area) => Chip(label: Text(area)))
          .toList(),
    );
  }

  Widget _buildGoals(BuildContext context) {
    if (widget.goals.isEmpty) {
      return Text(
        '目標はまだ決まっていません。\n'
        '対話をしながら少しずつ整理していきましょう。',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.goals.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                entry.value,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSupportPreferences(BuildContext context) {
    if (widget.supportPreferences.isEmpty) {
      return Text(
        '支援方法は、利用しながら選べます。',
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.supportPreferences
          .map(
            (preference) => Chip(
              avatar: const Icon(Icons.check, size: 18),
              label: Text(preference),
            ),
          )
          .toList(),
    );
  }

  Widget _buildQuickAction({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 32),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayActionCard(BuildContext context) {
    final action = _todayAction;
    final hasAction = action != null && action.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  hasAction ? Icons.flag_outlined : Icons.lightbulb_outline,
                  size: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '今日の一歩',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              hasAction
                  ? action
                  : 'まずは、今の状況や予定を確認しながら、'
                        '今日できることを一緒に考えましょう。',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.6,
                fontWeight: hasAction ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openNextStep,
              icon: Icon(hasAction ? Icons.edit_outlined : Icons.arrow_forward),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(hasAction ? '次の一歩を見直す' : '次の一歩を考える'),
              ),
            ),
            if (hasAction) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  _showComingSoon(
                    context,
                    '次の工程で、完了したActionをJourneyへ残せるようにします',
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('できたと記録する'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Life Partner'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: '設定',
            onPressed: () {
              _showComingSoon(context, '設定画面は今後追加します');
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '$_nameさん、\n今日も一緒に考えましょう。',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'これまでの歩みを振り返りながら、'
                    '今のあなたに合った次の一歩を考えます。',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 32),
                  _buildTodayActionCard(context),
                  const SizedBox(height: 20),
                  _buildSection(
                    context: context,
                    title: 'Life Projects',
                    child: _buildSelectedAreas(context),
                  ),
                  _buildSection(
                    context: context,
                    title: '目指したい状態',
                    child: _buildGoals(context),
                  ),
                  _buildSection(
                    context: context,
                    title: 'AIに希望する支援',
                    child: _buildSupportPreferences(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'できること',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildQuickAction(
                        context: context,
                        icon: Icons.calendar_month_outlined,
                        title: 'カレンダー',
                        description: '月の予定を確認し、日ごとの時間を整理します。',
                        onTap: () {
                          _openCalendar();
                        },
                      ),
                      _buildQuickAction(
                        context: context,
                        icon: Icons.route_outlined,
                        title: '歩みを残す',
                        description: '今日行ったことや感じたことを記録します。',
                        onTap: () {
                          _showComingSoon(context, 'Journey機能は今後追加します');
                        },
                      ),
                      _buildQuickAction(
                        context: context,
                        icon: Icons.auto_stories_outlined,
                        title: '振り返る',
                        description: '経験を振り返り、気付きを整理します。',
                        onTap: () {
                          _showComingSoon(context, 'Reflection機能は今後追加します');
                        },
                      ),
                      _buildQuickAction(
                        context: context,
                        icon: Icons.chat_bubble_outline,
                        title: 'AIと相談する',
                        description: '答えを決めつけず、次の一歩を一緒に考えます。',
                        onTap: () {
                          _showComingSoon(context, 'AI Dialogue機能は今後追加します');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
