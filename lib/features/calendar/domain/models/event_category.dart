enum EventCategory {
  work,
  learning,
  family,
  health,
  training,
  meal,
  sleep,
  hobby,
  lifeProject,
  other,
}

extension EventCategoryView on EventCategory {
  String get label {
    switch (this) {
      case EventCategory.work:
        return '仕事';
      case EventCategory.learning:
        return '学校・学習';
      case EventCategory.family:
        return '家族';
      case EventCategory.health:
        return '健康';
      case EventCategory.training:
        return 'トレーニング';
      case EventCategory.meal:
        return '食事';
      case EventCategory.sleep:
        return '睡眠';
      case EventCategory.hobby:
        return '趣味';
      case EventCategory.lifeProject:
        return 'Life Project';
      case EventCategory.other:
        return 'その他';
    }
  }
}
