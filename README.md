# EmailNotificationSystem
A minimal-yet-complete email platform built with Elixir, Phoenix, and LiveView. It supports user registration/login, role-based access (frontend/admin/superuser), contacts & groups, single and bulk email sending, job queueing with Oban, and delivery/recipient status tracking.

Tech stack

Phoenix 1.8.1
Elixir 1.18.4
Erlang/OTP 27
Elixir / Phoenix / LiveView – web & real-time UI
Ecto / PostgreSQL – persistence
Oban – background jobs & priority queue
Swoosh – email delivery
Tailwind – styling (via /assets)

QUICK START
0) Prerequisites
PostgreSQL running locally
Node.js (for assets)

1) Clone & install deps
git clone https://github.com/Fene-87/email_notification_system.git
cd email_notification_system

mix deps.get

cd assets && npm install && cd ..

2) Database
Configure your local DB in config/dev.exs and config/test.exs if necessary, then:

mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs

Login credentials:
 - Frontend user: Email: user@email.com, Password: User123!
 - Admin user: Email: admin@email.com, Password: Admin123!
 - Superuser: Email: superuser@email.com, Password: Super123!

(There’s a migration that creates the Oban jobs table, so you don’t need to add it.)

4) Start the app
# Dev server with interactive shell:
iex -S mix phx.server

or

mix phx.server

Visit http://localhost:4000.


HOW THE SYSTEM WORKS(user flows)
1) Authentication
/auth – Register or login.
After you register, you will now have to login
After login, you land on /dashboard.

2) Frontend user features
Contacts (/contacts): create, edit, delete.
Compose email (/emails/compose): pick Single or Bulk.
Emails (/emails): see sent/queued/failed; delete sent emails; view per-recipient status.
Sending uses Swoosh in a background job via Oban.
Each recipient is an EmailRecipient row with status lifecycle: pending → sent|failed|bounced.

3) Admin features
Admin → Manage Users (/admin/users):
View users and their emails.
Delete user (+ cascade delete all their data).
If superuser: upgrade user to gold plan; grant/revoke admin.

4) Gold plan features (superuser can assign)
Retry failed emails (on /emails) – re-enqueues only failed/bounced/pending recipients.
Groups (/groups) – create groups, add contacts, send group emails.
Group email status – per-group statistics (sent/pending/failed contacts).

Background jobs & priority queueing
Oban runs in the supervision tree (see application.ex).
Jobs go to queue :emails.
Priority is set from the email’s priority (1 = highest, 10 = lowest).
Worker: EmailNotificationSystem.Workers.EmailWorker

To verify jobs are running:
Check DB table oban_jobs while sending/retrying.
Watch server logs ([debug] and worker logs) as emails are processed.

Data model (high level)
users: access_level (frontend/admin), plan_type (basic/gold), plus profile fields.
contacts: belong to users; have is_active, email_address, indexes on (user_id, email_address).
groups: belong to users; many-to-many with contacts via group_contacts.
emails: belong to users (and optionally a group), fields like priority, status, sent_at.
email_recipients: belong to emails and contacts; per-recipient status & timestamps.
Migrations include sensible FKs, indexes, constraints, and the Oban jobs table.

Running tests
mix test


Tests cover:
Accounts (authenticate, create)
LiveViews (contacts, compose/send, admin users)
Emails logic (queuing, retry checks)

Key routes (cheat sheet)
/auth – login/register
/dashboard – landing after login
/contacts – manage contacts
/emails – list/history, delete, retry (gold)
/emails/compose – compose single/bulk/group
/groups – manage groups (gold)
/admin/users – admin management; superuser can upgrade/grant/revoke
