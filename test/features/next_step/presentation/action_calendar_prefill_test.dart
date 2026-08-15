import 'package:ai_life_partner/features/calendar/domain/models/ai_visibility.dart';
import 'package:ai_life_partner/features/calendar/domain/models/available_time_window.dart';
import 'package:ai_life_partner/features/calendar/domain/models/event_category.dart';
import 'package:ai_life_partner/features/next_step/presentation/action_calendar_prefill.dart';
import 'package:ai_life_partner/features/next_step/presentation/next_step_result.dart';
import 'package:flutter_test/flutter_test.dart';

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

final DateTime defaultStartAt = DateTime(2026, 8, 7, 9);

void main() {
  group('buildActionCalendarPrefill 空き時間から', () {
    test('空き時間の開始からAction長さぶんを初期候補にする', () {
      final prefill = buildActionCalendarPrefill(
        result: NextStepResult.fromCalendarWindow(
          actionText: '18時から少しトレーニングする',
          window: window(18, 0, 21, 0),
          duration: const Duration(minutes: 30),
        ),
        defaultStartAt: defaultStartAt,
      );

      expect(prefill.title, '18時から少しトレーニングする');
      expect(prefill.startAt, DateTime(2026, 8, 7, 18));
      expect(prefill.endAt, DateTime(2026, 8, 7, 18, 30));

      // 空き時間全体（18:00 - 21:00）を予定にしない。
      expect(prefill.endAt, isNot(DateTime(2026, 8, 7, 21)));
    });

    test('Action長さが空き時間を超える場合は空き時間の終わりで止める', () {
      final prefill = buildActionCalendarPrefill(
        result: NextStepResult.fromCalendarWindow(
          actionText: 'トレーニングする',
          window: window(18, 0, 18, 20),
          duration: const Duration(minutes: 60),
        ),
        defaultStartAt: defaultStartAt,
      );

      expect(prefill.startAt, DateTime(2026, 8, 7, 18));
      expect(prefill.endAt, DateTime(2026, 8, 7, 18, 20));
      expect(prefill.hasSchedule, isTrue);
    });

    test('初期候補は必ず選んだ空き時間の中に収まる', () {
      final selectedWindow = window(18, 0, 18, 20);

      final prefill = buildActionCalendarPrefill(
        result: NextStepResult.fromCalendarWindow(
          actionText: 'トレーニングする',
          window: selectedWindow,
          duration: const Duration(hours: 3),
        ),
        defaultStartAt: defaultStartAt,
      );

      expect(prefill.startAt!.isBefore(selectedWindow.startAt), isFalse);
      expect(prefill.endAt!.isAfter(selectedWindow.endAt), isFalse);
    });
  });

  group('buildActionCalendarPrefill 手動指定から', () {
    test('既定の開始時刻から手動で決めた長さぶんを初期候補にする', () {
      final prefill = buildActionCalendarPrefill(
        result: const NextStepResult.fromManualTime(
          actionText: '30分だけ学習する',
          duration: Duration(minutes: 30),
        ),
        defaultStartAt: defaultStartAt,
      );

      expect(prefill.startAt, DateTime(2026, 8, 7, 9));
      expect(prefill.endAt, DateTime(2026, 8, 7, 9, 30));
      expect(
        prefill.endAt!.difference(prefill.startAt!),
        const Duration(minutes: 30),
      );
    });

    test('長さが決まっていない場合は日時の候補を作らない', () {
      final prefill = buildActionCalendarPrefill(
        result: const NextStepResult.fromManualTime(actionText: '時間を見ながら進める'),
        defaultStartAt: defaultStartAt,
      );

      // 存在しない長さを勝手に決めず、Event Editorの既定に任せる。
      expect(prefill.startAt, isNull);
      expect(prefill.endAt, isNull);
      expect(prefill.hasSchedule, isFalse);
      expect(prefill.title, '時間を見ながら進める');
    });
  });

  group('buildActionCalendarPrefill 共通', () {
    test('前後の空白を除いたAction textをtitleにする', () {
      final prefill = buildActionCalendarPrefill(
        result: const NextStepResult.fromManualTime(actionText: '  朝の学習を始める  '),
        defaultStartAt: defaultStartAt,
      );

      expect(prefill.title, '朝の学習を始める');
    });

    test('既定のカテゴリーとAI Visibilityはプライバシーを守る設定になる', () {
      final prefill = buildActionCalendarPrefill(
        result: const NextStepResult.fromManualTime(
          actionText: '学習する',
          duration: Duration(minutes: 30),
        ),
        defaultStartAt: defaultStartAt,
      );

      expect(prefill.category, EventCategory.lifeProject);
      expect(prefill.aiVisibility, AiVisibility.busyOnly);
    });
  });
}
