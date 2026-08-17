import 'package:ai_life_partner/features/insight/domain/models/insight_entry.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime discoveredAt = DateTime(2026, 5, 20, 21);

const String longInsightText =
    '予定どおりにいかなくても、その日の状況に合わせて変えてよい。'
    '無理を続けるより、休むことも前に進むために必要だと思えた。'
    '始めるまでが一番重いので、10分だけ始めると続けやすい。';

InsightEntry createEntry({
  String id = 'insight-1',
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
  group('InsightEntry', () {
    test('Humanが書いた気づきを残せる', () {
      final entry = createEntry(insightText: '休むことも前に進むために必要。');

      expect(entry.id, 'insight-1');
      expect(entry.humanId, 'local-human');
      expect(entry.reflectionEntryId, 'reflection-1');
      expect(entry.insightText, '休むことも前に進むために必要。');
      expect(entry.discoveredAt, discoveredAt);
      expect(entry.createdAt, discoveredAt);
      expect(entry.updatedAt, discoveredAt);
    });

    test('ひとことだけでも残せる', () {
      final entry = createEntry(insightText: '休んでよかった。');

      expect(entry.insightText, '休んでよかった。');
    });

    test('少し長い文章でも残せる', () {
      final entry = createEntry(insightText: longInsightText);

      expect(entry.insightText, longInsightText);
      expect(entry.insightText.length, greaterThan(60));
    });

    test('IDが空の場合は作れない', () {
      expect(() => createEntry(id: '  '), throwsA(isA<ArgumentError>()));
    });

    test('Human IDが空の場合は作れない', () {
      expect(() => createEntry(humanId: ''), throwsA(isA<ArgumentError>()));
    });

    test('もとになる振り返りのIDが空の場合は作れない', () {
      expect(
        () => createEntry(reflectionEntryId: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('気づきの言葉が空の場合は作れない', () {
      expect(() => createEntry(insightText: ''), throwsA(isA<ArgumentError>()));
    });

    test('気づきの言葉が空白だけの場合は作れない', () {
      expect(
        () => createEntry(insightText: '  \n  '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('もとの振り返りの写しは持たず、IDだけで関連づける', () {
      final entry = createEntry(reflectionEntryId: 'reflection-42');

      // 振り返りの内容はReflection側が持ち続ける。
      expect(entry.reflectionEntryId, 'reflection-42');
    });
  });
}
