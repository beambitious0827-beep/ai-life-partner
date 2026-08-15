import '../models/journey_entry.dart';

/// 歩みの保存先。
///
/// v1では保存と取得だけを持つ。
/// 編集や削除は、必要になった時点で追加する。
abstract interface class JourneyRepository {
  /// [rangeStart] 以上 [rangeEnd] 未満に起きた歩みを、新しい順で返す。
  Future<List<JourneyEntry>> getEntries({
    required String humanId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  Future<JourneyEntry?> getEntryById(String entryId);

  Future<void> saveEntry(JourneyEntry entry);
}
