import 'package:flutter/material.dart';

enum AvailableTime { tenMinutes, thirtyMinutes, sixtyMinutes, flexible }

extension AvailableTimeView on AvailableTime {
  String get label {
    switch (this) {
      case AvailableTime.tenMinutes:
        return '10分';
      case AvailableTime.thirtyMinutes:
        return '30分';
      case AvailableTime.sixtyMinutes:
        return '60分';
      case AvailableTime.flexible:
        return '時間は調整できる';
    }
  }

  String get actionDuration {
    switch (this) {
      case AvailableTime.tenMinutes:
        return '10分';
      case AvailableTime.thirtyMinutes:
        return '30分';
      case AvailableTime.sixtyMinutes:
        return '60分';
      case AvailableTime.flexible:
        return '自分で決めた時間';
    }
  }
}

enum EnergyLevel { low, medium, high }

extension EnergyLevelView on EnergyLevel {
  String get label {
    switch (this) {
      case EnergyLevel.low:
        return '余力は少ない';
      case EnergyLevel.medium:
        return 'いつもどおり';
      case EnergyLevel.high:
        return '余力がある';
    }
  }

  String get description {
    switch (this) {
      case EnergyLevel.low:
        return '今日は負担を抑えたい';
      case EnergyLevel.medium:
        return '無理なく進められそう';
      case EnergyLevel.high:
        return '少し多めに取り組めそう';
    }
  }

  String get pace {
    switch (this) {
      case EnergyLevel.low:
        return '負担を抑えて';
      case EnergyLevel.medium:
        return '無理のない範囲で';
      case EnergyLevel.high:
        return '余力を活かして';
    }
  }
}

class NextStepPage extends StatefulWidget {
  const NextStepPage({
    super.key,
    required this.selectedAreas,
    required this.goals,
    this.displayName,
  });

  final String? displayName;
  final List<String> selectedAreas;
  final Map<String, String> goals;

  @override
  State<NextStepPage> createState() => _NextStepPageState();
}

class _NextStepPageState extends State<NextStepPage> {
  final TextEditingController _situationController = TextEditingController();

  final TextEditingController _actionController = TextEditingController();

  late String _selectedArea;

  AvailableTime? _selectedTime;
  EnergyLevel? _selectedEnergy;

  List<String> _suggestions = <String>[];
  String? _selectedSuggestion;

  List<String> get _availableAreas {
    if (widget.selectedAreas.isEmpty) {
      return const <String>['暮らし全体'];
    }

    return widget.selectedAreas;
  }

  String get _displayName {
    final name = widget.displayName?.trim();

    if (name == null || name.isEmpty) {
      return 'あなた';
    }

    return name;
  }

  String? get _selectedGoal {
    return widget.goals[_selectedArea] ?? widget.goals['全体'];
  }

  bool get _canGenerateSuggestions {
    return _selectedTime != null && _selectedEnergy != null;
  }

  bool get _canConfirmAction {
    return _actionController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _selectedArea = _availableAreas.first;
  }

