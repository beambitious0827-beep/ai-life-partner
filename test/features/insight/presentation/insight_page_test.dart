import 'package:ai_life_partner/features/insight/data/in_memory_insight_repository.dart';
import 'package:ai_life_partner/features/insight/domain/models/insight_entry.dart';
import 'package:ai_life_partner/features/insight/domain/repositories/insight_repository.dart';
import 'package:ai_life_partner/features/insight/presentation/insight_page.dart';
import 'package:ai_life_partner/features/reflection/data/in_memory_reflection_repository.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:ai_life_partner/features/reflection/domain/repositories/reflection_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String humanId = 'local-human';

/// InsightPageは「今」を基準に読み込むため、テストも今を基準にする。
DateTime daysAgo(int days, {int hour = 21}) {
  final now = DateTime.now();

  return DateTime(now.year, now.month, now.day - days, hour);
}

InsightEntry createInsightEntry({
  required String id,
  required DateTime discoveredAt,
  String humanId = 'local-human',
  String reflectionEntryId = 'reflection-1',
  String insightText = '休むことも前に進むために必要。',
}) {
  return InsightEntry(
    id: id,
    humanId: humanId,
    reflectionEntryId: reflectionEntryId,
    insightText: insightText,
    discoveredAt: discoveredAt,
    createdAt: discoveredAt,
    updatedAt: discoveredAt,
  );
}

