// Supabase Edge Function: stripe-webhook
// Deploy via: Supabase Dashboard → Edge Functions → Create function → name it
// "stripe-webhook" → paste this in → Deploy.
//
// Then set these secrets (Dashboard → Edge Functions → stripe-webhook → Secrets,
// or Project Settings → Edge Functions → Secrets):
//   STRIPE_SECRET_KEY        (Stripe Dashboard → Developers → API keys)
//   STRIPE_WEBHOOK_SECRET    (created when you add the webhook endpoint below)
//   SUPABASE_URL             (Project Settings → API)
//   SUPABASE_SERVICE_ROLE_KEY (Project Settings → API — keep this secret, never
//                              put it in the frontend code)
//
// Then in Stripe Dashboard → Developers → Webhooks → Add endpoint, use:
//   https://<your-project-ref>.functions.supabase.co/stripe-webhook
// and select the "checkout.session.completed" event.

const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY")!;

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const signature = req.headers.get("Stripe-Signature");
  const body = await req.text();

  try {
    const event = await verifyStripeEvent(body, signature ?? "", webhookSecret);
    if (!event.id || !(await claimStripeEvent(event.id, event.type))) {
      return new Response("ok", { status: 200 });
    }

    if (event.type === "checkout.session.completed") {
      const session = event.data?.object ?? {};
      const email = ((session.customer_details?.email || session.customer_email || "") as string).toLowerCase();

      if (email) {
        await patchMemberPremium(email, true);
      }
    }

    if (event.type === "customer.subscription.deleted") {
      const sub = event.data?.object ?? {};
      const customerId = sub.customer as string;
      const customerEmail = await fetchCustomerEmail(customerId, stripeSecretKey);

      if (customerEmail) {
        await patchMemberPremium(customerEmail.toLowerCase(), false);
      }
    }

    return new Response("ok", { status: 200 });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("Webhook Error:", message);
    return new Response(`Webhook Error: ${message}`, { status: 400 });
  }
});

async function verifyStripeEvent(body: string, signature: string, webhookSecret: string): Promise<any> {
  if (!signature) throw new Error("Missing Stripe-Signature header");

  const parts = signature.split(",");
  const timestampPart = parts.find((part) => part.startsWith("t="));
  const timestamp = timestampPart ? Number(timestampPart.slice(2)) : NaN;

  if (!Number.isFinite(timestamp)) {
    throw new Error("Missing or invalid Stripe-Signature timestamp");
  }
  if (Math.abs(Math.floor(Date.now() / 1000) - timestamp) > 300) {
    throw new Error("Stripe-Signature timestamp is outside the five-minute tolerance");
  }

  const hashes = parts
    .filter((part) => part.startsWith("v1="))
    .map((part) => part.slice(3));

  if (hashes.length === 0) {
    throw new Error("Missing Stripe-Signature v1 hash");
  }

  const payload = `${timestamp}.${body}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(webhookSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const digestBytes = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload))
  );
  const digest = bytesToHex(digestBytes);

  const verified = hashes.some((candidate) => timingSafeEqual(candidate, digest));
  if (!verified) {
    throw new Error("Signature verification failed");
  }

  return JSON.parse(body);
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function timingSafeEqual(a: string, b: string): boolean {
  const aBytes = new TextEncoder().encode(a);
  const bBytes = new TextEncoder().encode(b);
  if (aBytes.length !== bBytes.length) return false;

  let result = 0;
  for (let i = 0; i < aBytes.length; i++) {
    result |= aBytes[i] ^ bBytes[i];
  }
  return result === 0;
}

async function patchMemberPremium(email: string, premium: boolean) {
  const update = premium
    ? { premium: true, premium_since: new Date().toISOString() }
    : { premium: false, premium_since: null };

  const url = `${supabaseUrl}/rest/v1/members?email=eq.${encodeURIComponent(email)}`;
  const response = await fetch(url, {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      Prefer: "return=minimal",
      Authorization: `Bearer ${serviceRoleKey}`,
      apikey: serviceRoleKey,
    },
    body: JSON.stringify(update),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Failed to update member status: ${response.status} ${text}`);
  }
}

async function claimStripeEvent(eventId: string, eventType: string): Promise<boolean> {
  const response = await fetch(`${supabaseUrl}/rest/v1/stripe_events`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Prefer: "return=minimal",
      Authorization: `Bearer ${serviceRoleKey}`,
      apikey: serviceRoleKey,
    },
    body: JSON.stringify({event_id: eventId, event_type: eventType}),
  });

  if (response.status === 409) return false;
  if (!response.ok) throw new Error(`Failed to record Stripe event: ${response.status}`);
  return true;
}

async function fetchCustomerEmail(customerId: string, stripeSecretKey: string): Promise<string> {
  const url = `https://api.stripe.com/v1/customers/${encodeURIComponent(customerId)}`;
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${stripeSecretKey}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Stripe customer lookup failed: ${response.status}`);
  }

  const data = await response.json();
  return (data.email ?? "") as string;
}

