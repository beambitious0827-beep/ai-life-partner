import '../models/available_time_window.dart';
import '../models/calendar_event.dart';

/// CalendarEventの集合から、予定で埋まっていない時間帯を算出する。
///
/// Flutter、Repository、外部カレンダーのいずれにも依存しない純粋なDomain Service。
/// 利用の流れは次のとおり。
///
///     CalendarRepository
///             ↓
///     CalendarEvents
///             ↓
///     AvailableTimeCalculator
///             ↓
///     AvailableTimeWindows
///
/// AiVisibilityによる除外は行わない。
/// hiddenの予定を「空いている時間」として扱うと、
/// 実際には予定がある時間へ次の一歩を置いてしまうためである。
/// AIへ渡すContextでAI Visibilityを尊重する処理は、別の境界で実装する。
class AvailableTimeCalculator {
  const AvailableTimeCalculator();

  /// [rangeStart] 以上 [rangeEnd] 未満の範囲から、空き時間を開始日時の昇順で返す。
  ///
  /// [events] の順序には依存しない。
  /// 範囲全体が予定で埋まっている場合は空のListを返す。
  List<AvailableTimeWindow> calculate({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required Iterable<CalendarEvent> events,
  }) {
    if (!rangeEnd.isAfter(rangeStart)) {
      throw ArgumentError('空き時間を求める期間の終了日時は、開始日時より後に設定してください。');
    }

    final busyBlocks = _busyBlocks(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      events: events,
    );

    final windows = <AvailableTimeWindow>[];

    var cursor = rangeStart;

    for (final block in busyBlocks) {
      if (block.startAt.isAfter(cursor)) {
        windows.add(AvailableTimeWindow(startAt: cursor, endAt: block.startAt));
      }

      if (block.endAt.isAfter(cursor)) {
        cursor = block.endAt;
      }
    }

    if (rangeEnd.isAfter(cursor)) {
      windows.add(AvailableTimeWindow(startAt: cursor, endAt: rangeEnd));
    }

    return List<AvailableTimeWindow>.unmodifiable(windows);
  }

  /// 対象範囲に重なる予定だけを範囲内へ切り取り、重複と隣接を統合して返す。
  ///
  /// 戻り値は開始日時の昇順で、互いに重ならない。
  List<_BusyBlock> _busyBlocks({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required Iterable<CalendarEvent> events,
  }) {
    final clippedBlocks = <_BusyBlock>[];

    for (final event in events) {
      // 対象範囲と重ならない予定は、空き時間へ影響させない。
      if (!event.overlaps(rangeStart: rangeStart, rangeEnd: rangeEnd)) {
        continue;
      }

      // 一部だけ重なる予定は、対象範囲内へ切り取って扱う。
      final startAt = event.startAt.isBefore(rangeStart)
          ? rangeStart
          : event.startAt;

      final endAt = event.endAt.isAfter(rangeEnd) ? rangeEnd : event.endAt;

      if (!endAt.isAfter(startAt)) {
        continue;
      }

      clippedBlocks.add(_BusyBlock(startAt: startAt, endAt: endAt));
    }

    // 入力の順序に依存しないよう、ここで並べ替える。
    clippedBlocks.sort((first, second) {
      return first.startAt.compareTo(second.startAt);
    });

    final mergedBlocks = <_BusyBlock>[];

    for (final block in clippedBlocks) {
      if (mergedBlocks.isEmpty) {
        mergedBlocks.add(block);

        continue;
      }

      final lastBlock = mergedBlocks.last;

      // 開始が直前の終了より後なら、間に空き時間がある。
      // 同時刻（隣接）や重複は、ひとつのbusy blockへ統合する。
      if (block.startAt.isAfter(lastBlock.endAt)) {
        mergedBlocks.add(block);

        continue;
      }

      if (block.endAt.isAfter(lastBlock.endAt)) {
        mergedBlocks[mergedBlocks.length - 1] = _BusyBlock(
          startAt: lastBlock.startAt,
          endAt: block.endAt,
        );
      }
    }

    return mergedBlocks;
  }
}

/// 予定で埋まっている時間帯。計算の途中でだけ使用する。
class _BusyBlock {
  const _BusyBlock({required this.startAt, required this.endAt});

  final DateTime startAt;
  final DateTime endAt;
}
