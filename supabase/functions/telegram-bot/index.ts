// supabase/functions/telegram-bot/index.ts
//
// بوت تليجرام 24/7 — Edge Function
// ====================================
// يستقبل تحديثات تليجرام (webhook) ويرد بالتقارير المالية لكل مستخدم حسب الـ uid.
//
// الرابط الذي يُسجَّل في تليجرام:
//   https://<project>.supabase.co/functions/v1/telegram-bot?uid=<USER_ID>
//
// المتطلبات:
//   • جدول telegram_config (bot_token, chat_id, owner_name, enabled) — لكل مستخدم.
//   • جدول user_data (data jsonb) — نسخة بيانات التطبيق التي يرفعها التطبيق.
//   • SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY متاحان تلقائياً داخل الـ Edge Function.
//
// مهم: انشر الدالة بـ --no-verify-jwt لأن تليجرام لا يرسل توكن مصادقة.
//
// ملاحظة: كل الحسابات هنا مطابقة تماماً لمنطق lib/models/models.dart
//         (groupProfit, totalBillsOwed, remaining ... إلخ) حتى تطابق أرقام التطبيق.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── الأنواع (كما تُحفظ في الـ JSON من التطبيق) ──────────────────────────────

interface Member {
  id: string;
  gid: string;            // ← مهم: الربط بالمجموعة عبر gid (مش groupId)
  name: string;
  phone: string;
  price: number;
  balance: number;
  type?: string;          // 'regular' | 'landline' | 'homeforgee'
  paymentFlag?: string | null;
  deferralDate?: string | null;
  deferralNote?: string | null;
  package?: string;
  date?: string | null;
  guarantorName?: string | null;
}

interface ExtraBundle {
  month?: string;
  gb?: number;
  cost?: number;
}

interface Group {
  id: string;
  phone: string;
  type?: string;          // '3800' | '1800' | 'manual'
  provider?: string | null;
  ownerName?: string | null;
  fixedBillAmount?: number;
  giftProfit?: number;
  pendingPointsProfit?: number;
  billDebt?: number;
  maxClients?: number | null;
  extraClientFee?: number | null;
  lineType?: string;      // 'home4g' | 'adsl' | 'guest' | 'mobile'
  expiryDate?: string | null;
  offerEndDate?: string | null;
  extraBundles?: ExtraBundle[];
  rewardPoints?: number;
  pointsValue?: number;
  voucherValue?: number;
  voucherPeriod?: string;
  voucherStartDate?: string | null;
  refundableInsurance?: number;
  insuranceClaimDate?: string | null;
}

interface WorkNum {
  phone: string;
  label?: string;
  provider?: string | null;
  status?: string;        // 'available' | 'reserved' | 'needsRenewal' | 'damaged'
  notes?: string | null;
  lastContactDate?: string | null;   // آخر اتصال/تفعيل (ISO)
  offerExpiryDate?: string | null;
  reminderDaysOverride?: number | null;
}

interface GeneralNote {
  content?: string;
  reminderTime?: string | null;
  isCompleted?: boolean;
}

interface Guarantor {
  name: string;
  phone: string;
  type?: string;          // 'personal' | 'company' | 'relative'
  notes?: string | null;
}

interface BillPayment {
  amount: number;
}

interface CompanyBill {
  id: string;
  groupId: string;
  month: string;          // "2025-05"
  actualAmount: number;
  payments?: BillPayment[];
  // ملاحظة: remaining / isPaid / isPartial لا تُحفظ — تُحسب من payments.
}

interface Rental {
  name: string;
  rent: number;
  balance: number;
  status: string;
}

interface WaitlistEntry {
  name: string;
  phone: string;
  status: string;
  packageType?: string;
}

interface GuestUser {
  clientName: string;
  clientPhone: string;
  clientAmount: number;
  dealerCost: number;
  isCollected: boolean;
  dealerName?: string | null;
}

interface AppDB {
  groups: Group[];
  members: Member[];
  rentals: Rental[];
  waitlist: WaitlistEntry[];
  guestUsers: GuestUser[];
  companyBills: CompanyBill[];
  activityLog: Array<Record<string, unknown>>;
  workNums: WorkNum[];
  generalNotes: GeneralNote[];
  guarantors: Guarantor[];
}

// ─── أدوات مساعدة ─────────────────────────────────────────────────────────

const num = (v: unknown) => {
  const x = Number(v);
  return isNaN(x) ? 0 : x;
};
const n0 = (v: number) => Math.round(v).toLocaleString("en-US"); // رقم بدون كسور
const esc = (s: unknown) =>
  String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");

function emptyDB(raw: Partial<AppDB> | null | undefined): AppDB {
  return {
    groups: (raw?.groups as Group[]) ?? [],
    members: (raw?.members as Member[]) ?? [],
    rentals: (raw?.rentals as Rental[]) ?? [],
    waitlist: (raw?.waitlist as WaitlistEntry[]) ?? [],
    guestUsers: (raw?.guestUsers as GuestUser[]) ?? [],
    companyBills: (raw?.companyBills as CompanyBill[]) ?? [],
    activityLog: (raw?.activityLog as Array<Record<string, unknown>>) ?? [],
    workNums: (raw?.workNums as WorkNum[]) ?? [],
    generalNotes: (raw?.generalNotes as GeneralNote[]) ?? [],
    guarantors: (raw?.guarantors as Guarantor[]) ?? [],
  };
}

