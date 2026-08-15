import 'dart:async';

import 'package:ai_life_partner/features/journey/data/in_memory_journey_repository.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_outcome.dart';
import 'package:ai_life_partner/features/journey/domain/repositories/journey_repository.dart';
import 'package:ai_life_partner/features/journey/presentation/journey_record_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String humanId = 'local-human';
const String plannedActionText = '30分トレーニングする';

const Key saveButtonKey = Key('journey_record_save_button');
const Key cancelButtonKey = Key('journey_record_cancel_button');
const Key actualActionFieldKey = Key('journey_record_actual_action_field');
const Key noteFieldKey = Key('journey_record_note_field');

Key outcomeKey(JourneyOutcome outcome) {
  return Key('journey_record_outcome_${outcome.name}');
}

/// 記録結果を受け取るための入れ物。
class ResultHolder {
  JourneyEntry? value;
}

Future<ResultHolder> pumpRecordPage(
  WidgetTester tester, {
  required JourneyRepository repository,
  Duration? plannedDuration,
  String? sourceCalendarEventId,
}) async {
  final holder = ResultHolder();

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
                  holder.value = await Navigator.of(context).push<JourneyEntry>(
                    MaterialPageRoute<JourneyEntry>(
                      builder: (context) => JourneyRecordPage(
                        repository: repository,
                        humanId: humanId,
                        plannedActionText: plannedActionText,
                        plannedDuration: plannedDuration,
                        sourceCalendarEventId: sourceCalendarEventId,
                      ),
                    ),
                  );
                },
                child: const Text('歩みへ'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('歩みへ'));
  await tester.pumpAndSettle();

  expect(find.byType(JourneyRecordPage), findsOneWidget);

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

/// 保存だけが待機するJourney Repository。
///
/// Supabaseなどで保存に時間がかかる状況を再現するために使う。
class SlowSaveJourneyRepository implements JourneyRepository {
  final InMemoryJourneyRepository _inner = InMemoryJourneyRepository();

  final Completer<void> _saveGate = Completer<void>();

  void completeSave() {
    if (!_saveGate.isCompleted) {
      _saveGate.complete();
    }
  }

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
  Future<JourneyEntry?> getEntryById(String entryId) {
    return _inner.getEntryById(entryId);
  }

  @override
  Future<void> saveEntry(JourneyEntry entry) async {
    await _saveGate.future;

    await _inner.saveEntry(entry);
  }
}

/// 1回目のsaveEntryだけ失敗するJourney Repository。
class FlakySaveJourneyRepository implements JourneyRepository {
  final InMemoryJourneyRepository _inner = InMemoryJourneyRepository();

  int saveAttempts = 0;

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
  Future<JourneyEntry?> getEntryById(String entryId) {
    return _inner.getEntryById(entryId);
  }

  @override
  Future<void> saveEntry(JourneyEntry entry) async {
    saveAttempts += 1;

    if (saveAttempts == 1) {
      throw StateError('歩みを保存できませんでした');
    }

    await _inner.saveEntry(entry);
  }
}

/// その結果が選ばれているかどうか。
bool isOutcomeSelected(WidgetTester tester, JourneyOutcome outcome) {
  return tester
      .widgetList(
        find.descendant(
          of: find.byKey(outcomeKey(outcome)),
          matching: find.byIcon(Icons.check_circle),
        ),
      )
      .isNotEmpty;
}

/// その結果カードが操作できる状態かどうか。
bool isOutcomeTappable(WidgetTester tester, JourneyOutcome outcome) {
  final inkWell = tester.widget<InkWell>(
    find.descendant(
      of: find.byKey(outcomeKey(outcome)),
      matching: find.byType(InkWell),
    ),
  );

  return inkWell.onTap != null;
}

bool isFieldEnabled(WidgetTester tester, Key key) {
  return tester.widget<TextField>(find.byKey(key)).enabled ?? true;
}

Future<List<JourneyEntry>> readEntries(JourneyRepository repository) {
  final now = DateTime.now();

  return repository.getEntries(
    humanId: humanId,
    rangeStart: DateTime(now.year, now.month, now.day),
    rangeEnd: DateTime(now.year, now.month, now.day + 1),
  );
}

