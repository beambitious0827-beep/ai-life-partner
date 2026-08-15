import 'package:ai_life_partner/features/journey/data/in_memory_journey_repository.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_entry.dart';
import 'package:ai_life_partner/features/journey/domain/models/journey_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

JourneyEntry createEntry({
  required String id,
  required DateTime occurredAt,
  String humanId = 'human-1',
  String plannedActionText = '30分トレーニングする',
  JourneyOutcome outcome = JourneyOutcome.completed,
  String? note,
}) {
  return JourneyEntry(
    id: id,
    humanId: humanId,
    plannedActionText: plannedActionText,
    outcome: outcome,
    note: note,
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
  );
}

void main() {
  group('InMemoryJourneyRepository', () {
    test('保存した歩みをIDで取り出せる', () async {
      final repository = InMemoryJourneyRepository();

      final entry = createEntry(
        id: 'journey-1',
        occurredAt: DateTime(2026, 8, 15, 21),
      );

      expect(await repository.getEntryById('journey-1'), isNull);

      await repository.saveEntry(entry);

      final saved = await repository.getEntryById('journey-1');

      expect(saved, isNotNull);
      expect(saved!.plannedActionText, '30分トレーニングする');
    });

    test('別のHumanの歩みは取得しない', () async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(id: 'mine', occurredAt: DateTime(2026, 8, 15, 21)),
          createEntry(
            id: 'other',
            humanId: 'human-2',
            occurredAt: DateTime(2026, 8, 15, 22),
          ),
        ],
      );

      final entries = await repository.getEntries(
        humanId: 'human-1',
        rangeStart: DateTime(2026, 8),
        rangeEnd: DateTime(2026, 9),
      );

      expect(entries.map((entry) => entry.id), <String>['mine']);
    });

    test('期間の外にある歩みは取得しない', () async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(id: 'before', occurredAt: DateTime(2026, 7, 31, 23)),
          createEntry(id: 'inside', occurredAt: DateTime(2026, 8, 15, 21)),
          createEntry(id: 'after', occurredAt: DateTime(2026, 9, 1)),
        ],
      );

      final entries = await repository.getEntries(
        humanId: 'human-1',
        rangeStart: DateTime(2026, 8),
        rangeEnd: DateTime(2026, 9),
      );

      expect(entries.map((entry) => entry.id), <String>['inside']);
    });

    test('期間の開始は含み、終了は含まない', () async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(id: 'at-start', occurredAt: DateTime(2026, 8)),
          createEntry(id: 'at-end', occurredAt: DateTime(2026, 9)),
        ],
      );

      final entries = await repository.getEntries(
        humanId: 'human-1',
        rangeStart: DateTime(2026, 8),
        rangeEnd: DateTime(2026, 9),
      );

      expect(entries.map((entry) => entry.id), <String>['at-start']);
    });

    test('新しい歩みから順に返す', () async {
      final repository = InMemoryJourneyRepository(
        seedEntries: <JourneyEntry>[
          createEntry(id: 'middle', occurredAt: DateTime(2026, 8, 14, 20)),
          createEntry(id: 'newest', occurredAt: DateTime(2026, 8, 15, 21)),
          createEntry(id: 'oldest', occurredAt: DateTime(2026, 8, 13, 9)),
        ],
      );

      final entries = await repository.getEntries(
        humanId: 'human-1',
        rangeStart: DateTime(2026, 8),
        rangeEnd: DateTime(2026, 9),
      );

      expect(entries.map((entry) => entry.id), <String>[
        'newest',
        'middle',
        'oldest',
      ]);
    });

    test('同じIDで保存すると置き換わる', () async {
      final repository = InMemoryJourneyRepository();

      final occurredAt = DateTime(2026, 8, 15, 21);

      await repository.saveEntry(
        createEntry(id: 'journey-1', occurredAt: occurredAt),
      );

      await repository.saveEntry(
        createEntry(id: 'journey-1', occurredAt: occurredAt, note: 'あとから書き足した'),
      );

      final entries = await repository.getEntries(
        humanId: 'human-1',
        rangeStart: DateTime(2026, 8),
        rangeEnd: DateTime(2026, 9),
      );

      expect(entries, hasLength(1));
      expect(entries.single.note, 'あとから書き足した');
    });

    test('期間が不正な場合は拒否する', () async {
      final repository = InMemoryJourneyRepository();

      expect(
        () => repository.getEntries(
          humanId: 'human-1',
          rangeStart: DateTime(2026, 8),
          rangeEnd: DateTime(2026, 8),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
