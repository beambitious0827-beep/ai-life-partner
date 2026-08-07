import 'package:ai_life_partner/features/calendar/domain/models/available_time_window.dart';
import 'package:ai_life_partner/features/calendar/presentation/available_time_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDurationLabel', () {
    test('60分未満は分だけで表す', () {
      expect(formatDurationLabel(const Duration(minutes: 30)), '30分');
      expect(formatDurationLabel(const Duration(minutes: 45)), '45分');
      expect(formatDurationLabel(const Duration(minutes: 59)), '59分');
    });

    test('ちょうどの時間は分を表示しない', () {
      expect(formatDurationLabel(const Duration(minutes: 60)), '1時間');
      expect(formatDurationLabel(const Duration(minutes: 120)), '2時間');
      expect(formatDurationLabel(const Duration(hours: 17)), '17時間');
    });

    test('端数のある時間は時間と分で表す', () {
      expect(formatDurationLabel(const Duration(minutes: 90)), '1時間30分');
      expect(formatDurationLabel(const Duration(minutes: 61)), '1時間1分');
      expect(
        formatDurationLabel(const Duration(hours: 2, minutes: 30)),
        '2時間30分',
      );
    });

    test('秒は切り捨てて分単位で表す', () {
      expect(
        formatDurationLabel(const Duration(minutes: 30, seconds: 59)),
        '30分',
      );
    });
  });

  group('formatClockTime', () {
    test('時刻を2桁ずつで表す', () {
      expect(formatClockTime(DateTime(2026, 8, 7, 6)), '06:00');
      expect(formatClockTime(DateTime(2026, 8, 7, 9, 5)), '09:05');
      expect(formatClockTime(DateTime(2026, 8, 7, 23, 30)), '23:30');
    });
  });

  group('formatAvailableTimeRange', () {
    test('空き時間の時間帯を表す', () {
      final window = AvailableTimeWindow(
        startAt: DateTime(2026, 8, 7, 6),
        endAt: DateTime(2026, 8, 7, 9),
      );

      expect(formatAvailableTimeRange(window), '06:00 - 09:00');
    });

    test('分を含む時間帯も表せる', () {
      final window = AvailableTimeWindow(
        startAt: DateTime(2026, 8, 7, 10),
        endAt: DateTime(2026, 8, 7, 12, 30),
      );

      expect(formatAvailableTimeRange(window), '10:00 - 12:30');
      expect(formatDurationLabel(window.duration), '2時間30分');
    });
  });
}
