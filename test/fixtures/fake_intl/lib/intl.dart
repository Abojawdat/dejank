class DateFormat {
  DateFormat([String? pattern, String? locale]);
  DateFormat.yMd([String? locale]);
  String format(DateTime date) => '$date';
}

class NumberFormat {
  NumberFormat([String? pattern, String? locale]);
  NumberFormat.currency({String? locale, String? symbol});
  String format(num number) => '$number';
}