  @override
  void dispose() {
    _situationController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  void _clearSuggestions() {
    _suggestions = <String>[];
    _selectedSuggestion = null;
    _actionController.clear();
  }

  void _selectArea(String area) {
    setState(() {
      _selectedArea = area;
      _clearSuggestions();
    });
  }

  void _selectTime(AvailableTime time) {
    setState(() {
      _selectedTime = time;
      _clearSuggestions();
    });
  }

  void _selectEnergy(EnergyLevel energy) {
    setState(() {
      _selectedEnergy = energy;
      _clearSuggestions();
    });
  }

  List<String> _buildAreaSuggestions({
    required String area,
    required AvailableTime time,
    required EnergyLevel energy,
  }) {
    final duration = time.actionDuration;
    final pace = energy.pace;

    switch (area) {
      case '学習・受験':
        return <String>[
          '$pace、取り組む単元を1つ決めて$duration集中する',
          '苦手な問題を1問選び、解き方を自分の言葉で整理する',
          '今日の学習内容を3つ以内に絞り、最初の1つに着手する',
        ];

      case 'トレーニング':
        return <String>[
          '$pace、$durationでできるトレーニングを1つ選んで行う',
          '体調を確認し、今日鍛える部位と最初の1種目を決める',
          'ウォームアップを始め、終わった時点で続けるか判断する',
        ];

      case '食事':
        return <String>[
          '次の食事で、目標に合う食品を1つ追加する',
          '今日の食事を1食だけ記録し、良かった点を1つ見つける',
          '$pace、明日の食事を1食分だけ考えて準備する',
        ];

      case '睡眠・生活リズム':
        return <String>[
          '今夜の就寝目標時刻を決める',
          '寝る前にやめることを1つ決める',
          '$durationでできる翌朝の準備を済ませ、休める状態を作る',
        ];

      case '仕事・プロジェクト':
        return <String>[
          '今日進める作業を1つだけ選び、$duration取り組む',
          'やることを3つ以内に整理し、最優先を決める',
          '迷っている点を1つ言葉にして、次に確認することを決める',
        ];

      case '趣味・新しい挑戦':
        return <String>[
          '$durationだけ、楽しみたいことに触れる',
          '上達したいことを1つ選び、小さな練習を始める',
          '次に試したいことをメモし、準備を1つ進める',
        ];

      case 'その他':
      case '暮らし全体':
      default:
        return <String>[
          '$pace、今できることを1つだけ選んで$duration取り組む',
          '気になっていることを3つ書き出し、最優先を1つ決める',
          '次に進むために必要な準備を1つだけ行う',
        ];
    }
  }

  void _generateSuggestions() {
    final selectedTime = _selectedTime;
    final selectedEnergy = _selectedEnergy;

    if (selectedTime == null || selectedEnergy == null) {
      return;
    }

    FocusScope.of(context).unfocus();

    final suggestions = _buildAreaSuggestions(
      area: _selectedArea,
      time: selectedTime,
      energy: selectedEnergy,
    );

    final goal = _selectedGoal?.trim();
    final situation = _situationController.text.trim();

    if (goal != null && goal.isNotEmpty) {
      suggestions[1] = '目標「$goal」に近づくため、今日できる最小の行動を1つ決めて始める';
    }

    if (situation.isNotEmpty) {
      suggestions[2] = '今の状況を踏まえ、最も負担が少ない準備を1つだけ始める';
    }

    setState(() {
      _suggestions = suggestions;
      _selectedSuggestion = null;
      _actionController.clear();
    });
  }

  void _selectSuggestion(String suggestion) {
    setState(() {
      _selectedSuggestion = suggestion;
      _actionController.text = suggestion;
    });
  }

  Future<void> _confirmAction() async {
    final action = _actionController.text.trim();

    if (action.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('この一歩に決めますか？'),
          content: Text(
            action,
            style: Theme.of(
              dialogContext,
            ).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('もう一度考える'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('この一歩に決める'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    Navigator.of(context).pop(action);
  }

  Widget _buildSection({
    required BuildContext context,
    required String number,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 16, child: Text(number)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(String suggestion) {
    final selected = _selectedSuggestion == suggestion;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: selected ? colorScheme.primaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _selectSuggestion(suggestion);
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? colorScheme.primary : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  suggestion,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedGoal = _selectedGoal?.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('次の一歩を考える')),
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
                    '$_displayNameさんの今の状況から、\n今日の一歩を考えましょう。',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AI Life Partnerは候補を示しますが、'
                    'どの一歩を選ぶかはあなたが決めます。',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 32),
                  _buildSection(
                    context: context,
                    number: '1',
                    title: '今日は何を進めたいですか？',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _availableAreas.map((area) {
                            return ChoiceChip(
                              label: Text(area),
                              selected: _selectedArea == area,
                              onSelected: (_) {
                                _selectArea(area);
                              },
                            );
                          }).toList(),
                        ),
                        if (selectedGoal != null &&
                            selectedGoal.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Text(
                            '目指している状態',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            selectedGoal,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(height: 1.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildSection(
                    context: context,
                    number: '2',
                    title: '今日はどれくらい時間を使えますか？',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: AvailableTime.values.map((time) {
                        return ChoiceChip(
                          label: Text(time.label),
                          selected: _selectedTime == time,
                          onSelected: (_) {
                            _selectTime(time);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  _buildSection(
                    context: context,
                    number: '3',
                    title: '今の余力はどれくらいですか？',
                    child: Column(
                      children: EnergyLevel.values.map((energy) {
                        final selected = _selectedEnergy == energy;

                        return Card(
                          color: selected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              _selectEnergy(energy);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          energy.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(energy.description),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  _buildSection(
                    context: context,
                    number: '4',
                    title: '今の状況を教えてください',
                    child: TextField(
                      controller: _situationController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: '現在の状況（任意）',
                        hintText: '例：今日は仕事が忙しく、少し疲れている',
                        helperText: 'まとまっていなくても大丈夫です。',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _canGenerateSuggestions
                        ? _generateSuggestions
                        : null,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Text('今の状況から候補を考える'),
                    ),
                  ),
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 44),
                    Text(
                      '候補を見比べて、\n自分の一歩を決めましょう。',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '候補をそのまま選んでも、自分の言葉に直しても構いません。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    ..._suggestions.map(_buildSuggestionCard),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _actionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '自分で決める次のAction',
                        helperText: '選んだ候補は、自由に書き換えられます。',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          if (value != _selectedSuggestion) {
                            _selectedSuggestion = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _canConfirmAction ? _confirmAction : null,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        child: Text('この一歩に決める'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
