/// Manual date/time formatting — no intl dependency required.
String formatTime12Hour(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour24 = local.hour;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

String formatLongDate(DateTime dateTime) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final local = dateTime.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}