function currentMonth(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

// ─── حسابات الفواتير (CompanyBill) — مطابقة للـ getters في models.dart ────────

const billPaid = (b: CompanyBill) =>
  (b.payments ?? []).reduce((s, p) => s + num(p.amount), 0);
const billRemaining = (b: CompanyBill) =>
  Math.max(0, num(b.actualAmount) - billPaid(b));
const billIsPaid = (b: CompanyBill) => billRemaining(b) <= 0;
const billIsPartial = (b: CompanyBill) => billPaid(b) > 0 && !billIsPaid(b);

// ─── حسابات المجموعات (مطابقة لـ models.dart) ───────────────────────────────

const membersOf = (db: AppDB, gid: string) =>
  db.members.filter((m) => m.gid === gid);

const findGroup = (db: AppDB, gid: string) =>
  db.groups.find((x) => x.id === gid);

// عدد خطوط الزيادة القابلة للخصم (موبايل فقط، فوق الحد الأقصى)
function groupExtraLines(db: AppDB, g: Group): number {
  if (g.maxClients == null || g.extraClientFee == null || g.extraClientFee <= 0) return 0;
  if (g.lineType === "home4g" || g.lineType === "adsl") return 0;
  const count = membersOf(db, g.id).filter((m) => (m.type ?? "regular") === "regular").length;
  return count > g.maxClients ? count - g.maxClients : 0;
}

const groupExtraLineFee = (db: AppDB, g: Group) =>
  groupExtraLines(db, g) * num(g.extraClientFee);

const extraCostThisMonth = (g: Group, month: string) =>
  (g.extraBundles ?? [])
    .filter((b) => b.month === month)
    .reduce((s, b) => s + num(b.cost), 0);

// ربح المجموعة — يعتمد حصراً على fixedBillAmount (المبلغ الثابت المتفق عليه).
function groupProfit(db: AppDB, gid: string): number {
  const g = findGroup(db, gid);
  if (!g) return 0;
  const income = membersOf(db, gid).reduce((s, m) => s + num(m.price), 0);
  const cost = num(g.fixedBillAmount);
  if (cost <= 0 && g.type !== "manual") return 0; // لا تكلفة محددة → لا ربح محسوب
  const extraFee = g.type === "manual" ? 0 : groupExtraLineFee(db, g);
  const extraBundleCost = extraCostThisMonth(g, currentMonth());
  return income - cost - extraFee - extraBundleCost;
}

const groupDebt = (db: AppDB, gid: string) =>
  membersOf(db, gid).filter((m) => m.balance < 0).reduce((s, m) => s + -m.balance, 0);

// ─── الإجماليات (مطابقة لـ models.dart) ─────────────────────────────────────

const totalBillingProfit = (db: AppDB) =>
  db.groups.reduce((s, g) => s + groupProfit(db, g.id), 0);

const totalMonthlyIncome = (db: AppDB) =>
  db.members.reduce((s, m) => s + num(m.price), 0);

const totalDebt = (db: AppDB) =>
  db.members.filter((m) => m.balance < 0).reduce((s, m) => s + -m.balance, 0);

const debtorCount = (db: AppDB) =>
  db.members.filter((m) => m.balance < 0).length;

function totalBillsOwed(db: AppDB): number {
  if (db.companyBills.length === 0) {
    return db.groups.reduce((s, g) => s + num(g.billDebt), 0);
  }
  const fromBills = db.companyBills.reduce((s, b) => s + billRemaining(b), 0);
  const groupsWithBills = new Set(db.companyBills.map((b) => b.groupId));
  const legacy = db.groups
    .filter((g) => !groupsWithBills.has(g.id))
    .reduce((s, g) => s + num(g.billDebt), 0);
  return fromBills + legacy;
}

const giftProfitTotal = (db: AppDB) =>
  db.groups.reduce((s, g) => s + num(g.giftProfit), 0);

const pointsProfitTotal = (db: AppDB) =>
  db.groups.reduce((s, g) => s + num(g.pendingPointsProfit), 0);

const rentalIncome = (db: AppDB) =>
  db.rentals.filter((r) => r.status === "active").reduce((s, r) => s + num(r.rent), 0);

const netProfit = (db: AppDB) =>
  totalBillingProfit(db) + rentalIncome(db) + giftProfitTotal(db) + pointsProfitTotal(db);

const guestProfit = (g: GuestUser) => num(g.clientAmount) - num(g.dealerCost);

function prevMonth(month: string): string {
  const [y, m] = month.split("-").map((x) => parseInt(x, 10));
  const d = new Date(y, m - 2, 1); // (m-1 صفري) - 1
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

// ─── بُناة الرسائل (HTML) ───────────────────────────────────────────────────

const PROV_EMOJI: Record<string, string> = {
  etisalat: "🟢", orange: "🟠", vodafone: "🔴", we: "🟣",
};
const PROV_NAME: Record<string, string> = {
  etisalat: "اتصالات", orange: "أورانج", vodafone: "فودافون", we: "WE",
};

function welcome(ownerName: string): string {
  return `✈️ <b>بوت إدارة الاتصالات</b>
👤 <i>${esc(ownerName)}</i>
🤖 <i>أكثر من 50 أمر — اكتب أي واحد</i>

📊 <b>نظرة مالية</b>
/تقرير — تقرير شامل
/ملخص — لوحة أرقام سريعة
/ربح — الأرباح بالتفصيل
/صافي — صافي الربح فقط
/دخل — الدخل الشهري فقط
/مستحقاتي — اللي ليّا على العملاء
/عليا — اللي عليّا للشركات
/اليوم — نشاط النهاردة

💸 <b>المديونيات</b>
/ديون — كل المدينين
/اكبر 5 — أكبر 5 مديونيات
/اصغر 5 — أصغر 5 مديونيات
/فوق 500 — اللي عليهم أكثر من 500
/حمر — أصحاب العلامة الحمراء
/صفرا — أصحاب العلامة الصفراء
/احصاء_ديون — إحصائيات الديون
/بدون_ضامن — مدينون بلا ضامن (خطر)

⏳ <b>التأجيلات</b>
/مؤجل — كل المؤجَّلين
/تأجيلات 7 — تأجيلات خلال 7 أيام

👥 <b>العملاء</b>
/عملاء — إحصائيات
/بحث احمد — بحث بالاسم/الرقم
/كبار 10 — أكبر اشتراكات
/جدد 10 — أحدث العملاء
/نظاف — بدون ديون
/مجاني — سعر صفر
/ضامنين — قائمة الضامنين

📡 <b>المجموعات والخطوط</b>
/مجموعات — كل المجموعات
/مجموعة 0100 — تفاصيل خط
/سعة — العملاء مقابل الحد
/متاح — خطوط بها أماكن فاضية
/ممتلئ — خطوط ممتلئة
/نقاط — نقاط المكافآت
/هدايا — أرباح الهدايا
/قسائم — القسائم
/تأمين — التأمين المسترد
/انتهاء — خطوط تنتهي قريباً
/عروض — عروض تنتهي قريباً

📋 <b>الفواتير + الشركات</b>
/فواتير — غير المسددة
/مدفوع — المسددة
/اتصالات /فودافون /اورانج /وي — ملخص كل شركة

🚨 <b>تنبيهات ذكية ووقائية</b>
/تنبيهات — تنبيهات عامة مهمة
/مضاعفة — فواتير زادت فجأة (خطر)
/تجديد — أرقام محتاجة اتصال قبل التقفيل
/متعثرين — عملاء محتاجين متابعة عاجلة
/متوقع 7 — المتوقع تحصيله قريباً
/فرص — ربط الأماكن الفاضية بقائمة الانتظار
/احسب 3800 5 — حاسبة ربح خط قبل الإضافة

🎛️ <b>تفاعلي</b>
/قائمة — أزرار سريعة
/رسم — رسوم بيانية
/كارت [اسم] — كارت عميل كامل
/واتس [اسم] — لينك واتساب جاهز

🗂️ <b>أخرى</b>
/ايجارات — الإيجارات النشطة
/ضيوف — العملاء الضيوف
/انتظار — قائمة الانتظار
/ارقام — أرقام الشغل
/ملاحظات — الملاحظات
/نشاط 15 — آخر نشاط

💡 الأوامر تعمل بـ / أو بدونها، والأرقام اختيارية.`;
}

function fullReport(db: AppDB, ownerName: string): string {
  const now = new Date();
  const billsPending = db.companyBills.filter((b) => !billIsPaid(b)).length;
  const billsPaid = db.companyBills.filter((b) => billIsPaid(b)).length;

  return `📊 <b>التقرير المالي الشامل</b>
👤 <i>${esc(ownerName)}</i>
📅 <i>${now.getDate()}/${now.getMonth() + 1}/${now.getFullYear()}</i>
━━━━━━━━━━━━━━━━━━

👥 <b>الإحصائيات العامة:</b>
• المجموعات: <b>${db.groups.length}</b>
• العملاء: <b>${db.members.length}</b>
• المدينون: <b>${debtorCount(db)}</b>
• قائمة الانتظار: <b>${db.waitlist.length}</b>

💵 <b>الإيرادات الشهرية:</b>
• من العملاء: <b>${n0(totalMonthlyIncome(db))} ج</b>
• إيجارات: <b>${n0(rentalIncome(db))} ج</b>
• هدايا: <b>${n0(giftProfitTotal(db))} ج</b>
• نقاط: <b>${n0(pointsProfitTotal(db))} ج</b>

📋 <b>فواتير الشركات:</b>
• مستحق: <b>${n0(totalBillsOwed(db))} ج</b>
• معلقة: <b>${billsPending}</b>
• مسددة: <b>${billsPaid}</b>

💸 <b>مديونية العملاء:</b>
<code>${n0(totalDebt(db))} ج</code>

📈 <b>صافي الربح:</b>
<code>${n0(netProfit(db))} ج</code>`;
}

function profitReport(db: AppDB): string {
  const billing = totalBillingProfit(db);
  const gifts = giftProfitTotal(db);
  const points = pointsProfitTotal(db);
  const rentals = rentalIncome(db);
  const total = billing + gifts + points + rentals;

  let out = "💹 <b>تقرير الأرباح التفصيلي</b>\n━━━━━━━━━━━━━━━━━━\n\n";
  out += `📱 ربح الفواتير: <b>${n0(billing)} ج</b>\n`;
  out += `🎁 ربح الهدايا:  <b>${n0(gifts)} ج</b>\n`;
  out += `🪙 ربح النقاط:   <b>${n0(points)} ج</b>\n`;
  out += `🏠 دخل الإيجارات:<b>${n0(rentals)} ج</b>\n`;
  out += "━━━━━━━━━━━━━━\n";
  out += `✅ <b>الإجمالي: <code>${n0(total)} ج</code></b>\n\n`;
  out += "📋 <b>ربح كل مجموعة:</b>\n";
  for (const g of db.groups) {
    const p = groupProfit(db, g.id);
    if (p === 0) continue;
    out += `${p > 0 ? "🟢" : "🔴"} ${esc(g.phone)}: <b>${n0(p)} ج</b>\n`;
  }
  return out;
}

function debtsReport(db: AppDB): string {
  const debtors = db.members
    .filter((m) => m.balance < 0)
    .sort((a, b) => a.balance - b.balance);
  if (debtors.length === 0) return "✅ <b>لا توجد مديونيات حالياً 🎉</b>";

  let out = "💸 <b>قائمة المديونيات</b>\n";
  out += `الإجمالي: <code>${n0(totalDebt(db))} ج</code> — ${debtors.length} مدين\n\n`;
  for (const m of debtors.slice(0, 25)) {
    const flag = m.paymentFlag === "red" ? "🔴" : m.paymentFlag === "yellow" ? "🟡" : "⚪";
    out += `${flag} <b>${esc(m.name)}</b> — <code>${n0(-m.balance)} ج</code>\n`;
    out += `   📞 ${esc(m.phone)}\n`;
  }
  if (debtors.length > 25) out += `\n... و ${debtors.length - 25} آخرين`;
  return out;
}

// أكبر N مدينين — مثال: /اكبر 5  (الافتراضي 5 لو ما اتكتبش رقم)
function topDebtorsReport(db: AppDB, count: number): string {
  const n = count > 0 ? count : 5;
  const debtors = db.members
    .filter((m) => m.balance < 0)
    .sort((a, b) => a.balance - b.balance);
  if (debtors.length === 0) return "✅ <b>لا توجد مديونيات حالياً 🎉</b>";

  const top = debtors.slice(0, n);
  const topTotal = top.reduce((s, m) => s + -m.balance, 0);
  let out = `🔝 <b>أكبر ${top.length} مديونيات</b>\n`;
  out += `إجماليهم: <code>${n0(topTotal)} ج</code>\n\n`;
  let i = 0;
  for (const m of top) {
    i++;
    const flag = m.paymentFlag === "red" ? "🔴" : m.paymentFlag === "yellow" ? "🟡" : "⚪";
    out += `${i}. ${flag} <b>${esc(m.name)}</b> — <code>${n0(-m.balance)} ج</code>\n`;
    out += `   📞 ${esc(m.phone)}\n`;
  }
  return out;
}

// المدينون فوق مبلغ معيّن — مثال: /فوق 500  (الافتراضي 500)
function debtorsAboveReport(db: AppDB, threshold: number): string {
  const limit = threshold > 0 ? threshold : 500;
  const debtors = db.members
    .filter((m) => -m.balance > limit)
    .sort((a, b) => a.balance - b.balance);
  if (debtors.length === 0) {
    return `✅ <b>لا يوجد مدينون عليهم أكثر من ${n0(limit)} ج 🎉</b>`;
  }

  const total = debtors.reduce((s, m) => s + -m.balance, 0);
  let out = `💸 <b>مدينون عليهم أكثر من ${n0(limit)} ج</b>\n`;
  out += `العدد: <b>${debtors.length}</b> — الإجمالي: <code>${n0(total)} ج</code>\n\n`;
  let i = 0;
  for (const m of debtors.slice(0, 50)) {
    i++;
    const flag = m.paymentFlag === "red" ? "🔴" : m.paymentFlag === "yellow" ? "🟡" : "⚪";
    out += `${i}. ${flag} <b>${esc(m.name)}</b> — <code>${n0(-m.balance)} ج</code>\n`;
    out += `   📞 ${esc(m.phone)}\n`;
  }
  if (debtors.length > 50) out += `\n... و ${debtors.length - 50} آخرين`;
  return out;
}

function billsReport(db: AppDB): string {
  const unpaid = db.companyBills.filter((b) => !billIsPaid(b));
  if (unpaid.length === 0) return "✅ <b>لا توجد فواتير معلقة 🎉</b>";

  const byProv: Record<string, Array<{ b: CompanyBill; g: Group }>> = {};
  for (const b of unpaid) {
    const g = findGroup(db, b.groupId) ?? ({ id: "", phone: "?" } as Group);
    const key = g.provider ?? "other";
    (byProv[key] ??= []).push({ b, g });
  }

  const total = unpaid.reduce((s, b) => s + billRemaining(b), 0);
  let out = "📋 <b>فواتير الشركات غير المسددة</b>\n";
  out += `الإجمالي: <code>${n0(total)} ج</code>\n\n`;
  for (const [prov, list] of Object.entries(byProv)) {
    const provTotal = list.reduce((s, x) => s + billRemaining(x.b), 0);
    out += `${PROV_EMOJI[prov] ?? "📡"} <b>${PROV_NAME[prov] ?? prov} — ${n0(provTotal)} ج</b>\n`;
    for (const { b, g } of list) {
      out += `  ${billIsPartial(b) ? "🟡" : "🔴"} ${esc(g.phone)}: <code>${n0(billRemaining(b))} ج</code> (${esc(b.month)})\n`;
    }
    out += "\n";
  }
  return out;
}

function groupsReport(db: AppDB): string {
  let out = "📡 <b>تقرير المجموعات</b>\n━━━━━━━━━━━━━━━━━━\n\n";
  for (const g of db.groups) {
    const members = membersOf(db, g.id);
    const debt = groupDebt(db, g.id);
    const profit = groupProfit(db, g.id);
    out += `${PROV_EMOJI[g.provider ?? ""] ?? "📡"} <b>${esc(g.phone)}</b>${g.ownerName ? ` — ${esc(g.ownerName)}` : ""}\n`;
    out += `   👥 ${members.length} عميل | ربح: <b>${n0(profit)} ج</b>\n`;
    if (debt > 0) out += `   💸 ديون عملاء: <code>${n0(debt)} ج</code>\n`;
  }
  return out;
}

function membersReport(db: AppDB): string {
  const total = db.members.length;
  const debtors = db.members.filter((m) => m.balance < 0).length;
  const clear = db.members.filter((m) => m.balance >= 0 && m.price > 0).length;
  const zero = db.members.filter((m) => m.price === 0).length;
  const deferred = db.members.filter((m) => m.deferralDate != null).length;
  return `👥 <b>تقرير العملاء</b>
━━━━━━━━━━━━━━━━━━

الإجمالي: <b>${total} عميل</b>
✅ مسددون: <b>${clear}</b>
🔴 عليهم ديون: <b>${debtors}</b>
⚪ سعر صفر: <b>${zero}</b>
⏳ مؤجلو الدفع: <b>${deferred}</b>

💰 الدخل الشهري: <code>${n0(totalMonthlyIncome(db))} ج</code>
💸 إجمالي المديونية: <code>${n0(totalDebt(db))} ج</code>`;
}

function alertsReport(db: AppDB): string {
  const now = new Date();
  const curM = currentMonth();
  const prevM = prevMonth(curM);

  let out = "⚠️ <b>تنبيهات تحتاج مراجعة</b>\n━━━━━━━━━━━━━━━━━━\n\n";
  let any = false;

  // فواتير مضاعفة
  for (const b of db.companyBills.filter((x) => x.month === curM)) {
    const prev = db.companyBills.find((x) => x.groupId === b.groupId && x.month === prevM);
    if (prev && prev.actualAmount > 0 && b.actualAmount >= prev.actualAmount * 1.75) {
      const g = findGroup(db, b.groupId) ?? ({ phone: "?" } as Group);
      out += `🔴 <b>فاتورة مضاعفة:</b> ${esc(g.phone)}\n`;
      out += `   الشهر الماضي: ${n0(prev.actualAmount)} ج → هذا الشهر: <b>${n0(b.actualAmount)} ج</b>\n\n`;
      any = true;
    }
  }

  // خطوط تنتهي خلال 14 يوم
  for (const g of db.groups) {
    if (!g.expiryDate) continue;
    const exp = new Date(g.expiryDate);
    if (isNaN(exp.getTime())) continue;
    const days = Math.floor((exp.getTime() - now.getTime()) / 86400000);
    if (days >= 0 && days <= 14) {
      out += `⏰ <b>خط ينتهي بعد ${days} يوم:</b> ${esc(g.phone)}\n`;
      if (g.ownerName) out += `   👤 ${esc(g.ownerName)}\n`;
      out += `   📅 ${esc(g.expiryDate)}\n\n`;
      any = true;
    }
  }

  // ديون مرتفعة (> 500)
  for (const m of db.members.filter((x) => x.balance < -500)) {
    out += `💸 <b>دين مرتفع:</b> ${esc(m.name)} (${esc(m.phone)})\n`;
    out += `   المبلغ: <code>${n0(-m.balance)} ج</code>\n\n`;
    any = true;
  }

  if (!any) return "✅ <b>لا توجد تنبيهات حالياً — كل شيء بخير 🎉</b>";
  return out;
}

function expiryReport(db: AppDB): string {
  const now = new Date();
  const list = db.groups
    .filter((g) => g.expiryDate)
    .map((g) => ({ g, d: Math.floor((new Date(g.expiryDate!).getTime() - now.getTime()) / 86400000) }))
    .filter((e) => !isNaN(e.d) && e.d >= -5 && e.d <= 30)
    .sort((a, b) => a.d - b.d);

  if (list.length === 0) return "✅ لا توجد خطوط تنتهي في الـ 30 يوم القادمة";

  let out = "⏰ <b>خطوط تنتهي قريباً</b>\n━━━━━━━━━━━━━━━━━━\n\n";
  for (const { g, d } of list) {
    const em = d < 0 ? "🔴" : d <= 7 ? "🟠" : "🟡";
    const txt = d < 0 ? `انتهت منذ ${-d} يوم` : `بعد ${d} يوم`;
    out += `${em} <b>${esc(g.phone)}</b> — ${txt}\n`;
    if (g.ownerName) out += `   👤 ${esc(g.ownerName)}\n`;
  }
  return out;
}

function waitlistReport(db: AppDB): string {
  if (db.waitlist.length === 0) return "📋 قائمة الانتظار فارغة حالياً";
  const statusEmoji: Record<string, string> = { waiting: "⏳", contacted: "📞", assigned: "✅" };
  let out = `⏳ <b>قائمة الانتظار (${db.waitlist.length})</b>\n\n`;
  for (const w of db.waitlist) {
    out += `${statusEmoji[w.status] ?? "⏳"} <b>${esc(w.name)}</b> — ${esc(w.phone)}\n`;
    if (w.packageType && w.packageType !== "any") out += `   📦 ${esc(w.packageType)} MB\n`;
  }
  return out;
}

function guestsReport(db: AppDB): string {
  if (db.guestUsers.length === 0) return "🧳 لا يوجد عملاء ضيوف حالياً";
  const totalProfit = db.guestUsers.reduce((s, g) => s + guestProfit(g), 0);
  let out = `🧳 <b>العملاء الضيوف (${db.guestUsers.length})</b>\n`;
  out += `ربح إجمالي: <code>${n0(totalProfit)} ج</code>\n\n`;
  for (const g of db.guestUsers) {
    out += `${g.isCollected ? "✅" : "⏳"} <b>${esc(g.clientName)}</b> (${esc(g.clientPhone)})\n`;
    out += `   💰 ${n0(g.clientAmount)} ج — تكلفة: ${n0(g.dealerCost)} ج — ربح: <b>${n0(guestProfit(g))} ج</b>\n`;
    if (g.dealerName) out += `   🏪 عند: ${esc(g.dealerName)}\n`;
  }
  return out;
}

function rentalsReport(db: AppDB): string {
  const active = db.rentals.filter((r) => r.status === "active");
  if (active.length === 0) return "🏠 لا توجد إيجارات نشطة حالياً";
  const total = active.reduce((s, r) => s + num(r.rent), 0);
  let out = `🏠 <b>الإيجارات النشطة (${active.length})</b>\n`;
  out += `إجمالي شهري: <code>${n0(total)} ج</code>\n\n`;
  for (const r of active) {
    out += `🟢 <b>${esc(r.name)}</b> — ${n0(r.rent)} ج/شهر\n`;
    if (r.balance !== 0) {
      out += `   ${r.balance > 0 ? "✅ رصيد" : "🔴 دين"}: ${n0(Math.abs(r.balance))} ج\n`;
    }
  }
  return out;
}

function todaySummary(db: AppDB): string {
  const now = new Date();
  const todayStr = `${now.getDate()}/${now.getMonth() + 1}/${now.getFullYear()}`;
  const todayLogs = db.activityLog
    .filter((a) => (a["date"] as string) === todayStr)
    .slice(0, 15);

  let out = `📅 <b>ملخص اليوم — ${todayStr}</b>\n━━━━━━━━━━━━━━━━━━\n\n`;
  if (todayLogs.length === 0) {
    out += "لا يوجد نشاط مسجل اليوم\n\n";
  } else {
    for (const a of todayLogs) out += `• ${esc(a["desc"] ?? "")}\n`;
    out += "\n";
  }
  out += `💰 الدخل الشهري: <code>${n0(totalMonthlyIncome(db))} ج</code>\n`;
  out += `💸 المديونيات: <code>${n0(totalDebt(db))} ج</code>\n`;
  out += `📋 فواتير معلقة: <code>${db.companyBills.filter((b) => !billIsPaid(b)).length}</code>`;
  return out;
}

// ═══════════════════════════════════════════════════════════════════════════
//  تقارير إضافية (الحزمة الموسّعة ~50 أمر)
// ═══════════════════════════════════════════════════════════════════════════

const flagOf = (m: Member) =>
  m.paymentFlag === "red" ? "🔴" : m.paymentFlag === "yellow" ? "🟡" : "⚪";

const groupByGid = (db: AppDB, gid: string) => db.groups.find((g) => g.id === gid);

function daysUntil(dateStr?: string | null): number | null {
  if (!dateStr) return null;
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return null;
  return Math.floor((d.getTime() - Date.now()) / 86400000);
}

// ── ملخص سريع (لوحة أرقام) ──────────────────────────────────────────────────
function quickDashboard(db: AppDB): string {
  const active = db.rentals.filter((r) => r.status === "active").length;
  const unpaidBills = db.companyBills.filter((b) => !billIsPaid(b)).length;
  return `📌 <b>ملخص سريع</b>
━━━━━━━━━━━━━━━━━━
📡 المجموعات: <b>${db.groups.length}</b>
👥 العملاء: <b>${db.members.length}</b>
🔴 المدينون: <b>${debtorCount(db)}</b>
💸 إجمالي الديون: <code>${n0(totalDebt(db))} ج</code>
💵 الدخل الشهري: <code>${n0(totalMonthlyIncome(db))} ج</code>
📈 صافي الربح: <code>${n0(netProfit(db))} ج</code>
📋 فواتير معلقة: <b>${unpaidBills}</b>
🏠 إيجارات نشطة: <b>${active}</b>
🧳 ضيوف: <b>${db.guestUsers.length}</b>
⏳ انتظار: <b>${db.waitlist.length}</b>`;
}

// ── صافي الربح فقط ──────────────────────────────────────────────────────────
function netOnly(db: AppDB): string {
  return `📈 <b>صافي الربح الشهري</b>\n<code>${n0(netProfit(db))} ج</code>`;
}

// ── الدخل الشهري فقط ────────────────────────────────────────────────────────
function incomeOnly(db: AppDB): string {
  return `💵 <b>الدخل الشهري من العملاء</b>\n<code>${n0(totalMonthlyIncome(db))} ج</code>`;
}

// ── مستحقاتك (ليّا كام) ─────────────────────────────────────────────────────
function receivablesOnly(db: AppDB): string {
  return `💰 <b>مستحقاتك على العملاء (ليّا)</b>\n<code>${n0(totalDebt(db))} ج</code> — ${debtorCount(db)} مدين`;
}

// ── اللي عليك للشركات (عليّا كام) ───────────────────────────────────────────
function payablesOnly(db: AppDB): string {
  return `📋 <b>المستحق لشركات الاتصالات (عليّا)</b>\n<code>${n0(totalBillsOwed(db))} ج</code>`;
}

// ── أقل N مدينين (أصغر الديون) ──────────────────────────────────────────────
function smallDebtorsReport(db: AppDB, count: number): string {
  const n = count > 0 ? count : 5;
  const debtors = db.members.filter((m) => m.balance < 0).sort((a, b) => b.balance - a.balance);
  if (debtors.length === 0) return "✅ <b>لا توجد مديونيات حالياً 🎉</b>";
  let out = `🔻 <b>أصغر ${Math.min(n, debtors.length)} مديونيات</b>\n\n`;
  let i = 0;
  for (const m of debtors.slice(0, n)) {
    i++;
    out += `${i}. ${flagOf(m)} <b>${esc(m.name)}</b> — <code>${n0(-m.balance)} ج</code>\n   📞 ${esc(m.phone)}\n`;
  }
  return out;
}

// ── المدينون حسب لون العلم ──────────────────────────────────────────────────
function flaggedReport(db: AppDB, flag: string): string {
  const label = flag === "red" ? "🔴 الحمراء (خطر)" : "🟡 الصفراء (متابعة)";
  const list = db.members
    .filter((m) => m.balance < 0 && m.paymentFlag === flag)
    .sort((a, b) => a.balance - b.balance);
  if (list.length === 0) return `✅ لا يوجد مدينون بالعلامة ${label}`;
  const total = list.reduce((s, m) => s + -m.balance, 0);
  let out = `<b>مدينون بالعلامة ${label}</b>\nالعدد: <b>${list.length}</b> — الإجمالي: <code>${n0(total)} ج</code>\n\n`;
  let i = 0;
  for (const m of list.slice(0, 50)) {
    i++;
    out += `${i}. <b>${esc(m.name)}</b> — <code>${n0(-m.balance)} ج</code>\n   📞 ${esc(m.phone)}\n`;
  }
  if (list.length > 50) out += `\n... و ${list.length - 50} آخرين`;
  return out;
}

// ── المؤجلون (تأجيل دفع) ────────────────────────────────────────────────────
function deferredReport(db: AppDB): string {
  const list = db.members
    .filter((m) => m.deferralDate)
    .sort((a, b) => (a.deferralDate! < b.deferralDate! ? -1 : 1));
  if (list.length === 0) return "✅ لا يوجد عملاء مؤجَّلون حالياً";
  let out = `⏳ <b>العملاء المؤجَّلون (${list.length})</b>\n━━━━━━━━━━━━━━━━━━\n\n`;
  for (const m of list) {
    const d = daysUntil(m.deferralDate);
    const when = d === null ? "" : d < 0 ? ` (فات ${-d} يوم)` : d === 0 ? " (النهاردة!)" : ` (بعد ${d} يوم)`;
    out += `📅 <b>${esc(m.name)}</b> — ${esc(m.deferralDate)}${when}\n`;
    out += `   📞 ${esc(m.phone)}`;
    if (m.balance < 0) out += ` | دين: <code>${n0(-m.balance)} ج</code>`;
    out += "\n";
    if (m.deferralNote) out += `   📝 ${esc(m.deferralNote)}\n`;
  }
  return out;
}

// ── تأجيلات قرب موعدها (خلال N يوم، الافتراضي 7) ─────────────────────────────
function deferralsDueReport(db: AppDB, withinDays: number): string {
  const win = withinDays > 0 ? withinDays : 7;
  const list = db.members
    .filter((m) => {
      const d = daysUntil(m.deferralDate);
      return d !== null && d <= win;
    })
    .sort((a, b) => (daysUntil(a.deferralDate)! - daysUntil(b.deferralDate)!));
  if (list.length === 0) return `✅ لا توجد تأجيلات مستحقة خلال ${win} يوم`;
  let out = `⏰ <b>تأجيلات مستحقة خلال ${win} يوم</b>\n\n`;
  for (const m of list) {
    const d = daysUntil(m.deferralDate)!;
    const when = d < 0 ? `فات ${-d} يوم` : d === 0 ? "النهاردة!" : `بعد ${d} يوم`;
    out += `📅 <b>${esc(m.name)}</b> — ${when}\n   📞 ${esc(m.phone)}`;
    if (m.balance < 0) out += ` | <code>${n0(-m.balance)} ج</code>`;
    out += "\n";
  }
  return out;
}

// ── بحث عن عميل بالاسم أو الرقم ──────────────────────────────────────────────
function searchMembers(db: AppDB, query: string): string {
  const q = query.trim().toLowerCase();
  if (!q) return "✍️ اكتب اسم أو رقم بعد الأمر.\nمثال: <code>/بحث احمد</code>";
  const hits = db.members.filter(
    (m) => m.name.toLowerCase().includes(q) || m.phone.includes(q),
  );
  if (hits.length === 0) return `🔍 لا يوجد عميل مطابق لـ "${esc(query)}"`;
  let out = `🔍 <b>نتائج البحث عن "${esc(query)}" (${hits.length})</b>\n💡 للتفاصيل والأزرار: <code>/كارت ${esc(query)}</code>\n━━━━━━━━━━━━━━━━━━\n\n`;
  for (const m of hits.slice(0, 20)) {
    const g = groupByGid(db, m.gid);
    out += `${flagOf(m)} <b>${esc(m.name)}</b>\n`;
    out += `   📞 ${esc(m.phone)}\n`;
    out += `   💵 اشتراك: ${n0(m.price)} ج | ${m.balance < 0 ? "دين: <code>" + n0(-m.balance) + " ج</code>" : "رصيد سليم ✅"}\n`;
    if (m.package) out += `   📦 ${esc(m.package)}\n`;
    if (g) out += `   📡 خط: ${esc(g.phone)}\n`;
    if (m.deferralDate) out += `   ⏳ مؤجل لـ: ${esc(m.deferralDate)}\n`;
    out += "\n";
  }
  if (hits.length > 20) out += `... و ${hits.length - 20} نتيجة أخرى`;
  return out;
}

// ── أكبر العملاء قيمة اشتراك ────────────────────────────────────────────────
function topPayingReport(db: AppDB, count: number): string {
  const n = count > 0 ? count : 10;
  const list = [...db.members].filter((m) => m.price > 0).sort((a, b) => b.price - a.price);
  if (list.length === 0) return "لا يوجد عملاء باشتراك.";
  let out = `💎 <b>أكبر ${Math.min(n, list.length)} عملاء قيمة اشتراك</b>\n\n`;
  let i = 0;
  for (const m of list.slice(0, n)) {
    i++;
    out += `${i}. <b>${esc(m.name)}</b> — <code>${n0(m.price)} ج</code>\n   📞 ${esc(m.phone)}\n`;
  }
  return out;
}

// ── أحدث العملاء المضافين ────────────────────────────────────────────────────
function recentMembersReport(db: AppDB, count: number): string {
  const n = count > 0 ? count : 10;
  const list = db.members
    .filter((m) => m.date)
    .sort((a, b) => (a.date! < b.date! ? 1 : -1));
  if (list.length === 0) return "لا توجد بيانات تواريخ للعملاء.";
  let out = `🆕 <b>أحدث ${Math.min(n, list.length)} عملاء</b>\n\n`;
  for (const m of list.slice(0, n)) {
    out += `• <b>${esc(m.name)}</b> — ${esc(m.date)}\n   📞 ${esc(m.phone)}\n`;
  }
  return out;
}

// ── العملاء بدون دين (نظاف) ──────────────────────────────────────────────────
function clearMembersReport(db: AppDB): string {
  const clear = db.members.filter((m) => m.balance >= 0 && m.price > 0);
  return `✅ <b>عملاء مسدّدون (بدون دين)</b>\nالعدد: <b>${clear.length}</b> من ${db.members.length} عميل`;
}

// ── عملاء سعر صفر ────────────────────────────────────────────────────────────
function zeroPriceReport(db: AppDB): string {
  const list = db.members.filter((m) => m.price === 0);
  if (list.length === 0) return "✅ لا يوجد عملاء بسعر صفر";
  let out = `⚪ <b>عملاء بسعر صفر (${list.length})</b>\n\n`;
  for (const m of list.slice(0, 50)) {
    out += `• <b>${esc(m.name)}</b> — 📞 ${esc(m.phone)}\n`;
  }
  if (list.length > 50) out += `\n... و ${list.length - 50} آخرين`;
  return out;
}

// ── المدينون بدون ضامن (مخاطرة) ─────────────────────────────────────────────
function noGuarantorRiskReport(db: AppDB): string {
  const list = db.members
    .filter((m) => m.balance < 0 && !(m.guarantorName && m.guarantorName.trim()))
    .sort((a, b) => a.balance - b.balance);
  if (list.length === 0) return "✅ كل المدينين عليهم ضامن 👍";
  const total = list.reduce((s, m) => s + -m.balance, 0);
  let out = `⚠️ <b>مدينون بدون ضامن (مخاطرة)</b>\nالعدد: <b>${list.length}</b> — الإجمالي: <code>${n0(total)} ج</code>\n\n`;
  let i = 0;
  for (const m of list.slice(0, 40)) {
    i++;
    out += `${i}. ${flagOf(m)} <b>${esc(m.name)}</b> — <code>${n0(-m.balance)} ج</code>\n   📞 ${esc(m.phone)}\n`;
  }
  if (list.length > 40) out += `\n... و ${list.length - 40} آخرين`;
  return out;
}

// ── الضامنون ────────────────────────────────────────────────────────────────
function guarantorsReport(db: AppDB): string {
  if (db.guarantors.length === 0) return "لا يوجد ضامنون مسجَّلون.";
  const typeLabel: Record<string, string> = {
    personal: "شخصي", company: "شركة", relative: "قريب",
  };
  let out = `🛡️ <b>الضامنون (${db.guarantors.length})</b>\n━━━━━━━━━━━━━━━━━━\n\n`;
  for (const g of db.guarantors.slice(0, 50)) {
    out += `• <b>${esc(g.name)}</b> — 📞 ${esc(g.phone)}`;
    if (g.type) out += ` (${typeLabel[g.type] ?? g.type})`;
    out += "\n";
  }
  return out;
}

// ── تفاصيل مجموعة محددة بالرقم ───────────────────────────────────────────────
function groupDetail(db: AppDB, query: string): string {
  const q = query.trim();
  if (!q) return "✍️ اكتب رقم الخط بعد الأمر.\nمثال: <code>/مجموعة 0100</code>";
  const g = db.groups.find((x) => x.phone.includes(q));
  if (!g) return `لا توجد مجموعة رقمها يحتوي "${esc(q)}"`;
  const members = membersOf(db, g.id);
  const debt = groupDebt(db, g.id);
  const profit = groupProfit(db, g.id);
  const debtorsHere = members.filter((m) => m.balance < 0).length;
  let out = `📡 <b>تفاصيل الخط ${esc(g.phone)}</b>\n━━━━━━━━━━━━━━━━━━\n`;
  if (g.ownerName) out += `👤 صاحب الخط: ${esc(g.ownerName)}\n`;
  if (g.provider) out += `🏢 الشركة: ${PROV_NAME[g.provider] ?? g.provider}\n`;
  out += `👥 العملاء: <b>${members.length}</b>${g.maxClients ? ` / ${g.maxClients}` : ""}\n`;
  out += `🔴 مدينون: <b>${debtorsHere}</b>\n`;
  out += `💵 الفاتورة الثابتة: ${n0(num(g.fixedBillAmount))} ج\n`;
  out += `📈 ربح المجموعة: <code>${n0(profit)} ج</code>\n`;
  if (debt > 0) out += `💸 ديون العملاء: <code>${n0(debt)} ج</code>\n`;
  if (g.expiryDate) out += `📅 ينتهي: ${esc(g.expiryDate)}\n`;
  if (num(g.rewardPoints) > 0) out += `🪙 نقاط: ${n0(num(g.rewardPoints))}\n`;
  out += `\n<b>العملاء:</b>\n`;
  for (const m of members) {
    out += `${flagOf(m)} ${esc(m.name)} — ${m.balance < 0 ? "دين " + n0(-m.balance) + " ج" : n0(m.price) + " ج"}\n`;
  }
  return out;
}

// ── سعة المجموعات (عدد العملاء مقابل الحد الأقصى) ────────────────────────────
function capacityReport(db: AppDB): string {
  let out = "📊 <b>سعة المجموعات</b>\n━━━━━━━━━━━━━━━━━━\n\n";
  for (const g of db.groups) {
    const used = membersOf(db, g.id).length;
    const max = g.maxClients ?? 0;
    const bar = max > 0 ? `${used}/${max}` : `${used}`;
    const mark = max > 0 && used >= max ? "🔴" : max > 0 && used >= max - 1 ? "🟡" : "🟢";
    out += `${mark} ${esc(g.phone)} — <b>${bar}</b>\n`;
  }
  return out;
}

// ── مجموعات فيها أماكن فاضية ─────────────────────────────────────────────────
function availableSlotsReport(db: AppDB): string {
  const list = db.groups
    .map((g) => ({ g, free: (g.maxClients ?? 0) - membersOf(db, g.id).length }))
    .filter((x) => (x.g.maxClients ?? 0) > 0 && x.free > 0)
    .sort((a, b) => b.free - a.free);
  if (list.length === 0) return "🔴 لا توجد أماكن فاضية في أي مجموعة";
  let out = "🟢 <b>مجموعات بها أماكن فاضية</b>\n\n";
  for (const { g, free } of list) {
    out += `📡 ${esc(g.phone)} — فاضي <b>${free}</b> مكان\n`;
  }
  return out;
}

// ── مجموعات ممتلئة أو زيادة ──────────────────────────────────────────────────
function fullGroupsReport(db: AppDB): string {
  const list = db.groups
    .map((g) => ({ g, used: membersOf(db, g.id).length, max: g.maxClients ?? 0 }))
    .filter((x) => x.max > 0 && x.used >= x.max);
  if (list.length === 0) return "✅ لا توجد مجموعات ممتلئة";
  let out = "🔴 <b>مجموعات ممتلئة / بزيادة</b>\n\n";
  for (const { g, used, max } of list) {
    const over = used - max;
    out += `📡 ${esc(g.phone)} — <b>${used}/${max}</b>${over > 0 ? ` (زيادة ${over})` : ""}\n`;
  }
  return out;
}

// ── النقاط لكل مجموعة ────────────────────────────────────────────────────────
function pointsReport(db: AppDB): string {
  const list = db.groups.filter((g) => num(g.rewardPoints) > 0);
  if (list.length === 0) return "لا توجد نقاط مسجَّلة على أي خط.";
  let totalPts = 0, totalVal = 0;
  let out = "🪙 <b>نقاط المكافآت لكل خط</b>\n━━━━━━━━━━━━━━━━━━\n\n";
  for (const g of list) {
    const pts = num(g.rewardPoints);
    const val = pts * num(g.pointsValue);
    totalPts += pts; totalVal += val;
    out += `📡 ${esc(g.phone)} — <b>${n0(pts)}</b> نقطة (~${n0(val)} ج)\n`;
  }
  out += `\n💰 الإجمالي: <b>${n0(totalPts)}</b> نقطة ≈ <code>${n0(totalVal)} ج</code>`;
  return out;
}

// ── أرباح الهدايا لكل مجموعة ─────────────────────────────────────────────────
function giftsReport(db: AppDB): string {
  const list = db.groups.filter((g) => num(g.giftProfit) > 0);
  const total = giftProfitTotal(db);
  if (list.length === 0) return "لا توجد أرباح هدايا مسجَّلة.";
  let out = `🎁 <b>أرباح الهدايا</b>\nالإجمالي: <code>${n0(total)} ج</code>\n\n`;
  for (const g of list) {
    out += `📡 ${esc(g.phone)} — <b>${n0(num(g.giftProfit))} ج</b>\n`;
  }
  return out;
}

// ── القسائم القادمة ─────────────────────────────────────────────────────────
function vouchersReport(db: AppDB): string {
  const list = db.groups.filter((g) => num(g.voucherValue) > 0);
  if (list.length === 0) return "لا توجد قسائم مسجَّلة.";
  let out = "🎟️ <b>القسائم</b>\n━━━━━━━━━━━━━━━━━━\n\n";
  for (const g of list) {
    out += `📡 ${esc(g.phone)} — <b>${n0(num(g.voucherValue))} ج</b>`;
    if (g.voucherStartDate) out += ` (تبدأ ${esc(g.voucherStartDate)}، كل ${g.voucherPeriod === "1y" ? "سنة" : "6 شهور"})`;
    out += "\n";
  }
  return out;
}

// ── مطالبات التأمين القريبة ──────────────────────────────────────────────────
function insuranceReport(db: AppDB): string {
  const list = db.groups
    .filter((g) => num(g.refundableInsurance) > 0)
    .map((g) => ({ g, d: daysUntil(g.insuranceClaimDate) }));
  if (list.length === 0) return "لا يوجد تأمين مسترد مسجَّل.";
  let out = "🛡️ <b>التأمين المسترد</b>\n━━━━━━━━━━━━━━━━━━\n\n";
  for (const { g, d } of list) {
    out += `📡 ${esc(g.phone)} — <b>${n0(num(g.refundableInsurance))} ج</b>`;
    if (g.insuranceClaimDate) {
      const when = d === null ? "" : d < 0 ? ` (حان منذ ${-d} يوم)` : ` (بعد ${d} يوم)`;
      out += ` — مطالبة: ${esc(g.insuranceClaimDate)}${when}`;
    }
    out += "\n";
  }
  return out;
}

// ── العروض المنتهية قريباً ───────────────────────────────────────────────────
function offersReport(db: AppDB): string {
  const now = Date.now();
  const list = db.groups
    .filter((g) => g.offerEndDate)
    .map((g) => ({ g, d: Math.floor((new Date(g.offerEndDate!).getTime() - now) / 86400000) }))
    .filter((e) => !isNaN(e.d) && e.d >= -5 && e.d <= 75)
    .sort((a, b) => a.d - b.d);
  if (list.length === 0) return "✅ لا توجد عروض تنتهي قريباً";
  let out = "🎯 <b>عروض تنتهي قريباً</b>\n━━━━━━━━━━━━━━━━━━\n\n";
  for (const { g, d } of list) {
    const em = d < 0 ? "🔴" : d <= 14 ? "🟠" : "🟡";
    const txt = d < 0 ? `انتهى منذ ${-d} يوم` : `بعد ${d} يوم`;
    out += `${em} ${esc(g.phone)} — ${txt} (${esc(g.offerEndDate)})\n`;
  }
  return out;
}

// ── الفواتير المدفوعة ────────────────────────────────────────────────────────
function paidBillsReport(db: AppDB): string {
  const paid = db.companyBills.filter((b) => billIsPaid(b));
  if (paid.length === 0) return "لا توجد فواتير مدفوعة بعد.";
  const total = paid.reduce((s, b) => s + num(b.actualAmount), 0);
  let out = `✅ <b>فواتير مدفوعة (${paid.length})</b>\nالإجمالي: <code>${n0(total)} ج</code>\n\n`;
  for (const b of paid.slice(0, 40)) {
    const g = groupByGid(db, b.groupId);
    out += `• ${esc(g?.phone ?? "?")} — ${n0(num(b.actualAmount))} ج (${esc(b.month)})\n`;
  }
  return out;
}

// ── ملخص حسب الشركة ──────────────────────────────────────────────────────────
function providerSummary(db: AppDB, provider: string): string {
  const groups = db.groups.filter((g) => g.provider === provider);
  if (groups.length === 0) return `لا توجد خطوط لشركة ${PROV_NAME[provider] ?? provider}`;
  const ids = new Set(groups.map((g) => g.id));
  const members = db.members.filter((m) => ids.has(m.gid));
  const debt = members.filter((m) => m.balance < 0).reduce((s, m) => s + -m.balance, 0);
  const profit = groups.reduce((s, g) => s + groupProfit(db, g.id), 0);
  const billsOwed = db.companyBills.filter((b) => ids.has(b.groupId) && !billIsPaid(b)).reduce((s, b) => s + billRemaining(b), 0);
  return `${PROV_EMOJI[provider] ?? "📡"} <b>ملخص ${PROV_NAME[provider] ?? provider}</b>
━━━━━━━━━━━━━━━━━━
📡 الخطوط: <b>${groups.length}</b>
👥 العملاء: <b>${members.length}</b>
📈 الربح: <code>${n0(profit)} ج</code>
💸 ديون العملاء: <code>${n0(debt)} ج</code>
📋 فواتير مستحقة: <code>${n0(billsOwed)} ج</code>`;
}

// ── أرقام الشغل ──────────────────────────────────────────────────────────────
function workNumsReport(db: AppDB): string {
  if (db.workNums.length === 0) return "لا توجد أرقام مسجَّلة.";
  const statusEmoji: Record<string, string> = {
    available: "🟢", reserved: "🟡", needsRenewal: "🟠", damaged: "🔴",
  };
  let out = "📇 <b>أرقام الشغل / المخزون</b>\n━━━━━━━━━━━━━━━━━━\n\n";
  for (const w of db.workNums.slice(0, 60)) {
    const em = statusEmoji[w.status ?? "available"] ?? "•";
    out += `${em} <code>${esc(w.phone)}</code>`;
    if (w.label) out += ` — ${esc(w.label)}`;
    if (w.provider) out += ` (${PROV_NAME[w.provider] ?? w.provider})`;
    out += "\n";
  }
  return out;
}

// ── (1) الفواتير المضاعفة: زادت 75%+ عن الشهر السابق ────────────────────────
function doubledBillsReport(db: AppDB): string {
  const now = new Date();
  const curM = currentMonth();
  const prevM = prevMonth(curM);
  const hits: string[] = [];
  for (const b of db.companyBills.filter((x) => x.month === curM)) {
    const prev = db.companyBills.find((x) => x.groupId === b.groupId && x.month === prevM);
    if (prev && prev.actualAmount > 0 && b.actualAmount >= prev.actualAmount * 1.75) {
      const g = findGroup(db, b.groupId) ?? ({ phone: "?" } as Group);
      const pct = Math.round(((b.actualAmount - prev.actualAmount) / prev.actualAmount) * 100);
      hits.push(`🔴 <b>${esc(g.phone)}</b>${g.ownerName ? ` (${esc(g.ownerName)})` : ""}\n   ${n0(prev.actualAmount)} ج ← ${n0(b.actualAmount)} ج (+${pct}%)`);
    }
  }
  if (hits.length === 0) return "✅ لا توجد فواتير مضاعفة هذا الشهر — كله طبيعي 👍";
  return `🚨 <b>فواتير مضاعفة هذا الشهر!</b>\nراجعها فوراً (احتمال خطأ شركة أو استهلاك زائد):\n━━━━━━━━━━━━━━━━━━\n\n${hits.join("\n\n")}`;
}

// ── (2) أرقام مخزون قربت تتقفل (محتاجة اتصال) ───────────────────────────────
function lineRenewalReport(db: AppDB, deactivationDays = 90, reminderDays = 15): string {
  const now = Date.now();
  const rows: Array<{ w: WorkNum; left: number }> = [];
  for (const w of db.workNums) {
    if (w.status === "damaged") continue;
    if (!w.lastContactDate) continue;
    const last = new Date(w.lastContactDate);
    if (isNaN(last.getTime())) continue;
    const daysSince = Math.floor((now - last.getTime()) / 86400000);
    const limit = w.reminderDaysOverride ?? deactivationDays;
    const left = limit - daysSince; // أيام متبقية قبل التقفيل
    if (left <= reminderDays) rows.push({ w, left });
  }
  if (rows.length === 0) return "✅ لا توجد أرقام معرّضة للتقفيل قريباً 👍";
  rows.sort((a, b) => a.left - b.left);
  let out = "⏰ <b>أرقام محتاجة اتصال قبل التقفيل!</b>\n━━━━━━━━━━━━━━━━━━\n\n";
  for (const { w, left } of rows) {
    const em = left <= 0 ? "🔴" : left <= 5 ? "🟠" : "🟡";
    const txt = left <= 0 ? `تجاوز الموعد بـ ${-left} يوم!` : `باقي ${left} يوم`;
    out += `${em} <code>${esc(w.phone)}</code>${w.label ? ` — ${esc(w.label)}` : ""} — ${txt}\n`;
  }
  out += "\n💡 اعمل اتصال/تفعيل على الأرقام دي عشان متتقفلش.";
  return out;
}

// ── (3) كشف العملاء النايمين: دين ثابت ومافيش تواصل ─────────────────────────
function dormantDebtorsReport(db: AppDB): string {
  // نعتمد على paymentFlag الأحمر كإشارة دين قديم/خطر + غياب تأجيل نشط
  const list = db.members
    .filter((m) => m.balance < -200 && m.paymentFlag === "red" && !m.deferralDate)
    .sort((a, b) => a.balance - b.balance);
  if (list.length === 0) return "✅ لا يوجد عملاء متعثرين بحاجة متابعة عاجلة 👍";
  const total = list.reduce((s, m) => s + -m.balance, 0);
  let out = `😴 <b>عملاء محتاجين متابعة عاجلة</b>\n(دين مرتفع + علامة حمراء + بدون تأجيل)\nالعدد: <b>${list.length}</b> — الإجمالي: <code>${n0(total)} ج</code>\n━━━━━━━━━━━━━━━━━━\n\n`;
  let i = 0;
  for (const m of list.slice(0, 30)) {
    i++;
    out += `${i}. 🔴 <b>${esc(m.name)}</b> — <code>${n0(-m.balance)} ج</code>\n   📞 ${esc(m.phone)}\n`;
  }
  if (list.length > 30) out += `\n... و ${list.length - 30} آخرين`;
  out += `\n\n💬 لتذكير سريع: /واتس [اسم العميل]`;
  return out;
}

// ── (4) المتوقع تحصيله: تأجيلات حلّ موعدها/قرب ──────────────────────────────
function expectedCollectionReport(db: AppDB, withinDays = 7): string {
  const list = db.members.filter((m) => {
    const d = daysUntil(m.deferralDate);
    return d !== null && d <= withinDays && m.balance < 0;
  });
  if (list.length === 0) return `لا توجد تحصيلات متوقعة (تأجيلات مستحقة) خلال ${withinDays} يوم.`;
  const expected = list.reduce((s, m) => s + -m.balance, 0);
  let out = `💰 <b>المتوقع تحصيله خلال ${withinDays} يوم</b>\n`;
  out += `الإجمالي المتوقع: <code>${n0(expected)} ج</code> من ${list.length} عميل\n━━━━━━━━━━━━━━━━━━\n\n`;
  list.sort((a, b) => daysUntil(a.deferralDate)! - daysUntil(b.deferralDate)!);
  for (const m of list) {
    const d = daysUntil(m.deferralDate)!;
    const w = d < 0 ? `فات ${-d} يوم` : d === 0 ? "النهاردة" : `بعد ${d} يوم`;
    out += `📅 <b>${esc(m.name)}</b> — <code>${n0(-m.balance)} ج</code> (${w})\n`;
  }
  return out;
}

// ── (5) ربط الفرص: خطوط فاضية + قائمة انتظار ────────────────────────────────
function matchOpportunitiesReport(db: AppDB): string {
  const freeGroups = db.groups
    .map((g) => ({ g, free: (g.maxClients ?? 0) - membersOf(db, g.id).length }))
    .filter((x) => (x.g.maxClients ?? 0) > 0 && x.free > 0);
  const totalFree = freeGroups.reduce((s, x) => s + x.free, 0);
  const waiting = db.waitlist.filter((w) => w.status !== "assigned");

  let out = "🔗 <b>ربط الفرص</b>\n━━━━━━━━━━━━━━━━━━\n\n";
  out += `🟢 أماكن فاضية: <b>${totalFree}</b> في ${freeGroups.length} خط\n`;
  out += `⏳ في قائمة الانتظار: <b>${waiting.length}</b>\n\n`;

  if (totalFree === 0) { out += "🔴 لا توجد أماكن فاضية حالياً."; return out; }
  if (waiting.length === 0) { out += "📋 قائمة الانتظار فاضية — مفيش حد تحطه دلوقتي."; return out; }

  out += `✅ <b>عندك فرصة!</b> تقدر تحط ${Math.min(totalFree, waiting.length)} من الانتظار:\n\n`;
  out += "<b>الأماكن المتاحة:</b>\n";
  for (const { g, free } of freeGroups) out += `📡 ${esc(g.phone)} — ${free} مكان\n`;
  out += "\n<b>أوائل قائمة الانتظار:</b>\n";
  for (const w of waiting.slice(0, totalFree)) {
    out += `👤 ${esc(w.name)} — 📞 ${esc(w.phone)}${w.packageType && w.packageType !== "any" ? ` (${esc(w.packageType)})` : ""}\n`;
  }
  return out;
}

// ── (9) حاسبة ربح خط قبل الإضافة ─────────────────────────────────────────────
function profitCalc(system: number, clients: number): string {
  // 3800 = 200 جيجا/260 سعر افتراضي ، غيره = 70 جيجا/190
  const isBig = system === 3800;
  const pricePerClient = isBig ? 260 : 190;
  const fixedBill = isBig ? 3800 : 1800; // تقديري للفاتورة الثابتة
  const income = clients * pricePerClient;
  const profit = income - fixedBill;
  return `🧮 <b>حاسبة ربح سريعة (تقديرية)</b>
━━━━━━━━━━━━━━━━━━
النظام: <b>${system}</b>
عدد العملاء: <b>${clients}</b>
سعر العميل (افتراضي): ${n0(pricePerClient)} ج
الدخل: ${n0(income)} ج
الفاتورة الثابتة (تقديري): ${n0(fixedBill)} ج
━━━━━━━━━━━━━━
${profit >= 0 ? "🟢" : "🔴"} <b>الربح المتوقع: ${n0(profit)} ج</b>

⚠️ أرقام تقديرية للمساعدة في القرار فقط — الأرقام الفعلية حسب إعداداتك في التطبيق.`;
}

// ── الملاحظات العامة ─────────────────────────────────────────────────────────
function notesReport(db: AppDB): string {
  const active = db.generalNotes.filter((n) => !n.isCompleted);
  if (active.length === 0) return "✅ لا توجد ملاحظات مفتوحة.";
  let out = `📝 <b>الملاحظات (${active.length})</b>\n━━━━━━━━━━━━━━━━━━\n\n`;
  for (const nt of active.slice(0, 30)) {
    const body = (nt.content ?? "").toString();
    if (!body) continue;
    out += `• ${esc(body.length > 150 ? body.slice(0, 150) + "…" : body)}\n`;
    if (nt.reminderTime) {
      const d = daysUntil(nt.reminderTime);
      const when = d === null ? "" : d < 0 ? ` (فات ${-d} يوم)` : d === 0 ? " (النهاردة!)" : ` (بعد ${d} يوم)`;
      out += `   ⏰ ${esc(String(nt.reminderTime).slice(0, 10))}${when}\n`;
    }
  }
  return out;
}

// ── آخر نشاط ─────────────────────────────────────────────────────────────────
function activityReport(db: AppDB, count: number): string {
  const n = count > 0 ? count : 15;
  if (db.activityLog.length === 0) return "لا يوجد نشاط مسجَّل.";
  const recent = db.activityLog.slice(-n).reverse();
  let out = `🕑 <b>آخر ${recent.length} نشاط</b>\n━━━━━━━━━━━━━━━━━━\n\n`;
  for (const a of recent) {
    const desc = (a["desc"] ?? a["text"] ?? "").toString();
    const date = (a["date"] ?? "").toString();
    out += `• ${esc(desc)}${date ? ` <i>(${esc(date)})</i>` : ""}\n`;
  }
  return out;
}

// ── إحصائيات سريعة للديون ────────────────────────────────────────────────────
function debtStatsReport(db: AppDB): string {
  const debtors = db.members.filter((m) => m.balance < 0);
  if (debtors.length === 0) return "✅ لا توجد مديونيات 🎉";
  const total = debtors.reduce((s, m) => s + -m.balance, 0);
  const avg = total / debtors.length;
  const max = Math.max(...debtors.map((m) => -m.balance));
  const red = debtors.filter((m) => m.paymentFlag === "red").length;
  const over500 = debtors.filter((m) => -m.balance > 500).length;
  return `📊 <b>إحصائيات الديون</b>
━━━━━━━━━━━━━━━━━━
👥 عدد المدينين: <b>${debtors.length}</b>
💸 إجمالي الديون: <code>${n0(total)} ج</code>
📈 متوسط الدين: <code>${n0(avg)} ج</code>
🔝 أكبر دين: <code>${n0(max)} ج</code>
🔴 بعلامة حمراء: <b>${red}</b>
⚠️ فوق 500 ج: <b>${over500}</b>`;
}

// ─── موجّه الأوامر (مطابق لـ telegram_service.dart) ──────────────────────────

function route(text: string, db: AppDB, ownerName: string): string {
  const raw = text.trim();
  const withSlash = raw.startsWith("/") ? raw : `/${raw}`;
  const parts = withSlash.split(/\s+/);
  const cmd = parts[0].replace(/@\w+/g, "").toLowerCase();
  // أول رقم في الأمر (لو موجود) — مثال: "/اكبر 5" → 5
  const arg = parts.slice(1).map((p) => parseInt(p, 10)).find((x) => !isNaN(x)) ?? 0;
  // باقي النص بعد الأمر (للبحث وتفاصيل المجموعة)
  const textArg = parts.slice(1).join(" ").trim();

  switch (cmd) {
    // ── مساعدة ──────────────────────────────────────────────
    case "/start":
    case "/help":
    case "/مساعدة":
    case "/اوامر":
    case "/أوامر":
      return welcome(ownerName);

    // ── نظرة عامة مالية ─────────────────────────────────────
    case "/تقرير":
    case "/report":
    case "/جرد":
    case "/inventory":
      return fullReport(db, ownerName);
    case "/ملخص":
    case "/summary":
      return quickDashboard(db);
    case "/ربح":
    case "/profit":
    case "/ارباح":
    case "/أرباح":
    case "/profits":
      return profitReport(db);
    case "/صافي":
    case "/net":
      return netOnly(db);
    case "/دخل":
    case "/income":
      return incomeOnly(db);
    case "/مستحقاتي":
    case "/ليا":
    case "/receivables":
      return receivablesOnly(db);
    case "/عليا":
    case "/عليّا":
    case "/payables":
      return payablesOnly(db);
    case "/اليوم":
    case "/today":
      return todaySummary(db);

    // ── المديونيات ──────────────────────────────────────────
    case "/ديون":
    case "/debts":
      return debtsReport(db);
    case "/اكبر":
    case "/أكبر":
    case "/top":
      return topDebtorsReport(db, arg);
    case "/اصغر":
    case "/أصغر":
    case "/bottom":
      return smallDebtorsReport(db, arg);
    case "/فوق":
    case "/above":
      return debtorsAboveReport(db, arg);
    case "/حمر":
    case "/حمراء":
    case "/red":
      return flaggedReport(db, "red");
    case "/صفرا":
    case "/صفراء":
    case "/yellow":
      return flaggedReport(db, "yellow");
    case "/احصاء_ديون":
    case "/debtstats":
      return debtStatsReport(db);
    case "/بدون_ضامن":
    case "/مخاطرة":
    case "/risk":
      return noGuarantorRiskReport(db);

    // ── التأجيلات ───────────────────────────────────────────
    case "/مؤجل":
    case "/مؤجلين":
    case "/تاجيل":
    case "/deferred":
      return deferredReport(db);
    case "/تأجيلات":
    case "/due":
      return deferralsDueReport(db, arg);

    // ── العملاء ─────────────────────────────────────────────
    case "/عملاء":
    case "/members":
      return membersReport(db);
    case "/بحث":
    case "/search":
      return searchMembers(db, textArg);
    case "/كبار":
    case "/vip":
      return topPayingReport(db, arg);
    case "/جدد":
    case "/recent":
      return recentMembersReport(db, arg);
    case "/نظاف":
    case "/clear":
      return clearMembersReport(db);
    case "/مجاني":
    case "/صفر":
    case "/zero":
      return zeroPriceReport(db);
    case "/ضامنين":
    case "/ضامنون":
    case "/guarantors":
      return guarantorsReport(db);

    // ── المجموعات والخطوط ───────────────────────────────────
    case "/مجموعات":
    case "/groups":
      return groupsReport(db);
    case "/مجموعة":
    case "/خط":
    case "/group":
      return groupDetail(db, textArg);
    case "/سعة":
    case "/capacity":
      return capacityReport(db);
    case "/متاح":
    case "/فاضي":
    case "/available":
      return availableSlotsReport(db);
    case "/ممتلئ":
    case "/full":
      return fullGroupsReport(db);
    case "/نقاط":
    case "/points":
      return pointsReport(db);
    case "/هدايا":
    case "/gifts":
      return giftsReport(db);
    case "/قسائم":
    case "/vouchers":
      return vouchersReport(db);
    case "/تأمين":
    case "/insurance":
      return insuranceReport(db);
    case "/انتهاء":
    case "/expiry":
      return expiryReport(db);
    case "/عروض":
    case "/offers":
      return offersReport(db);

    // ── الفواتير ────────────────────────────────────────────
    case "/فواتير":
    case "/bills":
      return billsReport(db);
    case "/مدفوع":
    case "/مدفوعة":
    case "/paid":
      return paidBillsReport(db);

    // ── حسب الشركة ──────────────────────────────────────────
    case "/اتصالات":
    case "/etisalat":
      return providerSummary(db, "etisalat");
    case "/فودافون":
    case "/vodafone":
      return providerSummary(db, "vodafone");
    case "/اورانج":
    case "/أورانج":
    case "/orange":
      return providerSummary(db, "orange");
    case "/وي":
    case "/we":
      return providerSummary(db, "we");

    // ── أخرى ────────────────────────────────────────────────
    case "/ايجارات":
    case "/rentals":
      return rentalsReport(db);
    case "/ضيوف":
    case "/guests":
      return guestsReport(db);
    case "/انتظار":
    case "/waitlist":
      return waitlistReport(db);
    case "/ارقام":
    case "/أرقام":
    case "/numbers":
      return workNumsReport(db);
    case "/ملاحظات":
    case "/notes":
      return notesReport(db);
    case "/نشاط":
    case "/activity":
      return activityReport(db, arg);
    case "/تنبيهات":
    case "/alerts":
      return alertsReport(db);

    // ── تنبيهات وقائية وذكية (الحزمة الجديدة) ───────────────
    case "/مضاعفة":
    case "/مضاعف":
    case "/doubled":
      return doubledBillsReport(db);
    case "/تجديد":
    case "/تقفيل":
    case "/renewal":
      return lineRenewalReport(db);
    case "/متعثرين":
    case "/نايمين":
    case "/dormant":
      return dormantDebtorsReport(db);
    case "/متوقع":
    case "/تحصيل":
    case "/expected":
      return expectedCollectionReport(db, arg > 0 ? arg : 7);
    case "/فرص":
    case "/match":
      return matchOpportunitiesReport(db);
    case "/احسب":
    case "/حاسبة":
    case "/calc": {
      const sys = parts.slice(1).map((p) => parseInt(p, 10)).find((x) => x === 3800 || x === 1800) ?? 3800;
      const clients = parts.slice(1).map((p) => parseInt(p, 10)).find((x) => x > 0 && x !== 3800 && x !== 1800) ?? 0;
      if (clients === 0) return "✍️ اكتب: <code>/احسب 3800 5</code>\n(النظام: 3800 أو 1800، وعدد العملاء)";
      return profitCalc(sys, clients);
    }

    default:
      return "❓ أمر غير معروف.\nأرسل /مساعدة لعرض كل الأوامر المتاحة.";
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ميزات تفاعلية: واتساب + كارت العميل + الأزرار + الرسم البياني
// ═══════════════════════════════════════════════════════════════════════════

// تحويل رقم مصري لصيغة wa.me (كود الدولة 20 بدون صفر البداية)
function normalizeEg(phone: string): string {
  let p = (phone ?? "").replace(/[^0-9]/g, "");
  if (p.startsWith("0020")) p = p.slice(2);
  if (p.startsWith("20")) return p;
  if (p.startsWith("0")) return "20" + p.slice(1);
  if (p.length === 10) return "20" + p; // 1xxxxxxxxx
  return p;
}

// رسالة تذكير المديونية الجاهزة
function waReminderText(m: Member, ownerName: string): string {
  const debt = -m.balance;
  return `السلام عليكم ${m.name} 🌟
نحب نذكّر حضرتك بقيمة المستحق: ${n0(debt)} ج
برجاء السداد في أقرب وقت، ولو تم السداد تجاهل الرسالة 🙏
${ownerName}`;
}

function waLink(phone: string, text: string): string {
  return `https://wa.me/${normalizeEg(phone)}?text=${encodeURIComponent(text)}`;
}

const findMember = (db: AppDB, id: string) => db.members.find((m) => m.id === id);

// كارت العميل الكامل + أزرار (واتساب / كارت)
function memberCard(db: AppDB, m: Member, ownerName: string): { text: string; keyboard: unknown } {
  const g = groupByGid(db, m.gid);
  let t = `👤 <b>${esc(m.name)}</b>\n━━━━━━━━━━━━━━━━━━\n`;
  t += `📞 الهاتف: <code>${esc(m.phone)}</code>\n`;
  t += `💵 الاشتراك: <b>${n0(m.price)} ج</b>\n`;
  if (m.balance < 0) t += `🔴 المديونية: <code>${n0(-m.balance)} ج</code> ${flagOf(m)}\n`;
  else if (m.balance > 0) t += `🟢 رصيد دائن: <code>${n0(m.balance)} ج</code>\n`;
  else t += `✅ الحساب مسدّد\n`;
  if (m.package) t += `📦 الباقة: ${esc(m.package)}\n`;
  if (g) t += `📡 الخط: ${esc(g.phone)}${g.ownerName ? ` (${esc(g.ownerName)})` : ""}\n`;
  if (m.guarantorName) t += `🛡️ الضامن: ${esc(m.guarantorName)}\n`;
  if (m.deferralDate) {
    const d = daysUntil(m.deferralDate);
    const w = d === null ? "" : d < 0 ? ` (فات ${-d} يوم)` : d === 0 ? " (النهاردة)" : ` (بعد ${d} يوم)`;
    t += `⏳ مؤجل لـ: ${esc(m.deferralDate)}${w}\n`;
  }
  if (m.date) t += `📅 الاشتراك من: ${esc(m.date)}\n`;

  const row: Array<Record<string, string>> = [];
  if (m.phone) {
    const msg = m.balance < 0 ? waReminderText(m, ownerName) : `السلام عليكم ${m.name} 🌟`;
    row.push({ text: "💬 واتساب", url: waLink(m.phone, msg) });
  }
  const keyboard = { inline_keyboard: row.length ? [row] : [] };
  return { text: t, keyboard };
}

// أمر /واتس [اسم] — يرجّع لينكات واتساب جاهزة للمطابقين
function whatsappCmd(db: AppDB, query: string, ownerName: string): { text: string; keyboard: unknown } {
  const q = query.trim().toLowerCase();
  if (!q) return { text: "✍️ اكتب اسم أو رقم العميل.\nمثال: <code>/واتس احمد</code>", keyboard: { inline_keyboard: [] } };
  const hits = db.members.filter((m) => m.name.toLowerCase().includes(q) || m.phone.includes(q));
  if (hits.length === 0) return { text: `🔍 لا يوجد عميل مطابق لـ "${esc(query)}"`, keyboard: { inline_keyboard: [] } };

  let t = `💬 <b>واتساب — نتائج "${esc(query)}"</b>\nاضغط على الزر لفتح المحادثة برسالة جاهزة:\n`;
  const rows: Array<Array<Record<string, string>>> = [];
  for (const m of hits.slice(0, 10)) {
    const msg = m.balance < 0 ? waReminderText(m, ownerName) : `السلام عليكم ${m.name} 🌟`;
    const label = `${m.name}${m.balance < 0 ? ` (${n0(-m.balance)} ج)` : ""}`;
    rows.push([{ text: `💬 ${label}`.slice(0, 60), url: waLink(m.phone, msg) }]);
  }
  return { text: t, keyboard: { inline_keyboard: rows } };
}

// لوحة المنيو الرئيسية (أزرار)
function mainMenuKeyboard(): unknown {
  return {
    inline_keyboard: [
      [{ text: "📌 ملخص", callback_data: "summary" }, { text: "📊 تقرير", callback_data: "report" }],
      [{ text: "💸 الديون", callback_data: "debts" }, { text: "🔝 أكبر 5", callback_data: "top" }],
      [{ text: "⏳ تأجيلات", callback_data: "deferred" }, { text: "⚠️ تنبيهات", callback_data: "alerts" }],
      [{ text: "💹 الأرباح", callback_data: "profit" }, { text: "📋 فواتير", callback_data: "bills" }],
      [{ text: "📡 مجموعات", callback_data: "groups" }, { text: "🔗 فرص", callback_data: "match" }],
      [{ text: "🚨 مضاعفة", callback_data: "مضاعفة" }, { text: "⏰ تجديد", callback_data: "تجديد" }],
      [{ text: "💰 متوقع", callback_data: "متوقع" }, { text: "😴 متعثرين", callback_data: "متعثرين" }],
      [{ text: "📈 رسم بياني", callback_data: "chart" }, { text: "❓ كل الأوامر", callback_data: "help" }],
    ],
  };
}

// رابط رسم بياني (QuickChart) — لقطة مالية بعناوين إنجليزية (تُعرض بوضوح)
function financialChartUrl(db: AppDB): string {
  const income = Math.round(totalMonthlyIncome(db));
  const debts = Math.round(totalDebt(db));
  const profit = Math.round(netProfit(db));
  const bills = Math.round(totalBillsOwed(db));
  const config = {
    type: "bar",
    data: {
      labels: ["Income", "Debts", "Net Profit", "Bills Owed"],
      datasets: [{
        label: "EGP",
        data: [income, debts, profit, bills],
        backgroundColor: ["#2e7d32", "#c62828", "#1565c0", "#ef6c00"],
      }],
    },
    options: {
      plugins: { legend: { display: false }, title: { display: true, text: "Financial Snapshot (EGP)" } },
    },
  };
  return `https://quickchart.io/chart?w=600&h=380&bkg=white&c=${encodeURIComponent(JSON.stringify(config))}`;
}

// رابط رسم بياني لأرباح كل شركة
function providerChartUrl(db: AppDB): string {
  const provs = ["etisalat", "vodafone", "orange", "we"];
  const names = ["Etisalat", "Vodafone", "Orange", "WE"];
  const data = provs.map((p) =>
    Math.round(db.groups.filter((g) => g.provider === p).reduce((s, g) => s + groupProfit(db, g.id), 0))
  );
  const config = {
    type: "bar",
    data: { labels: names, datasets: [{ label: "Profit EGP", data, backgroundColor: ["#2e7d32", "#c62828", "#ef6c00", "#6a1b9a"] }] },
    options: { plugins: { legend: { display: false }, title: { display: true, text: "Profit by Provider (EGP)" } } },
  };
  return `https://quickchart.io/chart?w=600&h=380&bkg=white&c=${encodeURIComponent(JSON.stringify(config))}`;
}

// ─── إرسال رسالة عبر تليجرام (مع تقسيم الرسائل الطويلة + أزرار اختيارية) ───────

async function sendMessage(
  token: string,
  chatId: number | string,
  text: string,
  replyMarkup?: unknown,
) {
  const chunks: string[] = [];
  let remaining = text;
  while (remaining.length > 4000) {
    let cut = remaining.lastIndexOf("\n", 4000);
    if (cut < 1) cut = 4000;
    chunks.push(remaining.slice(0, cut));
    remaining = remaining.slice(cut);
  }
  chunks.push(remaining);

  for (let i = 0; i < chunks.length; i++) {
    const body: Record<string, unknown> = {
      chat_id: chatId,
      text: chunks[i],
      parse_mode: "HTML",
      disable_web_page_preview: true,
    };
    // الأزرار تُرفق مع آخر جزء فقط
    if (replyMarkup && i === chunks.length - 1) body.reply_markup = replyMarkup;
    await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  }
}

async function sendPhoto(token: string, chatId: number | string, photoUrl: string, caption: string) {
  await fetch(`https://api.telegram.org/bot${token}/sendPhoto`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ chat_id: chatId, photo: photoUrl, caption, parse_mode: "HTML" }),
  });
}

async function answerCallback(token: string, callbackId: string) {
  await fetch(`https://api.telegram.org/bot${token}/answerCallbackQuery`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ callback_query_id: callbackId }),
  });
}

