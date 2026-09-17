# Parent Chat — backend, auth, paywall &amp; admin setup

Four things, in order: database → real sign-in → paywall → seeing who's
signed up. Do them in this order — auth needs the database to exist first,
and the paywall needs auth to exist first.

---

## 1. Create the database (Supabase)

1. Go to **supabase.com** → sign up (free) → **New project**. Pick a name,
   a database password (save it), and a region close to the UK.
2. **SQL Editor → New query** → paste in the full contents of `schema.sql`
   → **Run**. This creates all the tables, locks them down with Row Level
   Security, and sets up a database trigger that notifies members about
   matching marketplace searches (more on why below).
3. **Optional but recommended:** run `seed.sql` too. It adds a handful of
   realistic events, forum threads and marketplace listings so the app
   doesn't feel empty the first time someone opens it. Safe to skip, and
   safe to delete later.
4. **Project Settings → API** → copy the **Project URL** and the **anon
   public** key.
5. Open `index.html`, find near the top of the `<script>` tag:
   ```js
   const SUPABASE_URL = "YOUR_SUPABASE_PROJECT_URL";
   const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
   ```
   Replace both. Save.

---

## 2. Turn on real sign-in

The app uses Supabase email/password authentication. New users create an
account, confirm their email, and are signed in automatically. Returning
users sign in with their password. A password reset link is available for
existing users and forgotten passwords.

1. Supabase Dashboard → **Authentication → Providers** → make sure
   **Email** is enabled (it is by default).
2. **Authentication → URL Configuration**: set the **Site URL** to
  `https://parent-chat.netlify.app` and add
  `https://parent-chat.netlify.app/**` under **Redirect URLs**.
3. Configure the **Confirm signup** and **Reset password** email templates;
  keep `{{ .ConfirmationURL }}` in both templates.
4. Test account creation, email confirmation, password sign-in, and password
  reset from a fresh browser session.

**What changed under the hood:** a member's `id` in the database is now the
same id Supabase's Auth system assigns them, so the database itself can
enforce "you can only ever edit your own profile" — this isn't just a UI
rule, it's enforced at the database level even if someone bypasses your
app entirely. Saved marketplace searches and notifications are now private
per-member too (previously, in principle, the whole `saved_filters` table
was readable by anyone with the anon key). The one trade-off: since your
browser can no longer read *other* people's saved searches, the "notify
matching members" feature had to move server-side — it's now a Postgres
trigger (in `schema.sql`) that runs the matching with elevated privileges
and only ever writes notifications, never lets anyone read others' filters.

---

## 3. Set up the paywall (Stripe)

1. **stripe.com** → sign up. Use **Test mode** first.
2. **Product catalogue → Add product**: "Parent Chat Premium", £9.99,
   **Recurring, Monthly**. Save.
3. On that product, **Create payment link**. Set the confirmation page to
   **"Redirect to your website"**:
   ```
   https://your-site.netlify.app/?upgraded=1
   ```
4. Copy the link into `index.html`:
   ```js
   const STRIPE_PAYMENT_LINK = "YOUR_STRIPE_PAYMENT_LINK";
   ```
5. **Deploy the webhook**: Supabase Dashboard → **Edge Functions** →
   **Create a function** → name it `stripe-webhook` → paste in
   `stripe-webhook.ts` → **Deploy**.
   - Add secrets (same page, or Project Settings → Edge Functions →
     Secrets): `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`,
     `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` (the **service_role** key
     — Project Settings → API. Keep this one secret, it bypasses every
     rule in the database, which is exactly why the webhook needs it and
     the frontend never should have it).
   - Stripe → **Developers → Webhooks → Add endpoint** →
     `https://<your-project-ref>.functions.supabase.co/stripe-webhook` →
     select `checkout.session.completed` and
     `customer.subscription.deleted` → **Add endpoint**. Copy the signing
     secret it shows you into `STRIPE_WEBHOOK_SECRET`.
6. Test: sign in, click Upgrade, pay with Stripe's test card
   `4242 4242 4242 4242` (any future date/CVC). You should land back on the
   app, see "Activating your Premium…", and the badge appears within a few
   seconds.

Stripe takes roughly 1.5% + 20p per UK transaction on top of what you charge.

---

## 4. See who's signed up

- **No code:** Supabase Dashboard → **Table Editor** → `members`. Every
  signup is a row — sort, filter, export to CSV. Same for `events`,
  `forum_threads`, `market_listings`.
- **Inside the app:** add your email to `ADMIN_EMAILS` near the top of the
  script, sign in with it, and open **Members** — an extra "Admin" card
  shows total members, Premium conversion rate, content counts, and recent
  signups.
- **Netlify** still won't show any of this — it only knows about page
  visits, not who's a member.

---

## Before this goes properly public

- **A real privacy policy**, since the app now collects verified emails,
  names, locations and photos through a proper login. Needed both for
  Apple (if you go the App Store route later) and honestly, for anyone.
- **Rate limiting on sign-in**, if this gets any real traffic — Supabase
  has sensible defaults, but worth checking Authentication → Rate Limits
  before a public launch.
- Everything else from the original App Store notes (StoreKit instead of
  Stripe if you wrap this natively) still applies — see the earlier
  `parent-chat-capacitor.zip` README if you go that route.

---

## 5. What's new since the UX review

A few product changes went in based on a first-time-user walkthrough:

- **One banner, not two.** The old "set your area" and "join now" banners
  used to stack on top of each other. Now there's a single smart banner
  that shows exactly one message, in priority order (set your area → join
  → try Premium → nothing, once you're already Premium).
- **"Use my location"** appears next to every town picker (the banner, the
  Set Area modal, and the sign-up form) — one tap instead of scrolling a
  48-town dropdown, using the browser's geolocation to find the nearest
  match.
- **Search** on Events, Forum and Marketplace — a simple text filter on
  top of the existing distance filter.
- **Free "save for later"** — a heart icon on event cards and map places
  lets anyone (not just Premium) bookmark things, visible in a "Saved for
  later" card on their Members dashboard. This is the free tier's reason
  to come back, separate from the Premium saved-search-alerts feature.
- **Reporting** — a "Report this" link on forum threads and marketplace
  listings opens a short form (reason + optional details) that goes
  straight into the new `reports` table. Nothing public-facing reads that
  table — check it via Supabase Table Editor.
- **Community guidelines** — a short, honest one-pager linked from the
  footer.
- **A safety note on Marketplace** — "meet in a public place" — sitting
  above every listing.
- **Premium reframed**: first month free ("founding member" framing while
  the community is small), and the redundant duplicate upgrade button
  removed from the Members page — down to one clear ask per screen instead
  of three or four.

To configure the free trial in Stripe: on your Payment Link (or the
underlying Price), add a trial period — Stripe Dashboard → your product →
**Add a free trial** → 30 days — so "first month free" is actually true
at checkout, not just in the app's copy.

