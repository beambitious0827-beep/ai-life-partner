import 'package:ai_life_partner/features/calendar/domain/models/available_time_window.dart';
import 'package:ai_life_partner/features/next_step/presentation/calendar_availability.dart';
import 'package:ai_life_partner/features/next_step/presentation/next_step_page.dart';
import 'package:ai_life_partner/features/next_step/presentation/next_step_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Key windowKey(int index) {
  return Key('next_step_available_window_$index');
}

Key manualTimeKey(AvailableTime time) {
  return Key('next_step_manual_time_${time.name}');
}

AvailableTimeWindow window(
  int startHour,
  int startMinute,
  int endHour,
  int endMinute,
) {
  return AvailableTimeWindow(
    startAt: DateTime(2026, 8, 7, startHour, startMinute),
    endAt: DateTime(2026, 8, 7, endHour, endMinute),
  );
}

Future<void> pumpNextStep(
  WidgetTester tester, {
  List<AvailableTimeWindow> availableTimeWindows =
      const <AvailableTimeWindow>[],
  CalendarAvailability? availability,
  Future<CalendarAvailability> Function()? onReloadAvailability,
  List<String> selectedAreas = const <String>['トレーニング'],
  Map<String, String> goals = const <String, String>{},
}) async {
  tester.view.physicalSize = const Size(1400, 5000);
  tester.view.devicePixelRatio = 1.0;

  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: NextStepPage(
        displayName: 'Daishi',
        selectedAreas: selectedAreas,
        goals: goals,
        availability:
            availability ?? CalendarAvailability.loaded(availableTimeWindows),
        onReloadAvailability: onReloadAvailability,
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

Future<void> tapByText(WidgetTester tester, String text) async {
  final target = find.text(text);

  expect(target, findsOneWidget);

  await tester.ensureVisible(target);
  await tester.pumpAndSettle();

  await tester.tap(target);
  await tester.pumpAndSettle();
}

bool isWindowSelected(WidgetTester tester, int index) {
  return tester
      .widgetList(
        find.descendant(
          of: find.byKey(windowKey(index)),
          matching: find.byIcon(Icons.check_circle),
        ),
      )
      .isNotEmpty;
}

bool isManualTimeSelected(WidgetTester tester, AvailableTime time) {
  return tester.widget<ChoiceChip>(find.byKey(manualTimeKey(time))).selected;
}

Future<void> generateSuggestions(WidgetTester tester) async {
  await tapByText(tester, 'いつもどおり');
  await tapByText(tester, '今の状況から候補を考える');
}

/// NextStepPageの確定結果を受け取るための入れ物。
class ResultHolder {
  NextStepResult? value;
}

/// 確定結果を確認できるよう、呼び出し元の画面からNextStepPageを開く。
Future<ResultHolder> pumpNextStepWithHost(
  WidgetTester tester, {
  List<AvailableTimeWindow> availableTimeWindows =
      const <AvailableTimeWindow>[],
  CalendarAvailability? availability,
  List<String> selectedAreas = const <String>['トレーニング'],
  Map<String, String> goals = const <String, String>{},
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
                  holder.value = await Navigator.of(context)
                      .push<NextStepResult>(
                        MaterialPageRoute<NextStepResult>(
                          builder: (context) => NextStepPage(
                            displayName: 'Daishi',
                            selectedAreas: selectedAreas,
                            goals: goals,
                            availability:
                                availability ??
                                CalendarAvailability.loaded(
                                  availableTimeWindows,
                                ),
                          ),
                        ),
                      );
                },
                child: const Text('次の一歩へ'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('次の一歩へ'));
  await tester.pumpAndSettle();

  return holder;
}

/// 先頭の候補を選び、確認ダイアログまで通してActionを確定する。
Future<void> confirmFirstSuggestion(WidgetTester tester) async {
  await tapByKey(tester, const Key('next_step_suggestion_0'));

  await tapByText(tester, 'この一歩に決める');

  final confirmButton = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('この一歩に決める'),
  );

  expect(confirmButton, findsOneWidget);

  await tester.tap(confirmButton);
  await tester.pumpAndSettle();
}

void main() {
  group('NextStepPage カレンダーの空き時間', () {
    testWidgets('渡された空き時間が選択肢として表示される', (tester) async {
      await pumpNextStep(
        tester,
        availableTimeWindows: <AvailableTimeWindow>[
          window(6, 0, 9, 0),
          window(10, 30, 12, 0),
          window(18, 0, 20, 0),
        ],
      );

      expect(find.text('今日はいつ・どれくらい時間を使えますか？'), findsOneWidget);
      expect(find.text('カレンダーから見つかった空き時間'), findsOneWidget);

      expect(find.text('06:00 - 09:00'), findsOneWidget);
      expect(find.text('3時間'), findsOneWidget);

      expect(find.text('10:30 - 12:00'), findsOneWidget);
      expect(find.text('1時間30分'), findsOneWidget);

      expect(find.text('18:00 - 20:00'), findsOneWidget);
      expect(find.text('2時間'), findsOneWidget);

      // 空き時間を使うことは任意である、というHuman Firstの案内。
      expect(find.textContaining('空いている時間を使う必要はありません。'), findsOneWidget);

      // 手動の時間指定も残っている。
      for (final time in AvailableTime.values) {
        expect(find.byKey(manualTimeKey(time)), findsOneWidget);
      }
    });

    testWidgets('カレンダーの空き時間を選択できる', (tester) async {
      await pumpNextStep(
        tester,
        availableTimeWindows: <AvailableTimeWindow>[
          window(6, 0, 9, 0),
          window(10, 30, 12, 0),
        ],
      );

      expect(isWindowSelected(tester, 0), isFalse);

      await tapByKey(tester, windowKey(0));

      expect(isWindowSelected(tester, 0), isTrue);
      expect(isWindowSelected(tester, 1), isFalse);

      // 別の空き時間へ選び直せる。
      await tapByKey(tester, windowKey(1));

      expect(isWindowSelected(tester, 0), isFalse);
      expect(isWindowSelected(tester, 1), isTrue);
    });

    testWidgets('空き時間を選んだあとに手動時間を選ぶと、空き時間の選択が解除される', (tester) async {
      await pumpNextStep(
        tester,
        availableTimeWindows: <AvailableTimeWindow>[window(6, 0, 9, 0)],
      );

      await tapByKey(tester, windowKey(0));

      expect(isWindowSelected(tester, 0), isTrue);

      await tapByKey(tester, manualTimeKey(AvailableTime.thirtyMinutes));

      expect(isWindowSelected(tester, 0), isFalse);
      expect(isManualTimeSelected(tester, AvailableTime.thirtyMinutes), isTrue);
    });

    testWidgets('手動時間を選んだあとに空き時間を選ぶと、手動時間の選択が解除される', (tester) async {
      await pumpNextStep(
        tester,
        availableTimeWindows: <AvailableTimeWindow>[window(6, 0, 9, 0)],
      );

      await tapByKey(tester, manualTimeKey(AvailableTime.sixtyMinutes));

      expect(isManualTimeSelected(tester, AvailableTime.sixtyMinutes), isTrue);

      await tapByKey(tester, windowKey(0));

      expect(isManualTimeSelected(tester, AvailableTime.sixtyMinutes), isFalse);
      expect(isWindowSelected(tester, 0), isTrue);
    });

    testWidgets('空き時間の時間帯と、提案するActionの長さが候補文で区別される', (tester) async {
      await pumpNextStep(
        tester,
        availableTimeWindows: <AvailableTimeWindow>[window(14, 30, 16, 0)],
      );

      await tapByKey(tester, windowKey(0));

      // いつもどおり（medium）なので、提案するActionの長さは30分程度。
      await generateSuggestions(tester);

      expect(
        find.text('14:30〜16:00の空き時間の中で、無理のない範囲で30分程度トレーニングに取り組む'),
        findsOneWidget,
      );

      // 空き時間の長さ（1時間30分）は、そのままActionの長さにはならない。
      expect(find.textContaining('1時間30分程度'), findsNothing);
      expect(find.textContaining('1時間30分でできる'), findsNothing);
    });

    testWidgets('空き時間がない場合も手動の時間指定で候補を作れる', (tester) async {
      await pumpNextStep(tester);

      expect(
        find.textContaining('カレンダー上では、この時間帯に空いている時間が見つかりませんでした。'),
        findsOneWidget,
      );

      expect(find.byKey(windowKey(0)), findsNothing);
      expect(find.text('カレンダーから見つかった空き時間'), findsNothing);

      await tapByKey(tester, manualTimeKey(AvailableTime.sixtyMinutes));

      await generateSuggestions(tester);

      expect(find.text('無理のない範囲で、60分でできるトレーニングを1つ選んで行う'), findsOneWidget);
    });

    testWidgets('手動時間を選んだ場合の候補は、これまでと同じ内容になる', (tester) async {
      await pumpNextStep(
        tester,
        availableTimeWindows: <AvailableTimeWindow>[window(6, 0, 9, 0)],
      );

      await tapByKey(tester, manualTimeKey(AvailableTime.thirtyMinutes));

      await generateSuggestions(tester);

      expect(find.text('無理のない範囲で、30分でできるトレーニングを1つ選んで行う'), findsOneWidget);
      expect(find.text('体調を確認し、今日鍛える部位と最初の1種目を決める'), findsOneWidget);
      expect(find.text('ウォームアップを始め、終わった時点で続けるか判断する'), findsOneWidget);

      // 空き時間を選んでいないので、時間帯付きの候補は追加されない。
      expect(find.textContaining('の空き時間の中で'), findsNothing);
    });

    testWidgets('候補を選んでAction確定まで進める既存の流れが維持される', (tester) async {
      await pumpNextStep(tester);

      await tapByKey(tester, manualTimeKey(AvailableTime.tenMinutes));

      await generateSuggestions(tester);

      await tapByText(tester, '体調を確認し、今日鍛える部位と最初の1種目を決める');

      await tapByText(tester, 'この一歩に決める');

      expect(find.text('この一歩に決めますか？'), findsOneWidget);

      await tester.tap(find.text('もう一度考える'));
      await tester.pumpAndSettle();

      expect(find.text('この一歩に決めますか？'), findsNothing);
      expect(find.byType(NextStepPage), findsOneWidget);
    });
  });

  group('NextStepPage 長い空き時間', () {
    Future<void> pumpLongWindow(WidgetTester tester, String energyLabel) async {
      await pumpNextStep(
        tester,
        availableTimeWindows: <AvailableTimeWindow>[window(6, 0, 23, 0)],
      );

      // 空き時間の表示としては17時間で正しい。
      expect(find.text('06:00 - 23:00'), findsOneWidget);
      expect(find.text('17時間'), findsOneWidget);

      await tapByKey(tester, windowKey(0));

      await tapByText(tester, energyLabel);
      await tapByText(tester, '今の状況から候補を考える');
    }

    /// 17時間はAvailable Windowの表示にだけ現れ、
    /// Action候補のどこにも現れないことを確認する。
    ///
    /// Window全体をAction実行時間として扱っていないことの保証。
    void expectWindowLengthNotUsedAsActionDuration(WidgetTester tester) {
      expect(find.textContaining('17時間'), findsOneWidget);
      expect(find.byKey(windowKey(0)), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(windowKey(0)),
          matching: find.text('17時間'),
        ),
        findsOneWidget,
      );
    }

    testWidgets('17時間の空き時間でも、余力が少なければ10分程度を提案する', (tester) async {
      await pumpLongWindow(tester, '余力は少ない');

      expect(
        find.text('06:00〜23:00の空き時間の中で、負担を抑えて10分程度トレーニングに取り組む'),
        findsOneWidget,
      );

      expectWindowLengthNotUsedAsActionDuration(tester);
    });

    testWidgets('17時間の空き時間で、いつもどおりなら30分程度を提案する', (tester) async {
      await pumpLongWindow(tester, 'いつもどおり');

      expect(
        find.text('06:00〜23:00の空き時間の中で、無理のない範囲で30分程度トレーニングに取り組む'),
        findsOneWidget,
      );

      expectWindowLengthNotUsedAsActionDuration(tester);
    });

    testWidgets('17時間の空き時間で、余力があれば1時間程度を提案する', (tester) async {
      await pumpLongWindow(tester, '余力がある');

      // 60分はformatDurationLabelの表示方針にあわせて「1時間」と表す。
      // Calendar Available Time UIと同じ表記にそろえている。
      expect(
        find.text('06:00〜23:00の空き時間の中で、余力を活かして1時間程度トレーニングに取り組む'),
        findsOneWidget,
      );

      expectWindowLengthNotUsedAsActionDuration(tester);
    });

    testWidgets('空き時間が目安より短い場合は、空き時間の長さが上限になる', (tester) async {
      await pumpNextStep(
        tester,
        availableTimeWindows: <AvailableTimeWindow>[window(18, 0, 18, 20)],
      );

      await tapByKey(tester, windowKey(0));

      await tapByText(tester, '余力がある');
      await tapByText(tester, '今の状況から候補を考える');

      // 余力があっても余力の目安（1時間）は提案せず、20分を上限にする。
      expect(
        find.text('18:00〜18:20の空き時間の中で、余力を活かして20分程度トレーニングに取り組む'),
        findsOneWidget,
      );

      // 20分の空き時間なので、画面のどこにも「1時間」は現れない。
      // 手動指定の「60分」チップは常に表示されるため、ここでは対象にしない。
      expect(find.textContaining('1時間'), findsNothing);
    });
  });

  group('NextStepPage カレンダーを確認できなかった場合', () {
    testWidgets('取得失敗は、予定で埋まっている状態と区別して伝えられる', (tester) async {
      await pumpNextStep(
        tester,
        availability: const CalendarAvailability.failed(),
      );

      expect(find.textContaining('カレンダーを確認できませんでした。'), findsOneWidget);

      // 「確認したが空き時間がなかった」の文言は出さない。
      expect(find.textContaining('この時間帯に空いている時間が見つかりませんでした。'), findsNothing);
      expect(find.text('カレンダーから見つかった空き時間'), findsNothing);
    });

    testWidgets('取得失敗でも手動の時間指定で候補を作れる', (tester) async {
      await pumpNextStep(
        tester,
        availability: const CalendarAvailability.failed(),
      );

      for (final time in AvailableTime.values) {
        expect(find.byKey(manualTimeKey(time)), findsOneWidget);
      }

      await tapByKey(tester, manualTimeKey(AvailableTime.thirtyMinutes));

      await generateSuggestions(tester);

      expect(find.text('無理のない範囲で、30分でできるトレーニングを1つ選んで行う'), findsOneWidget);
    });

    testWidgets('「もう一度確認する」で空き時間を取り直せる', (tester) async {
      var reloadCount = 0;

      await pumpNextStep(
        tester,
        availability: const CalendarAvailability.failed(),
        onReloadAvailability: () async {
          reloadCount += 1;

          return CalendarAvailability.loaded(<AvailableTimeWindow>[
            window(10, 0, 12, 0),
          ]);
        },
      );

      await tapByKey(tester, const Key('next_step_reload_availability_button'));

      expect(reloadCount, 1);

      expect(find.textContaining('カレンダーを確認できませんでした。'), findsNothing);
      expect(find.text('カレンダーから見つかった空き時間'), findsOneWidget);
      expect(find.text('10:00 - 12:00'), findsOneWidget);
      expect(find.text('2時間'), findsOneWidget);
    });

    testWidgets('再試行の操作が渡されていない場合は再試行ボタンを出さない', (tester) async {
      await pumpNextStep(
        tester,
        availability: const CalendarAvailability.failed(),
      );

      expect(
        find.byKey(const Key('next_step_reload_availability_button')),
        findsNothing,
      );
    });
  });

  group('NextStepPage 確定結果', () {
    testWidgets('空き時間を選んで確定すると、結果に時間帯が残る', (tester) async {
      final selectedWindow = window(18, 0, 21, 0);

      final holder = await pumpNextStepWithHost(
        tester,
        availableTimeWindows: <AvailableTimeWindow>[selectedWindow],
      );

      await tapByKey(tester, windowKey(0));

      await generateSuggestions(tester);

      await confirmFirstSuggestion(tester);

      final result = holder.value;

      expect(result, isNotNull);
      expect(result!.actionText.isNotEmpty, isTrue);

      expect(result.usesCalendarWindow, isTrue);
      expect(result.selectedCalendarWindow, selectedWindow);
      expect(result.selectedCalendarWindow?.startAt, selectedWindow.startAt);
      expect(result.selectedCalendarWindow?.endAt, selectedWindow.endAt);
      expect(result.selectedCalendarWindow?.duration, const Duration(hours: 3));

      // 空き時間の長さ（3時間）ではなく、提案したActionの長さが残る。
      // generateSuggestionsは「いつもどおり」を選ぶので30分。
      expect(result.actionDuration, const Duration(minutes: 30));
    });

    testWidgets('空き時間が提案の目安より短い場合は、空き時間の長さが残る', (tester) async {
      final selectedWindow = window(18, 0, 18, 20);

      final holder = await pumpNextStepWithHost(
        tester,
        availableTimeWindows: <AvailableTimeWindow>[selectedWindow],
      );

      await tapByKey(tester, windowKey(0));

      await tapByText(tester, '余力がある');
      await tapByText(tester, '今の状況から候補を考える');

      await confirmFirstSuggestion(tester);

      final result = holder.value;

      expect(result, isNotNull);
      expect(result!.selectedCalendarWindow, selectedWindow);

      // 余力の目安は1時間だが、空き時間の20分を超えない。
      expect(result.actionDuration, const Duration(minutes: 20));
    });

    testWidgets('手動時間を選んで確定すると、結果に長さが残る', (tester) async {
      final holder = await pumpNextStepWithHost(
        tester,
        availableTimeWindows: <AvailableTimeWindow>[window(18, 0, 21, 0)],
      );

      await tapByKey(tester, manualTimeKey(AvailableTime.thirtyMinutes));

      await generateSuggestions(tester);

      await confirmFirstSuggestion(tester);

      final result = holder.value;

      expect(result, isNotNull);
      expect(result!.usesCalendarWindow, isFalse);
      expect(result.selectedCalendarWindow, isNull);
      expect(result.actionDuration, const Duration(minutes: 30));
    });

    testWidgets('「時間は調整できる」を選んだ場合は特定の長さを持たない', (tester) async {
      final holder = await pumpNextStepWithHost(tester);

      await tapByKey(tester, manualTimeKey(AvailableTime.flexible));

      await generateSuggestions(tester);

      await confirmFirstSuggestion(tester);

      final result = holder.value;

      expect(result, isNotNull);
      expect(result!.selectedCalendarWindow, isNull);

      // 存在しない長さを勝手に決めない。
      expect(result.actionDuration, isNull);
      expect(result.actionText.isNotEmpty, isTrue);
    });
  });
}
