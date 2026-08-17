import 'dart:async';

import 'package:ai_life_partner/features/insight/data/in_memory_insight_repository.dart';
import 'package:ai_life_partner/features/insight/domain/models/insight_entry.dart';
import 'package:ai_life_partner/features/insight/domain/repositories/insight_repository.dart';
import 'package:ai_life_partner/features/insight/presentation/insight_record_page.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String humanId = 'local-human';

const Key insightFieldKey = Key('insight_record_text_field');
const Key saveButtonKey = Key('insight_record_save_button');
const Key cancelButtonKey = Key('insight_record_cancel_button');

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

      final holder = await pumpRecordPage(
        tester,
        repository: repository,
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

      // 別のHumanの振り返りの内容も見せない。
      expect(find.text('他のHumanが感じたこと'), findsNothing);
      expect(find.text('他のHumanが気づいたこと'), findsNothing);
      expect(find.text('元の振り返り'), findsNothing);

      await tapByKey(tester, const Key('insight_record_close_button'));

      expect(find.byType(InsightRecordPage), findsNothing);
      expect(holder.value, isNull);
      expect(await readEntries(repository), isEmpty);
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
}
