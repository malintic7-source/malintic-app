/// French weekday names in calendar order.
const List<String> frenchWeekdays = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

/// Returns the calendar order for a French weekday.
int weekdayOrder(String day) {
  final index = frenchWeekdays.indexOf(day);
  return index == -1 ? 8 : index + 1;
}
