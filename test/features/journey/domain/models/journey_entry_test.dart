import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime occurredAt = DateTime(2026, 8, 15, 21);

JourneyEntry createEntry({
  String id = 'journey-1',
  String humanId = 'local-human',
  String plannedActionText = '30分トレーニングする',
  JourneyOutcome outcome = JourneyOutcome.completed,
  String? actualActionText,
  String? note,
  Duration? plannedDuration,
  String? sourceCalendarEventId,
}) {
  return JourneyEntry(
    id: id,
    humanId: humanId,
    plannedActionText: plannedActionText,
    outcome: outcome,
    actualActionText: actualActionText,
    note: note,
    plannedDuration: plannedDuration,
    sourceCalendarEventId: sourceCalendarEventId,
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
  );
}

void main() {
  group('JourneyOutcome', () {
    test('4つの結果に日本語のラベルがある', () {
      expect(JourneyOutcome.completed.label, 'できた');
      expect(JourneyOutcome.partial.label, '少し取り組んだ');
      expect(JourneyOutcome.changed.label, '別の一歩になった');
      expect(JourneyOutcome.rested.label, '今日は休んだ');
    });

    test('結果は4種類だけで、失敗を表す区分を持たない', () {
      expect(JourneyOutcome.values, hasLength(4));

      final names = JourneyOutcome.values.map((outcome) => outcome.name);

      expect(names, isNot(contains('failed')));
      expect(names, isNot(contains('incomplete')));
      expect(names, isNot(contains('abandoned')));
      expect(names, isNot(contains('unsuccessful')));
    });

    test('ラベルと説明に、責める言葉や評価の言葉を含まない', () {
      const forbidden = <String>['失敗', '未達', '達成率', '成功率', 'できなかった'];

      for (final outcome in JourneyOutcome.values) {
        for (final word in forbidden) {
          expect(outcome.label.contains(word), isFalse);
          expect(outcome.description.contains(word), isFalse);
        }
      }
    });

    test('別の一歩になった場合だけ、実際の一歩の入力を必要とする', () {
      expect(JourneyOutcome.changed.requiresActualActionText, isTrue);
      expect(JourneyOutcome.completed.requiresActualActionText, isFalse);
      expect(JourneyOutcome.partial.requiresActualActionText, isFalse);
      expect(JourneyOutcome.rested.requiresActualActionText, isFalse);
    });
  });

  group('JourneyEntry', () {
    test('必要な情報がそろっていれば作成できる', () {
      final entry = createEntry();

      expect(entry.id, 'journey-1');
      expect(entry.humanId, 'local-human');
      expect(entry.plannedActionText, '30分トレーニングする');
      expect(entry.outcome, JourneyOutcome.completed);
      expect(entry.occurredAt, occurredAt);
      expect(entry.createdAt, occurredAt);
      expect(entry.updatedAt, occurredAt);
    });

    test('任意の項目は省略できる', () {
      final entry = createEntry();

      expect(entry.actualActionText, isNull);
      expect(entry.note, isNull);
      expect(entry.plannedDuration, isNull);
      expect(entry.sourceCalendarEventId, isNull);

      expect(entry.hasActualActionText, isFalse);
      expect(entry.hasNote, isFalse);
    });

    test('任意の項目を持たせられる', () {
      final entry = createEntry(
        outcome: JourneyOutcome.partial,
        actualActionText: '10分だけ体を動かした',
        note: '思ったより疲れていた',
        plannedDuration: const Duration(minutes: 30),
        sourceCalendarEventId: 'event-1',
      );

      expect(entry.actualActionText, '10分だけ体を動かした');
      expect(entry.note, '思ったより疲れていた');
      expect(entry.plannedDuration, const Duration(minutes: 30));
      expect(entry.sourceCalendarEventId, 'event-1');

      expect(entry.hasActualActionText, isTrue);
      expect(entry.hasNote, isTrue);
    });

    test('IDが空の場合は作成できない', () {
      expect(() => createEntry(id: ''), throwsA(isA<ArgumentError>()));
      expect(() => createEntry(id: '   '), throwsA(isA<ArgumentError>()));
    });

    test('Human IDが空の場合は作成できない', () {
      expect(() => createEntry(humanId: ''), throwsA(isA<ArgumentError>()));
    });

    test('もとになった一歩が空の場合は作成できない', () {
      expect(
        () => createEntry(plannedActionText: ''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => createEntry(plannedActionText: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('別の一歩になった場合は、実際の一歩が必要になる', () {
      expect(
        () => createEntry(outcome: JourneyOutcome.changed),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => createEntry(
          outcome: JourneyOutcome.changed,
          actualActionText: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );

      final entry = createEntry(
        outcome: JourneyOutcome.changed,
        actualActionText: '家族との時間を優先した',
      );

      expect(entry.actualActionText, '家族との時間を優先した');
    });

    test('休んだ日も、そのままの結果として残せる', () {
      final entry = createEntry(outcome: JourneyOutcome.rested);

      expect(entry.outcome, JourneyOutcome.rested);
      expect(entry.outcome.label, '今日は休んだ');
    });
  });
}
