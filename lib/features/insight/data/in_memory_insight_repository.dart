import '../domain/models/insight_entry.dart';
import '../domain/repositories/insight_repository.dart';

/// MVP用の、アプリ内メモリだけで気づきを保持するRepository。
///
/// Persistent Storage Phaseで別の実装へ差し替える前提のため、
/// Presentation層はInsightRepositoryの型だけに依存する。
///
/// v1の約束事は次の三つ。
/// - InsightEntry.idは、誰の・どの振り返りからの気づきかを含む身元である。
///   一度残したあとで、そのHumanや振り返りを付け替えることはできない。
/// - ひとつの振り返りから残せる気づきはひとつだけ。
/// - 身元が同じIDでの保存は、同じ気づきのやり直しとして扱う。
/// この約束は保存経路でも初期データでも同じように守る。
class InMemoryInsightRepository implements InsightRepository {
  InMemoryInsightRepository({
    Iterable<InsightEntry> seedEntries = const <InsightEntry>[],
  }) {
    for (final entry in seedEntries) {
      // 初期データだからといって、約束を破った状態で始めない。
      _put(entry);
    }
  }

  final Map<String, InsightEntry> _entries = <String, InsightEntry>{};

  /// v1の約束を確かめてから保存する。
  ///
  /// 身元が同じIDの保存はやり直しとみなし、そのまま置き換える。
  /// 保存が届いたかどうかHumanに分からなくなった場合でも、
  /// 同じIDで送り直せば気づきが二重にならずに完了できる。
  ///
  /// 断ったときは、すでに残っている気づきに一切手を触れない。
  void _put(InsightEntry entry) {
    final existing = _entries[entry.id];

    if (existing != null) {
      // 同じIDは同じ気づきを指す。
      // あとから持ち主や対象の振り返りが入れ替わると、
      // 誰の、どの振り返りからの言葉なのかが分からなくなる。
      if (existing.humanId != entry.humanId) {
        throw StateError('同じIDの気づきが、別のHumanのものとして残っています。');
      }

      if (existing.reflectionEntryId != entry.reflectionEntryId) {
        throw StateError('同じIDの気づきが、別の振り返りのものとして残っています。');
      }
    }

    // 同じ振り返りへ別の気づきが増えると、どちらが「その振り返りの気づき」か
    // 決められなくなるため、静かに上書きせずに知らせる。
    final alreadyFound = _entries.values.any((other) {
      return other.id != entry.id &&
          other.humanId == entry.humanId &&
          other.reflectionEntryId == entry.reflectionEntryId;
    });

    if (alreadyFound) {
      throw StateError('この振り返りには、すでに気づきが残っています。');
    }

    _entries[entry.id] = entry;
  }

  @override
  Future<List<InsightEntry>> getEntries({
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

      return !entry.discoveredAt.isBefore(rangeStart) &&
          entry.discoveredAt.isBefore(rangeEnd);
    }).toList();

    // 気づきは読み返すものなので、新しいものから返す。
    entries.sort((first, second) {
      return second.discoveredAt.compareTo(first.discoveredAt);
    });

    return List<InsightEntry>.unmodifiable(entries);
  }

  @override
  Future<InsightEntry?> getEntryById(String entryId) async {
    return _entries[entryId];
  }

  @override
  Future<InsightEntry?> getEntryForReflection({
    required String humanId,
    required String reflectionEntryId,
  }) async {
    final matched = _entries.values.where((entry) {
      return entry.humanId == humanId &&
          entry.reflectionEntryId == reflectionEntryId;
    }).toList();

    if (matched.isEmpty) {
      return null;
    }

    // v1では振り返りひとつにつき気づきはひとつだが、
    // 万一複数あった場合でも、新しいものを返して表示を安定させる。
    matched.sort((first, second) {
      return second.discoveredAt.compareTo(first.discoveredAt);
    });

    return matched.first;
  }

  @override
  Future<void> saveEntry(InsightEntry entry) async {
    _put(entry);
  }
}
