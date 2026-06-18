// supabase/functions/employee-auth/index.ts
//
// مصادقة الموظفين (RBAC) — Edge Function
// ==========================================
// بيدير: تسجيل موظف جديد (register) + دخول الموظف (login).
// الموظف يشتغل على نفس بيانات صاحب المحل، والتحكم بالكامل من السيرفر.
//
// الإجراءات (POST JSON):
//   { action: "register", shopCode, name, pin }
//      → بينشئ حساب للموظف بحالة pending وينتظر موافقة المالك.
//   { action: "login", shopCode, name, pin }
//      → بيتحقق ويرجّع:
//          status=pending   (لسه مستني الموافقة)
//          status=disabled  (اتفصل)
//          status=active + session + ownerId  (يدخل البرنامج)
//
// مهم: انشر الدالة بـ --no-verify-jwt (الموظف لسه مش مسجّل دخول وقت التسجيل/الدخول).
//   SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY متاحين تلقائياً.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

// ── هاش الكود السري: salt$hash بـ SHA-256 ──────────────────────────────────
async function hashPin(pin: string, salt: string): Promise<string> {
  const data = new TextEncoder().encode(`${salt}:${pin}`);
  const buf = await crypto.subtle.digest("SHA-256", data);
  const hex = [...new Uint8Array(buf)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return `${salt}$${hex}`;
}

async function verifyPin(pin: string, stored: string): Promise<boolean> {
  const salt = stored.split("$")[0] ?? "";
  const expected = await hashPin(pin, salt);
  return expected === stored;
}

function randomToken(): string {
  return crypto.randomUUID().replace(/-/g, "") +
    crypto.randomUUID().replace(/-/g, "");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method" }, 405);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let body: Record<string, string>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "bad json" }, 400);
  }

  const action = (body.action ?? "").trim();
  const shopCode = (body.shopCode ?? "").trim();
  const name = (body.name ?? "").trim();
  const pin = (body.pin ?? "").trim();

  if (!shopCode || !name || !pin) {
    return json({ error: "ناقص بيانات (كود المحل / الاسم / الكود السري)" }, 400);
  }

  // إيجاد المالك عبر كود المحل
  const { data: owner } = await admin
    .from("owner_profiles")
    .select("user_id")
    .eq("shop_code", shopCode)
    .maybeSingle();

  if (!owner) return json({ error: "كود المحل غلط" }, 404);
  const ownerId = owner.user_id as string;

  // ─── تسجيل موظف جديد ──────────────────────────────────────────────────
  if (action === "register") {
    // الاسم مستخدم قبل كده في نفس المحل؟
    const { data: existing } = await admin
      .from("employees")
      .select("id, status")
      .eq("owner_id", ownerId)
      .eq("name", name)
      .maybeSingle();

    if (existing) {
      return json({
        error: "الاسم ده مستخدم بالفعل في المحل. لو ده انت، سجّل دخول.",
      }, 409);
    }

    // إنشاء حساب صناعي للموظف
    const email = `${crypto.randomUUID()}@employees.invalid`;
    const password = randomToken();
    const { data: created, error: createErr } = await admin.auth.admin
      .createUser({ email, password, email_confirm: true });

    if (createErr || !created?.user) {
      return json({ error: "فشل إنشاء حساب الموظف" }, 500);
    }

    const salt = crypto.randomUUID().slice(0, 8);
    const pinHash = await hashPin(pin, salt);

    const { error: insErr } = await admin.from("employees").insert({
      owner_id: ownerId,
      auth_uid: created.user.id,
      auth_email: email,
      name,
      pin_hash: pinHash,
      status: "pending",
    });

    if (insErr) {
      // تنظيف الحساب لو الإدراج فشل
      await admin.auth.admin.deleteUser(created.user.id);
      return json({ error: "فشل تسجيل الموظف" }, 500);
    }

    return json({ status: "pending" });
  }

  // ─── دخول الموظف ─────────────────────────────────────────────────────
  if (action === "login") {
    const { data: emp } = await admin
      .from("employees")
      .select("id, auth_uid, auth_email, pin_hash, status")
      .eq("owner_id", ownerId)
      .eq("name", name)
      .maybeSingle();

    if (!emp) return json({ error: "مفيش موظف بالاسم ده في المحل" }, 404);

    const ok = await verifyPin(pin, emp.pin_hash as string);
    if (!ok) return json({ error: "الكود السري غلط" }, 401);

    if (emp.status === "pending") return json({ status: "pending" });
    if (emp.status !== "active") return json({ status: "disabled" });

    // active → اعمل session: صفّر الباسورد لقيمة عشوائية وادخل بيها
    const newPwd = randomToken();
    const { error: updErr } = await admin.auth.admin.updateUserById(
      emp.auth_uid as string,
      { password: newPwd },
    );
    if (updErr) return json({ error: "فشل تجهيز الجلسة" }, 500);

    const anon = createClient(SUPABASE_URL, ANON_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: signIn, error: signErr } = await anon.auth
      .signInWithPassword({
        email: emp.auth_email as string,
        password: newPwd,
      });

    if (signErr || !signIn?.session) {
      return json({ error: "فشل تسجيل دخول الموظف" }, 500);
    }

    return json({
      status: "active",
      ownerId,
      employeeId: emp.id,
      employeeName: name,
      session: {
        access_token: signIn.session.access_token,
        refresh_token: signIn.session.refresh_token,
      },
    });
  }

  return json({ error: "إجراء غير معروف" }, 400);
});
