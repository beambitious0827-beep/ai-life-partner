import 'package:ai_life_partner/features/reflection/data/in_memory_reflection_repository.dart';
import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:flutter_test/flutter_test.dart';

const String humanId = 'local-human';

ReflectionEntry createEntry({
  required String id,
  required DateTime reflectedAt,
  String humanId = 'local-human',
  String journeyEntryId = 'journey-1',
  String? feelingText = '少し肩の力が抜けた',
  String? noticedText,
}) {
  return ReflectionEntry(
    id: id,
    humanId: humanId,
    journeyEntryId: journeyEntryId,
    feelingText: feelingText,
    noticedText: noticedText,
    reflectedAt: reflectedAt,
    createdAt: reflectedAt,
    updatedAt: reflectedAt,
  );
}

void main() {
  group('InMemoryReflectionRepository', () {
    final rangeStart = DateTime(2026, 5, 1);
    final rangeEnd = DateTime(2026, 6, 1);

    test('保存した振り返りを取り出せる', () async {
      final repository = InMemoryReflectionRepository();

      await repository.saveEntry(
        createEntry(id: 'reflection-1', reflectedAt: DateTime(2026, 5, 10)),
      );

      final entries = await repository.getEntries(
        humanId: humanId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(entries, hasLength(1));
      expect(entries.first.id, 'reflection-1');
    });

    test('別のHumanの振り返りは混ざらない', () async {
      final repository = InMemoryReflectionRepository(
        seedEntries: <ReflectionEntry>[
          createEntry(id: 'mine', reflectedAt: DateTime(2026, 5, 10)),
          createEntry(
            id: 'other',
            reflectedAt: DateTime(2026, 5, 11),
            humanId: 'other-human',
          ),
        ],
      );

      final entries = await repository.getEntries(
        humanId: humanId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(entries.map((entry) => entry.id), <String>['mine']);
    });

    test('期間の開始は含み、終了は含まない', () async {
      final repository = InMemoryReflectionRepository(
        seedEntries: <ReflectionEntry>[
          createEntry(
            id: 'before',
            reflectedAt: DateTime(2026, 4, 30, 23, 59),
            journeyEntryId: 'journey-before',
          ),
          createEntry(
            id: 'start',
            reflectedAt: rangeStart,
            journeyEntryId: 'journey-start',
          ),
          createEntry(
            id: 'end',
            reflectedAt: rangeEnd,
            journeyEntryId: 'journey-end',
          ),
        ],
      );

      final entries = await repository.getEntries(
        humanId: humanId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(entries.map((entry) => entry.id), <String>['start']);
    });

    test('新しい振り返りから順に返す', () async {
      final repository = InMemoryReflectionRepository(
        seedEntries: <ReflectionEntry>[
          createEntry(
            id: 'older',
            reflectedAt: DateTime(2026, 5, 2),
            journeyEntryId: 'journey-older',
          ),
          createEntry(
            id: 'newest',
            reflectedAt: DateTime(2026, 5, 20),
            journeyEntryId: 'journey-newest',
          ),
          createEntry(
            id: 'middle',
            reflectedAt: DateTime(2026, 5, 10),
            journeyEntryId: 'journey-middle',
          ),
        ],
      );

      final entries = await repository.getEntries(
        humanId: humanId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(entries.map((entry) => entry.id), <String>[
        'newest',
        'middle',
        'older',
      ]);
    });

    test('返された一覧は書き換えられない', () async {
      final repository = InMemoryReflectionRepository(
        seedEntries: <ReflectionEntry>[
          createEntry(id: 'reflection-1', reflectedAt: DateTime(2026, 5, 10)),
        ],
      );

      final entries = await repository.getEntries(
        humanId: humanId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(entries.clear, throwsUnsupportedError);
    });

    test('終了日時が開始日時より後でない場合は取得できない', () async {
      final repository = InMemoryReflectionRepository();

      expect(
        () => repository.getEntries(
          humanId: humanId,
          rangeStart: rangeStart,
          rangeEnd: rangeStart,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('IDを指定して取り出せる', () async {
      final repository = InMemoryReflectionRepository(
        seedEntries: <ReflectionEntry>[
          createEntry(id: 'reflection-1', reflectedAt: DateTime(2026, 5, 10)),
        ],
      );

      expect(
        (await repository.getEntryById('reflection-1'))?.id,
        'reflection-1',
      );
      expect(await repository.getEntryById('unknown'), isNull);
    });

    test('歩みを指定して、その振り返りを取り出せる', () async {
      final repository = InMemoryReflectionRepository(
        seedEntries: <ReflectionEntry>[
          createEntry(
            id: 'reflection-1',
            reflectedAt: DateTime(2026, 5, 10),
            journeyEntryId: 'journey-1',
          ),
        ],
      );

      final found = await repository.getEntryForJourney(
        humanId: humanId,
        journeyEntryId: 'journey-1',
      );

      expect(found?.id, 'reflection-1');
    });

    test('まだ振り返っていない歩みではnullを返す', () async {
      final repository = InMemoryReflectionRepository(
        seedEntries: <ReflectionEntry>[
          createEntry(
            id: 'reflection-1',
            reflectedAt: DateTime(2026, 5, 10),
            journeyEntryId: 'journey-1',
          ),
        ],
      );

      final found = await repository.getEntryForJourney(
        humanId: humanId,
        journeyEntryId: 'journey-2',
      );

      expect(found, isNull);
    });

    test('別のHumanの振り返りは、歩み指定でも返さない', () async {
      final repository = InMemoryReflectionRepository(
        seedEntries: <ReflectionEntry>[
          createEntry(
            id: 'reflection-1',
            reflectedAt: DateTime(2026, 5, 10),
            journeyEntryId: 'journey-1',
            humanId: 'other-human',
          ),
        ],
      );

      final found = await repository.getEntryForJourney(
        humanId: humanId,
        journeyEntryId: 'journey-1',
      );

      expect(found, isNull);
    });

    test('同じ歩みへ別の振り返りは増やさない', () async {
      final repository = InMemoryReflectionRepository(
        seedEntries: <ReflectionEntry>[
          createEntry(
            id: 'reflection-1',
            reflectedAt: DateTime(2026, 5, 10),
            journeyEntryId: 'journey-1',
            feelingText: '最初に残した気持ち',
          ),
        ],
      );

      await expectLater(
        repository.saveEntry(
          createEntry(
            id: 'reflection-2',
            reflectedAt: DateTime(2026, 5, 11),
            journeyEntryId: 'journey-1',
            feelingText: '二つ目の気持ち',
          ),
        ),
        throwsA(isA<StateError>()),
      );

      // 断られた保存は、もとの振り返りに触れていない。
      expect(await repository.getEntryById('reflection-2'), isNull);

      final stored = await repository.getEntryById('reflection-1');

      expect(stored?.feelingText, '最初に残した気持ち');

      final entries = await repository.getEntries(
        humanId: humanId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(entries, hasLength(1));
    });

    test('同じIDでの保存は、同じ振り返りのやり直しとして受け入れる', () async {
      final repository = InMemoryReflectionRepository();

      final first = createEntry(
        id: 'reflection-1',
        reflectedAt: DateTime(2026, 5, 10),
        journeyEntryId: 'journey-1',
        feelingText: '書いたばかりの気持ち',
      );

      await repository.saveEntry(first);

      // 保存が届いたか分からないまま、同じIDで送り直す。
      await repository.saveEntry(
        createEntry(
          id: 'reflection-1',
          reflectedAt: DateTime(2026, 5, 10),
          journeyEntryId: 'journey-1',
          feelingText: '書き直した気持ち',
        ),
      );

      final entries = await repository.getEntries(
        humanId: humanId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      // 振り返りは増えず、最後に送った内容になっている。
      expect(entries, hasLength(1));
      expect(entries.single.id, 'reflection-1');
      expect(entries.single.feelingText, '書き直した気持ち');

      // 誰の、どの歩みについての振り返りかは変わらない。
      expect(entries.single.humanId, humanId);
      expect(entries.single.journeyEntryId, 'journey-1');
    });

    test('同じIDでも、別のHumanのものとしては保存できない', () async {
      final repository = InMemoryReflectionRepository();

      await repository.saveEntry(
        createEntry(
          id: 'reflection-1',
          reflectedAt: DateTime(2026, 5, 10),
          journeyEntryId: 'journey-1',
          feelingText: '最初に残した気持ち',
        ),
      );

      await expectLater(
        repository.saveEntry(
          createEntry(
            id: 'reflection-1',
            reflectedAt: DateTime(2026, 5, 11),
            journeyEntryId: 'journey-1',
            humanId: 'other-human',
            feelingText: '別のHumanの気持ち',
          ),
        ),
        throwsA(isA<StateError>()),
      );

      // 断られた保存は、もとの振り返りに触れていない。
      final stored = await repository.getEntryById('reflection-1');

      expect(stored?.humanId, humanId);
      expect(stored?.journeyEntryId, 'journey-1');
      expect(stored?.feelingText, '最初に残した気持ち');
    });

    test('同じIDでも、別の歩みのものとしては保存できない', () async {
      final repository = InMemoryReflectionRepository();

      await repository.saveEntry(
        createEntry(
          id: 'reflection-1',
          reflectedAt: DateTime(2026, 5, 10),
          journeyEntryId: 'journey-1',
          feelingText: '最初に残した気持ち',
        ),
      );

      await expectLater(
        repository.saveEntry(
          createEntry(
            id: 'reflection-1',
            reflectedAt: DateTime(2026, 5, 11),
            journeyEntryId: 'journey-2',
            feelingText: '別の歩みの気持ち',
          ),
        ),
        throwsA(isA<StateError>()),
      );

      // 断られた保存は、もとの振り返りに触れていない。
      final stored = await repository.getEntryById('reflection-1');

      expect(stored?.humanId, humanId);
      expect(stored?.journeyEntryId, 'journey-1');
      expect(stored?.feelingText, '最初に残した気持ち');
    });

    test('同じIDでも、Humanと歩みの両方が違えば保存できない', () async {
      final repository = InMemoryReflectionRepository();

      await repository.saveEntry(
        createEntry(
          id: 'reflection-1',
          reflectedAt: DateTime(2026, 5, 10),
          journeyEntryId: 'journey-1',
          feelingText: '最初に残した気持ち',
        ),
      );

      await expectLater(
        repository.saveEntry(
          createEntry(
            id: 'reflection-1',
            reflectedAt: DateTime(2026, 5, 11),
            journeyEntryId: 'journey-2',
            humanId: 'other-human',
            feelingText: '別のHumanの、別の歩みの気持ち',
          ),
        ),
        throwsA(isA<StateError>()),
      );

      final stored = await repository.getEntryById('reflection-1');

      expect(stored?.humanId, humanId);
      expect(stored?.journeyEntryId, 'journey-1');
      expect(stored?.feelingText, '最初に残した気持ち');
    });

    test('初期データでも、同じ歩みに振り返りを二つ入れられない', () {
      expect(
        () => InMemoryReflectionRepository(
          seedEntries: <ReflectionEntry>[
            createEntry(
              id: 'reflection-1',
              reflectedAt: DateTime(2026, 5, 10),
              journeyEntryId: 'journey-1',
            ),
            createEntry(
              id: 'reflection-2',
              reflectedAt: DateTime(2026, 5, 11),
              journeyEntryId: 'journey-1',
            ),
          ],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('初期データでも、別のHumanの同じ歩みIDは重複としない', () async {
      final repository = InMemoryReflectionRepository(
        seedEntries: <ReflectionEntry>[
          createEntry(
            id: 'mine',
            reflectedAt: DateTime(2026, 5, 10),
            journeyEntryId: 'journey-1',
          ),
          createEntry(
            id: 'theirs',
            reflectedAt: DateTime(2026, 5, 11),
            journeyEntryId: 'journey-1',
            humanId: 'other-human',
          ),
        ],
      );

      expect((await repository.getEntryById('mine'))?.id, 'mine');
      expect((await repository.getEntryById('theirs'))?.id, 'theirs');
    });

    test('達成度や気分の点数のような数値は扱わない', () async {
      final repository = InMemoryReflectionRepository(
        seedEntries: <ReflectionEntry>[
          createEntry(
            id: 'reflection-1',
            reflectedAt: DateTime(2026, 5, 10),
            feelingText: '少し肩の力が抜けた',
            noticedText: '朝のほうが動きやすいみたいだ',
          ),
        ],
      );

      final entry = await repository.getEntryById('reflection-1');

      // 残るのはHumanの言葉だけで、点数や段階は保持しない。
      expect(entry?.feelingText, '少し肩の力が抜けた');
      expect(entry?.noticedText, '朝のほうが動きやすいみたいだ');
    });
  });
}
