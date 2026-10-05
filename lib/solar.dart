import 'dart:math' as math;

import 'methods.dart';
import 'models.dart';

// حساب المواقيت فلكياً داخل الجهاز (يعمل دون إنترنت).
// الخوارزمية: موضع الشمس (NOAA) + زوايا الجهة المعتمدة، وتم التحقق منها
// مقابل Aladhan في عدة مدن (تطابق في الدقيقة للفجر والشروق والظهر والمغرب والعشاء).

double _rad(double d) => d * math.pi / 180;
double _deg(double r) => r * 180 / math.pi;

/// اليوم الجولياني عند 0 توقيت عالمي لتاريخ ميلادي.
double _julian(int y, int m, int d) {
  var yy = y;
  var mm = m;
  if (mm <= 2) {
    yy -= 1;
    mm += 12;
  }
  final a = yy ~/ 100;
  final b = 2 - a + a ~/ 4;
  return (365.25 * (yy + 4716)).floorToDouble() + (30.6001 * (mm + 1)).floorToDouble() + d + b - 1524.5;
}

class _Sun {
  final double dec; // الميل بالدرجات
  final double eq; // معادلة الزمن بالدقائق
  const _Sun(this.dec, this.eq);
}

_Sun _sunAt(double jd) {
  final t = (jd - 2451545.0) / 36525;
  final l0 = (280.46646 + t * (36000.76983 + 0.0003032 * t)) % 360;
  final m = 357.52911 + t * (35999.05029 - 0.0001537 * t);
  final e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
  final mr = _rad(m);
  final c = (1.914602 - t * (0.004817 + 0.000014 * t)) * math.sin(mr) +
      (0.019993 - 0.000101 * t) * math.sin(2 * mr) +
      0.000289 * math.sin(3 * mr);
  final om = 125.04 - 1934.136 * t;
  final lam = l0 + c - 0.00569 - 0.00478 * math.sin(_rad(om));
  final eps0 = 23 + (26 + ((21.448 - t * (46.815 + t * (0.00059 - t * 0.001813)))) / 60) / 60;
  final eps = eps0 + 0.00256 * math.cos(_rad(om));
  final dec = _deg(math.asin(math.sin(_rad(eps)) * math.sin(_rad(lam))));
  final tn = math.tan(_rad(eps / 2));
  final yv = tn * tn;
  final l0r = _rad(l0);
  final eq = 4 *
      _deg(yv * math.sin(2 * l0r) -
          2 * e * math.sin(mr) +
          4 * e * yv * math.sin(mr) * math.cos(2 * l0r) -
          0.5 * yv * yv * math.sin(4 * l0r) -
          1.25 * e * e * math.sin(2 * mr));
  return _Sun(dec, eq);
}

class Solar {
  /// مواقيت يوم محلي [day] لإحداثيات [lat],[lon] وفق [sp]. [school]: 0 جمهور، 1 حنفي.
  static PrayerDay compute(DateTime day, double lat, double lon, MethodSpec sp, {int school = 0}) {
    final jd0 = _julian(day.year, day.month, day.day);
    final lonShift = 720 - 4 * lon; // دقائق من 0 ع.ع. إلى الزوال التقريبي

    var transit = lonShift;
    for (var i = 0; i < 3; i++) {
      transit = lonShift - _sunAt(jd0 + transit / 1440).eq;
    }

    /// وقت (بالدقائق من 0 ع.ع.) تصل فيه الشمس ارتفاعاً معيناً، أو null إن لم تبلغه.
    double? event(double Function(double dec) altOf, bool after) {
      var t = transit;
      for (var i = 0; i < 4; i++) {
        final s = _sunAt(jd0 + t / 1440);
        final alt = altOf(s.dec);
        final c = (math.sin(_rad(alt)) - math.sin(_rad(lat)) * math.sin(_rad(s.dec))) /
            (math.cos(_rad(lat)) * math.cos(_rad(s.dec)));
        if (c < -1 || c > 1) return null;
        final h = _deg(math.acos(c)) * 4;
        final tr = lonShift - s.eq;
        t = after ? tr + h : tr - h;
      }
      return t;
    }

    final factor = school == 1 ? 2.0 : 1.0;

    final sunrise = event((_) => -0.833, false);
    final sunset = event((_) => -0.833, true);
    final asr = event((dec) => _deg(math.atan(1 / (factor + math.tan(_rad((lat - dec).abs()))))), true);

    // الليل لحالات خطوط العرض العالية (قاعدة النسبة من الليل).
    final riseT = sunrise ?? (transit - 360);
    final setT = sunset ?? (transit + 360);
    final night = 1440 - (setT - riseT);

    final fajr = event((_) => -sp.fajr, false) ?? (riseT - night * sp.fajr / 60);

    double maghrib;
    if (sp.maghribAngle != null) {
      maghrib = event((_) => -sp.maghribAngle!, true) ?? setT;
    } else {
      maghrib = setT + sp.maghribMin;
    }

    double isha;
    if (sp.ishaMin > 0) {
      isha = maghrib + sp.ishaMin;
    } else {
      isha = event((_) => -sp.isha, true) ?? (setT + night * sp.isha / 60);
    }

    final base = DateTime.utc(day.year, day.month, day.day);
    DateTime at(double minutes) => base.add(Duration(minutes: minutes.round())).toLocal();

    return PrayerDay(
      fajr: at(fajr),
      sunrise: at(riseT),
      dhuhr: at(transit),
      asr: at(asr ?? (transit + 180)),
      maghrib: at(maghrib),
      isha: at(isha),
    );
  }
}

// ───────────────────────── التاريخ الهجري (تقريبي) ─────────────────────────

const hijriMonths = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الثاني', 'جمادى الأولى', 'جمادى الآخرة',
  'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
];

/// التقويم الهجري الحسابي (يختلف عن الرؤية بيوم أو يومين أحياناً).
String hijriTabular(DateTime d) {
  final jd = (_julian(d.year, d.month, d.day) + 0.5).floor();
  var l = jd - 1948440 + 10632;
  final n = (l - 1) ~/ 10631;
  l = l - 10631 * n + 354;
  final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) + (l ~/ 5670) * ((43 * l) ~/ 15238);
  l = l - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) - (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
  final m = (24 * l) ~/ 709;
  final dd = l - (709 * m) ~/ 24;
  final y = 30 * n + j - 30;
  final name = (m >= 1 && m <= 12) ? hijriMonths[m - 1] : '';
  return '$dd $name $y';
}
