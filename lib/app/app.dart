import 'package:flutter/material.dart';

import '../features/welcome/presentation/welcome_page.dart';

class AiLifePartnerApp extends StatelessWidget {
  const AiLifePartnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Life Partner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const WelcomePage(),
    );
  }
}
