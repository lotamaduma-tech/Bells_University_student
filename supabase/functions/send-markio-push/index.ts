import { createClient } from "npm:@supabase/supabase-js@2.57.0";
import webpush from "npm:web-push@3.6.7";

const cors = {
  "Access-Control-Allow-Origin": Deno.env.get("APP_ORIGIN") || "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405, headers: cors });

  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const publicKey = Deno.env.get("MARKIO_VAPID_PUBLIC_KEY");
  const privateKey = Deno.env.get("MARKIO_VAPID_PRIVATE_KEY");
  const subject = Deno.env.get("MARKIO_VAPID_SUBJECT");
  if (!url || !anon || !service || !publicKey || !privateKey || !subject) {
    return Response.json({ error: "Push delivery is not configured on the server." }, { status: 503, headers: cors });
  }

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return Response.json({ error: "Authentication required." }, { status: 401, headers: cors });
  const authClient = createClient(url, anon, { global: { headers: { Authorization: authorization } } });
  const { data: { user }, error: authError } = await authClient.auth.getUser();
  if (authError || !user) return Response.json({ error: "Invalid session." }, { status: 401, headers: cors });

  let body: { notificationId?: string };
  try { body = await req.json(); } catch { return Response.json({ error: "Invalid JSON." }, { status: 400, headers: cors }); }
  if (!body.notificationId) return Response.json({ error: "notificationId is required." }, { status: 400, headers: cors });

  const db = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: notification, error: notificationError } = await db.from("markio_notifications")
    .select("id,recipient_id,title,body,target_path,category,created_at")
    .eq("id", body.notificationId).eq("recipient_id", user.id).maybeSingle();
  if (notificationError || !notification) return Response.json({ error: "Notification not found." }, { status: 404, headers: cors });

  const { data: prefs } = await db.from("markio_notification_preferences").select("push_enabled").eq("user_id", user.id).maybeSingle();
  if (!prefs?.push_enabled || notification.category === "admin" || notification.category === "account_security") {
    return Response.json({ sent: 0, skipped: true }, { headers: cors });
  }

  webpush.setVapidDetails(subject, publicKey, privateKey);
  const { data: subscriptions, error: subscriptionError } = await db.from("markio_push_subscriptions")
    .select("id,endpoint,p256dh,auth").eq("user_id", user.id).is("disabled_at", null);
  if (subscriptionError) return Response.json({ error: "Could not load device subscriptions." }, { status: 500, headers: cors });

  let sent = 0;
  let expired = 0;
  for (const item of subscriptions || []) {
    try {
      await webpush.sendNotification(
        { endpoint: item.endpoint, keys: { p256dh: item.p256dh, auth: item.auth } },
        JSON.stringify({ title: notification.title, body: notification.body, url: notification.target_path, notificationId: notification.id }),
        { TTL: 60 * 60 * 24, urgency: "normal" },
      );
      sent += 1;
      await db.from("markio_push_subscriptions").update({ last_seen_at: new Date().toISOString(), last_error: null }).eq("id", item.id);
    } catch (error) {
      const status = Number((error as { statusCode?: number })?.statusCode || 0);
      if (status === 404 || status === 410) {
        expired += 1;
        await db.from("markio_push_subscriptions").update({ disabled_at: new Date().toISOString(), last_error: "Subscription expired" }).eq("id", item.id);
      } else {
        await db.from("markio_push_subscriptions").update({ last_error: String(error).slice(0, 500) }).eq("id", item.id);
      }
    }
  }
  return Response.json({ sent, expired, attempted: (subscriptions || []).length }, { headers: cors });
});