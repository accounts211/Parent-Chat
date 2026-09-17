# Parent Chat — web and iOS app outline

This repository contains a static Parent Chat web site plus a lightweight iOS wrapper folder intended for use inside Xcode.

## Local web run

```sh
cd parent-chat-repo
npm start
```

The web app is served at http://127.0.0.1:8000/index.html.

## iOS Xcode wrapper

Use the Swift files under `ios/ParentChatApp` as a source starter in an Xcode iOS app target. The wrapper loads the same app through `WKWebView`.

## Production requirements

1. Create a Supabase project and run `backend/schema.sql`.
2. Configure Auth Email/password, confirmation and reset emails, and add the
	configured Redirect / Site URLs.
3. Configure Stripe product and payment link.
4. Deploy `backend/stripe-webhook.ts` as a Supabase Edge Function named `stripe-webhook`.
5. Replace the placeholder credentials in `index.html` with real `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `STRIPE_PAYMENT_LINK` values.

The static HTML app can open locally from the `npm start` server. The iOS wrapper can be built on a Mac in Xcode with the same website URL or a secure HTTPS production host.
