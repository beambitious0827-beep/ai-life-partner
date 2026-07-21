import 'package:flutter/material.dart';

import 'onboarding_complete_page.dart';

enum SupportPreference {
  planning,
  questions,
  suggestions,
  journey,
  reflection,
  onDemand,
}

extension SupportPreferenceView on SupportPreference {
  String get label {
    switch (this) {
      case SupportPreference.planning:
        return '計画を一緒に考える';
      case SupportPreference.questions:
        return '問いかけで考えを整理する';
      case SupportPreference.suggestions:
        return '選択肢やヒントを提案する';
      case SupportPreference.journey:
        return '歩みや記録を整理する';
      case SupportPreference.reflection:
        return '振り返りを支える';
      case SupportPreference.onDemand:
        return '必要なときだけ相談する';
    }
  }

  String get description {
    switch (this) {
      case SupportPreference.planning:
        return '予定や状況に合わせて、次の行動を一緒に考えます。';
      case SupportPreference.questions:
        return 'すぐに答えを出さず、問いかけを通して考えを整理します。';
      case SupportPreference.suggestions:
        return '複数の選択肢と、その理由や注意点を提示します。';
      case SupportPreference.journey:
        return '行動や変化を歩みとして残し、分かりやすく整理します。';
      case SupportPreference.reflection:
        return '日々や節目の振り返りから、気付きを見つける手助けをします。';
      case SupportPreference.onDemand:
        return '普段は静かに見守り、相談されたときに支援します。';
    }
  }

  IconData get icon {
    switch (this) {
      case SupportPreference.planning:
        return Icons.calendar_month_outlined;
      case SupportPreference.questions:
        return Icons.question_answer_outlined;
      case SupportPreference.suggestions:
        return Icons.lightbulb_outline;
      case SupportPreference.journey:
        return Icons.route_outlined;
      case SupportPreference.reflection:
        return Icons.auto_stories_outlined;
      case SupportPreference.onDemand:
        return Icons.notifications_none_outlined;
    }
  }
}

class SupportPreferencePage extends StatefulWidget {
  const SupportPreferencePage({
    super.key,
    required this.selectedAreas,
    required this.goals,
    this.displayName,
  });

  final String? displayName;
  final List<String> selectedAreas;
  final Map<String, String> goals;

  @override
  State<SupportPreferencePage> createState() => _SupportPreferencePageState();
}

class _SupportPreferencePageState extends State<SupportPreferencePage> {
  final Set<SupportPreference> _selectedPreferences = <SupportPreference>{};

  String get _headline {
    final displayName = widget.displayName?.trim();

    if (displayName == null || displayName.isEmpty) {
      return 'どのような支援を\n希望しますか？';
    }

    return '$displayNameさんは、\nどのような支援を希望しますか？';
  }

  List<String> get _selectedLabels {
    return SupportPreference.values
        .where(_selectedPreferences.contains)
        .map((preference) => preference.label)
        .toList();
  }

  void _updateSelection(SupportPreference preference, bool selected) {
    setState(() {
      if (selected) {
        _selectedPreferences.add(preference);
      } else {
        _selectedPreferences.remove(preference);
      }
    });
  }

  void _openCompletion(List<String> supportPreferences) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OnboardingCompletePage(
          displayName: widget.displayName,
          selectedAreas: widget.selectedAreas,
          goals: widget.goals,
          supportPreferences: supportPreferences,
        ),
      ),
    );
  }

  void _completeSelection() {
    _openCompletion(_selectedLabels);
  }

  void _skipForNow() {
    _openCompletion(const <String>[]);
  }

  Widget _buildPreferenceCard(SupportPreference preference) {
    final selected = _selectedPreferences.contains(preference);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _updateSelection(preference, !selected);
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(preference.icon, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preference.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preference.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Checkbox(
                value: selected,
                onChanged: (value) {
                  _updateSelection(preference, value ?? false);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'ステップ 4 / 4',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const Spacer(),
                      Text(
                        '${_selectedPreferences.length}件選択',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(value: 1),
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
                    'AIの支援方法は一つに決める必要はありません。'
                    '今の希望に近いものを選んでください。'
                    'あとからいつでも変更できます。',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 32),
                  ...SupportPreference.values.map(_buildPreferenceCard),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _selectedPreferences.isEmpty
                        ? null
                        : _completeSelection,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('選んだ内容で初期設定を完了する'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _skipForNow,
                    child: const Text('あとで設定する'),
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
