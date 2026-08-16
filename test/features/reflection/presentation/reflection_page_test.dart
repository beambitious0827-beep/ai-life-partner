import 'package:ai_life_partner/features/journey/data/in_memory_journey_repository.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_outcome.dart';
import 'package:ai_life_partner/features/journey/domain/repositories/journey_repository.dart';
import 'package:ai_life_partner/features/reflection/data/in_memory_reflection_repository.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:ai_life_partner/features/reflection/domain/repositories/reflection_repository.dart';
import 'package:ai_life_partner/features/reflection/presentation/reflection_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String humanId = 'local-human';

/// ReflectionPageは「今」を基準に読み込むため、テストも今を基準にする。
DateTime daysAgo(int days, {int hour = 21}) {
  final now = DateTime.now();

  return DateTime(now.year, now.month, now.day - days, hour);
}

JourneyEntry createJourneyEntry({
  required String id,
  required DateTime occurredAt,
  String humanId = 'local-human',
  String plannedActionText = '30分トレーニングする',
  JourneyOutcome outcome = JourneyOutcome.partial,
}) {
  return JourneyEntry(
    id: id,
    humanId: humanId,
    plannedActionText: plannedActionText,
    outcome: outcome,
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
  );
}

ReflectionEntry createReflectionEntry({
  required String id,
  required DateTime reflectedAt,
  String journeyEntryId = 'journey-1',
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

/// 指定した歩みだけ読み込みに失敗するJourney Repository。
///
/// 補助の参照が壊れても、Human本人が書いた振り返りが消えないことを確かめる。
class PartlyFailingJourneyRepository implements JourneyRepository {
  PartlyFailingJourneyRepository({
    required this.failingEntryIds,
    Iterable<JourneyEntry> seedEntries = const <JourneyEntry>[],
  }) : _inner = InMemoryJourneyRepository(seedEntries: seedEntries);

  final Set<String> failingEntryIds;

  final InMemoryJourneyRepository _inner;

  @override
  Future<List<JourneyEntry>> getEntries({
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
  Future<JourneyEntry?> getEntryById(String entryId) async {
    if (failingEntryIds.contains(entryId)) {
      throw StateError('歩みを読み込めませんでした');
    }

    return _inner.getEntryById(entryId);
  }

  @override
  Future<void> saveEntry(JourneyEntry entry) {
    return _inner.saveEntry(entry);
  }
}

Future<void> pumpReflectionPage(
  WidgetTester tester, {
  required ReflectionRepository reflectionRepository,
  required JourneyRepository journeyRepository,
}) async {
  tester.view.physicalSize = const Size(1400, 5000);
  tester.view.devicePixelRatio = 1.0;

  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: ReflectionPage(
        reflectionRepository: reflectionRepository,
        journeyRepository: journeyRepository,
        humanId: humanId,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  group('ReflectionPage', () {
    testWidgets('振り返りがない場合は、待たずに済むことを伝える', (tester) async {
      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(),
        journeyRepository: InMemoryJourneyRepository(),
      );

      expect(find.byKey(const Key('reflection_empty_state')), findsOneWidget);
      expect(find.text('まだ振り返りはありません。'), findsOneWidget);
      expect(find.text('残したくなったときに、歩みを振り返ることができます。'), findsOneWidget);
    });

    testWidgets('残した振り返りと、もとの歩みが一緒に読める', (tester) async {
      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(
              id: 'reflection-1',
              reflectedAt: daysAgo(0),
              journeyEntryId: 'journey-1',
              feelingText: '少し肩の力が抜けた',
              noticedText: '朝のほうが動きやすいみたいだ',
            ),
          ],
        ),
        journeyRepository: InMemoryJourneyRepository(
          seedEntries: <JourneyEntry>[
            createJourneyEntry(
              id: 'journey-1',
              occurredAt: daysAgo(0),
              plannedActionText: '30分トレーニングする',
            ),
          ],
        ),
      );

      expect(
        find.byKey(const Key('reflection_entry_reflection-1')),
        findsOneWidget,
      );

      expect(find.text('振り返った歩み'), findsOneWidget);
      expect(find.text('30分トレーニングする'), findsOneWidget);
      expect(find.text('感じたこと'), findsOneWidget);
      expect(find.text('少し肩の力が抜けた'), findsOneWidget);
      expect(find.text('気づいたこと'), findsOneWidget);
      expect(find.text('朝のほうが動きやすいみたいだ'), findsOneWidget);

      expect(find.byKey(const Key('reflection_empty_state')), findsNothing);
    });

    testWidgets('書かれていない項目の欄は出さない', (tester) async {
      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(
              id: 'reflection-1',
              reflectedAt: daysAgo(0),
              feelingText: '少し肩の力が抜けた',
            ),
          ],
        ),
        journeyRepository: InMemoryJourneyRepository(
          seedEntries: <JourneyEntry>[
            createJourneyEntry(id: 'journey-1', occurredAt: daysAgo(0)),
          ],
        ),
      );

      expect(find.text('感じたこと'), findsOneWidget);
      expect(find.text('気づいたこと'), findsNothing);
    });

    testWidgets('新しい振り返りから順に並ぶ', (tester) async {
      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(
              id: 'older',
              reflectedAt: daysAgo(2),
              journeyEntryId: 'journey-older',
              feelingText: '一昨日の気持ち',
            ),
            createReflectionEntry(
              id: 'newest',
              reflectedAt: daysAgo(0),
              journeyEntryId: 'journey-newest',
              feelingText: '今日の気持ち',
            ),
            createReflectionEntry(
              id: 'middle',
              reflectedAt: daysAgo(1),
              journeyEntryId: 'journey-middle',
              feelingText: '昨日の気持ち',
            ),
          ],
        ),
        journeyRepository: InMemoryJourneyRepository(),
      );

      final newestPosition = tester.getTopLeft(find.text('今日の気持ち')).dy;
      final middlePosition = tester.getTopLeft(find.text('昨日の気持ち')).dy;
      final olderPosition = tester.getTopLeft(find.text('一昨日の気持ち')).dy;

      expect(newestPosition, lessThan(middlePosition));
      expect(middlePosition, lessThan(olderPosition));
    });

    testWidgets('もとの歩みが見つからなくても、書いた言葉は残して表示する', (tester) async {
      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(
              id: 'reflection-1',
              reflectedAt: daysAgo(0),
              journeyEntryId: 'missing-journey',
              feelingText: '少し肩の力が抜けた',
            ),
          ],
        ),
        journeyRepository: InMemoryJourneyRepository(),
      );

      expect(tester.takeException(), isNull);

      expect(
        find.byKey(const Key('reflection_entry_reflection-1')),
        findsOneWidget,
      );

      expect(find.text('少し肩の力が抜けた'), findsOneWidget);
      expect(find.text('振り返った歩み'), findsNothing);
      expect(find.text('元の歩みを確認できませんでした。'), findsOneWidget);
    });

    testWidgets('振り返りを良し悪しで分けない', (tester) async {
      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(
              id: 'reflection-1',
              reflectedAt: daysAgo(0),
              feelingText: 'まだ落ち着かない',
            ),
            createReflectionEntry(
              id: 'reflection-2',
              reflectedAt: daysAgo(1),
              journeyEntryId: 'journey-2',
              noticedText: '朝のほうが動きやすいみたいだ',
            ),
          ],
        ),
        journeyRepository: InMemoryJourneyRepository(),
      );

      const forbidden = <String>[
        '良い',
        '悪い',
        'ポジティブ',
        'ネガティブ',
        '前向き',
        '達成',
        '成功',
        '失敗',
        'スコア',
        '評価',
        '反省',
        '連続',
        '件中',
      ];

      for (final word in forbidden) {
        expect(
          find.textContaining(word),
          findsNothing,
          reason: '$word は振り返りの分類に使わない',
        );
      }
    });
  });

  group('ReflectionPage 歩みの参照に失敗した場合', () {
    testWidgets('一部の歩みが読めなくても、振り返り本文は消えない', (tester) async {
      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(
              id: 'reflection-ok',
              reflectedAt: daysAgo(0),
              journeyEntryId: 'journey-ok',
              feelingText: '読める歩みの気持ち',
              noticedText: '読める歩みの気づき',
            ),
            createReflectionEntry(
              id: 'reflection-broken',
              reflectedAt: daysAgo(1),
              journeyEntryId: 'journey-broken',
              feelingText: '読めない歩みの気持ち',
              noticedText: '読めない歩みの気づき',
            ),
          ],
        ),
        journeyRepository: PartlyFailingJourneyRepository(
          failingEntryIds: <String>{'journey-broken'},
          seedEntries: <JourneyEntry>[
            createJourneyEntry(
              id: 'journey-ok',
              occurredAt: daysAgo(0),
              plannedActionText: '読める歩みの一歩',
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);

      // 一覧そのものが消えたり、エラー画面になったりしない。
      expect(find.text('振り返りを読み込めませんでした。'), findsNothing);
      expect(find.byKey(const Key('reflection_empty_state')), findsNothing);

      expect(
        find.byKey(const Key('reflection_entry_reflection-ok')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reflection_entry_reflection-broken')),
        findsOneWidget,
      );

      // Human本人が書いた言葉は、どちらもそのまま残る。
      expect(find.text('読める歩みの気持ち'), findsOneWidget);
      expect(find.text('読める歩みの気づき'), findsOneWidget);
      expect(find.text('読めない歩みの気持ち'), findsOneWidget);
      expect(find.text('読めない歩みの気づき'), findsOneWidget);

      // 手がかりが添えられないのは、読めなかった歩みのぶんだけ。
      expect(find.text('振り返った歩み'), findsOneWidget);
      expect(find.text('読める歩みの一歩'), findsOneWidget);
      expect(find.text('元の歩みを確認できませんでした。'), findsOneWidget);
    });

    testWidgets('別のHumanの歩みは、手がかりとして表示しない', (tester) async {
      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(
              id: 'reflection-1',
              reflectedAt: daysAgo(0),
              journeyEntryId: 'journey-of-other',
              feelingText: '自分が書いた気持ち',
            ),
          ],
        ),
        journeyRepository: InMemoryJourneyRepository(
          seedEntries: <JourneyEntry>[
            createJourneyEntry(
              id: 'journey-of-other',
              occurredAt: daysAgo(0),
              humanId: 'other-human',
              plannedActionText: '他のHumanの一歩',
            ),
          ],
        ),
      );

      // 自分が書いた言葉は残る。
      expect(
        find.byKey(const Key('reflection_entry_reflection-1')),
        findsOneWidget,
      );
      expect(find.text('自分が書いた気持ち'), findsOneWidget);

      // 別のHumanの歩みの内容は、けっして出さない。
      expect(find.text('他のHumanの一歩'), findsNothing);
      expect(find.text('振り返った歩み'), findsNothing);
      expect(find.text('元の歩みを確認できませんでした。'), findsOneWidget);
    });
  });
}
