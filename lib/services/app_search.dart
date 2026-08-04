// lib/services/app_search.dart
// 🔍 محرّك البحث الموحّد للبرنامج كله.
//
// المشكلة اللي بيحلّها: كل شاشة كانت بتعمل `text.contains(q)` خام، يعني
// تكتب «احمد» ما يلاقيش «أحمد»، وتكتب «٠١٠» ما يلاقيش «010»، وتكتب
// «0100 123» ما يلاقيش «0100123456». دلوقتي كله بيعدّي من هنا.
//
// ملف دارت صافي — مفيش فيه Flutter، عشان أي طبقة تقدر تستورده.

/// تطبيع نص البحث: بيشيل التشكيل ويوحّد الألف/الهمزة والتاء المربوطة
/// والياء، ويحوّل الأرقام العربية (٠١٢) والفارسية (۰۱۲) لإنجليزية.
String normalizeArabic(String s) {
  var r = s.toLowerCase().trim();
  const diacritics = 'ًٌٍَُِّْـ';
  for (final d in diacritics.split('')) {
    r = r.replaceAll(d, '');
  }
  const indic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    r = r.replaceAll(indic[i], '$i').replaceAll(persian[i], '$i');
  }
  return r
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
}

final _nonDigit = RegExp(r'[^0-9]');
final _ws = RegExp(r'\s+');

/// أرقام بس — عشان «0100 123» و«0100-123» يلاقوا «0100123456».
String digitsOnly(String s) => normalizeArabic(s).replaceAll(_nonDigit, '');

/// بيقسّم كلام البحث لكلمات متطبّعة (فاضي = مفيش بحث).
List<String> searchTerms(String q) =>
    normalizeArabic(q).split(_ws).where((t) => t.isNotEmpty).toList();

/// 🔎 حقل بيدوّر فيه البحث + عنوانه (بنستخدم العنوان نوريّ المستخدم
/// البند ظهر ليه: «لقاه في: 🔢 السيريال»).
typedef SearchField = ({String label, String text});

/// بيرجّع الحقول اللي طابقت البحث، أو **null** لو الصف ده مش مطابق.
///
/// كل كلمة لازم تلاقي حقل (AND) — عشان «احمد 0100» تضيّق مش توسّع.
List<SearchField>? searchHits(List<String> terms, List<SearchField> fields) {
  if (terms.isEmpty) return const [];
  final norm = [
    for (final f in fields)
      (f: f, t: normalizeArabic(f.text), d: digitsOnly(f.text))
  ];
  final hits = <SearchField>[];
  final seen = <String>{};
  for (final term in terms) {
    final td = term.replaceAll(_nonDigit, '');
    var found = false;
    for (final n in norm) {
      if (n.t.contains(term) || (td.isNotEmpty && n.d.contains(td))) {
        found = true;
        if (seen.add(n.f.label)) hits.add(n.f);
      }
    }
    if (!found) return null; // كلمة مالقتش حاجة → الصف مرفوض
  }
  return hits;
}

/// نسخة مختصرة للشاشات اللي عايزة صح/غلط بس.
/// `texts` = كل الحقول اللي ينفع تدوّر فيها للصف ده.
bool searchMatches(String query, List<String> texts) {
  final terms = searchTerms(query);
  if (terms.isEmpty) return true;
  return searchHitsOf(terms, texts) != null;
}

/// زي [searchMatches] بس بتاخد الكلمات متقسّمة سلفاً (أسرع في اللوبات).
List<SearchField>? searchHitsOf(List<String> terms, List<String> texts) =>
    searchHits(terms, [for (final t in texts) (label: '', text: t)]);
