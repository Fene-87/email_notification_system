defmodule EmailNotificationSystemWeb.Admin.AdminUsersLiveTest do
  use EmailNotificationSystemWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias EmailNotificationSystem.Fixtures
  alias EmailNotificationSystem.Accounts

  defp log_in_as(conn, user), do: init_test_session(conn, %{"user_id" => user.id})

  test "superuser can see list and delete another user (but not self)", %{conn: conn} do
    # Create and promote superuser explicitly (fixture may ignore attrs)
    super = Fixtures.user_fixture(%{email_address: "su@example.com"})
    {:ok, super} = Accounts.update_user(super, %{access_level: "superuser"})

    # Check to avoid silent failures
    assert super.access_level == "superuser"

    target = Fixtures.user_fixture(%{email_address: "target@example.com"})
    keep   = Fixtures.user_fixture(%{email_address: "keep@example.com"})

    conn_super = log_in_as(conn, super)

    {:ok, lv, html} = live(conn_super, ~p"/admin/users")

    assert html =~ target.email_address
    assert html =~ keep.email_address

    # cannot delete self (button not rendered for current_user)
    refute html =~ ~s|phx-value-id="#{super.id}"|

    # delete target
    lv
    |> element(~s|button[phx-click=delete_user][phx-value-id="#{target.id}"]|)
    |> render_click()

    updated = render(lv)
    refute updated =~ target.email_address
    assert updated =~ keep.email_address
    refute updated =~ ~s|phx-value-id="#{super.id}"|
  end

  test "admin (non-superuser) can delete another user but not self", %{conn: conn} do
    admin = Fixtures.user_fixture(%{email_address: "deleter@example.com"})
    {:ok, admin} = Accounts.update_user(admin, %{access_level: "admin"})
    assert admin.access_level == "admin"

    victim = Fixtures.user_fixture(%{email_address: "victim@example.com"})

    {:ok, lv, html} =
      conn
      |> log_in_as(admin)
      |> live(~p"/admin/users")

    assert html =~ victim.email_address
    refute html =~ ~s|phx-value-id="#{admin.id}"|

    lv
    |> element(~s|button[phx-click=delete_user][phx-value-id="#{victim.id}"]|)
    |> render_click()

    updated = render(lv)
    refute updated =~ victim.email_address
  end
end
