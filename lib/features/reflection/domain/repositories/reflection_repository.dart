import '../models/reflection_entry.dart';

/// 振り返りの保存先。
///
/// v1では保存と取得だけを持つ。
/// 編集や削除は、必要になった時点で追加する。
abstract interface class ReflectionRepository {
  /// [rangeStart] 以上 [rangeEnd] 未満に残された振り返りを、新しい順で返す。
  Future<List<ReflectionEntry>> getEntries({
    required String humanId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  Future<ReflectionEntry?> getEntryById(String entryId);

  /// 指定した歩みに対する振り返りを返す。
  ///
  /// まだ振り返っていない場合はnullを返す。
  Future<ReflectionEntry?> getEntryForJourney({
    required String humanId,
    required String journeyEntryId,
  });

  Future<void> saveEntry(ReflectionEntry entry);
}
