# Vibe — Bells University-first dating prototype

Vibe is a mobile-first dating experience prototype. The initial build uses fictional adult demo profiles and local browser persistence. It does not provide real accounts, remote matching, verification, or cross-device messaging yet.

## Run locally

1. Install Node.js (LTS).
2. Run `npm install`.
3. Run `npm run dev`.
4. Open the local URL printed by Vite.

## Current prototype features

- Discovery feed with the requested gesture mapping: swipe left = accept, right = decline, down = next.
- Accessible Accept / Decline / Next controls and undo.
- Profile detail modal, Accepted list, local demo chats, profile editor and discovery filters.
- Local persistence for demo decisions, messages, profile edits and filters.
- Reduced-motion support, keyboard-friendly controls, responsive mobile/desktop layouts.
- Report/block controls in profile details (local demo behavior only).

## Backend status

No Supabase project has been selected for Vibe yet. The currently connected Supabase projects visible to the integration are named for other products, so this prototype does not connect to or modify them. Real auth, storage, matching, moderation, and messaging require a dedicated Vibe backend and server-enforced Row Level Security.

## Design note

The supplied reference image is pastel pink/ivory, while the written specification explicitly defines a dark palette (#0B0B0F, #15151B, #FF3D70). This implementation follows the written hex palette while retaining the reference's romantic, rounded visual language. The palette can be switched once you confirm which direction is final.
