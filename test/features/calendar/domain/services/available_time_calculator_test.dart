import 'package:ai_life_partner/features/calendar/domain/models/ai_visibility.dart';
import 'package:ai_life_partner/features/calendar/domain/models/available_time_window.dart';
import 'package:ai_life_partner/features/calendar/domain/models/calendar_event.dart';
import 'package:ai_life_partner/features/calendar/domain/services/available_time_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

const AvailableTimeCalculator calculator = AvailableTimeCalculator();

/// 2026年8月7日の時刻を作る。24時を渡すと翌日の00:00になる。
DateTime at(int hour, [int minute = 0]) {
  return DateTime(2026, 8, 7, hour, minute);
}

CalendarEvent createEvent({
  required DateTime startAt,
  required DateTime endAt,
  String id = 'event-1',
  String title = '予定',
  bool isAllDay = false,
  AiVisibility aiVisibility = AiVisibility.busyOnly,
}) {
  final createdAt = DateTime(2026, 8, 1, 9);

  return CalendarEvent(
    id: id,
    humanId: 'local-human',
    title: title,
    startAt: startAt,
    endAt: endAt,
    isAllDay: isAllDay,
    aiVisibility: aiVisibility,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

AvailableTimeWindow window(DateTime startAt, DateTime endAt) {
  return AvailableTimeWindow(startAt: startAt, endAt: endAt);
}

List<AvailableTimeWindow> calculateForDay(
  List<CalendarEvent> events, {
  DateTime? rangeStart,
  DateTime? rangeEnd,
}) {
  return calculator.calculate(
    rangeStart: rangeStart ?? at(6),
    rangeEnd: rangeEnd ?? at(23),
    events: events,
  );
}

void main() {
  group('AvailableTimeWindow', () {
    test('durationは開始日時と終了日時の差になる', () {
      final availableTime = window(at(10), at(11, 30));

      expect(availableTime.duration, const Duration(hours: 1, minutes: 30));
      expect(availableTime.durationMinutes, 90);
    });

    test('終了日時が開始日時より後でない場合は作成できない', () {
      expect(() => window(at(10), at(10)), throwsA(isA<ArgumentError>()));

      expect(() => window(at(11), at(10)), throwsA(isA<ArgumentError>()));
    });

    test('同じ時間帯のAvailableTimeWindowは等しい', () {
      expect(window(at(10), at(11)), window(at(10), at(11)));
      expect(window(at(10), at(11)), isNot(window(at(10), at(12))));
    });
  });

  group('AvailableTimeCalculator', () {
    test('予定がない場合は対象時間全体が空き時間になる', () {
      final windows = calculateForDay(<CalendarEvent>[]);

      expect(windows, <AvailableTimeWindow>[window(at(6), at(23))]);
    });

    test('予定が1件あると前後へ空き時間が分割される', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(startAt: at(9), endAt: at(10)),
      ]);

      expect(windows, <AvailableTimeWindow>[
        window(at(6), at(9)),
        window(at(10), at(23)),
      ]);
    });

    test('複数の予定から複数の空き時間が算出される', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(id: 'a', startAt: at(9), endAt: at(10)),
        createEvent(id: 'b', startAt: at(12), endAt: at(13)),
        createEvent(id: 'c', startAt: at(15, 30), endAt: at(17)),
      ]);

      expect(windows, <AvailableTimeWindow>[
        window(at(6), at(9)),
        window(at(10), at(12)),
        window(at(13), at(15, 30)),
        window(at(17), at(23)),
      ]);
    });

    test('入力する予定が順不同でも同じ結果になる', () {
      final sortedWindows = calculateForDay(<CalendarEvent>[
        createEvent(id: 'a', startAt: at(9), endAt: at(10)),
        createEvent(id: 'b', startAt: at(12), endAt: at(13)),
        createEvent(id: 'c', startAt: at(15, 30), endAt: at(17)),
      ]);

      final shuffledWindows = calculateForDay(<CalendarEvent>[
        createEvent(id: 'c', startAt: at(15, 30), endAt: at(17)),
        createEvent(id: 'a', startAt: at(9), endAt: at(10)),
        createEvent(id: 'b', startAt: at(12), endAt: at(13)),
      ]);

      expect(shuffledWindows, sortedWindows);
    });

    test('重なり合う予定はひとつのbusy timeへ統合される', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(id: 'a', startAt: at(9), endAt: at(11)),
        createEvent(id: 'b', startAt: at(10), endAt: at(12)),
      ]);

      expect(windows, <AvailableTimeWindow>[
        window(at(6), at(9)),
        window(at(12), at(23)),
      ]);
    });

    test('他の予定に完全に含まれる予定があっても空き時間は増えない', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(id: 'a', startAt: at(9), endAt: at(13)),
        createEvent(id: 'b', startAt: at(10), endAt: at(11)),
      ]);

      expect(windows, <AvailableTimeWindow>[
        window(at(6), at(9)),
        window(at(13), at(23)),
      ]);
    });

    test('連続する予定はひとつのbusy timeへ統合される', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(id: 'a', startAt: at(9), endAt: at(10)),
        createEvent(id: 'b', startAt: at(10), endAt: at(11)),
      ]);

      expect(windows, <AvailableTimeWindow>[
        window(at(6), at(9)),
        window(at(11), at(23)),
      ]);
    });

    test('対象時間より前の予定は無視される', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(startAt: at(2), endAt: at(5)),
      ]);

      expect(windows, <AvailableTimeWindow>[window(at(6), at(23))]);
    });

    test('対象時間より後の予定は無視される', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(startAt: at(23, 30), endAt: at(24)),
      ]);

      expect(windows, <AvailableTimeWindow>[window(at(6), at(23))]);
    });

    test('対象時間の開始ちょうどに終わる予定は無視される', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(startAt: at(5), endAt: at(6)),
      ]);

      expect(windows, <AvailableTimeWindow>[window(at(6), at(23))]);
    });

    test('対象時間の終了ちょうどに始まる予定は無視される', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(startAt: at(23), endAt: at(24)),
      ]);

      expect(windows, <AvailableTimeWindow>[window(at(6), at(23))]);
    });

    test('対象範囲へ前から一部だけ重なる予定は範囲内へ切り取られる', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(startAt: at(5), endAt: at(8)),
      ]);

      expect(windows, <AvailableTimeWindow>[window(at(8), at(23))]);
    });

    test('対象範囲へ後ろから一部だけ重なる予定は範囲内へ切り取られる', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(startAt: at(22), endAt: at(24)),
      ]);

      expect(windows, <AvailableTimeWindow>[window(at(6), at(22))]);
    });

    test('対象時間の開始ちょうどに始まる予定では、前方に空き時間ができない', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(startAt: at(6), endAt: at(8)),
      ]);

      expect(windows, <AvailableTimeWindow>[window(at(8), at(23))]);
    });

    test('対象時間の終了ちょうどに終わる予定では、後方に空き時間ができない', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(startAt: at(21), endAt: at(23)),
      ]);

      expect(windows, <AvailableTimeWindow>[window(at(6), at(21))]);
    });

    test('対象範囲全体が予定で埋まっている場合は空のListを返す', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(startAt: at(6), endAt: at(23)),
      ]);

      expect(windows, isEmpty);
    });

    test('対象範囲を包み込む予定でも空のListを返す', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(startAt: at(4), endAt: at(24)),
      ]);

      expect(windows, isEmpty);
    });

    test('終日予定によって対象時間全体が埋まる', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(
          startAt: DateTime(2026, 8, 7),
          endAt: DateTime(2026, 8, 8),
          isAllDay: true,
        ),
      ]);

      expect(windows, isEmpty);
    });

    test('AiVisibilityに関わらず、すべての予定をbusy timeとして扱う', () {
      for (final visibility in AiVisibility.values) {
        final windows = calculateForDay(<CalendarEvent>[
          createEvent(startAt: at(9), endAt: at(10), aiVisibility: visibility),
        ]);

        expect(windows, <AvailableTimeWindow>[
          window(at(6), at(9)),
          window(at(10), at(23)),
        ], reason: '${visibility.name}の予定も空き時間計算では予定として扱う');
      }
    });

    test('hiddenの予定でも、その時間を空き時間として返さない', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(
          startAt: at(6),
          endAt: at(23),
          aiVisibility: AiVisibility.hidden,
        ),
      ]);

      expect(windows, isEmpty);
    });

    test('返される空き時間は開始日時の昇順になる', () {
      final windows = calculateForDay(<CalendarEvent>[
        createEvent(id: 'c', startAt: at(20), endAt: at(21)),
        createEvent(id: 'a', startAt: at(8), endAt: at(9)),
        createEvent(id: 'b', startAt: at(14), endAt: at(15)),
      ]);

      final startTimes = windows
          .map((availableTime) => availableTime.startAt)
          .toList();

      final sortedStartTimes = List<DateTime>.from(startTimes)..sort();

      expect(startTimes, sortedStartTimes);
      expect(windows, hasLength(4));
    });

    test('対象範囲が不正な場合は拒否する', () {
      expect(
        () => calculator.calculate(
          rangeStart: at(9),
          rangeEnd: at(9),
          events: const <CalendarEvent>[],
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => calculator.calculate(
          rangeStart: at(10),
          rangeEnd: at(9),
          events: const <CalendarEvent>[],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('日をまたぐ範囲でも空き時間を算出できる', () {
      final windows = calculator.calculate(
        rangeStart: DateTime(2026, 8, 7, 22),
        rangeEnd: DateTime(2026, 8, 8, 6),
        events: <CalendarEvent>[
          createEvent(
            startAt: DateTime(2026, 8, 7, 23),
            endAt: DateTime(2026, 8, 8, 1),
          ),
        ],
      );

      expect(windows, <AvailableTimeWindow>[
        window(DateTime(2026, 8, 7, 22), DateTime(2026, 8, 7, 23)),
        window(DateTime(2026, 8, 8, 1), DateTime(2026, 8, 8, 6)),
      ]);
    });
  });
}
