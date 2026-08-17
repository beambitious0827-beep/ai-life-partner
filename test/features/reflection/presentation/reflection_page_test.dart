import 'dart:async';

import 'package:ai_life_partner/features/insight/data/demo_reflection_thinking_assistant.dart';
import 'package:ai_life_partner/features/insight/data/in_memory_insight_repository.dart';
import 'package:ai_life_partner/features/insight/domain/models/insight_entry.dart';
import 'package:ai_life_partner/features/insight/domain/repositories/insight_repository.dart';
import 'package:ai_life_partner/features/insight/presentation/insight_record_page.dart';
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

/// 指定した振り返りについてだけ、気づきの確認に失敗するInsight Repository。
///
/// 補助情報の障害が、振り返りそのものの表示を巻き添えにしないことを確かめる。
class PartlyFailingInsightRepository implements InsightRepository {
  PartlyFailingInsightRepository({
    required this.failingReflectionEntryIds,
    Iterable<InsightEntry> seedEntries = const <InsightEntry>[],
  }) : _inner = InMemoryInsightRepository(seedEntries: seedEntries);

  /// 確認に失敗させる振り返りのID。テストの途中で変えられる。
  final Set<String> failingReflectionEntryIds;

  final InMemoryInsightRepository _inner;

  @override
  Future<List<InsightEntry>> getEntries({
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
  Future<InsightEntry?> getEntryById(String entryId) {
    return _inner.getEntryById(entryId);
  }

  @override
  Future<InsightEntry?> getEntryForReflection({
    required String humanId,
    required String reflectionEntryId,
  }) async {
    if (failingReflectionEntryIds.contains(reflectionEntryId)) {
      throw StateError('気づきの状態を確認できませんでした');
    }

    return _inner.getEntryForReflection(
      humanId: humanId,
      reflectionEntryId: reflectionEntryId,
    );
  }

  @override
  Future<void> saveEntry(InsightEntry entry) {
    return _inner.saveEntry(entry);
  }
}

InsightEntry createInsightEntry({
  required String id,
  required String reflectionEntryId,
  required DateTime discoveredAt,
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

Future<void> tapByKey(WidgetTester tester, Key key) async {
  final target = find.byKey(key);

  expect(target, findsOneWidget);

  await tester.ensureVisible(target);
  await tester.pumpAndSettle();

  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<List<InsightEntry>> readInsights(InsightRepository repository) async {
  final now = DateTime.now();

  return repository.getEntries(
    humanId: humanId,
    rangeStart: DateTime(now.year, now.month, now.day - 1),
    rangeEnd: DateTime(now.year, now.month, now.day + 1),
  );
}

/// 気づきの状態確認の「返る順番」を操作できるInsight Repository。
///
/// 古い確認が新しい状態を上書きしないことを確かめるために使う。
class ControllableInsightRepository implements InsightRepository {
  ControllableInsightRepository({
    Iterable<InsightEntry> seedEntries = const <InsightEntry>[],
  }) : _inner = InMemoryInsightRepository(seedEntries: seedEntries);

  final InMemoryInsightRepository _inner;

  /// 確認が失敗する振り返りのID。テストの途中で変えられる。
  final Set<String> failingReflectionEntryIds = <String>{};

  /// 次の1回だけ確認を保留する振り返りのID。
  String? gatedReflectionEntryId;

  /// 保留した確認が最後に返す結果。
  ///
  /// 「その時点では気づきがなかった」という古い答えを再現するために使う。
  InsightEntry? gatedResult;

  /// 保留した確認を、成功ではなく失敗として終わらせるかどうか。
  bool gatedFails = false;

  Completer<void>? _gate;

  bool get hasPendingGate => _gate != null;

  /// 保留していた確認を完了させる。
  void releaseGate() {
    final gate = _gate;

    _gate = null;

    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
  }

  @override
  Future<List<InsightEntry>> getEntries({
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
  Future<InsightEntry?> getEntryById(String entryId) {
    return _inner.getEntryById(entryId);
  }

  @override
  Future<InsightEntry?> getEntryForReflection({
    required String humanId,
    required String reflectionEntryId,
  }) async {
    if (failingReflectionEntryIds.contains(reflectionEntryId)) {
      throw StateError('気づきの状態を確認できませんでした');
    }

    if (reflectionEntryId == gatedReflectionEntryId) {
      // 保留するのは最初の1回だけ。あとの確認はふつうに答える。
      gatedReflectionEntryId = null;

      final gate = Completer<void>();

      _gate = gate;

      await gate.future;

      if (gatedFails) {
        throw StateError('気づきの状態を確認できませんでした');
      }

      return gatedResult;
    }

    return _inner.getEntryForReflection(
      humanId: humanId,
      reflectionEntryId: reflectionEntryId,
    );
  }

  @override
  Future<void> saveEntry(InsightEntry entry) {
    return _inner.saveEntry(entry);
  }
}

bool isButtonEnabled(WidgetTester tester, Key key) {
  return tester.widget<ButtonStyleButton>(find.byKey(key)).onPressed != null;
}

Future<void> pumpReflectionPage(
  WidgetTester tester, {
  required ReflectionRepository reflectionRepository,
  required JourneyRepository journeyRepository,
  InsightRepository? insightRepository,
}) async {
  tester.view.physicalSize = const Size(1400, 5000);
  tester.view.devicePixelRatio = 1.0;

  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: ReflectionPage(
        reflectionRepository: reflectionRepository,
        journeyRepository: journeyRepository,
        insightRepository: insightRepository ?? InMemoryInsightRepository(),
        thinkingAssistant: const DemoReflectionThinkingAssistant(),
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

  group('ReflectionPage 気づきへの導線', () {
    testWidgets('画面を開いただけでは、気づきを作らない', (tester) async {
      final insightRepository = InMemoryInsightRepository();

      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(id: 'reflection-1', reflectedAt: daysAgo(0)),
          ],
        ),
        journeyRepository: InMemoryJourneyRepository(),
        insightRepository: insightRepository,
      );

      expect(await readInsights(insightRepository), isEmpty);
      expect(
        find.byKey(const Key('reflection_insight_button_reflection-1')),
        findsOneWidget,
      );
      expect(find.text('この振り返りから気づきを残す'), findsOneWidget);
    });

    testWidgets('気づきが残っている振り返りでは、そのことだけを伝える', (tester) async {
      final insightRepository = InMemoryInsightRepository(
        seedEntries: <InsightEntry>[
          createInsightEntry(
            id: 'insight-1',
            reflectionEntryId: 'reflection-1',
            discoveredAt: daysAgo(0),
          ),
        ],
      );

      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(id: 'reflection-1', reflectedAt: daysAgo(0)),
          ],
        ),
        journeyRepository: InMemoryJourneyRepository(),
        insightRepository: insightRepository,
      );

      expect(
        find.byKey(const Key('reflection_insight_recorded_reflection-1')),
        findsOneWidget,
      );
      expect(find.text('気づきを残しました'), findsOneWidget);

      expect(
        find.byKey(const Key('reflection_insight_button_reflection-1')),
        findsNothing,
      );
    });

    testWidgets('振り返りごとに、気づきの有無を分けて扱う', (tester) async {
      final insightRepository = InMemoryInsightRepository(
        seedEntries: <InsightEntry>[
          createInsightEntry(
            id: 'insight-1',
            reflectionEntryId: 'reflection-1',
            discoveredAt: daysAgo(0),
          ),
        ],
      );

      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(id: 'reflection-1', reflectedAt: daysAgo(0)),
            createReflectionEntry(
              id: 'reflection-2',
              reflectedAt: daysAgo(1),
              journeyEntryId: 'journey-2',
            ),
          ],
        ),
        journeyRepository: InMemoryJourneyRepository(),
        insightRepository: insightRepository,
      );

      expect(
        find.byKey(const Key('reflection_insight_recorded_reflection-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reflection_insight_button_reflection-2')),
        findsOneWidget,
      );
    });

    testWidgets('気づきを残すと、Repositoryの内容にあわせて表示が変わる', (tester) async {
      final insightRepository = InMemoryInsightRepository();

      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(
              id: 'reflection-1',
              reflectedAt: daysAgo(0),
              feelingText: '思ったより疲れていた',
            ),
            createReflectionEntry(
              id: 'reflection-2',
              reflectedAt: daysAgo(1),
              journeyEntryId: 'journey-2',
            ),
          ],
        ),
        journeyRepository: InMemoryJourneyRepository(),
        insightRepository: insightRepository,
      );

