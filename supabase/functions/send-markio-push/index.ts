import { createClient } from "npm:@supabase/supabase-js@2.57.0";
import webpush from "npm:web-push@3.6.7";

type DispatchBody = { notificationId?: string; dispatchToken?: string };
type PushPreference = {
  push_enabled?: boolean;
  order_notifications?: boolean;
  seller_activity?: boolean;
  product_updates?: boolean;
  announcements?: boolean;
};
type NotificationRow = {
  id: string;
  recipient_id: string;
  title: string;
  body: string;
  target_path: string;
  category: string;
};

const json = (body: Record<string, unknown>, status = 200) =>
  Response.json(body, { status, headers: { "Cache-Control": "no-store" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  let body: DispatchBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON." }, 400);
  }

  if (
    typeof body.notificationId !== "string" ||
    typeof body.dispatchToken !== "string" ||
    !/^[0-9a-f]{64}$/.test(body.dispatchToken)
  ) {
    return json({ error: "Invalid dispatch request." }, 400);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !service) return json({ error: "Server configuration is unavailable." }, 503);

  const db = createClient(url, service, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: claimed, error: claimError } = await db.rpc("markio_claim_push_job", {
    p_notification_id: body.notificationId,
    p_dispatch_token: body.dispatchToken,
  });
  if (claimError) return json({ error: "Could not claim notification dispatch." }, 500);

  const job = Array.isArray(claimed) ? claimed[0] : claimed;
  if (!job?.recipient_id) return json({ accepted: true, claimed: false }, 202);

  const finish = async (
    status: "delivered" | "skipped" | "retry" | "failed",
    errorMessage: string | null = null,
    retryDelaySeconds = 60,
  ) => {
    const { error } = await db.rpc("markio_finish_push_job", {
      p_notification_id: body.notificationId,
      p_dispatch_token: body.dispatchToken,
      p_status: status,
      p_error: errorMessage,
      p_retry_delay_seconds: retryDelaySeconds,
    });
    if (error) throw error;
  };

  try {
    const { data: notification, error: notificationError } = await db
      .from("markio_notifications")
      .select("id,recipient_id,title,body,target_path,category")
      .eq("id", body.notificationId)
      .eq("recipient_id", job.recipient_id)
      .maybeSingle();

    if (notificationError || !notification) {
      await finish("failed", "Notification record is unavailable.");
      return json({ error: "Notification not found." }, 404);
    }

    const notice = notification as NotificationRow;
    const { data: prefs, error: prefsError } = await db
      .from("markio_notification_preferences")
      .select("push_enabled,order_notifications,seller_activity,product_updates,announcements")
      .eq("user_id", notice.recipient_id)
      .maybeSingle();

    if (prefsError) throw prefsError;

    const categoryPreference: Record<string, keyof PushPreference> = {
      orders: "order_notifications",
      seller_activity: "seller_activity",
      product_updates: "product_updates",
      announcements: "announcements",
    };
    const preference = categoryPreference[notice.category];
    if (
      !prefs?.push_enabled ||
      notice.category === "admin" ||
      notice.category === "account_security" ||
      (preference && (prefs as PushPreference)[preference] === false)
    ) {
      await finish("skipped");
      return json({ sent: 0, skipped: true });
    }

    const { data: subscriptions, error: subscriptionError } = await db
      .from("markio_push_subscriptions")
      .select("id,endpoint,p256dh,auth")
      .eq("user_id", notice.recipient_id)
      .is("disabled_at", null);

    if (subscriptionError) throw subscriptionError;
    if (!subscriptions?.length) {
      await finish("skipped", "No active push subscriptions.");
      return json({ sent: 0, skipped: true });
    }

    const publicKey = Deno.env.get("MARKIO_VAPID_PUBLIC_KEY");
    const privateKey = Deno.env.get("MARKIO_VAPID_PRIVATE_KEY");
    const subject = Deno.env.get("MARKIO_VAPID_SUBJECT");
    if (!publicKey || !privateKey || !subject) {
      await finish("retry", "VAPID configuration is incomplete.", 1800);
      return json({ error: "Push delivery is not configured on the server." }, 503);
    }

    const { data: alreadyDelivered, error: deliveryReadError } = await db.rpc(
      "markio_get_push_delivery_subscription_ids",
      { p_notification_id: notice.id },
    );
    if (deliveryReadError) throw deliveryReadError;

    const deliveredIds = new Set<string>((alreadyDelivered || []) as string[]);
    webpush.setVapidDetails(subject, publicKey, privateKey);

    let sent = 0;
    let expired = 0;
    let transientFailures = 0;

    for (const item of subscriptions) {
      if (deliveredIds.has(item.id)) continue;
      try {
        const targetPath =
          typeof notice.target_path === "string" &&
          notice.target_path.startsWith("/") &&
          !notice.target_path.startsWith("//")
            ? notice.target_path
            : "/";

        await webpush.sendNotification(
          { endpoint: item.endpoint, keys: { p256dh: item.p256dh, auth: item.auth } },
          JSON.stringify({
            title: notice.title,
            body: notice.body,
            url: targetPath,
            notificationId: notice.id,
            tag: notice.id,
          }),
          { TTL: 60 * 60 * 24, urgency: "normal" },
        );

        const { error: recordError } = await db.rpc("markio_record_push_delivery", {
          p_notification_id: notice.id,
          p_subscription_id: item.id,
        });
        if (recordError) throw recordError;

        sent += 1;
        await db
          .from("markio_push_subscriptions")
          .update({ last_seen_at: new Date().toISOString(), last_error: null })
          .eq("id", item.id)
          .eq("user_id", notice.recipient_id);
      } catch (error) {
        const status = Number((error as { statusCode?: number })?.statusCode || 0);
        if (status === 404 || status === 410) {
          expired += 1;
          await db
            .from("markio_push_subscriptions")
            .update({
              disabled_at: new Date().toISOString(),
              last_error: "Subscription expired.",
            })
            .eq("id", item.id)
            .eq("user_id", notice.recipient_id);
        } else {
          transientFailures += 1;
          await db
            .from("markio_push_subscriptions")
            .update({ last_error: String(error).slice(0, 400) })
            .eq("id", item.id)
            .eq("user_id", notice.recipient_id);
        }
      }
    }

    if (transientFailures > 0) {
      const attempts = Number(job.attempt_count || 1);
      const delay = Math.min(3600, 30 * Math.pow(2, Math.max(0, attempts - 1)));
      await finish("retry", "One or more push providers failed temporarily.", delay);
    } else {
      await finish("delivered");
    }

    return json({
      sent,
      expired,
      attempted: subscriptions.length,
      previouslyDelivered: deliveredIds.size,
      retried: transientFailures > 0,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected push dispatch failure.";
    try {
      const attempts = Number(job.attempt_count || 1);
      const delay = Math.min(3600, 30 * Math.pow(2, Math.max(0, attempts - 1)));
      await finish("retry", message.slice(0, 400), delay);
    } catch {
      // The database lease expires and the scheduled dispatcher will retry the job.
    }
    return json({ error: "Push dispatch failed; the job remains eligible for retry." }, 500);
  }
});
