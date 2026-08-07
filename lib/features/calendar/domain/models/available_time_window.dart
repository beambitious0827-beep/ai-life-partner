/// 予定で埋まっていない、連続した時間帯。
///
/// AvailableTimeWindowは保存せず、CalendarEventから都度算出する。
/// Human本人が「次の一歩」をどこに置けるかを考えるための材料になる。
class AvailableTimeWindow {
  AvailableTimeWindow({required this.startAt, required this.endAt}) {
    if (!endAt.isAfter(startAt)) {
      throw ArgumentError('空き時間の終了日時は、開始日時より後に設定してください。');
    }
  }

  final DateTime startAt;
  final DateTime endAt;

  Duration get duration {
    return endAt.difference(startAt);
  }

  /// 「30分空いています」のように扱いやすいよう、分単位でも取得できるようにする。
  int get durationMinutes {
    return duration.inMinutes;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AvailableTimeWindow &&
        other.startAt == startAt &&
        other.endAt == endAt;
  }

  @override
  int get hashCode {
    return Object.hash(startAt, endAt);
  }

  @override
  String toString() {
    return 'AvailableTimeWindow($startAt - $endAt)';
  }
}
