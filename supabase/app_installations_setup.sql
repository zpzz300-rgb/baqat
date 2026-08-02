-- ════════════════════════════════════════════════════════════════════════
--  سجل كل تثبيت للبرنامج (تجريبي + مفعّل) — telecom_app7777
--  شغّل هذا الملف مرة واحدة في:  Supabase Dashboard → SQL Editor → New query
-- ════════════════════════════════════════════════════════════════════════

create table if not exists public.app_installations (
  device_id      text primary key,
  customer_name  text,
  customer_phone text,
  key_code       text,
  notes          text,
  first_seen     timestamptz not null default now(),
  last_seen      timestamptz not null default now()
);

alter table public.app_installations enable row level security;

-- نفس نمط الصلاحيات المستخدم فعلاً في جداول التطبيق الأخرى (main_lines):
-- الوصول من التطبيق بيتم بمفتاح anon مباشرة من غير جلسة مستخدم (زي جدول
-- subscriptions الحالي)، فالسماح هنا "Allow all" بيطابق نفس مستوى الثقة
-- المستخدم بالفعل في باقي الجداول، مش تخفيف جديد.
drop policy if exists "Allow all" on public.app_installations;
create policy "Allow all" on public.app_installations for all using (true) with check (true);

-- ════════════════════════════════════════════════════════════════════════
--  تم. الخطوة الجاية: التطبيق هيبلّغ الجهاز تلقائياً في AuthService.checkStatus().
-- ════════════════════════════════════════════════════════════════════════
