import 'package:ai_life_partner/features/calendar/presentation/event_schedule_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EventScheduleInput createSchedule({
  required DateTime date,
  bool isAllDay = false,
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0),
  TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0),
}) {
  return EventScheduleInput(
    date: date,
    isAllDay: isAllDay,
    startTime: startTime,
    endTime: endTime,
  );
}

void main() {
  group('EventScheduleInput', () {
    test('終日予定は選択日の00:00から翌日の00:00までになる', () {
      final schedule = createSchedule(
        date: DateTime(2026, 7, 22),
        isAllDay: true,
      );

      expect(schedule.startAt, DateTime(2026, 7, 22));
      expect(schedule.endAt, DateTime(2026, 7, 23));
      expect(schedule.isValid, isTrue);
      expect(schedule.validationMessage, isNull);
    });

    test('月末の終日予定は翌月1日の00:00までになる', () {
      final schedule = createSchedule(
        date: DateTime(2026, 7, 31),
        isAllDay: true,
      );

      expect(schedule.startAt, DateTime(2026, 7, 31));
      expect(schedule.endAt, DateTime(2026, 8, 1));
    });

    test('終日予定では入力された時刻を使用しない', () {
      final schedule = createSchedule(
        date: DateTime(2026, 7, 22),
        isAllDay: true,
        startTime: const TimeOfDay(hour: 18, minute: 30),
        endTime: const TimeOfDay(hour: 7, minute: 15),
      );

      expect(schedule.startAt, DateTime(2026, 7, 22));
      expect(schedule.endAt, DateTime(2026, 7, 23));
      expect(schedule.isValid, isTrue);
    });

    test('時間指定予定は選択日と時刻を組み合わせる', () {
      final schedule = createSchedule(
        date: DateTime(2026, 7, 22),
        startTime: const TimeOfDay(hour: 18, minute: 30),
        endTime: const TimeOfDay(hour: 19, minute: 45),
      );

      expect(schedule.startAt, DateTime(2026, 7, 22, 18, 30));
      expect(schedule.endAt, DateTime(2026, 7, 22, 19, 45));
      expect(schedule.isValid, isTrue);
      expect(schedule.validationMessage, isNull);
    });

    test('日付の時刻部分は開始日時に影響しない', () {
      final schedule = createSchedule(
        date: DateTime(2026, 7, 22, 23, 59),
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 0),
      );

      expect(schedule.startAt, DateTime(2026, 7, 22, 9));
      expect(schedule.endAt, DateTime(2026, 7, 22, 10));
    });

    test('終了時刻が開始時刻より前の場合は不正になる', () {
      final schedule = createSchedule(
        date: DateTime(2026, 7, 22),
        startTime: const TimeOfDay(hour: 19, minute: 0),
        endTime: const TimeOfDay(hour: 18, minute: 0),
      );

      expect(schedule.isValid, isFalse);
      expect(schedule.validationMessage, '終了時刻は開始時刻より後に設定してください。');
    });

    test('終了時刻が開始時刻と同じ場合は不正になる', () {
      final schedule = createSchedule(
        date: DateTime(2026, 7, 22),
        startTime: const TimeOfDay(hour: 19, minute: 0),
        endTime: const TimeOfDay(hour: 19, minute: 0),
      );

      expect(schedule.isValid, isFalse);
      expect(schedule.validationMessage, '終了時刻は開始時刻より後に設定してください。');
    });
  });
}
