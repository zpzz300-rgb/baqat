-- ════════════════════════════════════════════════════════════════════════
--  هوية الجهاز في لوحة الإدارة — telecom_app7777
--  شغّل هذا الملف مرة واحدة في:  Supabase Dashboard → SQL Editor → New query
--
--  المشكلة اللي بيحلها:
--  البرنامج بيسجّل الجهاز أول ما يفتح — يعني قبل ما حد يسجّل دخول — فبيفضل
--  «بدون اسم» للأبد. دلوقتي الجهاز بيكتب هويته كمان بعد الدخول: مالك ولا
--  موظف، واسم الموظف، والحساب اللي بيشتغل عليه.
--
--  ملاحظة أمان: البيانات دي بيكتبها الجهاز عن نفسه بس. مفيش أي تخفيف في
--  صلاحيات قراءة جداول العملاء أو الموظفين — كل عميل لسه بيشوف بتاعه بس.
-- ════════════════════════════════════════════════════════════════════════

alter table public.app_installations
  add column if not exists account_type   text;   -- 'owner' | 'employee'

alter table public.app_installations
  add column if not exists employee_name  text;   -- اسم الموظف لو الدخول بموظف

alter table public.app_installations
  add column if not exists owner_user_id  uuid;   -- حساب المحل اللي بيشتغل عليه

alter table public.app_installations
  add column if not exists login_email    text;   -- إيميل الدخول (للمالك)

create index if not exists app_installations_owner_user_id_idx
  on public.app_installations (owner_user_id);

-- ════════════════════════════════════════════════════════════════════════
--  تم. لوحة الإدارة بتربط الموظف بصاحب المحل عن طريق owner_user_id،
--  فمش محتاجة تقرا جداول الموظفين ولا حسابات العملاء أصلاً.
-- ════════════════════════════════════════════════════════════════════════
