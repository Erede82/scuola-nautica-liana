// create-student-app-access — PATCH 5B1 / 5B1-bis
// Deploy: supabase functions deploy create-student-app-access --no-verify-jwt
// Dettagli: docs/STUDENT_APP_ACCESS_BACKOFFICE.md

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type Body = {
  studentId?: string;
  email?: string;
  password?: string;
};

const STAFF_ROLES = new Set(["school_admin", "staff", "admin"]);

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function generateTemporaryPassword(): string {
  const buf = new Uint8Array(18);
  crypto.getRandomValues(buf);
  const core = Array.from(buf, (b) => b.toString(16).padStart(2, "0")).join(
    "",
  );
  // Requisiti tipici password: mix (lettere + numero + simbolo)
  return `Tmp${core}Aa1`;
}

/** Trim + lowercase; validazione minima (formato non RFC-completa). */
function normalizeEmailInput(raw: string | undefined): string | null {
  const s = (raw ?? "").trim().toLowerCase();
  if (s.length < 3) return null;
  const at = s.indexOf("@");
  if (at <= 0 || at === s.length - 1) return null;
  const local = s.slice(0, at);
  const domain = s.slice(at + 1);
  if (!local.length || !domain.includes(".")) return null;
  return s;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ success: false, error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("create-student-app-access: missing env");
    return jsonResponse(
      { success: false, error: "Server misconfiguration" },
      500,
    );
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ success: false, error: "Missing bearer token" }, 401);
  }

  const supabaseUser = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user: caller },
    error: callerError,
  } = await supabaseUser.auth.getUser();

  if (callerError || !caller) {
    return jsonResponse({ success: false, error: "Invalid token" }, 401);
  }

  const { data: roleRow, error: roleError } = await supabaseUser
    .from("school_user_roles")
    .select("role")
    .eq("user_id", caller.id)
    .maybeSingle();

  if (roleError) {
    console.error("school_user_roles:", roleError);
    return jsonResponse({ success: false, error: "Role check failed" }, 403);
  }

  const role = roleRow?.role as string | undefined;
  if (!role || !STAFF_ROLES.has(role)) {
    return jsonResponse(
      { success: false, error: "Forbidden: staff or school_admin required" },
      403,
    );
  }

  let body: Body;
  try {
    body = (await req.json()) as Body;
  } catch {
    return jsonResponse({ success: false, error: "Invalid JSON body" }, 400);
  }

  const studentId = body.studentId?.trim();
  const emailNormalized = normalizeEmailInput(body.email);

  if (!studentId) {
    return jsonResponse({ success: false, error: "studentId is required" }, 400);
  }
  if (!emailNormalized) {
    return jsonResponse(
      { success: false, error: "Valid email is required" },
      400,
    );
  }

  const temporaryPassword =
    body.password && body.password.length >= 8
      ? body.password
      : generateTemporaryPassword();

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data: created, error: createError } = await supabaseAdmin.auth.admin
    .createUser({
      email: emailNormalized,
      password: temporaryPassword,
      email_confirm: true,
    });

  if (createError || !created?.user?.id) {
    console.error("admin.createUser:", createError);
    return jsonResponse(
      {
        success: false,
        error:
          createError?.message ??
          "Unable to create auth user (email may already exist)",
      },
      400,
    );
  }

  const newUserId = created.user.id;

  const { error: linkError } = await supabaseAdmin.rpc(
    "link_student_app_access",
    {
      p_student_id: studentId,
      p_user_id: newUserId,
      p_email: emailNormalized,
    },
  );

  if (linkError) {
    console.error("link_student_app_access:", linkError);
    try {
      await supabaseAdmin.auth.admin.deleteUser(newUserId);
    } catch (delErr) {
      console.error("cleanup deleteUser failed:", delErr);
    }
    return jsonResponse(
      {
        success: false,
        error: linkError.message ?? "Database link failed; auth user rolled back",
      },
      422,
    );
  }

  return jsonResponse({
    success: true,
    studentId,
    userId: newUserId,
    email: emailNormalized,
    temporaryPassword,
  });
});
