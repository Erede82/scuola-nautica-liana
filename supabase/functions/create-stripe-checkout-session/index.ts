// create-stripe-checkout-session — P4C.3
// Deploy (solo dopo conferma): supabase functions deploy create-stripe-checkout-session
// Secrets: STRIPE_SECRET_KEY (Supabase secrets)
// Env auto: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
// Env required: CHECKOUT_ALLOWED_REDIRECT_ORIGINS (comma-separated origins, es.
//   http://localhost:3000,https://scuolanauticaliana.it,https://app.scuolanauticaliana.it)
//
// Dominio Pagamenti online: scrive su online_orders / online_payment_transactions.
// Non tocca Contabilità, payments, record_payment, student_financial_summaries,
// student_extra_purchases. Nessun webhook in questa fase.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import Stripe from "https://esm.sh/stripe@17.5.0?target=deno";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type Body = {
  productId?: string;
  successUrl?: string;
  cancelUrl?: string;
};

type ExtraProductRow = {
  id: string;
  title: string;
  subtitle: string | null;
  price_cents: number;
  currency_code: string;
  active: boolean;
};

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Origins autorizzati per successUrl/cancelUrl (env obbligatoria in produzione). */
function parseAllowedRedirectOrigins(raw: string | undefined): Set<string> | null {
  const s = (raw ?? "").trim();
  if (!s) return null;

  const origins = new Set<string>();
  for (const part of s.split(",")) {
    const trimmed = part.trim();
    if (!trimmed) continue;
    try {
      const url = new URL(trimmed);
      if (url.protocol !== "http:" && url.protocol !== "https:") continue;
      origins.add(url.origin);
    } catch {
      // Ignora voci env malformate.
    }
  }

  return origins.size > 0 ? origins : null;
}

function parseAllowedRedirectUrl(
  raw: string | undefined,
  allowedOrigins: Set<string>,
): string | null {
  const s = (raw ?? "").trim();
  if (!s) return null;
  try {
    const url = new URL(s);
    if (url.protocol !== "http:" && url.protocol !== "https:") return null;
    if (!allowedOrigins.has(url.origin)) return null;
    return url.toString();
  } catch {
    return null;
  }
}

/** Log Stripe controllato: nessun oggetto completo, secret o body request. */
function logStripeCheckoutError(context: string, err: unknown): string {
  if (err && typeof err === "object") {
    const e = err as Record<string, unknown>;
    const message = typeof e.message === "string"
      ? e.message
      : "Stripe checkout failed";
    const type = typeof e.type === "string" ? e.type : undefined;
    const requestId = typeof e.requestId === "string" ? e.requestId : undefined;
    console.error(context, {
      message,
      ...(type ? { type } : {}),
      ...(requestId ? { requestId } : {}),
    });
    return message;
  }

  console.error(context, { message: "unknown error" });
  return "Stripe checkout failed";
}

