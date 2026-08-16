import 'dart:async';

import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_outcome.dart';
import 'package:ai_life_partner/features/reflection/data/in_memory_reflection_repository.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:ai_life_partner/features/reflection/domain/repositories/reflection_repository.dart';
import 'package:ai_life_partner/features/reflection/presentation/reflection_record_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String humanId = 'local-human';
const String plannedActionText = '30分トレーニングする';

const Key feelingFieldKey = Key('reflection_record_feeling_field');
const Key noticedFieldKey = Key('reflection_record_noticed_field');
const Key saveButtonKey = Key('reflection_record_save_button');
const Key cancelButtonKey = Key('reflection_record_cancel_button');

JourneyEntry createJourneyEntry({
  String id = 'journey-1',
  String humanId = 'local-human',
  JourneyOutcome outcome = JourneyOutcome.partial,
  String? actualActionText,
  String? note,
}) {
  final occurredAt = DateTime.now();

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

/// 振り返りの保存結果を受け取るための入れ物。
class ResultHolder {
  ReflectionEntry? value;
}

Future<ResultHolder> pumpRecordPage(
  WidgetTester tester, {
  required ReflectionRepository repository,
  JourneyEntry? journeyEntry,
  String reflectingHumanId = humanId,
}) async {
  final holder = ResultHolder();
  final entry = journeyEntry ?? createJourneyEntry();

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
                  holder.value = await Navigator.of(context)
                      .push<ReflectionEntry>(
                        MaterialPageRoute<ReflectionEntry>(
                          builder: (context) => ReflectionRecordPage(
                            repository: repository,
                            humanId: reflectingHumanId,
                            journeyEntry: entry,
                          ),
                        ),
                      );
                },
                child: const Text('振り返りへ'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('振り返りへ'));
  await tester.pumpAndSettle();

  expect(find.byType(ReflectionRecordPage), findsOneWidget);

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

Future<List<ReflectionEntry>> readEntries(ReflectionRepository repository) {
  final now = DateTime.now();

  return repository.getEntries(
    humanId: humanId,
    rangeStart: DateTime(now.year, now.month, now.day),
    rangeEnd: DateTime(now.year, now.month, now.day + 1),
  );
}

/// 保存だけが待機するReflection Repository。
class SlowSaveReflectionRepository implements ReflectionRepository {
  final InMemoryReflectionRepository _inner = InMemoryReflectionRepository();

  final Completer<void> _saveGate = Completer<void>();

  void completeSave() {
    if (!_saveGate.isCompleted) {
      _saveGate.complete();
    }
  }

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
  }) {
    return _inner.getEntryForJourney(
      humanId: humanId,
      journeyEntryId: journeyEntryId,
    );
  }

  @override
  Future<void> saveEntry(ReflectionEntry entry) async {
    await _saveGate.future;

    await _inner.saveEntry(entry);
  }
}

/// 1回目のsaveEntryだけ失敗するReflection Repository。
class FlakySaveReflectionRepository implements ReflectionRepository {
  final InMemoryReflectionRepository _inner = InMemoryReflectionRepository();

  /// saveEntryが呼ばれたときのReflection ID。失敗した試行も含む。
  final List<String> attemptedIds = <String>[];

  /// 実際に保存まで届いたReflection ID。
  final List<String> savedIds = <String>[];

  int saveAttempts = 0;

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
  }) {
    return _inner.getEntryForJourney(
      humanId: humanId,
      journeyEntryId: journeyEntryId,
    );
  }

  @override
  Future<void> saveEntry(ReflectionEntry entry) async {
    saveAttempts += 1;

    attemptedIds.add(entry.id);

    if (saveAttempts == 1) {
      throw StateError('振り返りを保存できませんでした');
    }

    await _inner.saveEntry(entry);

    savedIds.add(entry.id);
  }
}

/// 1回目のsaveEntryだけ、保存を済ませてから失敗するReflection Repository。
///
/// Supabaseなどで「保存は届いたが、その結果を受け取れなかった」状況を再現する。
/// Humanには失敗に見えるが、実際にはRepositoryへ残っている。
class CommitThenFailReflectionRepository implements ReflectionRepository {
  final InMemoryReflectionRepository _inner = InMemoryReflectionRepository();

  final List<String> savedIds = <String>[];

