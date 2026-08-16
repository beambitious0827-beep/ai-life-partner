import 'package:ai_life_partner/features/journey/data/in_memory_journey_repository.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_outcome.dart';
import 'package:ai_life_partner/features/journey/domain/repositories/journey_repository.dart';
import 'package:ai_life_partner/features/journey/presentation/journey_page.dart';
import 'package:ai_life_partner/features/reflection/data/in_memory_reflection_repository.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:ai_life_partner/features/reflection/domain/repositories/reflection_repository.dart';
import 'package:ai_life_partner/features/reflection/presentation/reflection_record_page.dart';
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

ReflectionEntry createReflectionEntry({
  required String id,
  required String journeyEntryId,
  required DateTime reflectedAt,
  String? feelingText = '少し肩の力が抜けた',
  String? noticedText,
}) {
  return ReflectionEntry(
    id: id,
    humanId: humanId,
    journeyEntryId: journeyEntryId,
    feelingText: feelingText,
    noticedText: noticedText,
    reflectedAt: reflectedAt,
    createdAt: reflectedAt,
    updatedAt: reflectedAt,
  );
}

/// 指定した歩みについてだけ、振り返りの確認に失敗するReflection Repository。
///
/// 補助情報の障害が、歩みそのものの表示を巻き添えにしないことを確かめる。
class PartlyFailingReflectionRepository implements ReflectionRepository {
  PartlyFailingReflectionRepository({
    required this.failingJourneyEntryIds,
    Iterable<ReflectionEntry> seedEntries = const <ReflectionEntry>[],
  }) : _inner = InMemoryReflectionRepository(seedEntries: seedEntries);

  /// 確認に失敗させる歩みのID。テストの途中で変えられる。
  final Set<String> failingJourneyEntryIds;

  final InMemoryReflectionRepository _inner;

  @override
  Future<List<ReflectionEntry>> getEntries({
    required String humanId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    return _inner.getEntries(
      humanId: humanId,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
  }

  @override
  Future<ReflectionEntry?> getEntryById(String entryId) {
    return _inner.getEntryById(entryId);
  }

  @override
  Future<ReflectionEntry?> getEntryForJourney({
    required String humanId,
    required String journeyEntryId,
  }) async {
    if (failingJourneyEntryIds.contains(journeyEntryId)) {
      throw StateError('振り返りの状態を確認できませんでした');
    }

    return _inner.getEntryForJourney(
      humanId: humanId,
      journeyEntryId: journeyEntryId,
    );
  }

  @override
  Future<void> saveEntry(ReflectionEntry entry) {
    return _inner.saveEntry(entry);
  }
}

Future<void> pumpJourneyPage(
  WidgetTester tester, {
  required JourneyRepository repository,
  ReflectionRepository? reflectionRepository,
}) async {
  tester.view.physicalSize = const Size(1400, 5000);
  tester.view.devicePixelRatio = 1.0;

  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: JourneyPage(
        repository: repository,
        reflectionRepository:
            reflectionRepository ?? InMemoryReflectionRepository(),
        humanId: humanId,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> tapByKey(WidgetTester tester, Key key) async {
  final target = find.byKey(key);

  expect(target, findsOneWidget);

  await tester.ensureVisible(target);
  await tester.pumpAndSettle();

  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<List<ReflectionEntry>> readReflections(
  ReflectionRepository repository,
) async {
  final now = DateTime.now();

  return repository.getEntries(
    humanId: humanId,
    rangeStart: DateTime(now.year, now.month, now.day - 1),
    rangeEnd: DateTime(now.year, now.month, now.day + 1),
  );
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

  group('JourneyPage 振り返りへの導線', () {
    testWidgets('まだ振り返っていない歩みからは、振り返りを始められる', (tester) async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(id: 'journey-1', occurredAt: daysAgo(0)),
        ],
      );

      await pumpJourneyPage(tester, repository: repository);

      expect(
        find.byKey(const Key('journey_reflect_button_journey-1')),
        findsOneWidget,
      );
      expect(find.text('この歩みを振り返る'), findsOneWidget);

      expect(
        find.byKey(const Key('journey_reflected_label_journey-1')),
        findsNothing,
      );
    });

    testWidgets('振り返りが残っている歩みでは、そのことだけを伝える', (tester) async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(id: 'journey-1', occurredAt: daysAgo(0)),
        ],
      );

      final reflectionRepository = InMemoryReflectionRepository(
        seedEntries: <ReflectionEntry>[
          createReflectionEntry(
            id: 'reflection-1',
            journeyEntryId: 'journey-1',
            reflectedAt: daysAgo(0),
          ),
        ],
      );

      await pumpJourneyPage(
        tester,
        repository: repository,
        reflectionRepository: reflectionRepository,
      );

      expect(
        find.byKey(const Key('journey_reflected_label_journey-1')),
        findsOneWidget,
      );
      expect(find.text('振り返りを残しました'), findsOneWidget);

      expect(
        find.byKey(const Key('journey_reflect_button_journey-1')),
        findsNothing,
      );
    });

    testWidgets('歩みごとに、振り返りの有無を分けて扱う', (tester) async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(id: 'journey-1', occurredAt: daysAgo(0)),
          createEntry(id: 'journey-2', occurredAt: daysAgo(1)),
        ],
      );

      final reflectionRepository = InMemoryReflectionRepository(
        seedEntries: <ReflectionEntry>[
          createReflectionEntry(
            id: 'reflection-1',
            journeyEntryId: 'journey-1',
            reflectedAt: daysAgo(0),
          ),
        ],
      );

      await pumpJourneyPage(
        tester,
        repository: repository,
        reflectionRepository: reflectionRepository,
      );

      expect(
        find.byKey(const Key('journey_reflected_label_journey-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('journey_reflect_button_journey-2')),
        findsOneWidget,
      );
    });

