import 'package:flutter/material.dart';

class OnboardingCompletePage extends StatelessWidget {
  const OnboardingCompletePage({
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

  String get _displayName {
    final name = displayName?.trim();

    if (name == null || name.isEmpty) {
      return 'あなた';
    }

    return name;
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildChips(
    BuildContext context,
    List<String> values,
    String emptyMessage,
  ) {
    if (values.isEmpty) {
      return Text(emptyMessage, style: Theme.of(context).textTheme.bodyMedium);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) => Chip(label: Text(value))).toList(),
    );
  }

  Widget _buildGoals(BuildContext context) {
    if (goals.isEmpty) {
      return Text(
        '目標はあとから一緒に考えられます。',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: goals.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
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

  void _startApp(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('初期設定が完了しました。次はホーム画面へ接続します')));

    // 次の工程でAI Life Partnerのホーム画面へ接続します。
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('初期設定完了')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.check_circle_outline, size: 72),
                  const SizedBox(height: 24),
                  Text(
                    '$_displayNameさんの\n最初の準備ができました',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ここで決めた内容は完成形ではありません。'
                    '対話や歩みを重ねながら、少しずつ変えていけます。',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 36),
                  _buildSection(
                    context: context,
                    title: '取り組んでいること',
                    child: _buildChips(
                      context,
                      selectedAreas,
                      '取り組んでいることは、あとから設定できます。',
                    ),
                  ),
                  _buildSection(
                    context: context,
                    title: '目指したい状態',
                    child: _buildGoals(context),
                  ),
                  _buildSection(
                    context: context,
                    title: '希望する支援方法',
                    child: _buildChips(
                      context,
                      supportPreferences,
                      '支援方法は、利用しながら選べます。',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      _startApp(context);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('AI Life Partnerを始める'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('支援方法を見直す'),
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