// ينفّذ أمراً ويرسله (يتعامل مع الأوامر الخاصة: واتساب / رسم / قائمة / كارت)
async function execAndSend(
  token: string,
  chatId: number | string,
  raw: string,
  db: AppDB,
  ownerName: string,
) {
  const parts = (raw.startsWith("/") ? raw : `/${raw}`).split(/\s+/);
  const cmd = parts[0].replace(/@\w+/g, "").toLowerCase();
  const textArg = parts.slice(1).join(" ").trim();

  // قائمة الأزرار
  if (cmd === "/قائمة" || cmd === "/menu") {
    await sendMessage(token, chatId, "🎛️ <b>القائمة الرئيسية</b>\nاختر من الأزرار:", mainMenuKeyboard());
    return;
  }
  // واتساب
  if (cmd === "/واتس" || cmd === "/واتساب" || cmd === "/wa" || cmd === "/whatsapp") {
    const r = whatsappCmd(db, textArg, ownerName);
    await sendMessage(token, chatId, r.text, r.keyboard);
    return;
  }
  // كارت عميل (بحث يرجّع أول نتيجة ككارت)
  if (cmd === "/كارت" || cmd === "/card") {
    const q = textArg.toLowerCase();
    const hit = db.members.find((m) => m.name.toLowerCase().includes(q) || m.phone.includes(q));
    if (!hit) { await sendMessage(token, chatId, `🔍 لا يوجد عميل مطابق لـ "${esc(textArg)}"`); return; }
    const c = memberCard(db, hit, ownerName);
    await sendMessage(token, chatId, c.text, c.keyboard);
    return;
  }
  // رسم بياني
  if (cmd === "/رسم" || cmd === "/chart" || cmd === "/graph") {
    await sendPhoto(token, chatId, financialChartUrl(db), "📊 لقطة مالية");
    await sendPhoto(token, chatId, providerChartUrl(db), "📡 الأرباح حسب الشركة");
    return;
  }
  // أي أمر نصّي عادي
  const reply = route(raw, db, ownerName);
  // نُرفق منيو أزرار مع /start و /مساعدة
  const withMenu = cmd === "/start" || cmd === "/مساعدة" || cmd === "/help";
  await sendMessage(token, chatId, reply, withMenu ? mainMenuKeyboard() : undefined);
}

