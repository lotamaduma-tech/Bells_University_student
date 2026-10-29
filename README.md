# BellsConnect — Bells University campus social network

BellsConnect is a campus-first social network for Bells University of Technology students. It is designed for students aged 16 and above and focuses on meeting classmates, finding study/activity partners, connecting by username, messaging accepted connections, and planning meet-ups at public campus locations.

## Run locally

1. Install Node.js LTS.
2. Run `npm install`.
3. Copy `.env.example` to `.env.local`.
4. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` using the BellsConnect Supabase project values.
5. Run `npm run dev` and open the local URL Vite prints.

Never add a Supabase `service_role` key or secret key to frontend environment variables or Git.

## Current features

- Responsive desktop/mobile BellsConnect interface.
- Supabase email/password sign-up and login.
- 16+ date-of-birth validation in the client and database trigger, with no arbitrary upper age limit.
- Real member profiles only; no seeded demo discovery profiles.
- Generated unique usernames and username/name/interest search.
- Connection requests, acceptance/decline, and private real-time messaging for accepted connections.
- Shareable member profile links (the viewer must sign in).
- Campus meet-up plans using public campus locations.
- Food-spot discovery links for known on-campus listings; names and opening details should be verified by students before relying on them.
- RLS-backed Bells-only profile visibility, connections, chats, meet-ups, and profile-photo access.

## Supabase configuration still required

The connected Supabase database schema has been updated. Email confirmation is controlled by Supabase Auth settings, not the frontend. To allow sign-up without an email verification link, open [Supabase Auth Providers](https://supabase.com/dashboard/project/gxiirebjidkgucucegzn/auth/providers) and disable **Confirm email** for the Email provider. Then test sign-up and sign-in using a fresh test account.

Disabling email confirmation means email ownership is not verified. BellsConnect does not yet have an automated student-record verification integration, so do not describe accounts as institution-verified. A student verification/moderation workflow should be added before a broad launch.

## Database migrations

- `supabase/migrations/202610290001_bloom_initial_schema.sql` — original baseline schema.
- `supabase/migrations/202610290004_bellsconnect_campus_social.sql` — 16+ policy and campus social tables.
- `supabase/migrations/202610290005_bellsconnect_usernames.sql` — unique usernames.
- `supabase/migrations/202610290006_bellsconnect_isolate_campus.sql` — Bells-only profile visibility and indexes.

These migrations target the dedicated BellsConnect/Bloom Supabase project only. Never apply them to Adumex AI or NectarSpend.

## Build check

```bash
npm install
npm run build
```

The GitHub Actions build check is required before merging changes. End-to-end sign-up, realtime chat, and meetup flows still need testing with two real test accounts on the deployed preview.
