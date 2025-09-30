enum StatisticsPeopleType {
  statistics,
  participant,
  supervisor,
}

extension StatisticsPeopleTypeExtension on StatisticsPeopleType {
  String get label {
    switch (this) {
      case StatisticsPeopleType.statistics:
        return 'Statistika';
      case StatisticsPeopleType.participant:
        return 'İştirakçılar';
      case StatisticsPeopleType.supervisor:
        return 'Nəzarətçilər';
    }
  }

  int get index {
    switch (this) {
      case StatisticsPeopleType.statistics:
        return 0;
      case StatisticsPeopleType.participant:
        return 1;
      case StatisticsPeopleType.supervisor:
        return 2;
    }
  }
}
