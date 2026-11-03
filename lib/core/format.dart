import 'package:intl/intl.dart';

final _d = DateFormat('dd/MM/yyyy');
final _dt = DateFormat('dd/MM/yyyy HH:mm');
final _m = NumberFormat('#,##0.00');

DateTime? parseDt(dynamic v) =>
    v is DateTime ? v : (v == null ? null : DateTime.tryParse(v.toString()));
String fmtDate(dynamic v) => parseDt(v) == null ? '—' : _d.format(parseDt(v)!);
String fmtDateTime(dynamic v) => parseDt(v) == null ? '—' : _dt.format(parseDt(v)!);
String money(dynamic v) {
  final n = v is num ? v : num.tryParse('$v');
  return n == null ? '—' : 'Q ${_m.format(n)}';
}

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String isoDateTime(DateTime d) => DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(d);
String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

int? ageOf(dynamic birth) {
  final b = parseDt(birth);
  if (b == null) return null;
  final n = DateTime.now();
  var a = n.year - b.year;
  if (n.month < b.month || (n.month == b.month && n.day < b.day)) a--;
  return a;
}

String initials(String s) {
  final p = s.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p[1][0] : '')).toUpperCase();
}

String greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Buenos días' : (h < 19 ? 'Buenas tardes' : 'Buenas noches');
}
