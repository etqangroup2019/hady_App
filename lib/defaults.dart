import 'models.dart';

int _hm(int h, int m) => h * 60 + m;

/// الجدول الافتراضي: يوم على هدي السنة، مرتبط بمواقيت الصلاة.
/// كل شيء قابل للتعديل أو الإيقاف أو الحذف من شاشة «المهام».
List<Task> defaultTasks() {
  Task t(
    String id,
    String title,
    Cat cat,
    Anchor anchor,
    int offset, {
    int dur = 15,
    bool remind = false,
    String note = '',
    Set<int>? days,
  }) =>
      Task(
        id: id,
        title: title,
        cat: cat,
        anchor: anchor,
        offset: offset,
        duration: dur,
        remind: remind,
        note: note,
        days: days,
        builtin: true,
      );

  return [
    // ── الليل والفجر ──
    t('qiyam', 'قيام الليل', Cat.worship, Anchor.lastThird, 0,
        dur: 40, remind: true, note: 'ما تيسّر من الركعات، ثم الاستغفار والدعاء في الثلث الأخير'),
    t('suhoor', 'سحور الصيام', Cat.personal, Anchor.fajr, -40,
        dur: 20, remind: true, note: 'الاثنين والخميس إن نويت الصيام', days: {1, 4}),
    t('wake', 'الاستيقاظ والسواك والوضوء', Cat.sleep, Anchor.fajr, -20,
        dur: 15, remind: true),
    t('fajr_sunnah', 'سنة الفجر (ركعتان خفيفتان)', Cat.worship, Anchor.fajr, 5,
        dur: 5, note: 'ركعتا الفجر خير من الدنيا وما فيها'),
    t('fajr', 'صلاة الفجر', Cat.worship, Anchor.fajr, 15, dur: 15, note: 'في جماعة قدر الإمكان'),
    t('morning_adhkar', 'أذكار الصباح', Cat.dhikr, Anchor.fajr, 35, dur: 15, remind: true),
    t('wird', 'ورد القرآن (قراءة)', Cat.quran, Anchor.fajr, 55, dur: 30, remind: true),
    t('duha', 'صلاة الضحى', Cat.worship, Anchor.sunrise, 25,
        dur: 10, remind: true, note: 'بعد ارتفاع الشمس وحتى قبيل الظهر'),

    // ── الصباح والعمل ──
    t('home_morning', 'ترتيب وتنظيف المنزل', Cat.home, Anchor.fixed, _hm(7, 30), dur: 30),
    t('kahf', 'قراءة سورة الكهف', Cat.quran, Anchor.fixed, _hm(10, 0),
        dur: 25, remind: true, days: {5}),
    t('work1', 'العمل (الفترة الأولى)', Cat.work, Anchor.fixed, _hm(8, 30), dur: 210, remind: true),
    t('sadaqa', 'صدقة ولو يسيرة', Cat.worship, Anchor.fixed, _hm(11, 30), dur: 5),
    t('jumua_prep', 'الاغتسال والتبكير للجمعة', Cat.worship, Anchor.dhuhr, -90,
        dur: 20, remind: true, days: {5}),

    // ── الظهر ──
    t('dhuhr_before', 'سنة الظهر القبلية', Cat.worship, Anchor.dhuhr, 0, dur: 10),
    t('dhuhr', 'صلاة الظهر', Cat.worship, Anchor.dhuhr, 15),
    t('dhuhr_after', 'سنة الظهر البعدية', Cat.worship, Anchor.dhuhr, 30, dur: 5),
    t('qailula', 'القيلولة', Cat.sleep, Anchor.dhuhr, 45,
        dur: 30, note: 'نوم يسير يعين على قيام الليل'),
    t('work2', 'العمل (الفترة الثانية)', Cat.work, Anchor.dhuhr, 80, dur: 110),

    // ── العصر ──
    t('asr', 'صلاة العصر', Cat.worship, Anchor.asr, 15),
    t('evening_adhkar', 'أذكار المساء', Cat.dhikr, Anchor.asr, 35, dur: 15, remind: true),
    t('personal', 'قضاء الحاجات الشخصية', Cat.personal, Anchor.asr, 55, dur: 45),
    t('hifz', 'حفظ القرآن ومراجعته', Cat.quran, Anchor.maghrib, -45, dur: 30, remind: true),

    // ── المغرب والعشاء ──
    t('maghrib', 'صلاة المغرب', Cat.worship, Anchor.maghrib, 10),
    t('maghrib_after', 'سنة المغرب البعدية', Cat.worship, Anchor.maghrib, 25, dur: 5),
    t('family', 'وقت الأسرة', Cat.family, Anchor.maghrib, 35, dur: 60, remind: true),
    t('isha', 'صلاة العشاء', Cat.worship, Anchor.isha, 15),
    t('isha_after', 'سنة العشاء البعدية', Cat.worship, Anchor.isha, 30, dur: 5),
    t('witr', 'الشفع والوتر', Cat.worship, Anchor.isha, 40,
        dur: 15, remind: true, note: 'ويجوز تأخير الوتر إلى آخر الليل لمن وثق بالقيام'),
    t('reading', 'قراءة كتاب نافع', Cat.quran, Anchor.isha, 60, dur: 30),
    t('sleep_adhkar', 'أذكار النوم', Cat.dhikr, Anchor.isha, 95, dur: 10, remind: true),
    t('sleep', 'النوم', Cat.sleep, Anchor.isha, 110,
        dur: 420, remind: true, note: 'النوم المبكر يعين على القيام والفجر'),
  ];
}
