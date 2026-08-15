import 'package:ai_life_partner/features/calendar/domain/models/available_time_window.dart';
import 'package:ai_life_partner/features/calendar/presentation/available_time_format.dart';
import 'package:ai_life_partner/features/next_step/presentation/calendar_availability.dart';
import 'package:ai_life_partner/features/next_step/presentation/next_step_result.dart';
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

  /// 手動指定の長さ。「時間は調整できる」は特定の長さを持たない。
  Duration? get manualDuration {
    switch (this) {
      case AvailableTime.tenMinutes:
        return const Duration(minutes: 10);
      case AvailableTime.thirtyMinutes:
        return const Duration(minutes: 30);
      case AvailableTime.sixtyMinutes:
        return const Duration(minutes: 60);
      case AvailableTime.flexible:
        return null;
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

  /// カレンダーの空き時間を選んだときに提案するActionの長さの目安。
  ///
  /// 空き時間の長さそのものではない。
  /// 空いている時間は、休息にも家族との時間にも使えるHumanの時間なので、
  /// 全部をActionへ充てる前提にしない。
  Duration get suggestedActionDuration {
    switch (this) {
      case EnergyLevel.low:
        return const Duration(minutes: 10);
      case EnergyLevel.medium:
        return const Duration(minutes: 30);
      case EnergyLevel.high:
        return const Duration(minutes: 60);
    }
  }
}

/// 候補生成へ渡す「使える時間」の情報。
///
/// 手動指定でもCalendarの空き時間でも、ここへ集約してから候補文を組み立てる。
class _TimeContext {
  const _TimeContext({required this.durationLabel, this.rangeLabel});

  /// 「30分」「自分で決めた時間」「1時間30分」など。
  final String durationLabel;

  /// 「14:30〜16:00」など。Calendarの空き時間を選んだときだけ設定される。
  final String? rangeLabel;
}

class NextStepPage extends StatefulWidget {
  const NextStepPage({
    super.key,
    required this.selectedAreas,
    required this.goals,
    this.displayName,
    this.availability = CalendarAvailability.none,
    this.onReloadAvailability,
  });

  final String? displayName;
  final List<String> selectedAreas;
  final Map<String, String> goals;

  /// 呼び出し側が算出した、今日のカレンダー上の空き時間の読み込み結果。
  ///
  /// このページはCalendarRepositoryやCalendarEventを直接扱わない。
  /// AvailableTimeWindowだけを受け取ることで、
  /// AIへ見せない設定の予定の内容がこの画面へ伝わらないようにしている。
  final CalendarAvailability availability;

  /// 読み込みに失敗したときの再試行。
  ///
  /// Repositoryへのアクセスは呼び出し側の責務なので、
  /// このページは渡された関数を呼ぶだけにする。
  final Future<CalendarAvailability> Function()? onReloadAvailability;

  @override
  State<NextStepPage> createState() => _NextStepPageState();
}

class _NextStepPageState extends State<NextStepPage> {
  final TextEditingController _situationController = TextEditingController();

  final TextEditingController _actionController = TextEditingController();

  late String _selectedArea;

  AvailableTime? _selectedTime;

  /// Calendarの空き時間を選んだ場合の選択。手動指定とは排他的に扱う。
  AvailableTimeWindow? _selectedWindow;

  EnergyLevel? _selectedEnergy;

  List<String> _suggestions = <String>[];
  String? _selectedSuggestion;

  late CalendarAvailability _availability = widget.availability;

  bool _isReloadingAvailability = false;

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

  bool get _hasTimeSelection {
    return _selectedWindow != null || _selectedTime != null;
  }

  /// カレンダーの空き時間を選んだときに提案するActionの長さ。
  ///
  /// 余力に応じた目安を使い、空き時間の方が短ければそちらを上限にする。
  /// 空き時間の長さをそのままActionの長さにはしない。
  Duration _suggestedActionDuration({
    required AvailableTimeWindow window,
    required EnergyLevel energy,
  }) {
    final suggested = energy.suggestedActionDuration;

    return suggested <= window.duration ? suggested : window.duration;
  }

  /// 手動指定とCalendarの空き時間の、選ばれている方から候補生成の材料を作る。
  _TimeContext? _buildTimeContext(EnergyLevel energy) {
    final window = _selectedWindow;

    if (window != null) {
      return _TimeContext(
        durationLabel: formatDurationLabel(
          _suggestedActionDuration(window: window, energy: energy),
        ),
        rangeLabel:
            '${formatClockTime(window.startAt)}〜'
            '${formatClockTime(window.endAt)}',
      );
    }

    final time = _selectedTime;

    if (time != null) {
      return _TimeContext(durationLabel: time.actionDuration);
    }

    return null;
  }

  bool get _canGenerateSuggestions {
    return _hasTimeSelection && _selectedEnergy != null;
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

      // 手動で時間を決めたときは、Calendarの空き時間の選択を解除する。
      _selectedWindow = null;

      _clearSuggestions();
    });
  }

  void _selectWindow(AvailableTimeWindow window) {
    setState(() {
      _selectedWindow = window;

      // Calendarの空き時間を選んだときは、手動指定の選択を解除する。
      _selectedTime = null;

      _clearSuggestions();
    });
  }

  void _selectEnergy(EnergyLevel energy) {
    setState(() {
      _selectedEnergy = energy;
      _clearSuggestions();
    });
  }

  /// 空き時間の候補文で使う、取り組み内容の言い方。
  String _areaFocusLabel(String area) {
    switch (area) {
      case '学習・受験':
        return '学習';
      case 'トレーニング':
        return 'トレーニング';
      case '食事':
        return '食事の準備';
      case '睡眠・生活リズム':
        return '休息の準備';
      case '仕事・プロジェクト':
        return '仕事';
      case '趣味・新しい挑戦':
        return '趣味';
      default:
        return '今できること';
    }
  }

  List<String> _buildAreaSuggestions({
    required String area,
    required _TimeContext timeContext,
    required EnergyLevel energy,
  }) {
    final duration = timeContext.durationLabel;
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

  /// 読み込みに失敗した空き時間を、もう一度確認する。
  ///
  /// Repositoryは呼び出し側が持つので、ここでは渡された関数を実行するだけ。
  Future<void> _reloadAvailability() async {
    final reload = widget.onReloadAvailability;

    if (reload == null || _isReloadingAvailability) {
      return;
    }

    setState(() {
      _isReloadingAvailability = true;
    });

    final availability = await reload();

    if (!mounted) {
      return;
    }

    setState(() {
      _availability = availability;
      _isReloadingAvailability = false;

      // 取り直した空き時間に、選択済みの時間帯が残っているとは限らない。
      if (_selectedWindow != null &&
          !_availability.windows.contains(_selectedWindow)) {
        _selectedWindow = null;
        _clearSuggestions();
      }
    });
  }

  void _generateSuggestions() {
    final selectedEnergy = _selectedEnergy;

    if (selectedEnergy == null) {
      return;
    }

    final timeContext = _buildTimeContext(selectedEnergy);

    if (timeContext == null) {
      return;
    }

    FocusScope.of(context).unfocus();

    final suggestions = _buildAreaSuggestions(
      area: _selectedArea,
      timeContext: timeContext,
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

    // Calendarの空き時間を選んでいる場合だけ、時間帯が分かる候補を先頭へ足す。
    // 手動指定のときの候補は、これまでと同じ内容のままにする。
    final rangeLabel = timeContext.rangeLabel;

    if (rangeLabel != null) {
      final focus = _areaFocusLabel(_selectedArea);

      // 時間帯は「その中で行える範囲」、長さは「提案するActionの目安」。
      // 空き時間すべてをActionへ充てる書き方にはしない。
      suggestions.insert(
        0,
        '$rangeLabelの空き時間の中で、'
        '${selectedEnergy.pace}${timeContext.durationLabel}程度$focusに取り組む',
      );
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

    final window = _selectedWindow;
    final energy = _selectedEnergy;

    // 時間の情報も一緒に返す。Calendar Eventはここでは作らない。
    //
    // 空き時間を選んでいる場合は、その時間帯と、
    // 候補づくりで実際に使ったActionの長さの両方を返す。
    // 空き時間の長さそのものはActionの長さではない。
    final result = (window != null && energy != null)
        ? NextStepResult.fromCalendarWindow(
            actionText: action,
            window: window,
            duration: _suggestedActionDuration(window: window, energy: energy),
          )
        : NextStepResult.fromManualTime(
            actionText: action,
            duration: _selectedTime?.manualDuration,
          );

    Navigator.of(context).pop(result);
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

  Widget _buildAvailableWindowCard(int index, AvailableTimeWindow window) {
    final selected = _selectedWindow == window;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: Key('next_step_available_window_$index'),
      color: selected ? colorScheme.primaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _selectWindow(window);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? colorScheme.primary : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatAvailableTimeRange(window),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(formatDurationLabel(window.duration)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityNotice(String message) {
    return Text(
      message,
      key: const Key('next_step_availability_notice'),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
    );
  }

  Widget _buildTimeSection() {
    final availability = _availability;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (availability.isFailed) ...[
          _buildAvailabilityNotice(
            'カレンダーを確認できませんでした。\n'
            '時間は自分で指定して、次の一歩を考えることができます。',
          ),
          if (widget.onReloadAvailability != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('next_step_reload_availability_button'),
                onPressed: _isReloadingAvailability
                    ? null
                    : _reloadAvailability,
                icon: const Icon(Icons.refresh),
                label: const Text('もう一度確認する'),
              ),
            ),
          ],
        ] else if (availability.isFullyOccupied)
          _buildAvailabilityNotice(
            'カレンダー上では、この時間帯に空いている時間が見つかりませんでした。\n'
            '必要であれば、自分で使える時間を指定できます。',
          )
        else ...[
          Text(
            'カレンダーから見つかった空き時間',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '空いている時間を使う必要はありません。\n'
            '休息や、家族と過ごす時間にも使えます。\n'
            '今の状況に合う時間を選んでください。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 12),
          ...availability.windows.asMap().entries.map((entry) {
            return _buildAvailableWindowCard(entry.key, entry.value);
          }),
        ],
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 20),
        Text(
          '自分で時間を決める',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AvailableTime.values.map((time) {
            return ChoiceChip(
              key: Key('next_step_manual_time_${time.name}'),
              label: Text(time.label),
              selected: _selectedTime == time,
              onSelected: (_) {
                _selectTime(time);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(int index, String suggestion) {
    final selected = _selectedSuggestion == suggestion;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: Key('next_step_suggestion_$index'),
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
                    title: '今日はいつ・どれくらい時間を使えますか？',
                    child: _buildTimeSection(),
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
                    ..._suggestions.asMap().entries.map((entry) {
                      return _buildSuggestionCard(entry.key, entry.value);
                    }),
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