async function resolveStudentId(
  supabaseUser: ReturnType<typeof createClient>,
  userId: string,
): Promise<{ studentId: string; buyerEmail: string | null } | null> {
  const { data: studentRow, error: studentError } = await supabaseUser
    .from("students")
    .select("id, email")
    .eq("user_id", userId)
    .maybeSingle();

  if (studentError) {
    console.error("students lookup:", studentError);
    throw new Error("student_lookup_failed");
  }

  if (studentRow?.id) {
    return {
      studentId: studentRow.id as string,
      buyerEmail: (studentRow.email as string | null) ?? null,
    };
  }

  const { data: roleRow, error: roleError } = await supabaseUser
    .from("school_user_roles")
    .select("student_id")
    .eq("user_id", userId)
    .eq("role", "student")
    .maybeSingle();

  if (roleError) {
    console.error("school_user_roles lookup:", roleError);
    throw new Error("student_lookup_failed");
  }

  const studentId = roleRow?.student_id as string | undefined;
  if (!studentId) return null;

  return { studentId, buyerEmail: null };
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
  const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");

  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("create-stripe-checkout-session: missing Supabase env");
    return jsonResponse(
      { success: false, error: "Server misconfiguration" },
      500,
    );
  }

  if (!stripeSecretKey) {
    console.error("create-stripe-checkout-session: missing STRIPE_SECRET_KEY");
    return jsonResponse(
      { success: false, error: "Payment provider not configured" },
      503,
    );
  }

  const allowedRedirectOrigins = parseAllowedRedirectOrigins(
    Deno.env.get("CHECKOUT_ALLOWED_REDIRECT_ORIGINS"),
  );
  if (!allowedRedirectOrigins) {
    console.error(
      "create-stripe-checkout-session: missing CHECKOUT_ALLOWED_REDIRECT_ORIGINS",
    );
    return jsonResponse(
      { success: false, error: "Checkout redirect not configured" },
      503,
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
    return jsonResponse({ success: false, error: "Invalid or missing token" }, 401);
  }

  if (caller.is_anonymous) {
    return jsonResponse(
      { success: false, error: "Authentication required" },
      401,
    );
  }

  let studentContext: { studentId: string; buyerEmail: string | null } | null;
  try {
    studentContext = await resolveStudentId(supabaseUser, caller.id);
  } catch {
    return jsonResponse({ success: false, error: "Student lookup failed" }, 500);
  }

  if (!studentContext) {
    return jsonResponse(
      { success: false, error: "Forbidden: student profile required" },
      403,
    );
  }

  const { studentId, buyerEmail: studentEmail } = studentContext;
  const buyerEmail = (caller.email?.trim() || studentEmail || null) as
    | string
    | null;

  let body: Body;
  try {
    body = (await req.json()) as Body;
  } catch {
    return jsonResponse({ success: false, error: "Invalid JSON body" }, 400);
  }

  const productId = body.productId?.trim();
  const successUrl = parseAllowedRedirectUrl(body.successUrl, allowedRedirectOrigins);
  const cancelUrl = parseAllowedRedirectUrl(body.cancelUrl, allowedRedirectOrigins);

  if (!productId) {
    return jsonResponse({ success: false, error: "productId is required" }, 400);
  }
  if (!successUrl) {
    return jsonResponse({ success: false, error: "Invalid redirect URL" }, 400);
  }
  if (!cancelUrl) {
    return jsonResponse({ success: false, error: "Invalid redirect URL" }, 400);
  }

  const { data: productRow, error: productError } = await supabaseUser
    .from("extra_products")
    .select("id, title, subtitle, price_cents, currency_code, active")
    .eq("id", productId)
    .maybeSingle();

  if (productError) {
    console.error("extra_products lookup:", productError);
    return jsonResponse({ success: false, error: "Product lookup failed" }, 500);
  }

  const product = productRow as ExtraProductRow | null;
  if (!product) {
    return jsonResponse({ success: false, error: "Product not found" }, 404);
  }

  if (!product.active) {
    return jsonResponse({ success: false, error: "Product not available" }, 400);
  }

  const title = product.title?.trim();
  if (!title) {
    return jsonResponse({ success: false, error: "Product not available" }, 400);
  }

  const amountCents = product.price_cents;
  if (typeof amountCents !== "number" || amountCents <= 0) {
    return jsonResponse({ success: false, error: "Product not available" }, 400);
  }

  const currencyCode = (product.currency_code ?? "EUR").toUpperCase();
  if (currencyCode !== "EUR") {
    return jsonResponse(
      { success: false, error: "Unsupported product currency" },
      400,
    );
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data: orderCode, error: orderCodeError } = await supabaseAdmin.rpc(
    "generate_online_order_code",
  );

  if (orderCodeError || !orderCode) {
    console.error("generate_online_order_code:", orderCodeError);
    return jsonResponse(
      { success: false, error: "Unable to create order" },
      500,
    );
  }

  const { data: orderRow, error: orderInsertError } = await supabaseAdmin
    .from("online_orders")
    .insert({
      order_code: orderCode as string,
      order_kind: "extra_video",
      buyer_kind: "student",
      student_id: studentId,
      product_id: productId,
      amount_cents: amountCents,
      currency_code: "EUR",
      order_status: "pending_payment",
      fulfillment_status: "pending",
      buyer_email: buyerEmail,
      metadata: {
        source: "create-stripe-checkout-session",
        product_title: title,
        auth_user_id: caller.id,
      },
    })
    .select("id")
    .single();

  if (orderInsertError || !orderRow?.id) {
    console.error("online_orders insert:", orderInsertError);
    return jsonResponse(
      { success: false, error: "Unable to create order" },
      500,
    );
  }

  const orderId = orderRow.id as string;
  const stripe = new Stripe(stripeSecretKey, {
    httpClient: Stripe.createFetchHttpClient(),
  });

  let session: Stripe.Checkout.Session;
  try {
    session = await stripe.checkout.sessions.create({
      mode: "payment",
      line_items: [
        {
          price_data: {
            currency: "eur",
            product_data: {
              name: title,
              ...(product.subtitle?.trim()
                ? { description: product.subtitle.trim() }
                : {}),
            },
            unit_amount: amountCents,
          },
          quantity: 1,
        },
      ],
      metadata: {
        order_id: orderId,
        product_id: productId,
        student_id: studentId,
      },
      client_reference_id: orderId,
      success_url: successUrl,
      cancel_url: cancelUrl,
      ...(buyerEmail ? { customer_email: buyerEmail } : {}),
    });
  } catch (stripeErr) {
    const stripeMessage = logStripeCheckoutError(
      "stripe.checkout.sessions.create",
      stripeErr,
    );

    const { error: markFailedError } = await supabaseAdmin
      .from("online_orders")
      .update({
        order_status: "failed",
        fulfillment_error: stripeMessage.slice(0, 500),
        metadata: {
          source: "create-stripe-checkout-session",
          product_title: title,
          auth_user_id: caller.id,
          stripe_error: stripeMessage.slice(0, 500),
        },
      })
      .eq("id", orderId);

    if (markFailedError) {
      console.error("online_orders mark failed:", markFailedError);
    }

    return jsonResponse(
      { success: false, error: "Unable to start payment session" },
      502,
    );
  }

  if (!session.url) {
    console.error("stripe session missing url:", session.id);
    await supabaseAdmin
      .from("online_orders")
      .update({
        order_status: "failed",
        fulfillment_error: "Stripe session missing checkout URL",
      })
      .eq("id", orderId);

    return jsonResponse(
      { success: false, error: "Unable to start payment session" },
      502,
    );
  }

  const { error: txInsertError } = await supabaseAdmin
    .from("online_payment_transactions")
    .insert({
      order_id: orderId,
      provider: "stripe",
      provider_checkout_session_id: session.id,
      checkout_url: session.url,
      payment_status: "initiated",
      amount_cents: amountCents,
      currency_code: "EUR",
    });

  if (txInsertError) {
    const txErrorMessage = txInsertError.message ?? "insert_failed";
    console.error("online_payment_transactions insert:", txErrorMessage);

    const { error: markFailedError } = await supabaseAdmin
      .from("online_orders")
      .update({
        order_status: "failed",
        fulfillment_error: "Payment transaction record failed",
        metadata: {
          source: "create-stripe-checkout-session",
          product_title: title,
          auth_user_id: caller.id,
          stripe_checkout_session_id: session.id,
          tx_insert_error: txErrorMessage.slice(0, 200),
        },
      })
      .eq("id", orderId);

    if (markFailedError) {
      console.error("online_orders mark failed after tx insert:", markFailedError.message);
    }

    // Best-effort: evita sessione Checkout orfana utilizzabile.
    try {
      await stripe.checkout.sessions.expire(session.id);
    } catch (expireErr) {
      // TODO P4C.4+: monitorare sessioni orfane; cleanup manuale Stripe Dashboard se expire fallisce.
      logStripeCheckoutError("stripe.checkout.sessions.expire", expireErr);
    }

    return jsonResponse(
      { success: false, error: "Unable to start payment session" },
      500,
    );
  }

  return jsonResponse({
    success: true,
    checkoutUrl: session.url,
    orderId,
  });
});
