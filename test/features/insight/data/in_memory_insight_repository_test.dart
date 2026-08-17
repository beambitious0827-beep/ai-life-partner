import 'package:ai_life_partner/features/insight/data/in_memory_insight_repository.dart';
import 'package:ai_life_partner/features/insight/domain/models/insight_entry.dart';
import 'package:flutter_test/flutter_test.dart';

const String humanId = 'local-human';

InsightEntry createEntry({
  required String id,
  required DateTime discoveredAt,
  String humanId = 'local-human',
  String reflectionEntryId = 'reflection-1',
  String insightText = '休むことも前に進むために必要。',
}) {
  return InsightEntry(
    id: id,
    humanId: humanId,
    reflectionEntryId: reflectionEntryId,
    insightText: insightText,
    discoveredAt: discoveredAt,
    createdAt: discoveredAt,
    updatedAt: discoveredAt,
  );
}

void main() {
  group('InMemoryInsightRepository', () {
    final rangeStart = DateTime(2026, 5, 1);
    final rangeEnd = DateTime(2026, 6, 1);

    test('保存した気づきを取り出せる', () async {
      final repository = InMemoryInsightRepository();

      await repository.saveEntry(
        createEntry(id: 'insight-1', discoveredAt: DateTime(2026, 5, 10)),
      );

      final entries = await repository.getEntries(
        humanId: humanId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(entries, hasLength(1));
      expect(entries.first.id, 'insight-1');
      expect(entries.first.insightText, '休むことも前に進むために必要。');
    });

    test('別のHumanの気づきは混ざらない', () async {
      final repository = InMemoryInsightRepository(
        seedEntries: <InsightEntry>[
          createEntry(id: 'mine', discoveredAt: DateTime(2026, 5, 10)),
          createEntry(
            id: 'other',
            discoveredAt: DateTime(2026, 5, 11),
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
      final repository = InMemoryInsightRepository(
        seedEntries: <InsightEntry>[
          createEntry(
            id: 'before',
            discoveredAt: DateTime(2026, 4, 30, 23, 59),
            reflectionEntryId: 'reflection-before',
          ),
          createEntry(
            id: 'start',
            discoveredAt: rangeStart,
            reflectionEntryId: 'reflection-start',
          ),
          createEntry(
            id: 'end',
            discoveredAt: rangeEnd,
            reflectionEntryId: 'reflection-end',
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

    test('新しい気づきから順に返す', () async {
      final repository = InMemoryInsightRepository(
        seedEntries: <InsightEntry>[
          createEntry(
            id: 'older',
            discoveredAt: DateTime(2026, 5, 2),
            reflectionEntryId: 'reflection-older',
          ),
          createEntry(
            id: 'newest',
            discoveredAt: DateTime(2026, 5, 20),
            reflectionEntryId: 'reflection-newest',
          ),
          createEntry(
            id: 'middle',
            discoveredAt: DateTime(2026, 5, 10),
            reflectionEntryId: 'reflection-middle',
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
      final repository = InMemoryInsightRepository(
        seedEntries: <InsightEntry>[
          createEntry(id: 'insight-1', discoveredAt: DateTime(2026, 5, 10)),
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
      final repository = InMemoryInsightRepository();

      await expectLater(
        repository.getEntries(
          humanId: humanId,
          rangeStart: rangeStart,
          rangeEnd: rangeStart,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('IDを指定して取り出せる', () async {
      final repository = InMemoryInsightRepository(
        seedEntries: <InsightEntry>[
          createEntry(id: 'insight-1', discoveredAt: DateTime(2026, 5, 10)),
        ],
      );

      expect((await repository.getEntryById('insight-1'))?.id, 'insight-1');
      expect(await repository.getEntryById('unknown'), isNull);
    });

    test('振り返りを指定して、その気づきを取り出せる', () async {
      final repository = InMemoryInsightRepository(
        seedEntries: <InsightEntry>[
          createEntry(
            id: 'insight-1',
            discoveredAt: DateTime(2026, 5, 10),
            reflectionEntryId: 'reflection-1',
          ),
        ],
      );

      final found = await repository.getEntryForReflection(
        humanId: humanId,
        reflectionEntryId: 'reflection-1',
      );

      expect(found?.id, 'insight-1');
    });

    test('まだ気づきを残していない振り返りではnullを返す', () async {
      final repository = InMemoryInsightRepository(
        seedEntries: <InsightEntry>[
          createEntry(
            id: 'insight-1',
            discoveredAt: DateTime(2026, 5, 10),
            reflectionEntryId: 'reflection-1',
          ),
        ],
      );

      final found = await repository.getEntryForReflection(
        humanId: humanId,
        reflectionEntryId: 'reflection-2',
      );

      expect(found, isNull);
    });

    test('別のHumanの気づきは、振り返り指定でも返さない', () async {
      final repository = InMemoryInsightRepository(
        seedEntries: <InsightEntry>[
          createEntry(
            id: 'insight-1',
            discoveredAt: DateTime(2026, 5, 10),
            reflectionEntryId: 'reflection-1',
            humanId: 'other-human',
          ),
        ],
      );

      final found = await repository.getEntryForReflection(
        humanId: humanId,
        reflectionEntryId: 'reflection-1',
      );

      expect(found, isNull);
    });

    test('同じ振り返りへ別の気づきは増やさない', () async {
      final repository = InMemoryInsightRepository(
        seedEntries: <InsightEntry>[
          createEntry(
            id: 'insight-1',
            discoveredAt: DateTime(2026, 5, 10),
            reflectionEntryId: 'reflection-1',
            insightText: '最初に残した気づき',
          ),
        ],
      );

      await expectLater(
        repository.saveEntry(
          createEntry(
            id: 'insight-2',
            discoveredAt: DateTime(2026, 5, 11),
            reflectionEntryId: 'reflection-1',
            insightText: '二つ目の気づき',
          ),
        ),
        throwsA(isA<StateError>()),
      );

      // 断られた保存は、もとの気づきに触れていない。
      expect(await repository.getEntryById('insight-2'), isNull);

      final stored = await repository.getEntryById('insight-1');

      expect(stored?.insightText, '最初に残した気づき');

      final entries = await repository.getEntries(
        humanId: humanId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(entries, hasLength(1));
    });

    test('同じIDでの保存は、同じ気づきのやり直しとして受け入れる', () async {
      final repository = InMemoryInsightRepository();

      await repository.saveEntry(
        createEntry(
          id: 'insight-1',
          discoveredAt: DateTime(2026, 5, 10),
          reflectionEntryId: 'reflection-1',
          insightText: '書いたばかりの気づき',
        ),
      );

      // 保存が届いたか分からないまま、同じIDで送り直す。
      await repository.saveEntry(
        createEntry(
          id: 'insight-1',
          discoveredAt: DateTime(2026, 5, 10),
          reflectionEntryId: 'reflection-1',
          insightText: '書き直した気づき',
        ),
      );

      final entries = await repository.getEntries(
        humanId: humanId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      // 気づきは増えず、最後に送った内容になっている。
      expect(entries, hasLength(1));
      expect(entries.single.id, 'insight-1');
      expect(entries.single.insightText, '書き直した気づき');

      // 誰の、どの振り返りからの気づきかは変わらない。
      expect(entries.single.humanId, humanId);
      expect(entries.single.reflectionEntryId, 'reflection-1');
    });

    test('同じIDでも、別のHumanのものとしては保存できない', () async {
      final repository = InMemoryInsightRepository();

      await repository.saveEntry(
        createEntry(
          id: 'insight-1',
          discoveredAt: DateTime(2026, 5, 10),
          reflectionEntryId: 'reflection-1',
          insightText: '最初に残した気づき',
        ),
      );

      await expectLater(
        repository.saveEntry(
          createEntry(
            id: 'insight-1',
            discoveredAt: DateTime(2026, 5, 11),
            reflectionEntryId: 'reflection-1',
            humanId: 'other-human',
            insightText: '別のHumanの気づき',
          ),
        ),
        throwsA(isA<StateError>()),
      );

      final stored = await repository.getEntryById('insight-1');

      expect(stored?.humanId, humanId);
      expect(stored?.reflectionEntryId, 'reflection-1');
      expect(stored?.insightText, '最初に残した気づき');
    });

    test('同じIDでも、別の振り返りのものとしては保存できない', () async {
      final repository = InMemoryInsightRepository();

      await repository.saveEntry(
        createEntry(
          id: 'insight-1',
          discoveredAt: DateTime(2026, 5, 10),
          reflectionEntryId: 'reflection-1',
          insightText: '最初に残した気づき',
        ),
      );

      await expectLater(
        repository.saveEntry(
          createEntry(
            id: 'insight-1',
            discoveredAt: DateTime(2026, 5, 11),
            reflectionEntryId: 'reflection-2',
            insightText: '別の振り返りの気づき',
          ),
        ),
        throwsA(isA<StateError>()),
      );

      final stored = await repository.getEntryById('insight-1');

      expect(stored?.humanId, humanId);
      expect(stored?.reflectionEntryId, 'reflection-1');
      expect(stored?.insightText, '最初に残した気づき');
    });

    test('初期データでも、同じ振り返りに気づきを二つ入れられない', () {
      expect(
        () => InMemoryInsightRepository(
          seedEntries: <InsightEntry>[
            createEntry(
              id: 'insight-1',
              discoveredAt: DateTime(2026, 5, 10),
              reflectionEntryId: 'reflection-1',
            ),
            createEntry(
              id: 'insight-2',
              discoveredAt: DateTime(2026, 5, 11),
              reflectionEntryId: 'reflection-1',
            ),
          ],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('初期データでも、同じIDで別のHumanのものは入れられない', () {
      expect(
        () => InMemoryInsightRepository(
          seedEntries: <InsightEntry>[
            createEntry(id: 'insight-1', discoveredAt: DateTime(2026, 5, 10)),
            createEntry(
              id: 'insight-1',
              discoveredAt: DateTime(2026, 5, 11),
              humanId: 'other-human',
            ),
          ],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('初期データでも、同じIDで別の振り返りのものは入れられない', () {
      expect(
        () => InMemoryInsightRepository(
          seedEntries: <InsightEntry>[
            createEntry(id: 'insight-1', discoveredAt: DateTime(2026, 5, 10)),
            createEntry(
              id: 'insight-1',
              discoveredAt: DateTime(2026, 5, 11),
              reflectionEntryId: 'reflection-2',
            ),
          ],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('初期データでも、別のHumanの同じ振り返りIDは重複としない', () async {
      final repository = InMemoryInsightRepository(
        seedEntries: <InsightEntry>[
          createEntry(
            id: 'mine',
            discoveredAt: DateTime(2026, 5, 10),
            reflectionEntryId: 'reflection-1',
          ),
          createEntry(
            id: 'theirs',
            discoveredAt: DateTime(2026, 5, 11),
            reflectionEntryId: 'reflection-1',
            humanId: 'other-human',
          ),
        ],
      );

      expect((await repository.getEntryById('mine'))?.id, 'mine');
      expect((await repository.getEntryById('theirs'))?.id, 'theirs');
    });

    test('成長段階や学習スコアのような数値は扱わない', () async {
      final repository = InMemoryInsightRepository(
        seedEntries: <InsightEntry>[
          createEntry(
            id: 'insight-1',
            discoveredAt: DateTime(2026, 5, 10),
            insightText: '始めるまでが一番重く、10分だけ始めると続けやすい。',
          ),
        ],
      );

      final entry = await repository.getEntryById('insight-1');

      // 残るのはHumanの言葉だけで、段階や点数は保持しない。
      expect(entry?.insightText, '始めるまでが一番重く、10分だけ始めると続けやすい。');
    });
  });
}