// ═══════════════════════════════════════════════════════════════════════════
//  التقارير التلقائية (Cron) — تقرير صباحي + تذكير تحصيل أسبوعي
// ═══════════════════════════════════════════════════════════════════════════

// تقرير صباحي: ملخص ديون + تأجيلات مستحقة + خطوط تنتهي قريباً + ديون مرتفعة
function dailyDigest(db: AppDB, ownerName: string): string {
  const now = new Date();
  const debtors = db.members.filter((m) => m.balance < 0);
  let out = `🌅 <b>تقرير الصباح — ${ownerName}</b>\n`;
  out += `📅 ${now.getDate()}/${now.getMonth() + 1}/${now.getFullYear()}\n━━━━━━━━━━━━━━━━━━\n\n`;

  out += `💸 <b>الديون:</b> ${debtors.length} مدين — إجمالي <code>${n0(totalDebt(db))} ج</code>\n`;
  const top3 = [...debtors].sort((a, b) => a.balance - b.balance).slice(0, 3);
  for (const m of top3) out += `   ${flagOf(m)} ${esc(m.name)} — ${n0(-m.balance)} ج\n`;

  // تأجيلات مستحقة خلال يومين
  const dueSoon = db.members.filter((m) => {
    const d = daysUntil(m.deferralDate);
    return d !== null && d <= 2;
  });
  if (dueSoon.length) {
    out += `\n⏳ <b>تأجيلات مستحقة:</b>\n`;
    for (const m of dueSoon) {
      const d = daysUntil(m.deferralDate)!;
      const w = d < 0 ? `فات ${-d} يوم` : d === 0 ? "النهاردة" : `بعد ${d} يوم`;
      out += `   📅 ${esc(m.name)} (${w})${m.balance < 0 ? ` — ${n0(-m.balance)} ج` : ""}\n`;
    }
  }

  // ديون مرتفعة فوق 500
  const high = debtors.filter((m) => -m.balance > 500);
  if (high.length) out += `\n⚠️ <b>${high.length}</b> عميل دينهم فوق 500 ج\n`;

  // خطوط تنتهي خلال 7 أيام
  const expSoon = db.groups.filter((g) => {
    const d = daysUntil(g.expiryDate);
    return d !== null && d >= 0 && d <= 7;
  });
  if (expSoon.length) {
    out += `\n📅 <b>خطوط تنتهي قريباً:</b>\n`;
    for (const g of expSoon) out += `   ⏰ ${esc(g.phone)} (بعد ${daysUntil(g.expiryDate)} يوم)\n`;
  }

  // فواتير مضاعفة هذا الشهر (تنبيه وقائي)
  const curM = currentMonth();
  const prevM = prevMonth(curM);
  const doubled = db.companyBills.filter((b) => {
    if (b.month !== curM) return false;
    const prev = db.companyBills.find((x) => x.groupId === b.groupId && x.month === prevM);
    return prev && prev.actualAmount > 0 && b.actualAmount >= prev.actualAmount * 1.75;
  });
  if (doubled.length) out += `\n\n🚨 <b>${doubled.length}</b> فاتورة مضاعفة هذا الشهر — اكتب /مضاعفة`;

  // أرقام مخزون قربت تتقفل
  const nowMs = Date.now();
  const renew = db.workNums.filter((w) => {
    if (w.status === "damaged" || !w.lastContactDate) return false;
    const last = new Date(w.lastContactDate);
    if (isNaN(last.getTime())) return false;
    const daysSince = Math.floor((nowMs - last.getTime()) / 86400000);
    return (w.reminderDaysOverride ?? 90) - daysSince <= 15;
  });
  if (renew.length) out += `\n⏰ <b>${renew.length}</b> رقم محتاج اتصال قبل التقفيل — اكتب /تجديد`;

  out += `\n\n💵 الدخل الشهري: <code>${n0(totalMonthlyIncome(db))} ج</code>`;
  out += `\n📈 صافي الربح: <code>${n0(netProfit(db))} ج</code>`;
  out += `\n\n💡 اكتب /قائمة لكل الخيارات.`;
  return out;
}

