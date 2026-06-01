import 'package:hijri/hijri_calendar.dart';

class HijriHelper {
  static const List<String> _monthNames = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  /// Returns a month key in the form `YYYY-MM` based on the current Hijri date.
  static String currentMonthKey() {
    final h = HijriCalendar.now();
    return '${h.hYear}-${h.hMonth.toString().padLeft(2, '0')}';
  }

  static String monthTitleFromKey(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;

    final year = parts[0];
    final month = int.tryParse(parts[1]) ?? 0;
    if (month < 1 || month > _monthNames.length) return monthKey;

    return '${_monthNames[month - 1]} ${year}هـ';
  }

  /// Compute the next Hijri month key from a given `YYYY-MM` Hijri monthKey.
  static String nextMonthKeyFrom(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 1;
    var ny = y;
    var nm = m + 1;
    if (nm > 12) {
      nm = 1;
      ny += 1;
    }
    return '$ny-${nm.toString().padLeft(2, '0')}';
  }

  /// Compute the previous Hijri month key from a given `YYYY-MM` Hijri monthKey.
  static String previousMonthKeyFrom(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 1;
    var ny = y;
    var nm = m - 1;
    if (nm < 1) {
      nm = 12;
      ny -= 1;
    }
    return '$ny-${nm.toString().padLeft(2, '0')}';
  }
}
