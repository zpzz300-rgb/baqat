-- ════════════════════════════════════════════════════════════════════════
--  إعداد قاعدة البيانات لبوت تليجرام 24/7
--  شغّل هذا الملف مرة واحدة في:  Supabase Dashboard → SQL Editor → New query
-- ════════════════════════════════════════════════════════════════════════

-- ── 1) جدول إعدادات البوت (توكن + chat_id لكل مستخدم) ──────────────────────
create table if not exists public.telegram_config (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  bot_token  text not null,
  owner_name text,
  chat_id    text,
  enabled    boolean     not null default false,
  updated_at timestamptz not null default now()
);

-- ── 2) تأمين الصفوف: كل مستخدم يرى/يعدّل صفّه فقط ──────────────────────────
alter table public.telegram_config enable row level security;

-- نحذف السياسة القديمة إن وُجدت (تفادياً لخطأ التكرار عند إعادة التشغيل)
drop policy if exists "own telegram config" on public.telegram_config;

create policy "own telegram config"
  on public.telegram_config
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ملاحظة: الـ Edge Function تستخدم Service Role Key الذي يتجاوز RLS،
-- لذلك ستقرأ التوكن بنجاح من السيرفر. السياسة أعلاه لحماية وصول التطبيق فقط.

-- ── 3) جدول بيانات التطبيق (إن لم يكن موجوداً مسبقاً) ──────────────────────
create table if not exists public.user_data (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.user_data enable row level security;

drop policy if exists "own user data" on public.user_data;

create policy "own user data"
  on public.user_data
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ════════════════════════════════════════════════════════════════════════
--  تم. الآن انشر الـ Edge Function ثم فعّل البوت من داخل التطبيق.
-- ════════════════════════════════════════════════════════════════════════
