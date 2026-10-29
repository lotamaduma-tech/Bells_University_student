# Bloom — Bells University-first dating app

Bloom is a mobile-first, campus-focused dating app project for adults aged 18 and over. The current UI prototype contains fictional sample profiles; those samples are not real members. The dedicated Bloom Supabase project has been created. The frontend must be redeployed after configuring its Vercel environment variables; full registration, profile upload, matching, and cross-device messaging still require end-to-end testing.

## Run locally

1. Install Node.js LTS.
2. Run `npm install`.
3. Copy `.env.example` to `.env.local`.
4. Add the dedicated Bloom Supabase project URL and publishable key to `.env.local` for local development. These variables are also configured in Vercel for production, preview, and development.
5. Run `npm run dev` and open the local URL Vite prints.

Never add a Supabase `service_role` key or any secret key to frontend environment variables or Git.

## Current implementation

- Bloom welcome/intro screen and sign-up/login UI.
- Adult-only (18+) date-of-birth check in the UI and database signup trigger.
- Email verification flow (requires email confirmation to be enabled in Supabase Auth).
- Profile onboarding: display name, profile photo, bio, interests, sports, likes, dislikes, and relationship intention.
- Private profile-photo bucket with owner upload policies.
- SQL schema for profiles, preferences, likes, mutual matches, conversations, members, messages, blocks, reports and profile prompts.
- Database functions for secure profile completion and atomic mutual-match creation.
- Client service functions for discovery profile loading, match decisions, message history, sending messages and Realtime message subscriptions.

## Supabase setup

The initial migration is in `supabase/migrations/202610290001_bloom_initial_schema.sql`.

**Only apply this migration to a dedicated Bloom Supabase project. Do not apply it to Adumex AI or NectarSpend.**

After the project is created:

1. Open its SQL Editor or apply the migration with the Supabase migration workflow.
2. Confirm email verification is enabled in Authentication settings.
3. Copy the project URL and publishable key into `.env.local` as `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`.
4. Test signup with a dedicated test account, complete onboarding, and verify that unauthenticated users cannot read profile or chat data.
5. Test messaging with two verified adult test accounts and confirm that only mutual matches can create a conversation.

## Security notes

- The frontend publishable key is intended for browser use; database access must be constrained by RLS.
- Never trust frontend checks alone for age, matching or conversation membership.
- Profile images are stored in a private bucket.
- The database only creates a conversation after a mutual like.
- Report submission is stored in the database, but an operational moderation workflow and response process still need to be established.
- University affiliation verification is not yet implemented; do not label members as university-verified until a real verification process exists.
- The prototype still contains fictional sample discovery profiles and local demo chat UI; do not present those as real members or live messages.

## Build

```bash
npm install
npm run build
```