    testWidgets('振り返りを残すと、Repositoryの内容にあわせて表示が変わる', (tester) async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(id: 'journey-1', occurredAt: daysAgo(0)),
        ],
      );

      final reflectionRepository = InMemoryReflectionRepository();

      await pumpJourneyPage(
        tester,
        repository: repository,
        reflectionRepository: reflectionRepository,
      );

      await tapByKey(tester, const Key('journey_reflect_button_journey-1'));

      expect(find.byType(ReflectionRecordPage), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('reflection_record_feeling_field')),
        '少し肩の力が抜けた',
      );
      await tester.pumpAndSettle();

      await tapByKey(tester, const Key('reflection_record_save_button'));

      expect(find.byType(ReflectionRecordPage), findsNothing);

      // 保存された事実はRepositoryにあり、画面もそれに合わせて変わる。
      final saved = (await readReflections(reflectionRepository)).single;

      expect(saved.journeyEntryId, 'journey-1');
      expect(saved.feelingText, '少し肩の力が抜けた');

      expect(
        find.byKey(const Key('journey_reflected_label_journey-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('journey_reflect_button_journey-1')),
        findsNothing,
      );
    });

    testWidgets('振り返りをやめた場合は、入り口のまま変わらない', (tester) async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(id: 'journey-1', occurredAt: daysAgo(0)),
        ],
      );

      final reflectionRepository = InMemoryReflectionRepository();

      await pumpJourneyPage(
        tester,
        repository: repository,
        reflectionRepository: reflectionRepository,
      );

      await tapByKey(tester, const Key('journey_reflect_button_journey-1'));

      await tapByKey(tester, const Key('reflection_record_cancel_button'));

      expect(find.byType(ReflectionRecordPage), findsNothing);
      expect(await readReflections(reflectionRepository), isEmpty);

      expect(
        find.byKey(const Key('journey_reflect_button_journey-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('journey_reflected_label_journey-1')),
        findsNothing,
      );
    });
  });

  group('JourneyPage 振り返りの状態を確認できない場合', () {
    testWidgets('振り返りを確認できなくても、歩みそのものは必ず表示する', (tester) async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(
            id: 'journey-1',
            occurredAt: daysAgo(0),
            plannedActionText: '30分トレーニングする',
            outcome: JourneyOutcome.changed,
            actualActionText: '家族との時間を優先した',
            note: '思ったより疲れていた',
          ),
        ],
      );

      await pumpJourneyPage(
        tester,
        repository: repository,
        reflectionRepository: PartlyFailingReflectionRepository(
          failingJourneyEntryIds: <String>{'journey-1'},
        ),
      );

      expect(tester.takeException(), isNull);

      // 歩みの一覧はエラーにならない。
      expect(find.text('歩みを読み込めませんでした。'), findsNothing);
      expect(find.byKey(const Key('journey_empty_state')), findsNothing);
      expect(find.byKey(const Key('journey_entry_journey-1')), findsOneWidget);

      // 歩みの本文はひとつも欠けない。
      expect(find.text('30分トレーニングする'), findsOneWidget);
      expect(find.text('別の一歩になった'), findsOneWidget);
      expect(find.text('家族との時間を優先した'), findsOneWidget);
      expect(find.text('思ったより疲れていた'), findsOneWidget);

      // 分からない状態は、分からないまま伝える。
      expect(
        find.byKey(const Key('journey_reflection_unknown_journey-1')),
        findsOneWidget,
      );
      expect(find.text('振り返りの状態を確認できませんでした。'), findsOneWidget);

      // 重複した振り返りを作りやすい入り口は出さない。
      expect(
        find.byKey(const Key('journey_reflect_button_journey-1')),
        findsNothing,
      );
      expect(find.text('この歩みを振り返る'), findsNothing);
      expect(
        find.byKey(const Key('journey_reflected_label_journey-1')),
        findsNothing,
      );
    });

    testWidgets('確認できなかった歩みだけを、状態不明として扱う', (tester) async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(id: 'journey-1', occurredAt: daysAgo(0)),
          createEntry(id: 'journey-2', occurredAt: daysAgo(1)),
          createEntry(id: 'journey-3', occurredAt: daysAgo(2)),
        ],
      );

      await pumpJourneyPage(
        tester,
        repository: repository,
        reflectionRepository: PartlyFailingReflectionRepository(
          failingJourneyEntryIds: <String>{'journey-2'},
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(
              id: 'reflection-1',
              journeyEntryId: 'journey-1',
              reflectedAt: daysAgo(0),
            ),
          ],
        ),
      );

      expect(
        find.byKey(const Key('journey_reflected_label_journey-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('journey_reflection_unknown_journey-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('journey_reflect_button_journey-3')),
        findsOneWidget,
      );
    });

    testWidgets('もう一度確認できれば、状態は元に戻る', (tester) async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(id: 'journey-1', occurredAt: daysAgo(0)),
        ],
      );

      final reflectionRepository = PartlyFailingReflectionRepository(
        failingJourneyEntryIds: <String>{'journey-1'},
      );

      await pumpJourneyPage(
        tester,
        repository: repository,
        reflectionRepository: reflectionRepository,
      );

      expect(
        find.byKey(const Key('journey_reflection_unknown_journey-1')),
        findsOneWidget,
      );

      // 確認できる状態に戻ってから、その歩みだけを確かめ直す。
      reflectionRepository.failingJourneyEntryIds.clear();

      await tapByKey(
        tester,
        const Key('journey_reflection_recheck_button_journey-1'),
      );

      expect(
        find.byKey(const Key('journey_reflection_unknown_journey-1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('journey_reflect_button_journey-1')),
        findsOneWidget,
      );
    });
  });
}