  int saveAttempts = 0;

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
  }) {
    return _inner.getEntryForJourney(
      humanId: humanId,
      journeyEntryId: journeyEntryId,
    );
  }

  @override
  Future<void> saveEntry(ReflectionEntry entry) async {
    saveAttempts += 1;

    await _inner.saveEntry(entry);

    savedIds.add(entry.id);

    if (saveAttempts == 1) {
      throw StateError('保存の結果を受け取れませんでした');
    }
  }
}

void main() {
  group('ReflectionRecordPage', () {
    testWidgets('振り返る対象の歩みが、そのまま読める', (tester) async {
      await pumpRecordPage(
        tester,
        repository: InMemoryReflectionRepository(),
        journeyEntry: createJourneyEntry(note: '思ったより疲れていた'),
      );

      expect(find.text('今日の一歩'), findsOneWidget);
      expect(find.text(plannedActionText), findsOneWidget);
      expect(find.text('歩み'), findsOneWidget);
      expect(find.text('少し取り組んだ'), findsOneWidget);
      expect(find.text('ひとこと'), findsOneWidget);
      expect(find.text('思ったより疲れていた'), findsOneWidget);
    });

    testWidgets('聞くのは二つの問いだけ', (tester) async {
      await pumpRecordPage(tester, repository: InMemoryReflectionRepository());

      expect(find.text('今、どんな感じですか？'), findsOneWidget);
      expect(find.text('この歩みから、何か気づいたことはありますか？'), findsOneWidget);
      expect(find.text('どちらか一つだけでも残せます。'), findsOneWidget);

      // 入力欄も二つだけ。
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('できなかった理由や改善点を尋ねない', (tester) async {
      await pumpRecordPage(tester, repository: InMemoryReflectionRepository());

      const forbidden = <String>[
        'なぜ',
        '原因',
        '改善',
        '反省',
        '評価',
        '採点',
        '点数',
        'スコア',
        '達成',
        '成功',
        '失敗',
        'できなかった',
        '何が悪かった',
      ];

      for (final word in forbidden) {
        expect(
          find.textContaining(word),
          findsNothing,
          reason: '$word はReflectionでは問わない',
        );
      }
    });

    testWidgets('感じたことだけでも残せる', (tester) async {
      final repository = InMemoryReflectionRepository();

      final holder = await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(feelingFieldKey), '少し肩の力が抜けた');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect(find.byType(ReflectionRecordPage), findsNothing);

      final entry = (await readEntries(repository)).single;

      expect(entry.journeyEntryId, 'journey-1');
      expect(entry.feelingText, '少し肩の力が抜けた');
      expect(entry.noticedText, isNull);

      expect(holder.value?.id, entry.id);
    });

    testWidgets('気づいたことだけでも残せる', (tester) async {
      final repository = InMemoryReflectionRepository();

      await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(noticedFieldKey), '朝のほうが動きやすいみたいだ');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      final entry = (await readEntries(repository)).single;

      expect(entry.feelingText, isNull);
      expect(entry.noticedText, '朝のほうが動きやすいみたいだ');
    });

    testWidgets('両方書いた場合は、どちらも残る', (tester) async {
      final repository = InMemoryReflectionRepository();

      await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(feelingFieldKey), '少し肩の力が抜けた');
      await tester.enterText(find.byKey(noticedFieldKey), '朝のほうが動きやすいみたいだ');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      final entry = (await readEntries(repository)).single;

      expect(entry.feelingText, '少し肩の力が抜けた');
      expect(entry.noticedText, '朝のほうが動きやすいみたいだ');
    });

    testWidgets('どちらも空のままでは保存せず、責めずに伝える', (tester) async {
      final repository = InMemoryReflectionRepository();

      await pumpRecordPage(tester, repository: repository);

      await tapByKey(tester, saveButtonKey);

      expect(find.byType(ReflectionRecordPage), findsOneWidget);
      expect(find.text('感じたことか気づいたことか、どちらかを残してください。'), findsOneWidget);
      expect(await readEntries(repository), isEmpty);

      // 書き始めれば、案内は消える。
      await tester.enterText(find.byKey(feelingFieldKey), 'まだ落ち着かない');
      await tester.pumpAndSettle();

      expect(find.text('感じたことか気づいたことか、どちらかを残してください。'), findsNothing);
    });

    testWidgets('空白だけの入力では保存しない', (tester) async {
      final repository = InMemoryReflectionRepository();

      await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(feelingFieldKey), '   ');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect(find.byType(ReflectionRecordPage), findsOneWidget);
      expect(await readEntries(repository), isEmpty);
    });

    testWidgets('キャンセルでは振り返りを残さない', (tester) async {
      final repository = InMemoryReflectionRepository();

      final holder = await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(feelingFieldKey), '少し肩の力が抜けた');
      await tester.pumpAndSettle();

      await tapByKey(tester, cancelButtonKey);

      expect(find.byType(ReflectionRecordPage), findsNothing);
      expect(holder.value, isNull);
      expect(await readEntries(repository), isEmpty);
    });

    testWidgets('戻る操作でも振り返りを残さない', (tester) async {
      final repository = InMemoryReflectionRepository();

      final holder = await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(feelingFieldKey), '少し肩の力が抜けた');
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(ReflectionRecordPage), findsNothing);
      expect(holder.value, isNull);
      expect(await readEntries(repository), isEmpty);
    });

    testWidgets('休んだ日も、同じ問いだけで振り返れる', (tester) async {
      final repository = InMemoryReflectionRepository();

      await pumpRecordPage(
        tester,
        repository: repository,
        journeyEntry: createJourneyEntry(outcome: JourneyOutcome.rested),
      );

      expect(find.text('今日は休んだ'), findsOneWidget);
      expect(find.text('今、どんな感じですか？'), findsOneWidget);
      expect(find.text('この歩みから、何か気づいたことはありますか？'), findsOneWidget);

      // 休んだ理由の説明は求めない。
      expect(find.textContaining('理由'), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.enterText(find.byKey(feelingFieldKey), '休んだら少し楽になった');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      final entry = (await readEntries(repository)).single;

      expect(entry.feelingText, '休んだら少し楽になった');
    });

    testWidgets('別の一歩になった日は、実際の一歩も一緒に読める', (tester) async {
      final repository = InMemoryReflectionRepository();

      await pumpRecordPage(
        tester,
        repository: repository,
        journeyEntry: createJourneyEntry(
          outcome: JourneyOutcome.changed,
          actualActionText: '家族との時間を優先した',
        ),
      );

      expect(find.text('別の一歩になった'), findsOneWidget);
      expect(find.text('実際の一歩'), findsOneWidget);
      expect(find.text('家族との時間を優先した'), findsOneWidget);

      // 変えたことの説明を追加で求めない。
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.enterText(find.byKey(noticedFieldKey), '予定を変えても進めた');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect((await readEntries(repository)).single.noticedText, '予定を変えても進めた');
    });
  });

  group('ReflectionRecordPage Humanの境界', () {
    testWidgets('別のHumanの歩みには、振り返りを始められない', (tester) async {
      final repository = InMemoryReflectionRepository();

      final holder = await pumpRecordPage(
        tester,
        repository: repository,
        journeyEntry: createJourneyEntry(
          humanId: 'other-human',
          note: '他のHumanのひとこと',
        ),
      );

      expect(
        find.byKey(const Key('reflection_record_unavailable')),
        findsOneWidget,
      );
      expect(find.text('この歩みを振り返ることができません。'), findsOneWidget);

      // 入力も保存もできない。
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(feelingFieldKey), findsNothing);
      expect(find.byKey(noticedFieldKey), findsNothing);
      expect(find.byKey(saveButtonKey), findsNothing);

      // 別のHumanの歩みの内容も見せない。
      expect(find.text(plannedActionText), findsNothing);
      expect(find.text('他のHumanのひとこと'), findsNothing);
      expect(find.text('少し取り組んだ'), findsNothing);

      await tapByKey(tester, const Key('reflection_record_close_button'));

      expect(find.byType(ReflectionRecordPage), findsNothing);
      expect(holder.value, isNull);
      expect(await readEntries(repository), isEmpty);
    });

    testWidgets('自分の歩みであれば、これまでどおり振り返れる', (tester) async {
      final repository = InMemoryReflectionRepository();

      await pumpRecordPage(
        tester,
        repository: repository,
        journeyEntry: createJourneyEntry(humanId: humanId),
      );

      expect(
        find.byKey(const Key('reflection_record_unavailable')),
        findsNothing,
      );
      expect(find.byType(TextField), findsNWidgets(2));
    });
  });

  group('ReflectionRecordPage 保存中', () {
    testWidgets('保存中は入力も操作も受け付けない', (tester) async {
      final repository = SlowSaveReflectionRepository();

      await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(feelingFieldKey), '保存前の言葉');
      await tester.pumpAndSettle();

      // 保存中は表示がアニメーションし続けるため、pumpAndSettleは使わない。
      await tester.tap(find.byKey(saveButtonKey));
      await tester.pump();

      expect(find.text('保存しています…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      expect(isFieldEnabled(tester, feelingFieldKey), isFalse);
      expect(isFieldEnabled(tester, noticedFieldKey), isFalse);
      expect(isButtonEnabled(tester, saveButtonKey), isFalse);
      expect(isButtonEnabled(tester, cancelButtonKey), isFalse);

      // 戻る操作でも離れられない。
      await tester.pageBack();
      await tester.pump();

      expect(find.byType(ReflectionRecordPage), findsOneWidget);

      repository.completeSave();

      await tester.pumpAndSettle();

      expect(find.byType(ReflectionRecordPage), findsNothing);

      final entry = (await readEntries(repository)).single;

      expect(entry.feelingText, '保存前の言葉');
    });

    testWidgets('保存に失敗しても閉じず、もう一度操作できる', (tester) async {
      final repository = FlakySaveReflectionRepository();

      final holder = await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(feelingFieldKey), '少し肩の力が抜けた');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect(repository.saveAttempts, 1);

      expect(find.byType(ReflectionRecordPage), findsOneWidget);
      expect(find.text('振り返りを保存できませんでした。もう一度お試しください。'), findsOneWidget);
      expect(await readEntries(repository), isEmpty);

      // 保存中の表示は解除され、すべて操作できる状態に戻る。
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(isFieldEnabled(tester, feelingFieldKey), isTrue);
      expect(isFieldEnabled(tester, noticedFieldKey), isTrue);
      expect(isButtonEnabled(tester, saveButtonKey), isTrue);
      expect(isButtonEnabled(tester, cancelButtonKey), isTrue);

      // 書いた言葉はそのまま残っていて、もう一度保存できる。
      await tapByKey(tester, saveButtonKey);

      expect(repository.saveAttempts, 2);
      expect(find.byType(ReflectionRecordPage), findsNothing);

      final entry = (await readEntries(repository)).single;

      expect(entry.feelingText, '少し肩の力が抜けた');
      expect(holder.value?.id, entry.id);
    });

    testWidgets('保存が届いたか分からない場合も、同じ振り返りとしてやり直せる', (tester) async {
      final repository = CommitThenFailReflectionRepository();

      final holder = await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(feelingFieldKey), '少し肩の力が抜けた');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      // Humanには保存できなかったように見える。
      expect(repository.saveAttempts, 1);
      expect(find.byType(ReflectionRecordPage), findsOneWidget);
      expect(find.text('振り返りを保存できませんでした。もう一度お試しください。'), findsOneWidget);

      // 実際にはRepositoryへ届いていた。
      final afterFirst = (await readEntries(repository)).single;

      final firstId = afterFirst.id;
      final firstReflectedAt = afterFirst.reflectedAt;

      // 書き足してから、もう一度残す。
      await tester.enterText(find.byKey(noticedFieldKey), '朝のほうが動きやすいみたいだ');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect(repository.saveAttempts, 2);
      expect(find.byType(ReflectionRecordPage), findsNothing);

      // 同じ振り返りのやり直しなので、新しいIDを作らない。
      expect(repository.savedIds, <String>[firstId, firstId]);

      final entries = await readEntries(repository);

      expect(entries, hasLength(1));
      expect(entries.single.id, firstId);
      expect(entries.single.feelingText, '少し肩の力が抜けた');
      expect(entries.single.noticedText, '朝のほうが動きやすいみたいだ');

      // 作成の身元は最初のままで、書き直した時刻だけが進む。
      expect(entries.single.reflectedAt, firstReflectedAt);
      expect(entries.single.createdAt, firstReflectedAt);
      expect(
        entries.single.updatedAt.isBefore(firstReflectedAt),
        isFalse,
        reason: '書き直した時刻が、作成時刻より前に戻ることはない',
      );

      expect(holder.value?.id, firstId);
    });

    testWidgets('保存前に失敗した場合も、やり直しは同じ振り返りとして扱う', (tester) async {
      final repository = FlakySaveReflectionRepository();

      await pumpRecordPage(tester, repository: repository);

      await tester.enterText(find.byKey(feelingFieldKey), '少し肩の力が抜けた');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect(repository.savedIds, <String>[]);

      await tapByKey(tester, saveButtonKey);

      // 2回の試行は、同じ振り返りのIDで行われている。
      expect(repository.attemptedIds, hasLength(2));
      expect(repository.attemptedIds.first, repository.attemptedIds.last);

      final entries = await readEntries(repository);

      expect(entries, hasLength(1));
      expect(entries.single.id, repository.attemptedIds.first);
    });
  });
}
