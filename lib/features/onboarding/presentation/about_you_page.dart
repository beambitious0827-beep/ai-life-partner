import 'package:flutter/material.dart';

class AboutYouPage extends StatefulWidget {
  const AboutYouPage({super.key});

  @override
  State<AboutYouPage> createState() => _AboutYouPageState();
}

class _AboutYouPageState extends State<AboutYouPage> {
  final TextEditingController _displayNameController = TextEditingController();

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    final displayName = _displayNameController.text.trim();

    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('呼び名を入力するか、「あとで設定する」を選んでください')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$displayNameさん、次は取り組んでいることを教えてください')),
    );

    // 次の工程で「取り組んでいること」の画面へ接続します。
  }

  void _skipForNow() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('呼び名はあとから設定できます')));

    // 次の工程で「取り組んでいること」の画面へ接続します。
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
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'あなたについて\n少し教えてください',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'AI Life Partnerが、あなたに合った支援を考えるために、'
                    'まずは呼び方を教えてください。',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _displayNameController,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.nickname],
                    decoration: const InputDecoration(
                      labelText: '呼び名',
                      hintText: '例：大志',
                      helperText: '本名でなくても大丈夫です。あとから変更できます。',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _goToNextStep(),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _goToNextStep,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('次へ'),
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