void main() {
  group('JourneyRecordPage', () {
    testWidgets('4つの結果から選べる', (tester) async {
      final repository = InMemoryJourneyRepository();

      await pumpRecordPage(tester, repository: repository);

      expect(find.text('その後、どうでしたか？'), findsOneWidget);
      expect(find.textContaining('どの結果も、その日の大切な歩みです。'), findsOneWidget);

      expect(find.text('できた'), findsOneWidget);
      expect(find.text('少し取り組んだ'), findsOneWidget);
      expect(find.text('別の一歩になった'), findsOneWidget);
      expect(find.text('今日は休んだ'), findsOneWidget);

      for (final outcome in JourneyOutcome.values) {
        expect(find.byKey(outcomeKey(outcome)), findsOneWidget);
      }

      // もとになった一歩が確認できる。
      expect(find.text(plannedActionText), findsOneWidget);
    });

    testWidgets('達成度や成功・失敗を表す言葉を使わない', (tester) async {
      await pumpRecordPage(tester, repository: InMemoryJourneyRepository());

      const forbidden = <String>[
        '失敗',
        '未達',
        '達成率',
        '成功率',
        '連続',
        'スコア',
        'ランキング',
      ];

      for (final word in forbidden) {
        expect(
          find.textContaining(word),
          findsNothing,
          reason: '$word はJourneyのUIでは使わない',
        );
      }
    });

    testWidgets('結果を選ばずに保存すると、選ぶよう促される', (tester) async {
      final repository = InMemoryJourneyRepository();

      await pumpRecordPage(tester, repository: repository);

      await tapByKey(tester, saveButtonKey);

      expect(find.text('その後どうだったかを、ひとつ選んでください。'), findsOneWidget);
      expect(find.byType(JourneyRecordPage), findsOneWidget);
      expect(await readEntries(repository), isEmpty);
    });

    testWidgets('「できた」を選んで歩みとして残せる', (tester) async {
      final repository = InMemoryJourneyRepository();

      final holder = await pumpRecordPage(
        tester,
        repository: repository,
        plannedDuration: const Duration(minutes: 30),
        sourceCalendarEventId: 'event-1',
      );

      await tapByKey(tester, outcomeKey(JourneyOutcome.completed));

      // 押すまでは保存しない。
      expect(await readEntries(repository), isEmpty);

      await tapByKey(tester, saveButtonKey);

      expect(find.byType(JourneyRecordPage), findsNothing);

      final entries = await readEntries(repository);

      expect(entries, hasLength(1));

      final entry = entries.single;

      expect(entry.outcome, JourneyOutcome.completed);
      expect(entry.plannedActionText, plannedActionText);
      expect(entry.humanId, humanId);
      expect(entry.plannedDuration, const Duration(minutes: 30));
      expect(entry.sourceCalendarEventId, 'event-1');
      expect(entry.actualActionText, isNull);
      expect(entry.note, isNull);

      // 保存したJourneyEntryが呼び出し元へ返る。
      expect(holder.value, isNotNull);
      expect(holder.value!.id, entry.id);
    });

    testWidgets('「今日は休んだ」もそのままの結果として残せる', (tester) async {
      final repository = InMemoryJourneyRepository();

      await pumpRecordPage(tester, repository: repository);

      await tapByKey(tester, outcomeKey(JourneyOutcome.rested));
      await tapByKey(tester, saveButtonKey);

      final entry = (await readEntries(repository)).single;

      expect(entry.outcome, JourneyOutcome.rested);
      expect(entry.outcome.label, '今日は休んだ');
    });

    testWidgets('「少し取り組んだ」も残せる', (tester) async {
      final repository = InMemoryJourneyRepository();

      await pumpRecordPage(tester, repository: repository);

      await tapByKey(tester, outcomeKey(JourneyOutcome.partial));
      await tapByKey(tester, saveButtonKey);

      final entry = (await readEntries(repository)).single;

      expect(entry.outcome, JourneyOutcome.partial);
    });

    testWidgets('「別の一歩になった」では、実際の一歩の入力を求める', (tester) async {
      final repository = InMemoryJourneyRepository();

      await pumpRecordPage(tester, repository: repository);

      // 選ぶまでは入力欄を出さない。
      expect(find.byKey(actualActionFieldKey), findsNothing);

      await tapByKey(tester, outcomeKey(JourneyOutcome.changed));

      expect(find.byKey(actualActionFieldKey), findsOneWidget);
      expect(find.text('どんな一歩になりましたか？'), findsOneWidget);

      // 空のままでは保存しない。
      await tapByKey(tester, saveButtonKey);

      expect(find.byType(JourneyRecordPage), findsOneWidget);
      expect(find.text('実際にどんな一歩になったか、ひとこと教えてください。'), findsOneWidget);
      expect(await readEntries(repository), isEmpty);

      // 入力すれば保存できる。
      await tester.enterText(find.byKey(actualActionFieldKey), '家族との時間を優先した');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect(find.byType(JourneyRecordPage), findsNothing);

      final entry = (await readEntries(repository)).single;

      expect(entry.outcome, JourneyOutcome.changed);
      expect(entry.actualActionText, '家族との時間を優先した');
    });

    testWidgets('ひとことは任意で、書いた場合は残る', (tester) async {
      final repository = InMemoryJourneyRepository();

      await pumpRecordPage(tester, repository: repository);

      await tapByKey(tester, outcomeKey(JourneyOutcome.partial));

      await tester.enterText(find.byKey(noteFieldKey), '10分だけでも始められた');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      final entry = (await readEntries(repository)).single;

      expect(entry.note, '10分だけでも始められた');
    });

    testWidgets('キャンセルでは歩みを残さない', (tester) async {
      final repository = InMemoryJourneyRepository();

      final holder = await pumpRecordPage(tester, repository: repository);

      await tapByKey(tester, outcomeKey(JourneyOutcome.completed));

      await tester.enterText(find.byKey(noteFieldKey), '残さないメモ');
      await tester.pumpAndSettle();

      await tapByKey(tester, cancelButtonKey);

      expect(find.byType(JourneyRecordPage), findsNothing);
      expect(await readEntries(repository), isEmpty);
      expect(holder.value, isNull);
    });

    testWidgets('戻る操作でも歩みを残さない', (tester) async {
      final repository = InMemoryJourneyRepository();

      final holder = await pumpRecordPage(tester, repository: repository);

      await tapByKey(tester, outcomeKey(JourneyOutcome.completed));

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(JourneyRecordPage), findsNothing);
      expect(await readEntries(repository), isEmpty);
      expect(holder.value, isNull);
    });

    testWidgets('保存直後に振り返りを求めない', (tester) async {
      final repository = InMemoryJourneyRepository();

      await pumpRecordPage(tester, repository: repository);

      await tapByKey(tester, outcomeKey(JourneyOutcome.rested));
      await tapByKey(tester, saveButtonKey);

      // Journeyは何が起きたかを残すだけ。Reflectionは別の責務。
      expect(find.textContaining('振り返'), findsNothing);
      expect(find.textContaining('なぜ'), findsNothing);
      expect(find.textContaining('反省'), findsNothing);
    });
  });

  group('JourneyRecordPage 結果を切り替えた場合', () {
    // 「別の一歩になった」以外では実際の一歩の欄が画面に出ないので、
    // 切り替え前の入力が保存されてはいけない。
    for (final outcome in <JourneyOutcome>[
      JourneyOutcome.completed,
      JourneyOutcome.partial,
      JourneyOutcome.rested,
    ]) {
      testWidgets('入力後に「${outcome.label}」へ変えると、実際の一歩は保存されない', (tester) async {
        final repository = InMemoryJourneyRepository();

        await pumpRecordPage(tester, repository: repository);

        await tapByKey(tester, outcomeKey(JourneyOutcome.changed));

        await tester.enterText(find.byKey(actualActionFieldKey), '散歩をした');
        await tester.pumpAndSettle();

        await tapByKey(tester, outcomeKey(outcome));

        // 入力欄は画面から消えている。
        expect(find.byKey(actualActionFieldKey), findsNothing);

        await tapByKey(tester, saveButtonKey);

        expect(find.byType(JourneyRecordPage), findsNothing);

        final entry = (await readEntries(repository)).single;

        expect(entry.outcome, outcome);
        expect(entry.actualActionText, isNull);
        expect(entry.hasActualActionText, isFalse);
      });
    }

    testWidgets('切り替え後に保存した歩みには、以前の入力が残らない', (tester) async {
      final repository = InMemoryJourneyRepository();

      await pumpRecordPage(tester, repository: repository);

      await tapByKey(tester, outcomeKey(JourneyOutcome.changed));

      await tester.enterText(find.byKey(actualActionFieldKey), '散歩をした');
      await tester.pumpAndSettle();

      await tapByKey(tester, outcomeKey(JourneyOutcome.rested));
      await tapByKey(tester, saveButtonKey);

      final entry = (await readEntries(repository)).single;

      expect(entry.outcome, JourneyOutcome.rested);
      expect(entry.actualActionText, isNull);

      // 保存された歩みのどこにも、以前の入力は含まれない。
      expect(entry.note, isNull);
      expect(entry.plannedActionText, plannedActionText);
    });

    testWidgets('「別の一歩になった」へ戻せば、入力し直して保存できる', (tester) async {
      final repository = InMemoryJourneyRepository();

      await pumpRecordPage(tester, repository: repository);

      await tapByKey(tester, outcomeKey(JourneyOutcome.changed));

      await tester.enterText(find.byKey(actualActionFieldKey), '散歩をした');
      await tester.pumpAndSettle();

      await tapByKey(tester, outcomeKey(JourneyOutcome.rested));
      await tapByKey(tester, outcomeKey(JourneyOutcome.changed));

      await tapByKey(tester, saveButtonKey);

      final entry = (await readEntries(repository)).single;

      expect(entry.outcome, JourneyOutcome.changed);
      expect(entry.actualActionText, '散歩をした');
    });
  });

  group('JourneyRecordPage 保存中', () {
    testWidgets('保存中は内容を変更できない', (tester) async {
      final repository = SlowSaveJourneyRepository();

      await pumpRecordPage(tester, repository: repository);

      await tapByKey(tester, outcomeKey(JourneyOutcome.partial));

      await tester.enterText(find.byKey(noteFieldKey), '保存前のひとこと');
      await tester.pumpAndSettle();

      // 保存中は表示がアニメーションし続けるため、pumpAndSettleは使わない。
      await tester.tap(find.byKey(saveButtonKey));
      await tester.pump();

      expect(find.text('保存しています…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 結果の選択も、ひとことの入力も受け付けない。
      for (final outcome in JourneyOutcome.values) {
        expect(isOutcomeTappable(tester, outcome), isFalse);
      }

      expect(isFieldEnabled(tester, noteFieldKey), isFalse);

      // 実際にタップしても選択は変わらない。
      await tester.tap(find.byKey(outcomeKey(JourneyOutcome.completed)));
      await tester.pump();

      expect(isOutcomeSelected(tester, JourneyOutcome.partial), isTrue);
      expect(isOutcomeSelected(tester, JourneyOutcome.completed), isFalse);

      // 戻る操作でも離れられない。
      await tester.pageBack();
      await tester.pump();

      expect(find.byType(JourneyRecordPage), findsOneWidget);

      // 保存が完了すれば、保存開始時点の内容がそのまま残る。
      repository.completeSave();

      await tester.pumpAndSettle();

      expect(find.byType(JourneyRecordPage), findsNothing);

      final entry = (await readEntries(repository)).single;

      expect(entry.outcome, JourneyOutcome.partial);
      expect(entry.note, '保存前のひとこと');
    });

    testWidgets('「別の一歩になった」の入力欄も保存中は変更できない', (tester) async {
      final repository = SlowSaveJourneyRepository();

      await pumpRecordPage(tester, repository: repository);

      await tapByKey(tester, outcomeKey(JourneyOutcome.changed));

      await tester.enterText(find.byKey(actualActionFieldKey), '散歩をした');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(saveButtonKey));
      await tester.pump();

      expect(isFieldEnabled(tester, actualActionFieldKey), isFalse);
      expect(isFieldEnabled(tester, noteFieldKey), isFalse);

      repository.completeSave();

      await tester.pumpAndSettle();

      final entry = (await readEntries(repository)).single;

      expect(entry.outcome, JourneyOutcome.changed);
      expect(entry.actualActionText, '散歩をした');
    });

    testWidgets('保存に失敗しても閉じず、もう一度操作できる', (tester) async {
      final repository = FlakySaveJourneyRepository();

      await pumpRecordPage(tester, repository: repository);

      await tapByKey(tester, outcomeKey(JourneyOutcome.partial));

      await tester.enterText(find.byKey(noteFieldKey), 'ひとこと');
      await tester.pumpAndSettle();

      await tapByKey(tester, saveButtonKey);

      expect(repository.saveAttempts, 1);

      // 記録画面に留まり、内容も残っている。
      expect(find.byType(JourneyRecordPage), findsOneWidget);
      expect(find.text('歩みを保存できませんでした。もう一度お試しください。'), findsOneWidget);
      expect(await readEntries(repository), isEmpty);

      // 保存中の表示は解除され、すべて操作できる状態に戻る。
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('歩みとして残す'), findsWidgets);

      for (final outcome in JourneyOutcome.values) {
        expect(isOutcomeTappable(tester, outcome), isTrue);
      }

      expect(isFieldEnabled(tester, noteFieldKey), isTrue);

      // 結果を選び直してから、もう一度保存できる。
      await tapByKey(tester, outcomeKey(JourneyOutcome.rested));

      await tapByKey(tester, saveButtonKey);

      expect(repository.saveAttempts, 2);
      expect(find.byType(JourneyRecordPage), findsNothing);

      final entry = (await readEntries(repository)).single;

      expect(entry.outcome, JourneyOutcome.rested);
      expect(entry.note, 'ひとこと');
    });
  });
}
