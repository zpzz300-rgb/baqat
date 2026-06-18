-- ════════════════════════════════════════════════════════════════════════
--  مزامنة آمنة ضد التضارب + الصندوق الأسود (سجل الرقابة) — telecom_app7777
--  شغّل هذا الملف مرة واحدة في:  Supabase Dashboard → SQL Editor → New query
-- ════════════════════════════════════════════════════════════════════════
--  هذا الملف بيعمل حاجتين:
--   1) حماية جدول user_data من الكتابة فوق الأحدث (Optimistic Concurrency)
--      عن طريق عمود version + دالة save_user_data_guarded.
--   2) جدول shop_audit_logs مستقل تماماً (Append-Only) — يسجّل كل حركة
--      في المحل، ومستحيل تتمسح أو تتعدّل من أي جهاز حتى لو رجعت المزامنة.
-- ════════════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;

-- ════════════════════════════════════════════════════════════════════════
--  (1) منع الكتابة فوق البيانات الأحدث — Optimistic Concurrency Control
-- ════════════════════════════════════════════════════════════════════════

-- عدّاد إصدار على صف بيانات كل مالك. أي كتابة ناجحة بتزوّده +1.
alter table public.user_data
  add column if not exists version bigint not null default 0;

-- دالة الحفظ المحمية: الجهاز بيبعت الإصدار اللي كان شايفه (p_base_version).
-- لو الإصدار على السيرفر بقى أحدث (يعني جهاز تاني كتب في الوقت ده) → نرفض
-- الكتابة ونرجّع نسخة السيرفر، والجهاز يسحبها بدل ما يمسح بيانات الناس.
create or replace function public.save_user_data_guarded(
  p_user_id      uuid,
  p_data         jsonb,
  p_base_version bigint
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current    bigint;
  v_authorized boolean;
begin
  -- فحص الصلاحية: المالك نفسه أو موظف فعّال تابع له
  v_authorized := (auth.uid() = p_user_id) or exists (
    select 1 from public.employees e
    where e.auth_uid = auth.uid()
      and e.owner_id = p_user_id
      and e.status   = 'active'
  );
  if not v_authorized then
    return jsonb_build_object('accepted', false, 'error', 'unauthorized');
  end if;

  -- قفل الصف لمنع أي سباق (TOCTOU) بين القراءة والكتابة
  select version into v_current
  from public.user_data
  where user_id = p_user_id
  for update;

  -- أول كتابة على الإطلاق لهذا المالك
  if v_current is null then
    insert into public.user_data (user_id, data, version, updated_at)
    values (p_user_id, p_data, 1, now());
    return jsonb_build_object('accepted', true, 'version', 1);
  end if;

  -- الجهاز قديم: الإصدار اللي معاه أقل من اللي على السيرفر → ارفض واسحب
  if p_base_version < v_current then
    return jsonb_build_object(
      'accepted', false,
      'stale',    true,
      'version',  v_current,
      'data',     (select data from public.user_data where user_id = p_user_id)
    );
  end if;

  -- الجهاز محدّث → اقبل الكتابة وزوّد الإصدار
  update public.user_data
     set data = p_data, version = v_current + 1, updated_at = now()
   where user_id = p_user_id;

  return jsonb_build_object('accepted', true, 'version', v_current + 1);
end;
$$;

grant execute on function public.save_user_data_guarded(uuid, jsonb, bigint) to authenticated;

-- ════════════════════════════════════════════════════════════════════════
--  (2) الصندوق الأسود: shop_audit_logs — جدول مستقل Append-Only
-- ════════════════════════════════════════════════════════════════════════
create table if not exists public.shop_audit_logs (
  id          bigint generated always as identity primary key,
  owner_id    uuid not null references auth.users (id) on delete cascade, -- المحل
  actor_uid   uuid,            -- مين عمل الحركة (auth uid)
  user_type   text,            -- "المالك" أو "موظف: فلان"
  is_employee boolean not null default false,
  action_type text,            -- نوع الحركة: pay / delete / message / move / add ...
  details     text,            -- وصف بالعامية: "تم سداد 100ج للعميل محمد"
  target_id   text,            -- الرابط النشط: رقم العميل / الفاتورة / العملية
  target_type text,            -- نوع الهدف: member / group / rental / worknum ...
  client_ts   timestamptz,     -- وقت الحركة على الجهاز (بالثانية)
  created_at  timestamptz not null default now()  -- وقت الوصول للسيرفر
);

create index if not exists idx_shop_audit_owner_created
  on public.shop_audit_logs (owner_id, created_at desc);

alter table public.shop_audit_logs enable row level security;

-- INSERT فقط: المالك أو موظف فعّال تابع له
drop policy if exists "audit append" on public.shop_audit_logs;
create policy "audit append"
  on public.shop_audit_logs
  for insert
  with check (
    auth.uid() = owner_id or exists (
      select 1 from public.employees e
      where e.auth_uid = auth.uid()
        and e.owner_id = shop_audit_logs.owner_id
        and e.status   = 'active'
    )
  );

-- SELECT: المالك أو موظف فعّال تابع له
drop policy if exists "audit read" on public.shop_audit_logs;
create policy "audit read"
  on public.shop_audit_logs
  for select
  using (
    auth.uid() = owner_id or exists (
      select 1 from public.employees e
      where e.auth_uid = auth.uid()
        and e.owner_id = shop_audit_logs.owner_id
        and e.status   = 'active'
    )
  );

-- ⛔ ملاحظة أمنية: مفيش أي policy لـ UPDATE أو DELETE.
--    مع تفعيل RLS، أي حركة تعديل/حذف من التطبيق (authenticated) بتتمنع تلقائياً.
--    يعني الجدول Append-Only بنسبة 100% — مستحيل أي جهاز يمسح أو يغيّر سطر.
--    (الحذف ممكن فقط من لوحة Supabase بصلاحية مالك المشروع/service_role.)

-- ════════════════════════════════════════════════════════════════════════
--  تم. السجل دلوقتي محصّن، والمزامنة آمنة ضد التضارب.
-- ════════════════════════════════════════════════════════════════════════
