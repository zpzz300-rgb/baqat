-- ════════════════════════════════════════════════════════════════════════
--  نظام إدارة الموظفين والصلاحيات (RBAC) — telecom_app7777
--  شغّل هذا الملف مرة واحدة في:  Supabase Dashboard → SQL Editor → New query
--  (أو يُطبَّق تلقائياً عبر supabase db push)
-- ════════════════════════════════════════════════════════════════════════

-- ── 0) امتدادات مطلوبة ────────────────────────────────────────────────────
create extension if not exists pgcrypto;  -- لـ gen_random_uuid()

-- ── 1) ملف المالك: كود المحل اللي الموظف بيسجّل بيه ───────────────────────
create table if not exists public.owner_profiles (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  shop_code  text unique not null,            -- كود المحل (يدخله الموظف عند التسجيل)
  shop_name  text,
  created_at timestamptz not null default now()
);

alter table public.owner_profiles enable row level security;

drop policy if exists "own owner profile" on public.owner_profiles;
create policy "own owner profile"
  on public.owner_profiles
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ملاحظة: البحث عن المالك بالـ shop_code وقت تسجيل الموظف بيتم داخل
-- الـ Edge Function بالـ Service Role (يتجاوز RLS)، فمش محتاجين قراءة عامة.

-- ── 2) جدول الموظفين ──────────────────────────────────────────────────────
create table if not exists public.employees (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references auth.users (id) on delete cascade,
  auth_uid    uuid references auth.users (id) on delete set null, -- حساب الموظف نفسه
  auth_email  text,                           -- الإيميل الصناعي لحساب الموظف (للدخول)
  name        text not null,
  pin_hash    text not null,                  -- هاش للكود السري (مش الكود نفسه)
  status      text not null default 'pending',-- pending | active | disabled
  created_at  timestamptz not null default now(),
  approved_at timestamptz,
  unique (owner_id, name)                      -- الاسم فريد داخل المحل الواحد
);

alter table public.employees enable row level security;

-- المالك يدير موظفينه بالكامل (موافقة/فصل/حذف)
drop policy if exists "owner manages employees" on public.employees;
create policy "owner manages employees"
  on public.employees
  for all
  using  (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- الموظف يقرأ صفّه هو فقط (عشان يكتشف الفصل لحظياً)
drop policy if exists "employee reads self" on public.employees;
create policy "employee reads self"
  on public.employees
  for select
  using (auth.uid() = auth_uid);

-- ── 3) السماح للموظف (active فقط) بالوصول لبيانات صاحب المحل ──────────────
--     ده اللي بيخلّي الموظف يشتغل على نفس بيانات المالك، والفصل فوري:
--     أول ما status يبقى disabled، الشرط يفشل والسيرفر يرفض كل قراءة/كتابة.
drop policy if exists "employee accesses owner data" on public.user_data;
create policy "employee accesses owner data"
  on public.user_data
  for all
  using (
    exists (
      select 1 from public.employees e
      where e.auth_uid = auth.uid()
        and e.owner_id = user_data.user_id
        and e.status   = 'active'
    )
  )
  with check (
    exists (
      select 1 from public.employees e
      where e.auth_uid = auth.uid()
        and e.owner_id = user_data.user_id
        and e.status   = 'active'
    )
  );

-- ── 4) تفعيل الـ Realtime على جدول الموظفين ───────────────────────────────
--     عشان التطبيق يسمع تغيير الحالة (فصل) لحظياً ويقفل في وش الموظف.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'employees'
  ) then
    alter publication supabase_realtime add table public.employees;
  end if;
end $$;

-- ════════════════════════════════════════════════════════════════════════
--  تم. الخطوة الجاية: نشر الـ Edge Function (employee-auth).
-- ════════════════════════════════════════════════════════════════════════
