import 'package:flutter/material.dart';

class GoalDefinitionPage extends StatefulWidget {
  const GoalDefinitionPage({
    super.key,
    required this.selectedAreas,
    this.displayName,
  });

  final List<String> selectedAreas;
  final String? displayName;

  @override
  State<GoalDefinitionPage> createState() => _GoalDefinitionPageState();
}

class _GoalDefinitionPageState extends State<GoalDefinitionPage> {
  final TextEditingController _generalGoalController = TextEditingController();

  final Map<String, TextEditingController> _goalControllers =
      <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();

    for (final area in widget.selectedAreas) {
      _goalControllers[area] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _generalGoalController.dispose();

    for (final controller in _goalControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  String get _headline {
    final displayName = widget.displayName?.trim();

    if (displayName == null || displayName.isEmpty) {
      return 'どのようになりたいですか？';
    }

    return '$displayNameさんは、\nどのようになりたいですか？';
  }

  bool get _hasAnyGoal {
    if (widget.selectedAreas.isEmpty) {
      return _generalGoalController.text.trim().isNotEmpty;
    }

    return _goalControllers.values.any(
      (controller) => controller.text.trim().isNotEmpty,
    );
  }

  String _exampleFor(String area) {
    switch (area) {
      case '学習・受験':
        return '例：苦手分野を整理し、受験までの学習計画を立てたい';
      case 'トレーニング':
        return '例：無理なく継続しながら、筋力と体力を高めたい';
      case '食事':
        return '例：目標や体調に合った食事を続けられるようになりたい';
      case '睡眠・生活リズム':
        return '例：生活に合った睡眠時間を確保し、体調を整えたい';
      case '仕事・プロジェクト':
        return '例：やるべきことを整理し、着実に前へ進めたい';
      case '趣味・新しい挑戦':
        return '例：新しいことを楽しみながら、少しずつ上達したい';
      case 'その他':
        return 'どのような状態を目指したいか、自由に入力してください';
      default:
        return 'どのようになりたいかを入力してください';
    }
  }

  void _goToNextStep() {
    final goals = <String>[];

    if (widget.selectedAreas.isEmpty) {
      final generalGoal = _generalGoalController.text.trim();

      if (generalGoal.isNotEmpty) {
        goals.add(generalGoal);
      }
    } else {
      for (final area in widget.selectedAreas) {
        final goal = _goalControllers[area]?.text.trim() ?? '';

        if (goal.isNotEmpty) {
          goals.add('$area：$goal');
        }
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${goals.length}件の目標を入力しました')));

    // 次の工程で「希望する支援方法」の画面へ接続します。
  }

  void _skipForNow() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('目標はあとから設定できます')));

    // 次の工程で「希望する支援方法」の画面へ接続します。
  }

  Widget _buildGeneralGoalField() {
    return TextField(
      controller: _generalGoalController,
      minLines: 3,
      maxLines: 5,
      decoration: const InputDecoration(
        labelText: '目指したい状態',
        hintText: '例：今の生活を整理し、次に何をすればよいか考えたい',
        helperText: 'まとまっていなくても大丈夫です。あとから変更できます。',
        alignLabelWithHint: true,
        border: OutlineInputBorder(),
      ),
      onChanged: (_) {
        setState(() {});
      },
    );
  }

  Widget _buildAreaGoalField(String area) {
    final controller = _goalControllers[area]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              area,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: '目指したい状態',
                hintText: _exampleFor(area),
                helperText: 'まだ具体的でなくても大丈夫です。',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
          ],
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
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'ステップ 3 / 4',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const Spacer(),
                      const Text('目標を考える'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(value: 0.75),
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
                    '今すぐ明確な答えを出す必要はありません。'
                    '今の時点で目指したい状態を、あなたの言葉で教えてください。',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 36),
                  if (widget.selectedAreas.isEmpty)
                    _buildGeneralGoalField()
                  else
                    ...widget.selectedAreas.map(_buildAreaGoalField),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _hasAnyGoal ? _goToNextStep : null,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('入力した内容で進む'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _skipForNow,
                    child: const Text('あとで考える'),
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
