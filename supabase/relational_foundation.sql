-- ════════════════════════════════════════════════════════════════════════
--  المرحلة 1: الأساس النِسبي (Relational Foundation) — telecom_app7777
--  شغّل مرة واحدة في:  Supabase Dashboard → SQL Editor → New query
-- ════════════════════════════════════════════════════════════════════════
--  جداول جديدة *إضافية* — مش بتلمس user_data (الـ blob) ولا بتكسر أي حاجة شغالة:
--    1) line_assignments      — تعيين المجموعات/الخطوط على الموظفين (للسرية والتوزيع)
--    2) line_invoice_history  — أرشيف فواتير كل خط (Append-Only): متوقع/فعلي/زيادة/ملاحظة
--  الربط بالمجموعة عبر group_id (نفس id المجموعة الموجود في بيانات المحل).
-- ════════════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;

-- ════════════════════════════════════════════════════════════════════════
--  (1) تعيين الخطوط/المجموعات على الموظفين
-- ════════════════════════════════════════════════════════════════════════
create table if not exists public.line_assignments (
  id          bigint generated always as identity primary key,
  owner_id    uuid not null references auth.users(id) on delete cascade,
  group_id    text not null,                              -- id المجموعة في الـ blob
  employee_id uuid not null references public.employees(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  unique (owner_id, group_id)                             -- كل مجموعة لموظف واحد
);
create index if not exists idx_line_assign_owner on public.line_assignments(owner_id);
create index if not exists idx_line_assign_emp   on public.line_assignments(employee_id);

alter table public.line_assignments enable row level security;

-- المالك: تحكم كامل في تعييناته
drop policy if exists "assign owner all" on public.line_assignments;
create policy "assign owner all" on public.line_assignments
  for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

-- الموظف الفعّال: يقرأ تعييناته هو بس (عشان يعرف مجموعاته)
drop policy if exists "assign emp read" on public.line_assignments;
create policy "assign emp read" on public.line_assignments
  for select using (exists (
    select 1 from public.employees e
    where e.id = line_assignments.employee_id
      and e.auth_uid = auth.uid()
      and e.status   = 'active'
  ));

-- ════════════════════════════════════════════════════════════════════════
--  (2) أرشيف فواتير الخطوط — Append-Only (مفيش UPDATE/DELETE policy)
-- ════════════════════════════════════════════════════════════════════════
create table if not exists public.line_invoice_history (
  id          bigint generated always as identity primary key,
  owner_id    uuid not null references auth.users(id) on delete cascade,
  group_id    text not null,
  month       text not null,                  -- "2026-05"
  expected    numeric(12,2),                  -- المتوقع (تنبؤي)
  actual      numeric(12,2) not null,         -- الفعلي اللي الشركة نزّلته
  variance    numeric(12,2),                  -- actual - expected
  has_overage boolean not null default false, -- فيه زيادة عن المتوقع؟
  note        text,                           -- ملاحظة الموظف عن الزيادة/الخطأ
  actor_uid   uuid,                           -- مين سجّل (auth uid)
  user_type   text,                           -- "المالك" / "موظف: فلان"
  created_at  timestamptz not null default now()
);
create index if not exists idx_invhist_owner_group
  on public.line_invoice_history(owner_id, group_id, month);

alter table public.line_invoice_history enable row level security;

-- INSERT: المالك، أو موظف فعّال *معيّن على الخط ده تحديداً*
drop policy if exists "invhist insert" on public.line_invoice_history;
create policy "invhist insert" on public.line_invoice_history
  for insert with check (
    auth.uid() = owner_id or exists (
      select 1 from public.employees e
      join public.line_assignments la on la.employee_id = e.id
      where e.auth_uid = auth.uid() and e.status = 'active'
        and la.owner_id = line_invoice_history.owner_id
        and la.group_id = line_invoice_history.group_id
    )
  );

-- SELECT: نفس الشرط (المالك يشوف الكل، الموظف يشوف خطوطه بس)
drop policy if exists "invhist read" on public.line_invoice_history;
create policy "invhist read" on public.line_invoice_history
  for select using (
    auth.uid() = owner_id or exists (
      select 1 from public.employees e
      join public.line_assignments la on la.employee_id = e.id
      where e.auth_uid = auth.uid() and e.status = 'active'
        and la.owner_id = line_invoice_history.owner_id
        and la.group_id = line_invoice_history.group_id
    )
  );

-- ⛔ مفيش UPDATE/DELETE policy → الأرشيف غير قابل للتعديل أو الحذف من أي جهاز.
-- ════════════════════════════════════════════════════════════════════════
--  تم الأساس. الخطوة الجاية: ربط شاشات التطبيق بالجدولين دول.
-- ════════════════════════════════════════════════════════════════════════
