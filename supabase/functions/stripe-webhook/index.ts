// stripe-webhook — P4C.4
// Deploy (solo dopo conferma): supabase functions deploy stripe-webhook --no-verify-jwt
// Secrets: STRIPE_WEBHOOK_SECRET (whsec_... da Stripe Dashboard webhook endpoint)
// Env auto: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//
// Gestisce checkout.session.completed → online_orders paid → fulfill_extra_online_order.
// Non tocca Contabilità, payments, record_payment, student_financial_summaries.
// Scrive su student_extra_purchases solo via RPC fulfill_extra_online_order (P4C.2).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import Stripe from "https://esm.sh/stripe@17.5.0?target=deno";

const HANDLED_EVENT = "checkout.session.completed";

// Deno Web Crypto è async: constructEventAsync + SubtleCryptoProvider (P4C.4.7).
const cryptoProvider = Stripe.createSubtleCryptoProvider();
/** Chiave API non usata per verify firma; serve solo al costruttore SDK. */
const stripe = new Stripe(
  Deno.env.get("STRIPE_SECRET_KEY") ?? "sk_test_webhook_verify_only",
  { httpClient: Stripe.createFetchHttpClient() },
);

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type OnlineOrderRow = {
  id: string;
  order_status: string;
  order_kind: string;
  student_id: string | null;
  amount_cents: number;
  currency_code: string;
  fulfillment_status: string;
};

/** Esito handler: success → marca processed_at; retry → 500, processed_at resta null. */
type HandlerOutcome =
  | { status: "success"; orderId: string | null }
  | {
    status: "retry";
    reason: string;
    checkoutSessionId?: string | null;
  };

function isValidUuid(value: string): boolean {
  return UUID_RE.test(value);
}

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function logInfo(context: string, fields: Record<string, unknown>): void {
  console.log(context, fields);
}

function logError(context: string, fields: Record<string, unknown>): void {
  console.error(context, fields);
}

/** Log Stripe controllato: nessun oggetto completo, secret o body grezzo. */
function logStripeError(context: string, err: unknown): string {
  if (err && typeof err === "object") {
    const e = err as Record<string, unknown>;
    const message = typeof e.message === "string"
      ? e.message
      : "Stripe error";
    const type = typeof e.type === "string" ? e.type : undefined;
    const requestId = typeof e.requestId === "string" ? e.requestId : undefined;
    logError(context, {
      message,
      ...(type ? { type } : {}),
      ...(requestId ? { requestId } : {}),
    });
    return message;
  }

  logError(context, { message: "unknown error" });
  return "Stripe error";
}

function paymentIntentId(
  paymentIntent: Stripe.Checkout.Session["payment_intent"],
): string | null {
  if (!paymentIntent) return null;
  if (typeof paymentIntent === "string") return paymentIntent;
  return paymentIntent.id ?? null;
}

function resolveOrderIdFromSession(session: Stripe.Checkout.Session): string | null {
  const fromMetadata = session.metadata?.order_id?.trim();
  if (fromMetadata) {
    return isValidUuid(fromMetadata) ? fromMetadata : null;
  }

  const fromReference = session.client_reference_id?.trim();
  if (fromReference) {
    return isValidUuid(fromReference) ? fromReference : null;
  }

  return null;
}

function webhookPayloadSummary(event: Stripe.Event): Record<string, unknown> {
  const session = event.data.object as Stripe.Checkout.Session;
  return {
    stripe_event_id: event.id,
    event_type: event.type,
    checkout_session_id: session.id ?? null,
    payment_status: session.payment_status ?? null,
    session_status: session.status ?? null,
    client_reference_id: session.client_reference_id ?? null,
    metadata_order_id: session.metadata?.order_id ?? null,
  };
}

async function markWebhookProcessed(
  supabaseAdmin: ReturnType<typeof createClient>,
  providerEventId: string,
  orderId: string | null,
): Promise<void> {
  const { error } = await supabaseAdmin
    .from("online_payment_webhook_events")
    .update({
      processed_at: new Date().toISOString(),
      order_id: orderId,
    })
    .eq("provider_event_id", providerEventId);

  if (error) {
    logError("stripe-webhook: mark processed failed", {
      provider_event_id: providerEventId,
      order_id: orderId,
      message: error.message,
    });
    throw error;
  }
}

