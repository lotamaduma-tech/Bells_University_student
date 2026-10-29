# BellsConnect private feedback administration

## What this adds
- Signed-in students can submit suggestions, bug reports, experience notes, or other feedback from **My profile → Give the developer feedback**.
- Feedback is stored in `public.bellsconnect_feedback` in Supabase.
- The private dashboard is at `/admin` (for example, `https://YOUR-BELLSCONNECT-DOMAIN/admin`).
- Row Level Security allows authenticated users to submit their own feedback. Only user IDs listed in `public.bellsconnect_admins` can read or update submissions.
- Email notifications are not configured by this feature; the dashboard is the source of truth.

## Grant your account admin access once
1. Sign in to BellsConnect with the account you want to use as the administrator.
2. Open the Supabase project's **Authentication → Users** page: https://supabase.com/dashboard/project/gxiirebjidkgucucegzn/auth/users
3. Find your account and copy its **User UID**.
4. Open the SQL Editor: https://supabase.com/dashboard/project/gxiirebjidkgucucegzn/sql/new
5. Run the following after replacing the placeholder with your exact User UID:

```sql
insert into public.bellsconnect_admins (user_id)
values ('YOUR_AUTH_USER_UUID')
on conflict (user_id) do nothing;
```

Do not use your email address in place of the UUID. Do not add a student or other account unless you intend to grant full feedback-reading access.

## View feedback
1. Sign in to BellsConnect with the administrator account.
2. Open `https://YOUR-BELLSCONNECT-DOMAIN/admin`.
3. Use the status filter to view New, Reviewing, or Resolved feedback. Update a submission's status as you work through it.
4. Refresh to load the latest submissions.

## Security notes
- Do not put a Supabase service-role key in frontend code.
- Do not remove the RLS policies on these tables.
- Admin access is granted by the database membership table, not by hiding the page in the UI.
- Feedback currently requires a signed-in user. It does not store the student's email address in the feedback record, and it does not email feedback automatically.
