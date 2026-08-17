import 'dart:async';

import 'package:ai_life_partner/features/insight/data/demo_reflection_thinking_assistant.dart';
import 'package:ai_life_partner/features/insight/data/in_memory_insight_repository.dart';
import 'package:ai_life_partner/features/insight/domain/models/insight_entry.dart';
import 'package:ai_life_partner/features/insight/domain/models/reflection_thinking_request.dart';
import 'package:ai_life_partner/features/insight/domain/models/reflection_thinking_support.dart';
import 'package:ai_life_partner/features/insight/domain/repositories/insight_repository.dart';
import 'package:ai_life_partner/features/insight/domain/services/reflection_thinking_assistant.dart';
import 'package:ai_life_partner/features/insight/presentation/insight_record_page.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String humanId = 'local-human';

const Key insightFieldKey = Key('insight_record_text_field');
const Key saveButtonKey = Key('insight_record_save_button');
const Key cancelButtonKey = Key('insight_record_cancel_button');
const Key thinkingButtonKey = Key('insight_record_thinking_button');
const Key thinkingSupportKey = Key('insight_record_thinking_support');
const Key thinkingDemoNoticeKey = Key('insight_record_thinking_demo_notice');

ReflectionThinkingSupport createSupport({String label = 'A'}) {
  return ReflectionThinkingSupport(
    questions: <String>['$label の問い'],
    perspectives: <String>['$label の別の見方'],
    possibilities: <String>['$label の可能性'],
  );
}

/// 受け取った材料を記録し、すぐに答えるAssistant。
class RecordingThinkingAssistant implements ReflectionThinkingAssistant {
  RecordingThinkingAssistant({
    this.isDemo = true,
    ReflectionThinkingSupport? result,
    this.failingCallCount = 0,
  }) : result = result ?? createSupport();

  @override
  final bool isDemo;

  final ReflectionThinkingSupport result;

  /// 最初の何回を失敗させるか。
  final int failingCallCount;

  /// AIへ渡された材料。ここに何が入るかがそのまま境界の確認になる。
  final List<ReflectionThinkingRequest> receivedRequests =
      <ReflectionThinkingRequest>[];

  int get callCount => receivedRequests.length;

  @override
  Future<ReflectionThinkingSupport> support(
    ReflectionThinkingRequest request,
  ) async {
    receivedRequests.add(request);

    if (receivedRequests.length <= failingCallCount) {
      throw StateError('AIと一緒に考えられませんでした');
    }

    return result;
  }
}

/// 呼び出しごとに答えを保留できるAssistant。
///
/// 考えている途中の状態を止めたまま確かめたり、
/// 頼み直しのたびに何回呼ばれたかを数えたりするために使う。
class GatedThinkingAssistant implements ReflectionThinkingAssistant {
  @override
  bool get isDemo => true;

  final List<ReflectionThinkingRequest> receivedRequests =
      <ReflectionThinkingRequest>[];

  final List<Completer<void>> _gates = <Completer<void>>[];

  /// 呼び出しの順番ごとの答え。
  final Map<int, ReflectionThinkingSupport> results =
      <int, ReflectionThinkingSupport>{};

  /// 失敗として終わらせる呼び出しの順番。
  final Set<int> failingCalls = <int>{};

  int get callCount => receivedRequests.length;

  bool isPending(int callIndex) {
    return callIndex < _gates.length && !_gates[callIndex].isCompleted;
  }

  void release(int callIndex) {
    final gate = _gates[callIndex];

    if (!gate.isCompleted) {
      gate.complete();
    }
  }

  @override
  Future<ReflectionThinkingSupport> support(
    ReflectionThinkingRequest request,
  ) async {
    final callIndex = receivedRequests.length;

    receivedRequests.add(request);

    final gate = Completer<void>();

    _gates.add(gate);

    await gate.future;

    if (failingCalls.contains(callIndex)) {
      throw StateError('AIと一緒に考えられませんでした');
    }

    return results[callIndex] ?? createSupport();
  }
}