async function ensureWebhookEventRow(
  supabaseAdmin: ReturnType<typeof createClient>,
  event: Stripe.Event,
): Promise<{ alreadyProcessed: boolean }> {
  const { data: existing, error: selectError } = await supabaseAdmin
    .from("online_payment_webhook_events")
    .select("id, processed_at")
    .eq("provider_event_id", event.id)
    .maybeSingle();

  if (selectError) {
    logError("stripe-webhook: webhook_events lookup failed", {
      provider_event_id: event.id,
      message: selectError.message,
    });
    throw selectError;
  }

  if (existing?.processed_at) {
    return { alreadyProcessed: true };
  }

  if (existing) {
    return { alreadyProcessed: false };
  }

  const { error: insertError } = await supabaseAdmin
    .from("online_payment_webhook_events")
    .insert({
      provider: "stripe",
      provider_event_id: event.id,
      event_type: event.type,
      payload: webhookPayloadSummary(event),
    });

  if (insertError) {
    if (insertError.code === "23505") {
      const { data: raced } = await supabaseAdmin
        .from("online_payment_webhook_events")
        .select("processed_at")
        .eq("provider_event_id", event.id)
        .maybeSingle();

      if (raced?.processed_at) {
        return { alreadyProcessed: true };
      }
      return { alreadyProcessed: false };
    }

    logError("stripe-webhook: webhook_events insert failed", {
      provider_event_id: event.id,
      message: insertError.message,
    });
    throw insertError;
  }

  return { alreadyProcessed: false };
}

async function resolveOrderId(
  supabaseAdmin: ReturnType<typeof createClient>,
  session: Stripe.Checkout.Session,
): Promise<string | null> {
  const direct = resolveOrderIdFromSession(session);
  if (direct) return direct;

  if (!session.id) return null;

  const { data: txRow, error: txError } = await supabaseAdmin
    .from("online_payment_transactions")
    .select("order_id")
    .eq("provider_checkout_session_id", session.id)
    .maybeSingle();

  if (txError) {
    logError("stripe-webhook: transaction lookup failed", {
      checkout_session_id: session.id,
      message: txError.message,
    });
    throw txError;
  }

  const fromTx = (txRow?.order_id as string | undefined) ?? null;
  if (fromTx && isValidUuid(fromTx)) return fromTx;

  return null;
}

function retryOutcome(
  reason: string,
  checkoutSessionId?: string | null,
): HandlerOutcome {
  return { status: "retry", reason, checkoutSessionId };
}

