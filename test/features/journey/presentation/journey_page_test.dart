import 'package:ai_life_partner/features/journey/data/in_memory_journey_repository.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_outcome.dart';
import 'package:ai_life_partner/features/journey/domain/repositories/journey_repository.dart';
import 'package:ai_life_partner/features/journey/presentation/journey_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String humanId = 'local-human';

/// JourneyPageは「今」を基準に読み込むため、テストも今を基準にする。
DateTime daysAgo(int days, {int hour = 21}) {
  final now = DateTime.now();

  return DateTime(now.year, now.month, now.day - days, hour);
}

JourneyEntry createEntry({
  required String id,
  required DateTime occurredAt,
  String plannedActionText = '30分トレーニングする',
  JourneyOutcome outcome = JourneyOutcome.completed,
  String? actualActionText,
  String? note,
}) {
  return JourneyEntry(
    id: id,
    humanId: humanId,
    plannedActionText: plannedActionText,
    outcome: outcome,
    actualActionText: actualActionText,
    note: note,
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
  );
}

Future<void> pumpJourneyPage(
  WidgetTester tester, {
  required JourneyRepository repository,
}) async {
  tester.view.physicalSize = const Size(1400, 5000);
  tester.view.devicePixelRatio = 1.0;

  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: JourneyPage(repository: repository, humanId: humanId),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  group('JourneyPage', () {
    testWidgets('歩みがない場合は、これから残っていくことを伝える', (tester) async {
      await pumpJourneyPage(tester, repository: InMemoryJourneyRepository());

      expect(find.byKey(const Key('journey_empty_state')), findsOneWidget);
      expect(find.text('まだ歩みはありません。'), findsOneWidget);
      expect(find.text('これからの一歩が、少しずつここに残っていきます。'), findsOneWidget);
    });

    testWidgets('保存された歩みの内容が表示される', (tester) async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(
            id: 'journey-1',
            occurredAt: daysAgo(0),
            plannedActionText: '30分トレーニングする',
            outcome: JourneyOutcome.partial,
            note: '10分だけでも体を動かせた',
          ),
        ],
      );

      await pumpJourneyPage(tester, repository: repository);

      expect(find.byKey(const Key('journey_entry_journey-1')), findsOneWidget);

      expect(find.text('30分トレーニングする'), findsOneWidget);
      expect(find.text('少し取り組んだ'), findsOneWidget);
      expect(find.text('10分だけでも体を動かせた'), findsOneWidget);

      expect(find.byKey(const Key('journey_empty_state')), findsNothing);
    });

    testWidgets('実際の一歩がある場合は一緒に表示される', (tester) async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(
            id: 'journey-1',
            occurredAt: daysAgo(0),
            outcome: JourneyOutcome.changed,
            actualActionText: '家族との時間を優先した',
          ),
        ],
      );

      await pumpJourneyPage(tester, repository: repository);

      expect(find.text('別の一歩になった'), findsOneWidget);
      expect(find.text('実際の一歩'), findsOneWidget);
      expect(find.text('家族との時間を優先した'), findsOneWidget);
    });

    testWidgets('任意の項目がない場合は、その欄を出さない', (tester) async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(id: 'journey-1', occurredAt: daysAgo(0)),
        ],
      );

      await pumpJourneyPage(tester, repository: repository);

      expect(find.text('実際の一歩'), findsNothing);
      expect(find.text('ひとこと'), findsNothing);
    });

    testWidgets('新しい歩みから順に並ぶ', (tester) async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(
            id: 'older',
            occurredAt: daysAgo(2),
            plannedActionText: '一昨日の一歩',
          ),
          createEntry(
            id: 'newest',
            occurredAt: daysAgo(0),
            plannedActionText: '今日の一歩の内容',
          ),
          createEntry(
            id: 'middle',
            occurredAt: daysAgo(1),
            plannedActionText: '昨日の一歩',
          ),
        ],
      );

      await pumpJourneyPage(tester, repository: repository);

      final newestPosition = tester.getTopLeft(find.text('今日の一歩の内容')).dy;
      final middlePosition = tester.getTopLeft(find.text('昨日の一歩')).dy;
      final olderPosition = tester.getTopLeft(find.text('一昨日の一歩')).dy;

      expect(newestPosition, lessThan(middlePosition));
      expect(middlePosition, lessThan(olderPosition));
    });

    testWidgets('達成率や連続記録のような集計を表示しない', (tester) async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(id: 'journey-1', occurredAt: daysAgo(0)),
          createEntry(
            id: 'journey-2',
            occurredAt: daysAgo(1),
            outcome: JourneyOutcome.rested,
          ),
        ],
      );

      await pumpJourneyPage(tester, repository: repository);

      const forbidden = <String>[
        '達成率',
        '成功率',
        '失敗',
        '未達',
        '連続',
        'スコア',
        'ランキング',
        '件中',
      ];

      for (final word in forbidden) {
        expect(
          find.textContaining(word),
          findsNothing,
          reason: '$word はJourneyのUIでは使わない',
        );
      }
    });
  });
}
