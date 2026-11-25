# MARKIO — Student commerce, made simple.

MARKIO is a university-first marketplace that helps students discover student-owned businesses, products, and services within their university community. It launches at Bells University of Technology, with an architecture intended to support additional universities later.

## Current product capabilities

- Supabase email/password authentication and student profile onboarding.
- Free student buyer accounts and seller applications.
- Admin-reviewed seller approval and vendor storefronts.
- Product and service listings with image uploads, categories, prices, availability, and fulfilment options.
- Marketplace search, category filtering, price sorting, product details, and saved listings.
- Direct buyer-to-vendor contact through WhatsApp. Buyers and sellers arrange collection, delivery, and payment directly.
- Listing reports, seller application moderation, listing moderation, and a private administrator workspace.
- Responsive desktop and mobile layouts with reduced-motion support.

## MARKIO Premium foundations

The Premium area is designed for approved student vendors. The current implementation includes:
- Vendor listing-view analytics.
- Premium early-access interest registration and administrator review.
- A subscription data model that can later be connected to a verified payment provider.

**Paid checkout is not enabled yet.** Do not activate subscriptions or mark accounts as paid from the browser. A payment provider integration and a server-side webhook that verifies provider signatures must be implemented before collecting subscription payments or granting paid access.

## Run locally

1. Install Node.js LTS.
2. Run `npm install`.
3. Copy `.env.example` to `.env.local`.
4. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` using the MARKIO Supabase project values.
5. Run `npm run dev` and open the local URL Vite prints.

Never add a Supabase `service_role` key or secret key to frontend environment variables or Git.

## Database and security

The application uses the existing Supabase project and marketplace schema. The MARKIO Premium foundation adds:
- `listing_views`: authenticated, non-owner product views, visible to the listing's vendor.
- `premium_interest`: a vendor early-access list with admin-only status management.
- `vendor_subscriptions`: subscription records readable by the account owner and administrators; browser clients cannot create or activate subscriptions.

These new tables have Row Level Security enabled and explicit Data API grants. Keep the existing authentication, marketplace, and administrator policies intact when extending the database.

## Build check

```bash
npm install
npm run build
```

The GitHub Actions build workflow and Vercel Preview deployment should pass before merging a change into `main`.
