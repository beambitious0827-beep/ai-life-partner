import '../domain/models/reflection_entry.dart';
import '../domain/repositories/reflection_repository.dart';

/// MVP用の、アプリ内メモリだけで振り返りを保持するRepository。
///
/// Persistent Storage Phaseで別の実装へ差し替える前提のため、
/// Presentation層はReflectionRepositoryの型だけに依存する。
///
/// v1の約束事は次の三つ。
/// - ReflectionEntry.idは、誰の・どの歩みについての振り返りかを含む身元である。
///   一度残したあとで、そのHumanや歩みを付け替えることはできない。
/// - 同じ歩みに残せる振り返りはひとつだけ。
/// - 身元が同じIDでの保存は、同じ振り返りのやり直しとして扱う。
/// この約束は保存経路でも初期データでも同じように守る。
class InMemoryReflectionRepository implements ReflectionRepository {
  InMemoryReflectionRepository({
    Iterable<ReflectionEntry> seedEntries = const <ReflectionEntry>[],
  }) {
    for (final entry in seedEntries) {
      // 初期データだからといって、約束を破った状態で始めない。
      _put(entry);
    }
  }

  final Map<String, ReflectionEntry> _entries = <String, ReflectionEntry>{};

  /// v1の約束を確かめてから保存する。
  ///
  /// 身元が同じIDの保存はやり直しとみなし、そのまま置き換える。
  /// 保存が届いたかどうかHumanに分からなくなった場合でも、
  /// 同じIDで送り直せば振り返りが二重にならずに完了できる。
  ///
  /// 断ったときは、すでに残っている振り返りに一切手を触れない。
  void _put(ReflectionEntry entry) {
    final existing = _entries[entry.id];

    if (existing != null) {
      // 同じIDは同じ振り返りを指す。
      // あとから持ち主や対象の歩みが入れ替わると、
      // 誰の、どの歩みについての言葉なのかが分からなくなる。
      if (existing.humanId != entry.humanId) {
        throw StateError('同じIDの振り返りが、別のHumanのものとして残っています。');
      }

      if (existing.journeyEntryId != entry.journeyEntryId) {
        throw StateError('同じIDの振り返りが、別の歩みのものとして残っています。');
      }
    }

    // 同じ歩みへ別の振り返りが増えると、どちらが「その歩みの振り返り」か
    // 決められなくなるため、静かに上書きせずに知らせる。
    final alreadyReflected = _entries.values.any((other) {
      return other.id != entry.id &&
          other.humanId == entry.humanId &&
          other.journeyEntryId == entry.journeyEntryId;
    });

    if (alreadyReflected) {
      throw StateError('この歩みには、すでに振り返りが残っています。');
    }

    _entries[entry.id] = entry;
  }

  @override
  Future<List<ReflectionEntry>> getEntries({
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

      return !entry.reflectedAt.isBefore(rangeStart) &&
          entry.reflectedAt.isBefore(rangeEnd);
    }).toList();

    // 振り返りは読み返すものなので、新しいものから返す。
    entries.sort((first, second) {
      return second.reflectedAt.compareTo(first.reflectedAt);
    });

    return List<ReflectionEntry>.unmodifiable(entries);
  }

  @override
  Future<ReflectionEntry?> getEntryById(String entryId) async {
    return _entries[entryId];
  }

  @override
  Future<ReflectionEntry?> getEntryForJourney({
    required String humanId,
    required String journeyEntryId,
  }) async {
    final matched = _entries.values.where((entry) {
      return entry.humanId == humanId && entry.journeyEntryId == journeyEntryId;
    }).toList();

    if (matched.isEmpty) {
      return null;
    }

    // v1では歩みひとつにつき振り返りはひとつだが、
    // 万一複数あった場合でも、新しいものを返して表示を安定させる。
    matched.sort((first, second) {
      return second.reflectedAt.compareTo(first.reflectedAt);
    });

    return matched.first;
  }

  @override
  Future<void> saveEntry(ReflectionEntry entry) async {
    _put(entry);
  }
}