async function handleCheckoutSessionCompleted(
  supabaseAdmin: ReturnType<typeof createClient>,
  event: Stripe.Event,
): Promise<HandlerOutcome> {
  const session = event.data.object as Stripe.Checkout.Session;

  logInfo("stripe-webhook: checkout.session.completed", {
    stripe_event_id: event.id,
    checkout_session_id: session.id,
    payment_status: session.payment_status,
    session_status: session.status,
  });

  if (!session.id) {
    logError("stripe-webhook: missing checkout session id", {
      stripe_event_id: event.id,
      retry: true,
    });
    return retryOutcome("missing_checkout_session_id");
  }

  const sessionReady = session.payment_status === "paid" &&
    session.status === "complete";

  if (!sessionReady) {
    logInfo("stripe-webhook: session not ready, deferring retry", {
      stripe_event_id: event.id,
      checkout_session_id: session.id,
      payment_status: session.payment_status,
      session_status: session.status,
      retry: true,
    });
    return retryOutcome("session_not_ready", session.id);
  }

  const orderId = await resolveOrderId(supabaseAdmin, session);
  if (!orderId || !isValidUuid(orderId)) {
    logError("stripe-webhook: paid session but order not resolved", {
      stripe_event_id: event.id,
      checkout_session_id: session.id,
      metadata_order_id: session.metadata?.order_id ?? null,
      client_reference_id: session.client_reference_id ?? null,
      resolved_order_id: orderId,
      retry: true,
    });
    return retryOutcome("order_not_resolved", session.id);
  }

  const { data: orderRow, error: orderError } = await supabaseAdmin
    .from("online_orders")
    .select(
      "id, order_status, order_kind, student_id, amount_cents, currency_code, fulfillment_status",
    )
    .eq("id", orderId)
    .maybeSingle();

  if (orderError) {
    logError("stripe-webhook: order lookup failed", {
      order_id: orderId,
      message: orderError.message,
    });
    throw orderError;
  }

  const order = orderRow as OnlineOrderRow | null;
  if (!order) {
    logError("stripe-webhook: paid session but order not found in database", {
      order_id: orderId,
      checkout_session_id: session.id,
      stripe_event_id: event.id,
      retry: true,
    });
    return retryOutcome("order_not_found", session.id);
  }

  const sessionAmount = session.amount_total;
  const sessionCurrency = (session.currency ?? "").toLowerCase();
  const orderCurrency = (order.currency_code ?? "EUR").toLowerCase();

  if (
    sessionAmount === null ||
    sessionAmount !== order.amount_cents ||
    sessionCurrency !== orderCurrency
  ) {
    logError("stripe-webhook: amount or currency mismatch", {
      order_id: orderId,
      order_amount_cents: order.amount_cents,
      session_amount_total: sessionAmount,
      order_currency: orderCurrency,
      session_currency: sessionCurrency,
    });

    await supabaseAdmin
      .from("online_orders")
      .update({
        order_status: "failed",
        fulfillment_error: "Stripe session amount or currency mismatch",
      })
      .eq("id", orderId);

    return { status: "success", orderId };
  }

  if (order.order_status !== "paid") {
    const { error: markPaidError } = await supabaseAdmin
      .from("online_orders")
      .update({ order_status: "paid" })
      .eq("id", orderId);

    if (markPaidError) {
      logError("stripe-webhook: mark order paid failed", {
        order_id: orderId,
        message: markPaidError.message,
      });
      throw markPaidError;
    }
  }

  const { error: txUpdateError } = await supabaseAdmin
    .from("online_payment_transactions")
    .update({
      payment_status: "completed",
      paid_at: new Date().toISOString(),
      provider_payment_intent_id: paymentIntentId(session.payment_intent),
      raw_provider_payload: {
        stripe_event_id: event.id,
        checkout_session_id: session.id,
        payment_status: session.payment_status,
        session_status: session.status,
        amount_total: session.amount_total,
        currency: session.currency,
      },
    })
    .eq("provider_checkout_session_id", session.id);

  if (txUpdateError) {
    logError("stripe-webhook: transaction update failed", {
      order_id: orderId,
      checkout_session_id: session.id,
      message: txUpdateError.message,
    });
    throw txUpdateError;
  }

  if (order.order_kind === "extra_video") {
    if (!order.student_id) {
      const { error: awaitingError } = await supabaseAdmin
        .from("online_orders")
        .update({ fulfillment_status: "awaiting_student_link" })
        .eq("id", orderId);

      if (awaitingError) {
        logError("stripe-webhook: awaiting_student_link update failed", {
          order_id: orderId,
          message: awaitingError.message,
        });
        throw awaitingError;
      }

      logInfo("stripe-webhook: extra_video without student_id", {
        order_id: orderId,
        fulfillment_status: "awaiting_student_link",
      });
    } else if (order.fulfillment_status !== "completed") {
      const { error: fulfillError } = await supabaseAdmin.rpc(
        "fulfill_extra_online_order",
        { p_order_id: orderId },
      );

      if (fulfillError) {
        logError("stripe-webhook: fulfill_extra_online_order failed", {
          order_id: orderId,
          message: fulfillError.message,
        });
        throw fulfillError;
      }

      logInfo("stripe-webhook: fulfillment completed", {
        order_id: orderId,
        order_kind: order.order_kind,
      });
    }
  } else {
    logInfo("stripe-webhook: order_kind not fulfilled in P4C.4", {
      order_id: orderId,
      order_kind: order.order_kind,
    });
  }

  return { status: "success", orderId };
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");

  if (!supabaseUrl || !serviceRoleKey) {
    logError("stripe-webhook: missing Supabase env", {});
    return jsonResponse({ error: "Server misconfiguration" }, 500);
  }

  if (!webhookSecret) {
    logError("stripe-webhook: missing STRIPE_WEBHOOK_SECRET", {});
    return jsonResponse({ error: "Webhook not configured" }, 503);
  }

  const signature = req.headers.get("stripe-signature");
  if (!signature) {
    logError("stripe-webhook: missing stripe-signature header", {});
    return jsonResponse({ error: "Missing signature" }, 400);
  }

  const rawBody = await req.text();

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(
      rawBody,
      signature,
      webhookSecret,
      undefined,
      cryptoProvider,
    ) as Stripe.Event;
  } catch (err) {
    logStripeError("stripe-webhook: signature verification failed", err);
    return jsonResponse({ error: "Invalid signature" }, 400);
  }

  if (event.type !== HANDLED_EVENT) {
    logInfo("stripe-webhook: ignored event type", {
      stripe_event_id: event.id,
      event_type: event.type,
    });
    return jsonResponse({ received: true, ignored: true });
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  try {
    const { alreadyProcessed } = await ensureWebhookEventRow(
      supabaseAdmin,
      event,
    );

    if (alreadyProcessed) {
      logInfo("stripe-webhook: duplicate event", {
        stripe_event_id: event.id,
        event_type: event.type,
      });
      return jsonResponse({ received: true });
    }

    const outcome = await handleCheckoutSessionCompleted(
      supabaseAdmin,
      event,
    );

    if (outcome.status === "retry") {
      logError("stripe-webhook: processing deferred for stripe retry", {
        stripe_event_id: event.id,
        event_type: event.type,
        reason: outcome.reason,
        checkout_session_id: outcome.checkoutSessionId ?? null,
        processed_at_set: false,
      });
      return jsonResponse({ error: "Processing deferred" }, 500);
    }

    await markWebhookProcessed(supabaseAdmin, event.id, outcome.orderId);

    logInfo("stripe-webhook: processed", {
      stripe_event_id: event.id,
      event_type: event.type,
      order_id: outcome.orderId,
      processed_at_set: true,
    });

    return jsonResponse({ received: true });
  } catch (err) {
    logError("stripe-webhook: processing failed", {
      stripe_event_id: event.id,
      event_type: event.type,
      message: err instanceof Error ? err.message : "unknown",
    });
    return jsonResponse({ error: "Processing failed" }, 500);
  }
});
