enum CalendarSource { internal, apple, google }

extension CalendarSourceView on CalendarSource {
  String get label {
    switch (this) {
      case CalendarSource.internal:
        return 'AI Life Partner';
      case CalendarSource.apple:
        return 'Appleカレンダー';
      case CalendarSource.google:
        return 'Googleカレンダー';
    }
  }
}
