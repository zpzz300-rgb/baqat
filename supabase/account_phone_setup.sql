-- ════════════════════════════════════════════════════════════════════════
--  ربط رقم الموبايل بالحساب بدل الجهاز — telecom_app7777
--  شغّل هذا الملف مرة واحدة في:  Supabase Dashboard → SQL Editor → New query
--
--  المشكلة اللي بيحلها:
--  كان الرقم متخزّن على الجهاز في app_installations، والبحث عنه بيتم بـ
--  user_id — والعمود ده مش موجود في الجدول أصلاً، فالاستعلام بيفشل والبرنامج
--  بيطلب الرقم من المستخدم كل مرة. دلوقتي الرقم بقى على الحساب نفسه.
-- ════════════════════════════════════════════════════════════════════════

-- ── 1) الرقم على الحساب (المصدر الأساسي من دلوقتي) ──────────────────────
alter table public.owner_profiles
  add column if not exists customer_phone text;

-- ── 2) العمود الناقص في جدول الأجهزة (اللي كان بيفشّل الاستعلام) ─────────
alter table public.app_installations
  add column if not exists user_id uuid;

alter table public.app_installations
  add column if not exists customer_name text;

create index if not exists app_installations_user_id_idx
  on public.app_installations (user_id);

-- ── 3) ترحيل الأرقام القديمة من الأجهزة للحسابات ────────────────────────
-- أي حساب لسه مالوش رقم، بناخد أحدث رقم متسجّل على أي جهاز بنفس الحساب.
update public.owner_profiles op
set customer_phone = src.customer_phone
from (
  select distinct on (user_id) user_id, customer_phone
  from public.app_installations
  where user_id is not null
    and customer_phone is not null
    and customer_phone <> ''
  order by user_id, last_seen desc
) src
where op.user_id = src.user_id
  and (op.customer_phone is null or op.customer_phone = '');

-- ════════════════════════════════════════════════════════════════════════
--  تم. بعد كده البرنامج بيسأل عن الرقم مرة واحدة بس في عمر الحساب،
--  وأي جهاز تاني بنفس الحساب مش هيسأل خالص.
-- ════════════════════════════════════════════════════════════════════════