      await tapByKey(
        tester,
        const Key('reflection_insight_button_reflection-1'),
      );

      expect(find.byType(InsightRecordPage), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('insight_record_text_field')),
        '休むことも前に進むために必要。',
      );
      await tester.pumpAndSettle();

      await tapByKey(tester, const Key('insight_record_save_button'));

      expect(find.byType(InsightRecordPage), findsNothing);

      // 保存された事実はRepositoryにあり、画面もそれに合わせて変わる。
      final saved = (await readInsights(insightRepository)).single;

      expect(saved.reflectionEntryId, 'reflection-1');
      expect(saved.insightText, '休むことも前に進むために必要。');

      expect(
        find.byKey(const Key('reflection_insight_recorded_reflection-1')),
        findsOneWidget,
      );

      // 同じ振り返りへ、もう一度気づきを作りやすい入り口は出さない。
      expect(
        find.byKey(const Key('reflection_insight_button_reflection-1')),
        findsNothing,
      );

      // 別の振り返りからは、これまでどおり気づきを残せる。
      expect(
        find.byKey(const Key('reflection_insight_button_reflection-2')),
        findsOneWidget,
      );
    });

    testWidgets('気づきを残すのをやめた場合は、入り口のまま変わらない', (tester) async {
      final insightRepository = InMemoryInsightRepository();

      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(id: 'reflection-1', reflectedAt: daysAgo(0)),
          ],
        ),
        journeyRepository: InMemoryJourneyRepository(),
        insightRepository: insightRepository,
      );

      await tapByKey(
        tester,
        const Key('reflection_insight_button_reflection-1'),
      );

      await tapByKey(tester, const Key('insight_record_cancel_button'));

      expect(find.byType(InsightRecordPage), findsNothing);
      expect(await readInsights(insightRepository), isEmpty);

      expect(
        find.byKey(const Key('reflection_insight_button_reflection-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reflection_insight_recorded_reflection-1')),
        findsNothing,
      );
    });
  });

  group('ReflectionPage 気づきの状態を確認できない場合', () {
    testWidgets('気づきを確認できなくても、振り返りそのものは必ず表示する', (tester) async {
      await pumpReflectionPage(
        tester,
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
        journeyRepository: InMemoryJourneyRepository(
          seedEntries: <JourneyEntry>[
            createJourneyEntry(
              id: 'journey-1',
              occurredAt: daysAgo(0),
              plannedActionText: '30分トレーニングする',
            ),
          ],
        ),
        insightRepository: PartlyFailingInsightRepository(
          failingReflectionEntryIds: <String>{'reflection-1'},
        ),
      );

      expect(tester.takeException(), isNull);

      // 振り返りの一覧はエラーにならない。
      expect(find.text('振り返りを読み込めませんでした。'), findsNothing);
      expect(find.byKey(const Key('reflection_empty_state')), findsNothing);
      expect(
        find.byKey(const Key('reflection_entry_reflection-1')),
        findsOneWidget,
      );

      // 振り返りの本文もその手がかりも欠けない。
      expect(find.text('振り返った歩み'), findsOneWidget);
      expect(find.text('30分トレーニングする'), findsOneWidget);
      expect(find.text('思ったより疲れていた'), findsOneWidget);
      expect(find.text('休んだことで少し気持ちが軽くなった'), findsOneWidget);

      // 分からない状態は、分からないまま伝える。
      expect(
        find.byKey(const Key('reflection_insight_unknown_reflection-1')),
        findsOneWidget,
      );
      expect(find.text('気づきの状態を確認できませんでした。'), findsOneWidget);

      // 重複した気づきを作りやすい入り口は出さない。
      expect(
        find.byKey(const Key('reflection_insight_button_reflection-1')),
        findsNothing,
      );
      expect(find.text('この振り返りから気づきを残す'), findsNothing);
      expect(
        find.byKey(const Key('reflection_insight_recorded_reflection-1')),
        findsNothing,
      );
    });

    testWidgets('確認できなかった振り返りだけを、状態不明として扱う', (tester) async {
      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(id: 'reflection-1', reflectedAt: daysAgo(0)),
            createReflectionEntry(
              id: 'reflection-2',
              reflectedAt: daysAgo(1),
              journeyEntryId: 'journey-2',
            ),
            createReflectionEntry(
              id: 'reflection-3',
              reflectedAt: daysAgo(2),
              journeyEntryId: 'journey-3',
            ),
          ],
        ),
        journeyRepository: InMemoryJourneyRepository(),
        insightRepository: PartlyFailingInsightRepository(
          failingReflectionEntryIds: <String>{'reflection-2'},
          seedEntries: <InsightEntry>[
            createInsightEntry(
              id: 'insight-1',
              reflectionEntryId: 'reflection-1',
              discoveredAt: daysAgo(0),
            ),
          ],
        ),
      );

      expect(
        find.byKey(const Key('reflection_insight_recorded_reflection-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reflection_insight_unknown_reflection-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reflection_insight_button_reflection-3')),
        findsOneWidget,
      );
    });

    testWidgets('もう一度確認できれば、状態は元に戻る', (tester) async {
      final insightRepository = PartlyFailingInsightRepository(
        failingReflectionEntryIds: <String>{'reflection-1'},
      );

      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(id: 'reflection-1', reflectedAt: daysAgo(0)),
          ],
        ),
        journeyRepository: InMemoryJourneyRepository(),
        insightRepository: insightRepository,
      );

      expect(
        find.byKey(const Key('reflection_insight_unknown_reflection-1')),
        findsOneWidget,
      );

      // 確認できる状態に戻ってから、その振り返りだけを確かめ直す。
      insightRepository.failingReflectionEntryIds.clear();

      await tapByKey(
        tester,
        const Key('reflection_insight_recheck_button_reflection-1'),
      );

      expect(
        find.byKey(const Key('reflection_insight_unknown_reflection-1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('reflection_insight_button_reflection-1')),
        findsOneWidget,
      );
    });
  });

  group('ReflectionPage 気づき状態の確認が前後した場合', () {
    /// AとBの振り返りを置き、Aの確認だけを保留できる状態にする。
    ///
    /// Aにはすでに気づきが残っているが、最初の読み込みでは確認に失敗する。
    Future<ControllableInsightRepository> pumpRaceablePage(
      WidgetTester tester,
    ) async {
      final insightRepository = ControllableInsightRepository(
        seedEntries: <InsightEntry>[
          createInsightEntry(
            id: 'insight-a',
            reflectionEntryId: 'reflection-a',
            discoveredAt: daysAgo(0),
          ),
        ],
      );

      insightRepository.failingReflectionEntryIds.add('reflection-a');

      await pumpReflectionPage(
        tester,
        reflectionRepository: InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createReflectionEntry(
              id: 'reflection-a',
              reflectedAt: daysAgo(0),
              feelingText: 'Aの振り返りで感じたこと',
            ),
            createReflectionEntry(
              id: 'reflection-b',
              reflectedAt: daysAgo(1),
              journeyEntryId: 'journey-b',
              feelingText: 'Bの振り返りで感じたこと',
            ),
          ],
        ),
        journeyRepository: InMemoryJourneyRepository(),
        insightRepository: insightRepository,
      );

      expect(
        find.byKey(const Key('reflection_insight_unknown_reflection-a')),
        findsOneWidget,
      );

      // ここから先のAの確認は保留し、「気づきなし」という古い答えを後で返す。
      insightRepository.failingReflectionEntryIds.clear();
      insightRepository.gatedReflectionEntryId = 'reflection-a';
      insightRepository.gatedResult = null;

      return insightRepository;
    }

    /// 保留中のAを残したまま、Bから気づきを残して画面全体を読み直させる。
    Future<void> recordInsightOnB(WidgetTester tester) async {
      await tapByKey(
        tester,
        const Key('reflection_insight_button_reflection-b'),
      );

      expect(find.byType(InsightRecordPage), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('insight_record_text_field')),
        'Bの振り返りからの気づき',
      );
      await tester.pumpAndSettle();

      await tapByKey(tester, const Key('insight_record_save_button'));

      expect(find.byType(InsightRecordPage), findsNothing);
    }

    testWidgets('確認しているあいだは、同じ確認を重ねて始められない', (tester) async {
      final insightRepository = await pumpRaceablePage(tester);

      await tester.tap(
        find.byKey(const Key('reflection_insight_recheck_button_reflection-a')),
      );
      await tester.pump();

      expect(insightRepository.hasPendingGate, isTrue);
      expect(find.text('確認しています…'), findsOneWidget);
      expect(find.text('もう一度確認する'), findsNothing);
      expect(
        isButtonEnabled(
          tester,
          const Key('reflection_insight_recheck_button_reflection-a'),
        ),
        isFalse,
      );

      // 振り返り本文は、確認中でも隠れない。
      expect(find.text('Aの振り返りで感じたこと'), findsOneWidget);

      insightRepository.gatedResult = null;
      insightRepository.releaseGate();

      await tester.pumpAndSettle();

      // 確認が終われば、状態は結果どおりに更新される。
      expect(
        find.byKey(const Key('reflection_insight_button_reflection-a')),
        findsOneWidget,
      );
    });

    testWidgets('古い確認結果は、新しい気づきの状態を上書きしない', (tester) async {
      final insightRepository = await pumpRaceablePage(tester);

      // Aの再確認を始める。まだ結果は返らない。
      await tester.tap(
        find.byKey(const Key('reflection_insight_recheck_button_reflection-a')),
      );
      await tester.pump();

      expect(insightRepository.hasPendingGate, isTrue);

      // 待っているあいだに、Bから気づきを残して画面全体が読み直される。
      await recordInsightOnB(tester);

      // 読み直しでAの気づきが見つかり、Aは「残しました」になる。
      expect(
        find.byKey(const Key('reflection_insight_recorded_reflection-a')),
        findsOneWidget,
      );

      // ここで、古いAの確認が「気づきなし」として返る。
      insightRepository.releaseGate();

      await tester.pumpAndSettle();

      // 古い答えは捨てられ、新しい状態がそのまま残る。
      expect(
        find.byKey(const Key('reflection_insight_recorded_reflection-a')),
        findsOneWidget,
      );
      expect(find.text('気づきを残しました'), findsNWidgets(2));
      expect(
        find.byKey(const Key('reflection_insight_button_reflection-a')),
        findsNothing,
      );
      expect(find.text('この振り返りから気づきを残す'), findsNothing);

      // 振り返り本文も欠けない。
      expect(find.text('Aの振り返りで感じたこと'), findsOneWidget);
      expect(find.text('Bの振り返りで感じたこと'), findsOneWidget);
    });

    testWidgets('古い確認の失敗も、新しい気づきの状態を戻さない', (tester) async {
      final insightRepository = await pumpRaceablePage(tester);

      // 保留したAの確認は、最後に失敗として終わる。
      insightRepository.gatedFails = true;

      await tester.tap(
        find.byKey(const Key('reflection_insight_recheck_button_reflection-a')),
      );
      await tester.pump();

      expect(insightRepository.hasPendingGate, isTrue);

      await recordInsightOnB(tester);

      expect(
        find.byKey(const Key('reflection_insight_recorded_reflection-a')),
        findsOneWidget,
      );

      insightRepository.releaseGate();

      await tester.pumpAndSettle();

      // 古い失敗で、確認できていた状態を「分からない」へ戻さない。
      expect(
        find.byKey(const Key('reflection_insight_recorded_reflection-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('reflection_insight_unknown_reflection-a')),
        findsNothing,
      );
      expect(find.text('気づきの状態を確認できませんでした。'), findsNothing);
      expect(find.text('Aの振り返りで感じたこと'), findsOneWidget);
    });
  });
}
