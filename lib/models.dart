import 'package:flutter/foundation.dart';

String two(int n) => n.toString().padLeft(2, '0');
String dateKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

T _enumOr<T extends Enum>(List<T> values, dynamic name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

// ───────────────────────── التصنيفات والارتكازات ─────────────────────────

enum Cat { worship, quran, dhikr, sleep, work, family, personal, home }

const catNames = <Cat, String>{
  Cat.worship: 'عبادة وصلاة',
  Cat.quran: 'قرآن وعلم',
  Cat.dhikr: 'أذكار',
  Cat.sleep: 'نوم واستيقاظ',
  Cat.work: 'عمل',
  Cat.family: 'أسرة',
  Cat.personal: 'حاجات شخصية',
  Cat.home: 'ترتيب وتنظيف',
};

enum Anchor { fixed, fajr, sunrise, dhuhr, asr, maghrib, isha, lastThird }

const anchorNames = <Anchor, String>{
  Anchor.fixed: 'وقت ثابت',
  Anchor.fajr: 'مرتبط بالفجر',
  Anchor.sunrise: 'مرتبط بالشروق',
  Anchor.dhuhr: 'مرتبط بالظهر',
  Anchor.asr: 'مرتبط بالعصر',
  Anchor.maghrib: 'مرتبط بالمغرب',
  Anchor.isha: 'مرتبط بالعشاء',
  Anchor.lastThird: 'مرتبط بالثلث الأخير من الليل',
};

const anchorShort = <Anchor, String>{
  Anchor.fixed: '',
  Anchor.fajr: 'الفجر',
  Anchor.sunrise: 'الشروق',
  Anchor.dhuhr: 'الظهر',
  Anchor.asr: 'العصر',
  Anchor.maghrib: 'المغرب',
  Anchor.isha: 'العشاء',
  Anchor.lastThird: 'الثلث الأخير',
};

const prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
const prayerNames = <String, String>{
  'fajr': 'الفجر',
  'sunrise': 'الشروق',
  'dhuhr': 'الظهر',
  'asr': 'العصر',
  'maghrib': 'المغرب',
  'isha': 'العشاء',
};

// ───────────────────────── مواقيت يوم واحد ─────────────────────────

class PrayerDay {
  final DateTime fajr, sunrise, dhuhr, asr, maghrib, isha;
  final bool approx;
  final String hijri;

  PrayerDay({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.approx = false,
    this.hijri = '',
  });

  /// مواقيت تقريبية تُستخدم فقط إذا لم تتوفر مواقيت حقيقية بعد.
  factory PrayerDay.approximate(DateTime day) {
    DateTime at(int h, int m) => DateTime(day.year, day.month, day.day, h, m);
    return PrayerDay(
      fajr: at(5, 0),
      sunrise: at(6, 20),
      dhuhr: at(12, 0),
      asr: at(15, 30),
      maghrib: at(18, 0),
      isha: at(19, 30),
      approx: true,
    );
  }

  factory PrayerDay.fromStrings(DateTime day, Map<String, String> t, {String hijri = ''}) {
    DateTime p(String k) {
      final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(t[k] ?? '');
      if (m == null) throw const FormatException('bad time');
      return DateTime(day.year, day.month, day.day, int.parse(m.group(1)!), int.parse(m.group(2)!));
    }

    return PrayerDay(
      fajr: p('Fajr'),
      sunrise: p('Sunrise'),
      dhuhr: p('Dhuhr'),
      asr: p('Asr'),
      maghrib: p('Maghrib'),
      isha: p('Isha'),
      hijri: hijri,
    );
  }

  Map<String, dynamic> toJson() {
    String f(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
    return {
      'Fajr': f(fajr),
      'Sunrise': f(sunrise),
      'Dhuhr': f(dhuhr),
      'Asr': f(asr),
      'Maghrib': f(maghrib),
      'Isha': f(isha),
      'hijri': hijri,
    };
  }

  factory PrayerDay.fromJson(DateTime day, Map<String, dynamic> j) {
    final t = <String, String>{};
    for (final k in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      t[k] = (j[k] ?? '').toString();
    }
    return PrayerDay.fromStrings(day, t, hijri: (j['hijri'] ?? '').toString());
  }

  PrayerDay withHijri(String h) => PrayerDay(
        fajr: fajr,
        sunrise: sunrise,
        dhuhr: dhuhr,
        asr: asr,
        maghrib: maghrib,
        isha: isha,
        approx: approx,
        hijri: h,
      );

  /// نسخة بعد تطبيق التعديل اليدوي بالدقائق لكل وقت.
  PrayerDay shifted(Map<String, int> tune) {
    if (tune.values.every((m) => m == 0)) return this;
    DateTime a(DateTime d, String k) => d.add(Duration(minutes: tune[k] ?? 0));
    return PrayerDay(
      fajr: a(fajr, 'fajr'),
      sunrise: a(sunrise, 'sunrise'),
      dhuhr: a(dhuhr, 'dhuhr'),
      asr: a(asr, 'asr'),
      maghrib: a(maghrib, 'maghrib'),
      isha: a(isha, 'isha'),
      approx: approx,
      hijri: hijri,
    );
  }

  /// بداية الثلث الأخير من الليل (من مغرب أمس إلى فجر اليوم).
  DateTime get lastThird {
    final prevMaghrib = maghrib.subtract(const Duration(days: 1));
    final night = fajr.difference(prevMaghrib);
    return fajr.subtract(Duration(seconds: night.inSeconds ~/ 3));
  }

  /// بداية وقت الضحى (بعد الشروق بنحو ربع ساعة).
  DateTime get duha => sunrise.add(const Duration(minutes: 15));

  DateTime byKey(String k) {
    switch (k) {
      case 'fajr':
        return fajr;
      case 'sunrise':
        return sunrise;
      case 'dhuhr':
        return dhuhr;
      case 'asr':
        return asr;
      case 'maghrib':
        return maghrib;
      default:
        return isha;
    }
  }
}

class NextPrayer {
  final String key;
  final DateTime time;
  NextPrayer(this.key, this.time);
  String get name => prayerNames[key] ?? key;
}

// ───────────────────────── المهمة ─────────────────────────

class Task {
  final String id;
  String title;
  String note;
  Cat cat;
  Anchor anchor;

  /// للمهام الثابتة: دقائق منذ منتصف الليل. لغيرها: الإزاحة بالدقائق (سالبة = قبل).
  int offset;
  int duration;
  bool remind;
  bool enabled;

  /// أيام الأسبوع (1=الاثنين … 7=الأحد). فارغة = كل الأيام.
  Set<int> days;
  bool builtin;

  Task({
    required this.id,
    required this.title,
    this.note = '',
    this.cat = Cat.personal,
    this.anchor = Anchor.fixed,
    this.offset = 540,
    this.duration = 15,
    this.remind = false,
    this.enabled = true,
    Set<int>? days,
    this.builtin = false,
  }) : days = days ?? <int>{};

  bool runsOn(DateTime d) => days.isEmpty || days.contains(d.weekday);

  DateTime startOn(DateTime day, PrayerDay p) {
    switch (anchor) {
      case Anchor.fixed:
        return DateTime(day.year, day.month, day.day, 0, offset);
      case Anchor.fajr:
        return p.fajr.add(Duration(minutes: offset));
      case Anchor.sunrise:
        return p.sunrise.add(Duration(minutes: offset));
      case Anchor.dhuhr:
        return p.dhuhr.add(Duration(minutes: offset));
      case Anchor.asr:
        return p.asr.add(Duration(minutes: offset));
      case Anchor.maghrib:
        return p.maghrib.add(Duration(minutes: offset));
      case Anchor.isha:
        return p.isha.add(Duration(minutes: offset));
      case Anchor.lastThird:
        return p.lastThird.add(Duration(minutes: offset));
    }
  }

  Task copy() => Task(
        id: id,
        title: title,
        note: note,
        cat: cat,
        anchor: anchor,
        offset: offset,
        duration: duration,
        remind: remind,
        enabled: enabled,
        days: {...days},
        builtin: builtin,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'cat': cat.name,
        'anchor': anchor.name,
        'offset': offset,
        'duration': duration,
        'remind': remind,
        'enabled': enabled,
        'days': days.toList(),
        'builtin': builtin,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        note: (j['note'] as String?) ?? '',
        cat: _enumOr(Cat.values, j['cat'], Cat.personal),
        anchor: _enumOr(Anchor.values, j['anchor'], Anchor.fixed),
        offset: (j['offset'] as num?)?.toInt() ?? 540,
        duration: (j['duration'] as num?)?.toInt() ?? 15,
        remind: (j['remind'] as bool?) ?? false,
        enabled: (j['enabled'] as bool?) ?? true,
        days: ((j['days'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet(),
        builtin: (j['builtin'] as bool?) ?? false,
      );
}

class Occ {
  final Task task;
  final DateTime start, end;
  Occ(this.task, this.start, this.end);
}

// ───────────────────────── الإعدادات ─────────────────────────

class NotifType {
  bool enabled;
  String sound;
  int minutes;
  NotifType(this.enabled, this.sound, this.minutes);

  Map<String, dynamic> toJson() => {'e': enabled, 's': sound, 'm': minutes};

  factory NotifType.fromJson(Map<String, dynamic> j, NotifType d) => NotifType(
        (j['e'] as bool?) ?? d.enabled,
        (j['s'] as String?) ?? d.sound,
        (j['m'] as num?)?.toInt() ?? d.minutes,
      );
}

class Settings {
  String theme = 'system'; // system | light | dark
  bool h24 = false;
  bool auto = true;
  double? lat, lon;
  String place = '';
  String city = '', country = '';
  int method = 5;
  bool autoMethod = true;
  String countryCode = '';
  double cFajr = 18.5, cIsha = 17.5;
  int school = 0;
  int hijriAdjust = 0;
  double volume = 0.8;
  bool pushOn = false;
  bool statusOn = false;
  Set<String> prayersOn = {...prayerKeys};
  Map<String, int> iqama = {'fajr': 20, 'dhuhr': 15, 'asr': 15, 'maghrib': 8, 'isha': 15};
  /// تعديل يدوي بالدقائق لكل وقت (fajr, sunrise, dhuhr, asr, maghrib, isha).
  Map<String, int> tune = {};
  Map<String, NotifType> types = {
    'pre': NotifType(true, 'chime', 10),
    'adhan': NotifType(true, 'tone', 0),
    'iqama': NotifType(true, 'double', 0),
    'task': NotifType(true, 'bell', 5),
  };

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'h24': h24,
        'auto': auto,
        'lat': lat,
        'lon': lon,
        'place': place,
        'city': city,
        'country': country,
        'method': method,
        'autoMethod': autoMethod,
        'countryCode': countryCode,
        'cFajr': cFajr,
        'cIsha': cIsha,
        'school': school,
        'hijriAdjust': hijriAdjust,
        'volume': volume,
        'pushOn': pushOn,
        'statusOn': statusOn,
        'prayersOn': prayersOn.toList(),
        'iqama': iqama,
        'tune': tune,
        'types': types.map((k, v) => MapEntry(k, v.toJson())),
      };

  Settings();

  factory Settings.fromJson(Map<String, dynamic> j) {
    final s = Settings();
    s.theme = (j['theme'] as String?) ?? s.theme;
    s.h24 = (j['h24'] as bool?) ?? s.h24;
    s.auto = (j['auto'] as bool?) ?? s.auto;
    s.lat = (j['lat'] as num?)?.toDouble();
    s.lon = (j['lon'] as num?)?.toDouble();
    s.place = (j['place'] as String?) ?? '';
    s.city = (j['city'] as String?) ?? '';
    s.country = (j['country'] as String?) ?? '';
    s.method = (j['method'] as num?)?.toInt() ?? s.method;
    s.autoMethod = (j['autoMethod'] as bool?) ?? s.autoMethod;
    s.countryCode = (j['countryCode'] as String?) ?? '';
    s.cFajr = (j['cFajr'] as num?)?.toDouble() ?? s.cFajr;
    s.cIsha = (j['cIsha'] as num?)?.toDouble() ?? s.cIsha;
    s.school = (j['school'] as num?)?.toInt() ?? s.school;
    s.hijriAdjust = (j['hijriAdjust'] as num?)?.toInt() ?? 0;
    s.volume = (j['volume'] as num?)?.toDouble() ?? s.volume;
    s.pushOn = (j['pushOn'] as bool?) ?? false;
    s.statusOn = (j['statusOn'] as bool?) ?? false;
    final po = j['prayersOn'];
    if (po is List) s.prayersOn = po.map((e) => e.toString()).toSet();
    final iq = j['iqama'];
    if (iq is Map) {
      iq.forEach((k, v) {
        if (v is num) s.iqama[k.toString()] = v.toInt();
      });
    }
    final tn = j['tune'];
    if (tn is Map) {
      tn.forEach((k, v) {
        if (v is num) s.tune[k.toString()] = v.toInt();
      });
    }
    final ty = j['types'];
    if (ty is Map) {
      for (final k in s.types.keys.toList()) {
        final v = ty[k];
        if (v is Map) {
          s.types[k] = NotifType.fromJson(Map<String, dynamic>.from(v), s.types[k]!);
        }
      }
    }
    return s;
  }
}

String fmtTime(DateTime t, bool h24) {
  if (h24) return '${two(t.hour)}:${two(t.minute)}';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${two(t.minute)} ${t.hour < 12 ? 'ص' : 'م'}';
}

String durLabel(int m) {
  if (m < 60) return '$m د';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h س' : '$h س $r د';
}

const weekdayNames = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const weekdayShort = ['اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];
const monthNames = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
];

String dateLabel(DateTime d) => '${d.day} ${monthNames[d.month - 1]} ${d.year}';

@immutable
class SoundOption {
  final String id, name;
  const SoundOption(this.id, this.name);
}

const soundOptions = <SoundOption>[
  SoundOption('chime', 'رنين لطيف'),
  SoundOption('bell', 'جرس هادئ'),
  SoundOption('drop', 'قطرة ماء'),
  SoundOption('harp', 'عزف هادئ'),
  SoundOption('tone', 'نغمة طويلة'),
  SoundOption('double', 'نغمتان'),
  SoundOption('custom', 'ملف صوتي خاص بي'),
  SoundOption('none', 'بدون صوت'),
];
