# 🚀 خطوات رفع بوت تليجرام (telegram-bot) على Supabase

اتبع الخطوات بالترتيب. كل أمر تكتبه في **PowerShell** جوه فولدر المشروع `D:\telecom_app7777`.

---

## 🔹 الخطوة 0 — تجهيز قاعدة البيانات (مرة واحدة)

1. ادخل على [Supabase Dashboard](https://supabase.com/dashboard) → مشروعك.
2. من القائمة الجانبية: **SQL Editor** → **New query**.
3. افتح الملف [telegram_setup.sql](telegram_setup.sql) وانسخ محتواه كله.
4. الصقه في المحرر واضغط **Run**.
   - ده بيعمل جدولي `telegram_config` و `user_data` ويظبط الصلاحيات.

---

## 🔹 الخطوة 1 — Supabase CLI (متثبت بالفعل ✅)

`winget` و `npm` مش موجودين على جهازك، فنزّلنا الـ CLI كملف تنفيذي جاهز في:
```
D:\telecom_app7777\.tools\supabase.exe
```

> **مهم:** كل الأوامر تحت بتبدأ بـ `.\.tools\supabase.exe` (مش `supabase` لوحدها)
> لأن البرنامج محلي ومش مضاف للـ PATH. لازم تكون واقف في فولدر المشروع `D:\telecom_app7777`.

تأكد إنه شغّال:

```powershell
.\.tools\supabase.exe --version
```

> (اختياري) لو عايز تكتب `supabase` بس من غير المسار الطويل، شغّل ده مرة واحدة في نفس النافذة:
> ```powershell
> Set-Alias supabase "D:\telecom_app7777\.tools\supabase.exe"
> ```
> وبعدها تقدر تستخدم باقي الأوامر بـ `supabase` عادي.

---

## 🔹 الخطوة 2 — تسجيل الدخول لحسابك في Supabase

```powershell
.\.tools\supabase.exe login
```

هيفتحلك المتصفح عشان تأكّد الدخول. وافق، وارجع للترمينال.

---

## 🔹 الخطوة 3 — ربط المشروع المحلي بمشروعك على السحابة

> الـ project ref بتاعك هو: **dxgpugiloiroguegzxtk**

```powershell
.\.tools\supabase.exe link --project-ref dxgpugiloiroguegzxtk
```

ممكن يطلب منك **Database password** (نفس باسورد قاعدة البيانات اللي حطيته وقت إنشاء المشروع). اكتبه.

---

## 🔹 الخطوة 4 — رفع (نشر) الدالة 🚀

```powershell
.\.tools\supabase.exe functions deploy telegram-bot --no-verify-jwt
```

> `--no-verify-jwt` مهم جداً عشان تليجرام يقدر يكلّم الدالة من غير توكن مصادقة.
>
> ملاحظة: الرفع بيحتاج **Docker** أحياناً. لو طلب منك Docker وأنت مش مثبّته،
> ضيف `--use-api` في آخر الأمر عشان يرفع عن طريق الـ API من غير Docker:
> ```powershell
> .\.tools\supabase.exe functions deploy telegram-bot --no-verify-jwt --use-api
> ```

لو نجح، هتشوف رسالة فيها رابط الدالة:
```
Deployed Function telegram-bot ...
https://dxgpugiloiroguegzxtk.supabase.co/functions/v1/telegram-bot
```

---

## 🔹 الخطوة 5 — تأكد إن الدالة شغّالة

افتح الرابط ده في أي متصفح:
```
https://dxgpugiloiroguegzxtk.supabase.co/functions/v1/telegram-bot
```
المفروض يظهرلك:
```
telegram-bot edge function is alive ✅
```
لو ظهرت الرسالة دي → الدالة اشتغلت تمام. ✅

---

## 🔹 الخطوة 6 — التفعيل من داخل التطبيق

1. تأكد إنك **مسجّل دخول** بحسابك جوه التطبيق (نفس حساب Supabase).
2. افتح **الإعدادات** → قسم **✈️ بوت تليجرام**.
3. تأكد إن **Bot Token** صح (من @BotFather).
4. فعّل المفتاح ✈️ بالأعلى.
   - التطبيق هيسجّل الـ webhook تلقائياً ويرفع بياناتك للسحابة.
5. افتح بوتك في تليجرام واكتب `/start` → المفروض يرد عليك فوراً. 🎉
6. جرّب `/تقرير` و `/ديون` و `/ربح`.

---

## ⚠️ لو حصلت مشكلة

| المشكلة | الحل |
|---------|------|
| البوت مش بيرد على `/start` | تأكد إنك عملت الخطوة 6 (فعّلت المفتاح بعد الرفع). الويبهوك بيتسجّل وقت التفعيل. |
| رسالة "🚫 هذا البوت خاص" | الـ `Chat ID` المحفوظ مش بتاعك. امسح خانة Chat ID في الإعدادات واحفظ، أو حط الـ Chat ID الصحيح. |
| البوت بيرد بأرقام صفر | لازم تفتح التطبيق وتعمل أي تعديل بسيط (أو فعّل البوت من جديد) عشان يرفع آخر نسخة من البيانات. |
| `deploy` بيطلب Docker | استخدم `--use-api` زي ما في الخطوة 4. |
| عايز تشوف الأخطاء | Dashboard → Edge Functions → telegram-bot → Logs |

---

## 🔄 لو عدّلت كود الدالة بعدين

اكتب نفس أمر الرفع تاني:
```powershell
.\.tools\supabase.exe functions deploy telegram-bot --no-verify-jwt
```
مش محتاج تعيد الويبهوك — هيفضل شغّال على نفس الرابط.
