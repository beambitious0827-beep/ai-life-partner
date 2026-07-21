import 'package:flutter/material.dart';

import 'goal_definition_page.dart';

enum FocusArea { learning, training, nutrition, sleep, work, hobby, other }

extension FocusAreaView on FocusArea {
  String get label {
    switch (this) {
      case FocusArea.learning:
        return '学習・受験';
      case FocusArea.training:
        return 'トレーニング';
      case FocusArea.nutrition:
        return '食事';
      case FocusArea.sleep:
        return '睡眠・生活リズム';
      case FocusArea.work:
        return '仕事・プロジェクト';
      case FocusArea.hobby:
        return '趣味・新しい挑戦';
      case FocusArea.other:
        return 'その他';
    }
  }

  IconData get icon {
    switch (this) {
      case FocusArea.learning:
        return Icons.school_outlined;
      case FocusArea.training:
        return Icons.fitness_center_outlined;
      case FocusArea.nutrition:
        return Icons.restaurant_outlined;
      case FocusArea.sleep:
        return Icons.bedtime_outlined;
      case FocusArea.work:
        return Icons.work_outline;
      case FocusArea.hobby:
        return Icons.auto_awesome_outlined;
      case FocusArea.other:
        return Icons.more_horiz;
    }
  }
}

class FocusSelectionPage extends StatefulWidget {
  const FocusSelectionPage({super.key, this.displayName});

  final String? displayName;

  @override
  State<FocusSelectionPage> createState() => _FocusSelectionPageState();
}

class _FocusSelectionPageState extends State<FocusSelectionPage> {
  final Set<FocusArea> _selectedAreas = <FocusArea>{};

  String get _headline {
    final displayName = widget.displayName?.trim();

    if (displayName == null || displayName.isEmpty) {
      return '今、取り組んでいることを\n教えてください';
    }

    return '$displayNameさんが今、\n取り組んでいることは何ですか？';
  }

  void _updateSelection(FocusArea area, bool selected) {
    setState(() {
      if (selected) {
        _selectedAreas.add(area);
      } else {
        _selectedAreas.remove(area);
      }
    });
  }

  List<String> get _selectedLabels {
    return FocusArea.values
        .where(_selectedAreas.contains)
        .map((area) => area.label)
        .toList();
  }

  void _openGoalDefinition(List<String> selectedAreas) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => GoalDefinitionPage(
          displayName: widget.displayName,
          selectedAreas: selectedAreas,
        ),
      ),
    );
  }

  void _goToNextStep() {
    _openGoalDefinition(_selectedLabels);
  }

  void _skipForNow() {
    _openGoalDefinition(const <String>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('初期設定')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'ステップ 2 / 4',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const Spacer(),
                      Text(
                        '${_selectedAreas.length}件選択',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(value: 0.5),
                  const SizedBox(height: 40),
                  Text(
                    _headline,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'AI Life Partnerと一緒に進めたいことを選んでください。'
                    '複数選択でき、あとからいつでも変更できます。',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 36),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: FocusArea.values.map((area) {
                      final selected = _selectedAreas.contains(area);

                      return FilterChip(
                        selected: selected,
                        showCheckmark: true,
                        avatar: Icon(area.icon, size: 20),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                          child: Text(area.label),
                        ),
                        onSelected: (value) {
                          _updateSelection(area, value);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                  FilledButton(
                    onPressed: _selectedAreas.isEmpty ? null : _goToNextStep,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('選んだ内容で進む'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _skipForNow,
                    child: const Text('あとで選ぶ'),
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
