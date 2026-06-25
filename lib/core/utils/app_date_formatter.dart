abstract final class AppDateFormatter {
  static String compact(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
  }

  static String dateTime(DateTime value) {
    final local = value.toLocal();
    return '${compact(local)} ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
