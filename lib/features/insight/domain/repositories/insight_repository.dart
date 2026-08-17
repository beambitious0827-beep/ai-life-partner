import '../models/insight_entry.dart';

/// 気づきの保存先。
///
/// v1では保存と取得だけを持つ。
/// 編集や削除は、必要になった時点で追加する。
abstract interface class InsightRepository {
  /// [rangeStart] 以上 [rangeEnd] 未満に残された気づきを、新しい順で返す。
  Future<List<InsightEntry>> getEntries({
    required String humanId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  Future<InsightEntry?> getEntryById(String entryId);

  /// 指定した振り返りから生まれた気づきを返す。
  ///
  /// まだ気づきを残していない場合はnullを返す。
  Future<InsightEntry?> getEntryForReflection({
    required String humanId,
    required String reflectionEntryId,
  });

  Future<void> saveEntry(InsightEntry entry);
}