ReflectionEntry createReflectionEntry({
  required String id,
  required DateTime reflectedAt,
  String humanId = 'local-human',
  String journeyEntryId = 'journey-1',
  String? feelingText = '思ったより疲れていた',
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

/// 指定した振り返りだけ読み込みに失敗するReflection Repository。
///
/// 補助の参照が壊れても、Human本人が書いた気づきが消えないことを確かめる。
class PartlyFailingReflectionRepository implements ReflectionRepository {
  PartlyFailingReflectionRepository({
    required this.failingEntryIds,
    Iterable<ReflectionEntry> seedEntries = const <ReflectionEntry>[],
  }) : _inner = InMemoryReflectionRepository(seedEntries: seedEntries);

  final Set<String> failingEntryIds;

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
  Future<ReflectionEntry?> getEntryById(String entryId) async {
    if (failingEntryIds.contains(entryId)) {
      throw StateError('振り返りを読み込めませんでした');
    }

    return _inner.getEntryById(entryId);
  }

  @override
  Future<ReflectionEntry?> getEntryForJourney({
    required String humanId,
    required String journeyEntryId,
  }) {
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

Future<void> pumpInsightPage(
  WidgetTester tester, {
  required InsightRepository insightRepository,
  required ReflectionRepository reflectionRepository,
}) async {
  tester.view.physicalSize = const Size(1400, 5000);
  tester.view.devicePixelRatio = 1.0;

  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: InsightPage(
        insightRepository: insightRepository,
        reflectionRepository: reflectionRepository,
        humanId: humanId,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  group('InsightPage', () {
    testWidgets('気づきがない場合は、待たずに済むことを伝える', (tester) async {
      await pumpInsightPage(
        tester,
        insightRepository: InMemoryInsightRepository(),
        reflectionRepository: InMemoryReflectionRepository(),
      );

      expect(find.byKey(const Key('insight_empty_state')), findsOneWidget);
      expect(find.text('まだ気づきはありません。'), findsOneWidget);
      expect(find.text('残したくなったときに、振り返りから気づきを残せます。'), findsOneWidget);
    });

    testWidgets('残した気づきと、もとの振り返りが一緒に読める', (tester) async {
      await pumpInsightPage(
        tester,
        insightRepository: InMemoryInsightRepository(
          seedEntries: <InsightEntry>[
            createInsightEntry(
              id: 'insight-1',
              discoveredAt: daysAgo(0),
              reflectionEntryId: 'reflection-1',
              insightText: '休むことも前に進むために必要。',
            ),
          ],
        ),
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(
              id: 'reflection-1',
              reflectedAt: daysAgo(0),
              feelingText: '思ったより疲れていた',
              noticedText: '休んだことで少し気持ちが軽くなった',
            ),
          ],
        ),
      );

      expect(find.byKey(const Key('insight_entry_insight-1')), findsOneWidget);

      expect(find.text('見つけた気づき'), findsOneWidget);
      expect(find.text('休むことも前に進むために必要。'), findsOneWidget);
      expect(find.text('感じたこと'), findsOneWidget);
      expect(find.text('思ったより疲れていた'), findsOneWidget);
      expect(find.text('気づいたこと'), findsOneWidget);
      expect(find.text('休んだことで少し気持ちが軽くなった'), findsOneWidget);

      expect(find.byKey(const Key('insight_empty_state')), findsNothing);
    });

    testWidgets('新しい気づきから順に並ぶ', (tester) async {
      await pumpInsightPage(
        tester,
        insightRepository: InMemoryInsightRepository(
          seedEntries: <InsightEntry>[
            createInsightEntry(
              id: 'older',
              discoveredAt: daysAgo(2),
              reflectionEntryId: 'reflection-older',
              insightText: '一昨日の気づき',
            ),
            createInsightEntry(
              id: 'newest',
              discoveredAt: daysAgo(0),
              reflectionEntryId: 'reflection-newest',
              insightText: '今日の気づき',
            ),
            createInsightEntry(
              id: 'middle',
              discoveredAt: daysAgo(1),
              reflectionEntryId: 'reflection-middle',
              insightText: '昨日の気づき',
            ),
          ],
        ),
        reflectionRepository: InMemoryReflectionRepository(),
      );

      final newestPosition = tester.getTopLeft(find.text('今日の気づき')).dy;
      final middlePosition = tester.getTopLeft(find.text('昨日の気づき')).dy;
      final olderPosition = tester.getTopLeft(find.text('一昨日の気づき')).dy;

      expect(newestPosition, lessThan(middlePosition));
      expect(middlePosition, lessThan(olderPosition));
    });

    testWidgets('もとの振り返りが見つからなくても、気づきは残して表示する', (tester) async {
      await pumpInsightPage(
        tester,
        insightRepository: InMemoryInsightRepository(
          seedEntries: <InsightEntry>[
            createInsightEntry(
              id: 'insight-1',
              discoveredAt: daysAgo(0),
              reflectionEntryId: 'missing-reflection',
              insightText: '休むことも前に進むために必要。',
            ),
          ],
        ),
        reflectionRepository: InMemoryReflectionRepository(),
      );

      expect(tester.takeException(), isNull);

      expect(find.byKey(const Key('insight_entry_insight-1')), findsOneWidget);
      expect(find.text('見つけた気づき'), findsOneWidget);
      expect(find.text('休むことも前に進むために必要。'), findsOneWidget);
      expect(find.text('元の振り返りを確認できませんでした。'), findsOneWidget);
      expect(find.text('感じたこと'), findsNothing);
    });

    testWidgets('気づきを良し悪しで分けない', (tester) async {
      await pumpInsightPage(
        tester,
        insightRepository: InMemoryInsightRepository(
          seedEntries: <InsightEntry>[
            createInsightEntry(
              id: 'insight-1',
              discoveredAt: daysAgo(0),
              reflectionEntryId: 'reflection-1',
              insightText: '休むことも前に進むために必要。',
            ),
            createInsightEntry(
              id: 'insight-2',
              discoveredAt: daysAgo(1),
              reflectionEntryId: 'reflection-2',
              insightText: '始めるまでが一番重く、10分だけ始めると続けやすい。',
            ),
          ],
        ),
        reflectionRepository: InMemoryReflectionRepository(),
      );

      const forbidden = <String>[
        '良い',
        '悪い',
        '正解',
        '不正解',
        '成長',
        '達成',
        '成功',
        '失敗',
        'スコア',
        '評価',
        'ランキング',
        '連続',
        '件中',
      ];

      for (final word in forbidden) {
        expect(
          find.textContaining(word),
          findsNothing,
          reason: '$word は気づきの分類に使わない',
        );
      }
    });
  });

  group('InsightPage 振り返りの参照に失敗した場合', () {
    testWidgets('一部の振り返りが読めなくても、気づき本文は消えない', (tester) async {
      await pumpInsightPage(
        tester,
        insightRepository: InMemoryInsightRepository(
          seedEntries: <InsightEntry>[
            createInsightEntry(
              id: 'insight-ok',
              discoveredAt: daysAgo(0),
              reflectionEntryId: 'reflection-ok',
              insightText: '読める振り返りからの気づき',
            ),
            createInsightEntry(
              id: 'insight-broken',
              discoveredAt: daysAgo(1),
              reflectionEntryId: 'reflection-broken',
              insightText: '読めない振り返りからの気づき',
            ),
          ],
        ),
        reflectionRepository: PartlyFailingReflectionRepository(
          failingEntryIds: <String>{'reflection-broken'},
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(
              id: 'reflection-ok',
              reflectedAt: daysAgo(0),
              feelingText: '読める振り返りで感じたこと',
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);

      // 一覧そのものが消えたり、エラー画面になったりしない。
      expect(find.text('気づきを読み込めませんでした。'), findsNothing);
      expect(find.byKey(const Key('insight_empty_state')), findsNothing);

      expect(find.byKey(const Key('insight_entry_insight-ok')), findsOneWidget);
      expect(
        find.byKey(const Key('insight_entry_insight-broken')),
        findsOneWidget,
      );

      // Human本人が書いた気づきは、どちらもそのまま残る。
      expect(find.text('読める振り返りからの気づき'), findsOneWidget);
      expect(find.text('読めない振り返りからの気づき'), findsOneWidget);

      // 手がかりが添えられないのは、読めなかった振り返りのぶんだけ。
      expect(find.text('読める振り返りで感じたこと'), findsOneWidget);
      expect(find.text('元の振り返りを確認できませんでした。'), findsOneWidget);
    });

    testWidgets('別のHumanの振り返りは、手がかりとして表示しない', (tester) async {
      await pumpInsightPage(
        tester,
        insightRepository: InMemoryInsightRepository(
          seedEntries: <InsightEntry>[
            createInsightEntry(
              id: 'insight-1',
              discoveredAt: daysAgo(0),
              reflectionEntryId: 'reflection-of-other',
              insightText: '自分が見つけた気づき',
            ),
          ],
        ),
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(
              id: 'reflection-of-other',
              reflectedAt: daysAgo(0),
              humanId: 'other-human',
              feelingText: '他のHumanが感じたこと',
              noticedText: '他のHumanが気づいたこと',
            ),
          ],
        ),
      );

      // 自分が書いた気づきは残る。
      expect(find.byKey(const Key('insight_entry_insight-1')), findsOneWidget);
      expect(find.text('自分が見つけた気づき'), findsOneWidget);

      // 別のHumanの振り返りの内容は、けっして出さない。
      expect(find.text('他のHumanが感じたこと'), findsNothing);
      expect(find.text('他のHumanが気づいたこと'), findsNothing);
      expect(find.text('感じたこと'), findsNothing);
      expect(find.text('元の振り返りを確認できませんでした。'), findsOneWidget);
    });
  });
}