// تذكير التحصيل الأسبوعي: قائمة كل المدينين جاهزة للجولة
function weeklyDigest(db: AppDB, ownerName: string): string {
  const debtors = db.members.filter((m) => m.balance < 0).sort((a, b) => a.balance - b.balance);
  let out = `📋 <b>تذكير التحصيل الأسبوعي — ${ownerName}</b>\n━━━━━━━━━━━━━━━━━━\n`;
  if (debtors.length === 0) return out + "\n✅ لا توجد مديونيات — أسبوع موفّق! 🎉";
  out += `إجمالي للتحصيل: <code>${n0(totalDebt(db))} ج</code> من ${debtors.length} عميل\n\n`;
  let i = 0;
  for (const m of debtors.slice(0, 40)) {
    i++;
    out += `${i}. ${flagOf(m)} <b>${esc(m.name)}</b> — <code>${n0(-m.balance)} ج</code> | 📞 ${esc(m.phone)}\n`;
  }
  if (debtors.length > 40) out += `\n... و ${debtors.length - 40} آخرين (اكتب /ديون للكل)`;
  out += `\n\n💬 لإرسال تذكير واتساب: /واتس [اسم العميل]`;
  return out;
}

// يشغّل تقريراً تلقائياً لكل المستخدمين المفعّلين
async function runCron(
  supabase: ReturnType<typeof createClient>,
  type: string,
): Promise<string> {
  const { data: configs } = await supabase
    .from("telegram_config")
    .select("user_id, bot_token, chat_id, owner_name, enabled")
    .eq("enabled", true);

  if (!configs || configs.length === 0) return "no enabled configs";

  let sent = 0;
  for (const cfg of configs) {
    const token = cfg.bot_token as string;
    const chatId = cfg.chat_id as string;
    if (!token || !chatId) continue; // لازم chat_id لإرسال تلقائي

    const { data: row } = await supabase
      .from("user_data")
      .select("data")
      .eq("user_id", cfg.user_id)
      .maybeSingle();
    const db = emptyDB(row?.data as Partial<AppDB> | null);
    const ownerName = (cfg.owner_name as string) || "صاحب الحساب";

    try {
      const msg = type === "weekly" ? weeklyDigest(db, ownerName) : dailyDigest(db, ownerName);
      await sendMessage(token, chatId, msg);
      sent++;
    } catch (_) { /* تجاهل مستخدم فاشل وأكمل الباقي */ }
  }
  return `cron ${type}: sent ${sent}`;
}

