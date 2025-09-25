defmodule EmailNotificationSystem.AccountsTest do
  use EmailNotificationSystem.DataCase, async: true
  alias EmailNotificationSystem.Accounts
  alias EmailNotificationSystem.Accounts.User
  import EmailNotificationSystem.Fixtures

  test "upgrade_to_gold/1" do
    user = user_fixture(%{plan_type: "basic"})
    {:ok, updated} = Accounts.upgrade_to_gold(user)
    assert updated.plan_type == "gold"
  end

  test "grant_admin_access/1 and revoke_admin_access/1" do
    user = user_fixture(%{access_level: "frontend"})
    {:ok, admin} = Accounts.grant_admin_access(user)
    assert admin.access_level == "admin"

    {:ok, frontend} = Accounts.revoke_admin_access(admin)
    assert frontend.access_level == "frontend"
  end

  test "authenticate_user/2 happy path" do
    user = user_fixture(%{email_address: "login@example.com", password: "supersecret"})

    assert {:ok, %User{id: id}} =
            Accounts.authenticate_user("login@example.com", "supersecret")

    assert id == user.id
  end

  test "authenticate_user/2 wrong password" do
    user_fixture(%{email_address: "nope@example.com", password: "rightpass"})
    assert {:error, :invalid_password} = Accounts.authenticate_user("nope@example.com", "wrong")
  end
end
