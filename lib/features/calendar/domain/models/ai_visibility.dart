enum AiVisibility { full, busyOnly, hidden }

extension AiVisibilityView on AiVisibility {
  String get label {
    switch (this) {
      case AiVisibility.full:
        return '詳細までAIが参照できる';
      case AiVisibility.busyOnly:
        return '予定がある時間帯だけ参照できる';
      case AiVisibility.hidden:
        return 'AIには見せない';
    }
  }

  String get description {
    switch (this) {
      case AiVisibility.full:
        return '予定名、日時、詳細、カテゴリーを支援に利用できます。';
      case AiVisibility.busyOnly:
        return '内容は見せず、予定が埋まっている時間だけ利用します。';
      case AiVisibility.hidden:
        return 'この予定の存在をAIの支援に利用しません。';
    }
  }
}
