import 'package:ai_life_partner/features/reflection/domain/models/reflection_entry.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime reflectedAt = DateTime(2026, 5, 20, 21);

ReflectionEntry createEntry({
  String id = 'reflection-1',
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
  group('ReflectionEntry', () {
    test('感じたことだけでも残せる', () {
      final entry = createEntry(feelingText: '少し肩の力が抜けた');

      expect(entry.hasFeelingText, isTrue);
      expect(entry.hasNoticedText, isFalse);
      expect(entry.noticedText, isNull);
    });

    test('気づいたことだけでも残せる', () {
      final entry = createEntry(
        feelingText: null,
        noticedText: '朝のほうが動きやすいみたいだ',
      );

      expect(entry.hasFeelingText, isFalse);
      expect(entry.hasNoticedText, isTrue);
    });

    test('両方残すこともできる', () {
      final entry = createEntry(
        feelingText: '少し肩の力が抜けた',
        noticedText: '朝のほうが動きやすいみたいだ',
      );

      expect(entry.hasFeelingText, isTrue);
      expect(entry.hasNoticedText, isTrue);
    });

    test('どちらも書かれていない場合は作れない', () {
      expect(
        () => createEntry(feelingText: null),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('空白だけの入力は残っていないものとして扱う', () {
      expect(
        () => createEntry(feelingText: '   ', noticedText: '\n'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('IDが空の場合は作れない', () {
      expect(() => createEntry(id: '  '), throwsA(isA<ArgumentError>()));
    });

    test('Human IDが空の場合は作れない', () {
      expect(() => createEntry(humanId: ''), throwsA(isA<ArgumentError>()));
    });

    test('もとになる歩みのIDが空の場合は作れない', () {
      expect(
        () => createEntry(journeyEntryId: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('振り返った日時と、もとになった歩みのIDを保持する', () {
      final entry = createEntry(journeyEntryId: 'journey-42');

      expect(entry.journeyEntryId, 'journey-42');
      expect(entry.reflectedAt, reflectedAt);
      expect(entry.createdAt, reflectedAt);
      expect(entry.updatedAt, reflectedAt);
    });
  });
}
