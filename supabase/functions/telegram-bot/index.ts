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

🗂️ <b>أخرى</b>
/ايجارات — الإيجارات النشطة
/ضيوف — العملاء الضيوف
/انتظار — قائمة الانتظار
/ارقام — أرقام الشغل
/ملاحظات — الملاحظات
/نشاط 15 — آخر نشاط
/تنبيهات — تنبيهات مهمة

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
  let out = `🔍 <b>نتائج البحث عن "${esc(query)}" (${hits.length})</b>\n━━━━━━━━━━━━━━━━━━\n\n`;
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

    default:
      return "❓ أمر غير معروف.\nأرسل /مساعدة لعرض كل الأوامر المتاحة.";
  }
}

// ─── إرسال رسالة عبر تليجرام (مع تقسيم الرسائل الطويلة) ───────────────────────

async function sendMessage(token: string, chatId: number | string, text: string) {
  const chunks: string[] = [];
  let remaining = text;
  while (remaining.length > 4000) {
    let cut = remaining.lastIndexOf("\n", 4000);
    if (cut < 1) cut = 4000;
    chunks.push(remaining.slice(0, cut));
    remaining = remaining.slice(cut);
  }
  chunks.push(remaining);

  for (const chunk of chunks) {
    await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: chatId,
        text: chunk,
        parse_mode: "HTML",
        disable_web_page_preview: true,
      }),
    });
  }
}

// ─── المعالج الرئيسي ─────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  // فحص صحة سريع (افتح الرابط في المتصفح للتأكد أن الدالة تعمل)
  if (req.method === "GET") {
    return new Response("telegram-bot edge function is alive ✅", { status: 200 });
  }
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const url = new URL(req.url);
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

  const message = (update["message"] ?? update["edited_message"]) as
    | Record<string, unknown>
    | undefined;
  const text = (message?.["text"] as string | undefined) ?? "";
  const chat = message?.["chat"] as Record<string, unknown> | undefined;
  const fromChatId = chat?.["id"] as number | undefined;
  if (!text || fromChatId == null) return ok();

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 1) جلب إعدادات البوت لهذا المستخدم (التوكن + التفعيل + chat_id)
  const { data: cfg, error: cfgErr } = await supabase
    .from("telegram_config")
    .select("bot_token, chat_id, owner_name, enabled")
    .eq("user_id", uid)
    .maybeSingle();

  if (cfgErr || !cfg || !cfg.bot_token) return ok(); // لا إعدادات — تجاهل بهدوء
  if (cfg.enabled === false) return ok();             // البوت موقوف

  const token = cfg.bot_token as string;
  const ownerName = (cfg.owner_name as string) || "صاحب الحساب";

  // 2) قفل المحادثة: إن كان chat_id محفوظاً، نرد فقط على نفس المالك.
  const savedChatId = cfg.chat_id ? String(cfg.chat_id) : "";
  if (savedChatId && savedChatId !== String(fromChatId)) {
    await sendMessage(token, fromChatId, "🚫 هذا البوت خاص ولا يردّ إلا على صاحبه.");
    return ok();
  }

  // 3) جلب بيانات التطبيق لهذا المستخدم
  const { data: row } = await supabase
    .from("user_data")
    .select("data")
    .eq("user_id", uid)
    .maybeSingle();

  const db = emptyDB(row?.data as Partial<AppDB> | null);

  // 4) تنفيذ الأمر والرد
  try {
    const reply = route(text, db, ownerName);
    await sendMessage(token, fromChatId, reply);
  } catch (e) {
    await sendMessage(token, fromChatId, `⚠️ حدث خطأ أثناء معالجة الأمر.\n<code>${esc(String(e))}</code>`);
  }

  return ok();
});
