const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String _two(int value) => value.toString().padLeft(2, '0');

/// 2026.09.14
String formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year}.${_two(local.month)}.${_two(local.day)}';
}

/// 2026.09.14 (월)
String formatDateWithWeekday(DateTime value) {
  final local = value.toLocal();
  return '${formatDate(local)} (${_weekdays[local.weekday - 1]})';
}

/// 2026.09.14 23:59
String formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${formatDate(local)} ${_two(local.hour)}:${_two(local.minute)}';
}

/// API에 보내는 날짜. 예: 2026-09-14
String toApiDate(DateTime value) =>
    '${value.year}-${_two(value.month)}-${_two(value.day)}';

/// 파일 크기. 예: 1.5MB
String formatSize(int bytes) {
  const units = [('GB', 1024 * 1024 * 1024), ('MB', 1024 * 1024), ('KB', 1024)];
  for (final (unit, scale) in units) {
    if (bytes >= scale) {
      final value = bytes / scale;
      final text = value >= 10 || value == value.roundToDouble()
          ? value.round().toString()
          : value.toStringAsFixed(1);
      return '$text$unit';
    }
  }
  return '${bytes}B';
}

/// 제출 기한까지 남은 시간. 지났으면 '마감'.
String dueLabel(DateTime due, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final local = due.toLocal();
  final left = local.difference(current);
  if (left.isNegative) return '마감';
  if (left.inHours < 1) return '${left.inMinutes < 1 ? 1 : left.inMinutes}분 남음';
  if (left.inHours < 24) return '${left.inHours}시간 남음';
  final days = DateTime(local.year, local.month, local.day)
      .difference(DateTime(current.year, current.month, current.day))
      .inDays;
  // 기한이 아주 먼 과제는 숫자가 길어지지 않게 줄인다. 정확한 날짜는 옆에 따로 보여준다.
  return days > 99 ? 'D-99+' : 'D-$days';
}
