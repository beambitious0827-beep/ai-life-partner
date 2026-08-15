import '../domain/models/journey_entry.dart';
import '../domain/repositories/journey_repository.dart';

/// MVP用の、アプリ内メモリだけで歩みを保持するRepository。
///
/// Persistent Storage Phaseで別の実装へ差し替える前提のため、
/// Presentation層はJourneyRepositoryの型だけに依存する。
class InMemoryJourneyRepository implements JourneyRepository {
  InMemoryJourneyRepository({
    Iterable<JourneyEntry> seedEntries = const <JourneyEntry>[],
  }) {
    for (final entry in seedEntries) {
      _entries[entry.id] = entry;
    }
  }

  final Map<String, JourneyEntry> _entries = <String, JourneyEntry>{};

  @override
  Future<List<JourneyEntry>> getEntries({
    required String humanId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    if (!rangeEnd.isAfter(rangeStart)) {
      throw ArgumentError('取得期間の終了日時は、開始日時より後に設定してください。');
    }

    final entries = _entries.values.where((entry) {
      if (entry.humanId != humanId) {
        return false;
      }

      return !entry.occurredAt.isBefore(rangeStart) &&
          entry.occurredAt.isBefore(rangeEnd);
    }).toList();

    // 歩みは履歴として読むものなので、新しいものから返す。
    entries.sort((first, second) {
      return second.occurredAt.compareTo(first.occurredAt);
    });

    return List<JourneyEntry>.unmodifiable(entries);
  }

  @override
  Future<JourneyEntry?> getEntryById(String entryId) async {
    return _entries[entryId];
  }

  @override
  Future<void> saveEntry(JourneyEntry entry) async {
    _entries[entry.id] = entry;
  }
}