// ─── المعالج الرئيسي ─────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  const url = new URL(req.url);

  // فحص صحة سريع (افتح الرابط في المتصفح للتأكد أن الدالة تعمل)
  if (req.method === "GET" && !url.searchParams.get("mode")) {
    return new Response("telegram-bot edge function is alive ✅", { status: 200 });
  }

  // ── وضع التقارير التلقائية (Cron) ──
  // يُستدعى من pg_cron: ?mode=cron&type=daily&key=SECRET
  if (url.searchParams.get("mode") === "cron") {
    const key = url.searchParams.get("key") ?? req.headers.get("x-cron-key");
    if (key !== Deno.env.get("CRON_SECRET")) {
      return new Response("forbidden", { status: 403 });
    }
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const type = url.searchParams.get("type") ?? "daily";
    const result = await runCron(supabase, type);
    return new Response(result, { status: 200 });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const uid = url.searchParams.get("uid");
  if (!uid) return new Response("missing uid", { status: 400 });

  // نرد دائماً 200 لتليجرام حتى لا يعيد المحاولة بلا نهاية.
  const ok = () => new Response("ok", { status: 200 });

  let update: Record<string, unknown>;
  try {
    update = await req.json();
  } catch {
    return ok();
  }

  // إما رسالة نصية أو ضغطة زر (callback)
  const callback = update["callback_query"] as Record<string, unknown> | undefined;
  const message = (update["message"] ?? update["edited_message"]) as
    | Record<string, unknown>
    | undefined;

  let fromChatId: number | undefined;
  let text = "";
  let callbackId = "";

  if (callback) {
    callbackId = (callback["id"] as string) ?? "";
    const cMsg = callback["message"] as Record<string, unknown> | undefined;
    const cChat = cMsg?.["chat"] as Record<string, unknown> | undefined;
    fromChatId = cChat?.["id"] as number | undefined;
    text = (callback["data"] as string) ?? "";
  } else {
    text = (message?.["text"] as string | undefined) ?? "";
    const chat = message?.["chat"] as Record<string, unknown> | undefined;
    fromChatId = chat?.["id"] as number | undefined;
  }
  if (!text || fromChatId == null) return ok();

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 1) جلب إعدادات البوت لهذا المستخدم
  const { data: cfg, error: cfgErr } = await supabase
    .from("telegram_config")
    .select("bot_token, chat_id, owner_name, enabled")
    .eq("user_id", uid)
    .maybeSingle();

  if (cfgErr || !cfg || !cfg.bot_token) return ok();
  if (cfg.enabled === false) return ok();

  const token = cfg.bot_token as string;
  const ownerName = (cfg.owner_name as string) || "صاحب الحساب";

  // 2) قفل المحادثة على المالك
  const savedChatId = cfg.chat_id ? String(cfg.chat_id) : "";
  if (savedChatId && savedChatId !== String(fromChatId)) {
    if (callbackId) await answerCallback(token, callbackId);
    await sendMessage(token, fromChatId, "🚫 هذا البوت خاص ولا يردّ إلا على صاحبه.");
    return ok();
  }

  // 3) جلب البيانات
  const { data: row } = await supabase
    .from("user_data")
    .select("data")
    .eq("user_id", uid)
    .maybeSingle();

  const db = emptyDB(row?.data as Partial<AppDB> | null);

  // 4) التنفيذ
  try {
    if (callbackId) await answerCallback(token, callbackId); // إيقاف مؤشر التحميل على الزر

    if (callback) {
      // ضغطة زر: data = "card:<id>" أو اسم أمر مثل "summary"/"chart"
      if (text.startsWith("card:")) {
        const m = findMember(db, text.slice(5));
        if (m) {
          const c = memberCard(db, m, ownerName);
          await sendMessage(token, fromChatId, c.text, c.keyboard);
        } else {
          await sendMessage(token, fromChatId, "تعذّر إيجاد العميل.");
        }
      } else {
        await execAndSend(token, fromChatId, "/" + text, db, ownerName);
      }
    } else {
      await execAndSend(token, fromChatId, text, db, ownerName);
    }
  } catch (e) {
    await sendMessage(token, fromChatId, `⚠️ حدث خطأ أثناء معالجة الأمر.\n<code>${esc(String(e))}</code>`);
  }

  return ok();
});
