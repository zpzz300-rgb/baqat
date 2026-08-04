// lib/services/menu_catalog.dart
// 📚 سجل بنود التنقّل وأقسامها — مصدر واحد بيستخدمه:
//   • القايمة الجانبية ☰  (home_screen)
//   • لوحة التنقّل السريع 🗂 (workspace_switcher)
//   • محرّر الترتيب 🔀      (menu_order_editor)
// أي شاشة جديدة تتضاف هنا بتظهر في التلاتة على طول.
//
// ملف بيانات صافي — مفيش فيه Flutter ولا منطق، عشان الـ Provider يقدر
// يستورده من غير ما يعتمد على طبقة الواجهة.

export 'app_search.dart' show normalizeArabic;

typedef MenuItemDef = ({
  String key,      // نفس مفتاح kWorkspaceScreens / _tabs
  String emoji,
  String title,
  String section,  // id القسم الافتراضي
});

typedef MenuSectionDef = ({
  String id,
  String emoji,
  String title,
  int color,       // لون الشريط الجانبي للقسم
});

/// الأقسام بترتيبها الافتراضي.
const kMenuSections = <MenuSectionDef>[
  (id: 'today',   emoji: '📌', title: 'النهاردة', color: 0xFFC62828),
  (id: 'lines',   emoji: '📡', title: 'الخطوط',  color: 0xFF1565C0),
  (id: 'money',   emoji: '💵', title: 'الفلوس',  color: 0xFF2E7D32),
  (id: 'clients', emoji: '👥', title: 'العملاء', color: 0xFFEF6C00),
  (id: 'comms',   emoji: '💬', title: 'التواصل', color: 0xFF6A1B9A),
  (id: 'archive', emoji: '🗄', title: 'الأرشيف', color: 0xFF546E7A),
];

/// كل بنود التنقّل. ملاحظة: القايمة الجانبية بتسمّي شاشة الفواتير `billing`
/// ولوحة التنقّل بتسمّيها `invoices` — التوحيد بيحصل في
/// `AppProvider.menuKeyAlias`، فالمفتاح هنا `invoices`.
/// الأسماء هنا مكتوبة عشان تقرا الاسم وتعرف الشاشة بتعمل إيه من غير ما
/// تفتحها — ومفيش إيموچي متكرر بين بندين، عشان تفرّقهم بالشكل بسرعة.
const kMenuCatalog = <MenuItemDef>[
  // 📌 النهاردة
  (key: 'today',        emoji: '📌',  title: 'لوحة النهاردة',  section: 'today'),
  // 📡 الخطوط
  (key: 'groups',       emoji: '🏠',  title: 'المجموعات',      section: 'lines'),
  (key: 'worknums',     emoji: '📋',  title: 'أرقام العمل',    section: 'lines'),
  (key: 'rentals',      emoji: '🔑',  title: 'الخطوط المؤجرة', section: 'lines'),
  (key: 'gifts',        emoji: '🎁',  title: 'الهدايا',        section: 'lines'),
  // 💵 الفلوس
  (key: 'invoices',     emoji: '🧾',  title: 'الفواتير',       section: 'money'),
  (key: 'profit',       emoji: '💰',  title: 'الأرباح',        section: 'money'),
  (key: 'assets',       emoji: '📊',  title: 'الأرضي والهوم',  section: 'money'),
  // 👥 العملاء
  (key: 'consolidated', emoji: '👤',  title: 'كل العملاء',     section: 'clients'),
  (key: 'flagged',      emoji: '🚦',  title: 'العملاء الخطر',  section: 'clients'),
  (key: 'filter',       emoji: '🎛️', title: 'بحث متقدّم',     section: 'clients'),
  (key: 'guarantors',   emoji: '🤝',  title: 'الكفلاء',        section: 'clients'),
  (key: 'guests',       emoji: '🧳',  title: 'الضيوف',         section: 'clients'),
  (key: 'waitlist',     emoji: '⏳',  title: 'قائمة الانتظار', section: 'clients'),
  // 💬 التواصل
  (key: 'reminders',    emoji: '🔔',  title: 'التنبيهات',      section: 'comms'),
  (key: 'notes',        emoji: '📝',  title: 'الملاحظات',      section: 'comms'),
  (key: 'complaints',   emoji: '📢',  title: 'الشكاوى',        section: 'comms'),
  (key: 'bulk',         emoji: '📤',  title: 'رسائل جماعية',   section: 'comms'),
  // 🗄 الأرشيف
  (key: 'archive',      emoji: '📦',  title: 'المؤرشفون',      section: 'archive'),
  (key: 'deleted',      emoji: '🗑',  title: 'المحذوفون',      section: 'archive'),
  (key: 'activity',     emoji: '📜',  title: 'سجل النشاط',     section: 'archive'),
  (key: 'dataio',       emoji: '💾',  title: 'نسخ واستيراد',   section: 'archive'),
  (key: 'help',         emoji: '📖',  title: 'شرح البرنامج',   section: 'archive'),
];

MenuSectionDef? menuSectionDef(String id) {
  for (final s in kMenuSections) {
    if (s.id == id) return s;
  }
  return null;
}

MenuItemDef? menuItemDef(String key) {
  for (final e in kMenuCatalog) {
    if (e.key == key) return e;
  }
  return null;
}

// `normalizeArabic` اتنقلت لـ app_search.dart (محرّك البحث الموحّد)
// وبنعيد تصديرها من هنا عشان اللي مستوردها من الملف ده يفضل شغّال.