ReflectionEntry createReflectionEntry({
  String id = 'reflection-1',
  String humanId = 'local-human',
  String? feelingText = '思ったより疲れていた',
  String? noticedText = '休んだことで少し気持ちが軽くなった',
}) {
  final reflectedAt = DateTime.now();

  return ReflectionEntry(
    id: id,
    humanId: humanId,
    journeyEntryId: 'journey-1',
    feelingText: feelingText,
    noticedText: noticedText,
    reflectedAt: reflectedAt,
    createdAt: reflectedAt,
    updatedAt: reflectedAt,
  );
}

/// 気づきの保存結果を受け取るための入れ物。
class ResultHolder {
  InsightEntry? value;
}

Future<ResultHolder> pumpRecordPage(
  WidgetTester tester, {
  required InsightRepository repository,
  ReflectionThinkingAssistant? assistant,
  ReflectionEntry? reflectionEntry,
  String recordingHumanId = humanId,
}) async {
  final holder = ResultHolder();
  final entry = reflectionEntry ?? createReflectionEntry();

  tester.view.physicalSize = const Size(1400, 5000);
  tester.view.devicePixelRatio = 1.0;

  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  holder.value = await Navigator.of(context).push<InsightEntry>(
                    MaterialPageRoute<InsightEntry>(
                      builder: (context) => InsightRecordPage(
                        repository: repository,
                        thinkingAssistant:
                            assistant ??
                            const DemoReflectionThinkingAssistant(),
                        humanId: recordingHumanId,
                        reflectionEntry: entry,
                      ),
                    ),
                  );
                },
                child: const Text('気づきへ'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('気づきへ'));
  await tester.pumpAndSettle();

  expect(find.byType(InsightRecordPage), findsOneWidget);

  return holder;
}

Future<void> tapByKey(WidgetTester tester, Key key) async {
  final target = find.byKey(key);

  expect(target, findsOneWidget);

  await tester.ensureVisible(target);
  await tester.pumpAndSettle();

  await tester.tap(target);
  await tester.pumpAndSettle();
}

bool isFieldEnabled(WidgetTester tester, Key key) {
  return tester.widget<TextField>(find.byKey(key)).enabled ?? true;
}

bool isButtonEnabled(WidgetTester tester, Key key) {
  return tester.widget<ButtonStyleButton>(find.byKey(key)).onPressed != null;
}

Future<List<InsightEntry>> readEntries(InsightRepository repository) {
  final now = DateTime.now();

  return repository.getEntries(
    humanId: humanId,
    rangeStart: DateTime(now.year, now.month, now.day),
    rangeEnd: DateTime(now.year, now.month, now.day + 1),
  );
}

/// 保存だけが待機するInsight Repository。
class SlowSaveInsightRepository implements InsightRepository {
  final InMemoryInsightRepository _inner = InMemoryInsightRepository();

  final Completer<void> _saveGate = Completer<void>();

  void completeSave() {
    if (!_saveGate.isCompleted) {
      _saveGate.complete();
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
  }) {
    return _inner.getEntryForReflection(
      humanId: humanId,
      reflectionEntryId: reflectionEntryId,
    );
  }

  @override
  Future<void> saveEntry(InsightEntry entry) async {
    await _saveGate.future;

    await _inner.saveEntry(entry);
  }
}

/// 1回目のsaveEntryだけ、保存へ届く前に失敗するInsight Repository。
class FlakySaveInsightRepository implements InsightRepository {
  final InMemoryInsightRepository _inner = InMemoryInsightRepository();

  /// saveEntryが呼ばれたときのInsight ID。失敗した試行も含む。
  final List<String> attemptedIds = <String>[];

  int saveAttempts = 0;

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
  }) {
    return _inner.getEntryForReflection(
      humanId: humanId,
      reflectionEntryId: reflectionEntryId,
    );
  }

  @override
  Future<void> saveEntry(InsightEntry entry) async {
    saveAttempts += 1;

    attemptedIds.add(entry.id);

    if (saveAttempts == 1) {
      throw StateError('気づきを保存できませんでした');
    }

    await _inner.saveEntry(entry);
  }
}

/// 1回目のsaveEntryだけ、保存を済ませてから失敗するInsight Repository。
///
/// 「保存は届いたが、その結果を受け取れなかった」状況を再現する。
class CommitThenFailInsightRepository implements InsightRepository {
  final InMemoryInsightRepository _inner = InMemoryInsightRepository();

