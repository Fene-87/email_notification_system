# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     EmailNotificationSystem.Repo.insert!(%EmailNotificationSystem.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias EmailNotificationSystem.{Repo, Accounts}
alias EmailNotificationSystem.Accounts.User

upsert_user = fn attrs ->
  case Repo.get_by(User, email_address: attrs.email_address) do
    nil ->
      case Accounts.create_user(attrs) do
        {:ok, user} -> user
        {:error, changeset} ->
          raise "Failed to create #{attrs.email_address}: #{inspect(changeset.errors)}"
      end

    user ->
      user
  end
end

# --- Admin user ---
admin =
  upsert_user.(%{
    first_name: "Admin",
    last_name: "User",
    email_address: "admin@email.com",
    msisdn: "+1111111111",
    password: "Admin123!"
  })

{:ok, _admin} =
  Accounts.update_user(admin, %{
    access_level: "admin",
    plan_type: "basic",
    is_active: true,
    email_verified: true
  })

# --- Regular (frontend) user ---
frontend_user =
  upsert_user.(%{
    first_name: "Regular",
    last_name: "User",
    email_address: "user@email.com",
    msisdn: "+1111111112",
    password: "User123!"
  })

{:ok, _frontend_user} =
  Accounts.update_user(frontend_user, %{
    access_level: "frontend",
    plan_type: "basic",
    is_active: true,
    email_verified: true
  })

# --- Superuser ---
superuser =
  upsert_user.(%{
    first_name: "Super",
    last_name: "User",
    email_address: "superuser@user.com",
    msisdn: "+1111111113",
    password: "Super123!"
  })

{:ok, _superuser} =
  Accounts.update_user(superuser, %{
    access_level: "superuser",
    plan_type: "gold",
    is_active: true,
    email_verified: true
  })

IO.puts("""
Seeded users:
  - admin@email.com      (password: Admin123!,    access: admin,     plan: basic)
  - user@email.com       (password: User123!,     access: frontend,  plan: basic)
  - superuser@user.com   (password: Super123!,    access: superuser, plan: gold)
""")