  final List<String> savedIds = <String>[];

  int saveAttempts = 0;

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
  }) {
    return _inner.getEntryForReflection(
      humanId: humanId,
      reflectionEntryId: reflectionEntryId,
    );
  }

  @override
  Future<void> saveEntry(InsightEntry entry) async {
    saveAttempts += 1;

    await _inner.saveEntry(entry);

    savedIds.add(entry.id);

    if (saveAttempts == 1) {
      throw StateError('保存の結果を受け取れませんでした');
    }
  }
}

void main() {
  group('InsightRecordPage', () {
    testWidgets('もとになる振り返りを、読むだけの形で確認できる', (tester) async {
      final repository = InMemoryInsightRepository();

      await pumpRecordPage(tester, repository: repository);

      expect(find.text('元の振り返り'), findsOneWidget);
      expect(find.text('感じたこと'), findsOneWidget);
      expect(find.text('思ったより疲れていた'), findsOneWidget);
      expect(find.text('気づいたこと'), findsOneWidget);
      expect(find.text('休んだことで少し気持ちが軽くなった'), findsOneWidget);

      // 振り返りを書き換える欄は出さない。入力欄は気づきのひとつだけ。
      expect(find.byType(TextField), findsOneWidget);

      // 画面を開いただけでは、何も保存されない。
      expect(await readEntries(repository), isEmpty);
    });

    testWidgets('書かれていない振り返りの欄は出さない', (tester) async {
      await pumpRecordPage(
        tester,
        repository: InMemoryInsightRepository(),
        reflectionEntry: createReflectionEntry(noticedText: null),
      );

      expect(find.text('感じたこと'), findsOneWidget);
      expect(find.text('気づいたこと'), findsNothing);
    });

    testWidgets('聞くのは気づきについてのひとつの問いだけ', (tester) async {
      await pumpRecordPage(tester, repository: InMemoryInsightRepository());

      expect(find.text('この振り返りから、あなたにとって大切だと思う気づきはありますか？'), findsOneWidget);
      expect(find.text('今は残さなくても大丈夫です。'), findsOneWidget);
    });

    testWidgets('正しい教訓や改善点を求めない', (tester) async {
      await pumpRecordPage(tester, repository: InMemoryInsightRepository());

      const forbidden = <String>[
        '教訓',
        '改善',
        '直すべき',
        '学びましたか',
        '反省',
        '正解',
        '不正解',
        '評価',
        '採点',
        'スコア',
        '達成',
        '成功',
        '失敗',
        'なぜ',
        '原因',
      ];

      for (final word in forbidden) {
        expect(
          find.textContaining(word),
          findsNothing,
          reason: '$word はInsightでは問わない',
        );
      }
    });

    testWidgets('Humanが書いた気づきを残せる', (tester) async {
      final repository = InMemoryInsightRepository();

      final holder = await pumpRecordPage(tester, repository: repository);

      await tester.enterText(
        find.byKey(insightFieldKey),
        '無理を続けるより、休むことも前に進むために必要。',
      );
      await tester.pumpAndSettle();

      // 入力しただけでは、まだ保存されない。
      expect(await readEntries(repository), isEmpty);

      await tapByKey(tester, saveButtonKey);

      expect(find.byType(InsightRecordPage), findsNothing);

      final entry = (await readEntries(repository)).single;

      expect(entry.reflectionEntryId, 'reflection-1');
      expect(entry.insightText, '無理を続けるより、休むことも前に進むために必要。');
      expect(entry.humanId, humanId);

      expect(holder.value?.id, entry.id);
    });

    testWidgets('前後の空白は落として残す', (tester) async {
      final repository = InMemoryInsightRepository();

      await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(insightFieldKey), '  休んでよかった。  ');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect((await readEntries(repository)).single.insightText, '休んでよかった。');
    });

    testWidgets('何も書かれていない場合は保存せず、責めずに伝える', (tester) async {
      final repository = InMemoryInsightRepository();

      await pumpRecordPage(tester, repository: repository);

      await tapByKey(tester, saveButtonKey);

      expect(find.byType(InsightRecordPage), findsOneWidget);
      expect(find.text('残したい気づきを、ひとこと書いてください。'), findsOneWidget);
      expect(await readEntries(repository), isEmpty);

      // 書き始めれば、案内は消える。
      await tester.enterText(find.byKey(insightFieldKey), '休んでよかった。');
      await tester.pumpAndSettle();

      expect(find.text('残したい気づきを、ひとこと書いてください。'), findsNothing);
    });

    testWidgets('空白だけの入力では保存しない', (tester) async {
      final repository = InMemoryInsightRepository();

      await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(insightFieldKey), '   ');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect(find.byType(InsightRecordPage), findsOneWidget);
      expect(await readEntries(repository), isEmpty);
    });

    testWidgets('キャンセルでは気づきを残さない', (tester) async {
      final repository = InMemoryInsightRepository();

      final holder = await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(insightFieldKey), '休んでよかった。');
      await tester.pumpAndSettle();

      await tapByKey(tester, cancelButtonKey);

      expect(find.byType(InsightRecordPage), findsNothing);
      expect(holder.value, isNull);
      expect(await readEntries(repository), isEmpty);
    });

    testWidgets('戻る操作でも気づきを残さない', (tester) async {
      final repository = InMemoryInsightRepository();

      final holder = await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(insightFieldKey), '休んでよかった。');
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(InsightRecordPage), findsNothing);
      expect(holder.value, isNull);
      expect(await readEntries(repository), isEmpty);
    });
  });

  group('InsightRecordPage Humanの境界', () {
    testWidgets('別のHumanの振り返りからは、気づきを残せない', (tester) async {
      final repository = InMemoryInsightRepository();
      final assistant = RecordingThinkingAssistant();

      final holder = await pumpRecordPage(
        tester,
        repository: repository,
        assistant: assistant,
        reflectionEntry: createReflectionEntry(
          humanId: 'other-human',
          feelingText: '他のHumanが感じたこと',
          noticedText: '他のHumanが気づいたこと',
        ),
      );

      expect(
        find.byKey(const Key('insight_record_unavailable')),
        findsOneWidget,
      );
      expect(find.text('この振り返りから気づきを残すことはできません。'), findsOneWidget);

      // 入力も保存もできない。
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(insightFieldKey), findsNothing);
      expect(find.byKey(saveButtonKey), findsNothing);

      // AIと一緒に考えることも始められない。
      expect(find.byKey(thinkingButtonKey), findsNothing);
      expect(find.text('AIと一緒に考える'), findsNothing);
      expect(assistant.callCount, 0);

      // 別のHumanの振り返りの内容も見せない。
      expect(find.text('他のHumanが感じたこと'), findsNothing);
      expect(find.text('他のHumanが気づいたこと'), findsNothing);
      expect(find.text('元の振り返り'), findsNothing);

      await tapByKey(tester, const Key('insight_record_close_button'));

      expect(find.byType(InsightRecordPage), findsNothing);
      expect(holder.value, isNull);
      expect(await readEntries(repository), isEmpty);
      expect(assistant.callCount, 0);
    });

    testWidgets('自分の振り返りであれば、これまでどおり気づきを残せる', (tester) async {
      await pumpRecordPage(
        tester,
        repository: InMemoryInsightRepository(),
        reflectionEntry: createReflectionEntry(humanId: humanId),
      );

      expect(find.byKey(const Key('insight_record_unavailable')), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('InsightRecordPage 保存中', () {
    testWidgets('保存中は入力も操作も受け付けない', (tester) async {
      final repository = SlowSaveInsightRepository();

      await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(insightFieldKey), '保存前の言葉');
      await tester.pumpAndSettle();

      // 保存中は表示がアニメーションし続けるため、pumpAndSettleは使わない。
      await tester.tap(find.byKey(saveButtonKey));
      await tester.pump();

      expect(find.text('保存しています…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      expect(isFieldEnabled(tester, insightFieldKey), isFalse);
      expect(isButtonEnabled(tester, saveButtonKey), isFalse);
      expect(isButtonEnabled(tester, cancelButtonKey), isFalse);

      // 戻る操作でも離れられない。
      await tester.pageBack();
      await tester.pump();

      expect(find.byType(InsightRecordPage), findsOneWidget);

      repository.completeSave();

      await tester.pumpAndSettle();

      expect(find.byType(InsightRecordPage), findsNothing);

      final entry = (await readEntries(repository)).single;

      expect(entry.insightText, '保存前の言葉');
    });

    testWidgets('保存に失敗しても閉じず、編集してもう一度残せる', (tester) async {
      final repository = FlakySaveInsightRepository();

      final holder = await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(insightFieldKey), '最初に書いた気づき');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect(repository.saveAttempts, 1);

      expect(find.byType(InsightRecordPage), findsOneWidget);
      expect(find.text('気づきを保存できませんでした。もう一度お試しください。'), findsOneWidget);
      expect(await readEntries(repository), isEmpty);

      // 保存中の表示は解除され、すべて操作できる状態に戻る。
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(isFieldEnabled(tester, insightFieldKey), isTrue);
      expect(isButtonEnabled(tester, saveButtonKey), isTrue);
      expect(isButtonEnabled(tester, cancelButtonKey), isTrue);

      // 書き直してから、もう一度残せる。
      await tester.enterText(find.byKey(insightFieldKey), '書き直した気づき');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect(repository.saveAttempts, 2);
      expect(find.byType(InsightRecordPage), findsNothing);

      // 2回の試行は、同じ気づきのIDで行われている。
      expect(repository.attemptedIds, hasLength(2));
      expect(repository.attemptedIds.first, repository.attemptedIds.last);

      final entries = await readEntries(repository);

      expect(entries, hasLength(1));
      expect(entries.single.id, repository.attemptedIds.first);
      expect(entries.single.insightText, '書き直した気づき');
      expect(holder.value?.id, entries.single.id);
    });

    testWidgets('保存が届いたか分からない場合も、同じ気づきとしてやり直せる', (tester) async {
      final repository = CommitThenFailInsightRepository();

      final holder = await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(insightFieldKey), '最初に書いた気づき');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      // Humanには保存できなかったように見える。
      expect(repository.saveAttempts, 1);
      expect(find.byType(InsightRecordPage), findsOneWidget);
      expect(find.text('気づきを保存できませんでした。もう一度お試しください。'), findsOneWidget);

      // 実際にはRepositoryへ届いていた。
      final afterFirst = (await readEntries(repository)).single;

      final firstId = afterFirst.id;
      final firstDiscoveredAt = afterFirst.discoveredAt;

      // 書き直してから、もう一度残す。
      await tester.enterText(find.byKey(insightFieldKey), '書き直した気づき');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect(repository.saveAttempts, 2);
      expect(find.byType(InsightRecordPage), findsNothing);

      // 同じ気づきのやり直しなので、新しいIDを作らない。
      expect(repository.savedIds, <String>[firstId, firstId]);

      final entries = await readEntries(repository);

      expect(entries, hasLength(1));
      expect(entries.single.id, firstId);
      expect(entries.single.insightText, '書き直した気づき');

      // 作成の身元は最初のままで、書き直した時刻だけが進む。
      expect(entries.single.discoveredAt, firstDiscoveredAt);
      expect(entries.single.createdAt, firstDiscoveredAt);
      expect(
        entries.single.updatedAt.isBefore(firstDiscoveredAt),
        isFalse,
        reason: '書き直した時刻が、作成時刻より前に戻ることはない',
      );

      expect(holder.value?.id, firstId);
    });
  });

  group('InsightRecordPage AIと一緒に考える', () {
    testWidgets('画面を開いただけでは、AIを呼ばない', (tester) async {
      final assistant = RecordingThinkingAssistant();

      await pumpRecordPage(
        tester,
        repository: InMemoryInsightRepository(),
        assistant: assistant,
      );

      expect(assistant.callCount, 0);
      expect(find.byKey(thinkingSupportKey), findsNothing);

      // 入り口はあるが、押すかどうかはHumanが決める。
      expect(find.byKey(thinkingButtonKey), findsOneWidget);
      expect(find.text('AIと一緒に考える'), findsOneWidget);
      expect(find.text('答えではなく、考えるためのヒントです。今は使わなくても大丈夫です。'), findsOneWidget);
    });

    testWidgets('気づきを書いただけでは、AIを呼ばない', (tester) async {
      final assistant = RecordingThinkingAssistant();

      await pumpRecordPage(
        tester,
        repository: InMemoryInsightRepository(),
        assistant: assistant,
      );

      await tester.enterText(find.byKey(insightFieldKey), '休んでよかった。');
      await tester.pumpAndSettle();

      expect(assistant.callCount, 0);
    });

    testWidgets('デモの実装であることを、控えめに伝える', (tester) async {
      await pumpRecordPage(
        tester,
        repository: InMemoryInsightRepository(),
        assistant: RecordingThinkingAssistant(),
      );

      expect(find.byKey(thinkingDemoNoticeKey), findsOneWidget);
      expect(find.text('AI思考サポート デモ'), findsOneWidget);
    });

    testWidgets('デモでない実装では、デモの断り書きを出さない', (tester) async {
      await pumpRecordPage(
        tester,
        repository: InMemoryInsightRepository(),
        assistant: RecordingThinkingAssistant(isDemo: false),
      );

      expect(find.byKey(thinkingDemoNoticeKey), findsNothing);
      expect(find.text('AI思考サポート デモ'), findsNothing);
    });

    testWidgets('Humanが押したときだけ、選んだ振り返りの言葉だけをAIへ渡す', (tester) async {
      final repository = InMemoryInsightRepository();
      final assistant = RecordingThinkingAssistant();

      await pumpRecordPage(
        tester,
        repository: repository,
        assistant: assistant,
        reflectionEntry: createReflectionEntry(
          id: 'reflection-42',
          feelingText: '思ったより疲れていた',
          noticedText: '休んだことで少し気持ちが軽くなった',
        ),
      );

      await tapByKey(tester, thinkingButtonKey);

      expect(assistant.callCount, 1);

      final request = assistant.receivedRequests.single;

      // 渡ったのは、Humanが選んだその振り返りの言葉だけ。
      expect(request.reflectionEntryId, 'reflection-42');
      expect(request.feelingText, '思ったより疲れていた');
      expect(request.noticedText, '休んだことで少し気持ちが軽くなった');

      // 呼んだだけでは、気づきは1件も保存されない。
      expect(await readEntries(repository), isEmpty);
    });

    testWidgets('考えるためのヒントとして、問い・別の見方・可能性を表示する', (tester) async {
      final repository = InMemoryInsightRepository();

      await pumpRecordPage(
        tester,
        repository: repository,
        assistant: RecordingThinkingAssistant(result: createSupport()),
      );

      await tapByKey(tester, thinkingButtonKey);

      expect(find.byKey(thinkingSupportKey), findsOneWidget);
      expect(find.text('考えるためのヒント'), findsOneWidget);
      expect(find.text('問い'), findsOneWidget);
      expect(find.text('A の問い'), findsOneWidget);
      expect(find.text('別の見方'), findsOneWidget);
      expect(find.text('A の別の見方'), findsOneWidget);
      expect(find.text('可能性'), findsOneWidget);
      expect(find.text('A の可能性'), findsOneWidget);

      // 気づきの入力欄は、AIの言葉で勝手に埋まらない。
      expect(
        tester.widget<TextField>(find.byKey(insightFieldKey)).controller?.text,
        '',
      );

      // AIの言葉だけでは、気づきは保存されない。
      expect(await readEntries(repository), isEmpty);
    });

    testWidgets('AIの言葉を読んだあとも、気づきを残すのはHuman自身', (tester) async {
      final repository = InMemoryInsightRepository();

      await pumpRecordPage(
        tester,
        repository: repository,
        assistant: RecordingThinkingAssistant(),
      );

      await tapByKey(tester, thinkingButtonKey);

      expect(await readEntries(repository), isEmpty);

      await tester.enterText(find.byKey(insightFieldKey), '休むことも前に進むために必要。');
      await tester.pumpAndSettle();

      expect(await readEntries(repository), isEmpty);

      await tapByKey(tester, saveButtonKey);

      final entry = (await readEntries(repository)).single;

      // 残るのはHumanが書いた言葉だけで、AIの言葉は混ざらない。
      expect(entry.insightText, '休むことも前に進むために必要。');
      expect(entry.insightText.contains('の問い'), isFalse);
      expect(entry.insightText.contains('の別の見方'), isFalse);
    });

    testWidgets('AIを使わなくても、これまでどおり気づきを残せる', (tester) async {
      final repository = InMemoryInsightRepository();
      final assistant = RecordingThinkingAssistant();

      await pumpRecordPage(
        tester,
        repository: repository,
        assistant: assistant,
      );

      await tester.enterText(find.byKey(insightFieldKey), '休んでよかった。');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect((await readEntries(repository)).single.insightText, '休んでよかった。');
      expect(assistant.callCount, 0);
    });

    testWidgets('考えている間は、続けて頼めない', (tester) async {
      final assistant = GatedThinkingAssistant();

      await pumpRecordPage(
        tester,
        repository: InMemoryInsightRepository(),
        assistant: assistant,
      );

      // 考えている間は表示がアニメーションするため、pumpAndSettleは使わない。
      await tester.tap(find.byKey(thinkingButtonKey));
      await tester.pump();

      expect(assistant.callCount, 1);
      expect(assistant.isPending(0), isTrue);

      expect(find.text('一緒に考えています…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(isButtonEnabled(tester, thinkingButtonKey), isFalse);

      // 気づきの入力は止めない。AIと保存は別の操作である。
      expect(isFieldEnabled(tester, insightFieldKey), isTrue);

      assistant.results[0] = createSupport();
      assistant.release(0);

      await tester.pumpAndSettle();

      expect(assistant.callCount, 1);
      expect(find.text('A の問い'), findsOneWidget);
      expect(find.text('もう一度一緒に考える'), findsOneWidget);
      expect(isButtonEnabled(tester, thinkingButtonKey), isTrue);
    });

    testWidgets('AIと一緒に考えられなくても、気づきは残せる', (tester) async {
      final repository = InMemoryInsightRepository();
      final assistant = RecordingThinkingAssistant(failingCallCount: 1);

      await pumpRecordPage(
        tester,
        repository: repository,
        assistant: assistant,
      );

      await tapByKey(tester, thinkingButtonKey);

      expect(assistant.callCount, 1);
      expect(find.byType(InsightRecordPage), findsOneWidget);
      expect(
        find.text('今はAIと一緒に考えることができませんでした。自分の言葉で気づきを残すことはできます。'),
        findsOneWidget,
      );

      // 振り返りの内容も、気づきの入力も、保存もそのまま使える。
      expect(find.text('元の振り返り'), findsOneWidget);
      expect(find.text('思ったより疲れていた'), findsOneWidget);
      expect(isFieldEnabled(tester, insightFieldKey), isTrue);
      expect(isButtonEnabled(tester, saveButtonKey), isTrue);
      expect(await readEntries(repository), isEmpty);

      // Humanが望めば、もう一度頼める。
      expect(isButtonEnabled(tester, thinkingButtonKey), isTrue);

      await tapByKey(tester, thinkingButtonKey);

      expect(assistant.callCount, 2);
      expect(find.byKey(thinkingSupportKey), findsOneWidget);
      expect(find.text('A の問い'), findsOneWidget);

      // AIが失敗していた間も、気づきはHumanの操作でそのまま残せる。
      await tester.enterText(find.byKey(insightFieldKey), '休んでよかった。');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect((await readEntries(repository)).single.insightText, '休んでよかった。');
    });

    testWidgets('AIが失敗しても、Humanだけで気づきを残せる', (tester) async {
      final repository = InMemoryInsightRepository();

      await pumpRecordPage(
        tester,
        repository: repository,
        assistant: RecordingThinkingAssistant(failingCallCount: 5),
      );

      await tapByKey(tester, thinkingButtonKey);

      await tester.enterText(find.byKey(insightFieldKey), '休んでよかった。');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect(find.byType(InsightRecordPage), findsNothing);
      expect((await readEntries(repository)).single.insightText, '休んでよかった。');
    });

    testWidgets('すばやく二度押しても、頼むのは一度だけ', (tester) async {
      final assistant = GatedThinkingAssistant();

      await pumpRecordPage(
        tester,
        repository: InMemoryInsightRepository(),
        assistant: assistant,
      );

      final button = find.byKey(thinkingButtonKey);

      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      // 同じフレームのうちに二度押される。
      // 画面はまだ作り直されていないので、ボタンは見た目上まだ押せる。
      await tester.tap(button);
      await tester.tap(button);
      await tester.pump();

      // それでも、AIへ頼むのは一度だけ。
      expect(assistant.callCount, 1);
      expect(assistant.isPending(0), isTrue);

      expect(find.text('一緒に考えています…'), findsOneWidget);
      expect(isButtonEnabled(tester, thinkingButtonKey), isFalse);

      assistant.results[0] = createSupport(label: 'A');
      assistant.release(0);

      await tester.pumpAndSettle();

      // 待っていた一度分の答えだけが返り、余分な依頼は残っていない。
      expect(assistant.callCount, 1);
      expect(find.text('A の問い'), findsOneWidget);
      expect(find.text('A の別の見方'), findsOneWidget);
    });

    testWidgets('失敗のあとにもう一度頼めて、そのときは新しい結果だけが残る', (tester) async {
      final assistant = GatedThinkingAssistant();

      await pumpRecordPage(
        tester,
        repository: InMemoryInsightRepository(),
        assistant: assistant,
      );

      final button = find.byKey(thinkingButtonKey);

      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      // 1回目は失敗として終わる。
      assistant.failingCalls.add(0);

      await tester.tap(button);
      await tester.pump();

      expect(assistant.callCount, 1);

      assistant.release(0);

      await tester.pumpAndSettle();

      expect(
        find.text('今はAIと一緒に考えることができませんでした。自分の言葉で気づきを残すことはできます。'),
        findsOneWidget,
      );

      // 失敗しても行き止まりにならず、Humanの操作でもう一度頼める。
      expect(isButtonEnabled(tester, thinkingButtonKey), isTrue);

      await tester.tap(button);
      await tester.pump();

      // 増えるのはちょうど1回分。
      expect(assistant.callCount, 2);
      expect(assistant.isPending(1), isTrue);

      assistant.results[1] = createSupport(label: 'B');
      assistant.release(1);

      await tester.pumpAndSettle();

      // 新しい結果だけが残り、前の失敗の知らせは消える。
      expect(find.text('B の問い'), findsOneWidget);
      expect(
        find.text('今はAIと一緒に考えることができませんでした。自分の言葉で気づきを残すことはできます。'),
        findsNothing,
      );
    });

    testWidgets('一度考えたあとでも、Humanが望めばもう一度頼める', (tester) async {
      final assistant = GatedThinkingAssistant();

      await pumpRecordPage(
        tester,
        repository: InMemoryInsightRepository(),
        assistant: assistant,
      );

      final button = find.byKey(thinkingButtonKey);

      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      await tester.tap(button);
      await tester.pump();

      assistant.results[0] = createSupport(label: 'A');
      assistant.release(0);

      await tester.pumpAndSettle();

      expect(assistant.callCount, 1);
      expect(find.text('A の問い'), findsOneWidget);
      expect(find.text('もう一度一緒に考える'), findsOneWidget);
      expect(isButtonEnabled(tester, thinkingButtonKey), isTrue);

      // 終わったあとの、Humanの明示的な頼み直しは止めない。
      await tester.tap(button);
      await tester.pump();

      expect(assistant.callCount, 2);

      assistant.results[1] = createSupport(label: 'B');
      assistant.release(1);

      await tester.pumpAndSettle();

      expect(find.text('B の問い'), findsOneWidget);
      expect(find.text('A の問い'), findsNothing);
    });

    testWidgets('考えている間に画面を離れても、あとから壊れない', (tester) async {
      final repository = InMemoryInsightRepository();
      final assistant = GatedThinkingAssistant();

      await pumpRecordPage(
        tester,
        repository: repository,
        assistant: assistant,
      );

      await tester.tap(find.byKey(thinkingButtonKey));
      await tester.pump();

      expect(assistant.isPending(0), isTrue);

      // 考えている途中でも、Humanは画面を離れられる。
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(InsightRecordPage), findsNothing);

      assistant.results[0] = createSupport();
      assistant.release(0);

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // 離れたあとに、勝手に何かが残ることもない。
      expect(await readEntries(repository), isEmpty);
    });
  });
}
