defmodule EmailNotificationSystemWeb.ContactsLiveTest do
  use EmailNotificationSystemWeb.ConnCase
  import Phoenix.LiveViewTest
  import EmailNotificationSystem.Fixtures

  test "lists & deletes a contact", %{conn: conn} do
    user = user_fixture()
    contact = contact_fixture(user)

    conn = log_in(conn, user)

    {:ok, lv, _html} = live(conn, ~p"/contacts")
    assert render(lv) =~ contact.email_address

    # Click delete (uses phx-click="delete_contact")
    lv
    |> element("button[phx-value-id='#{contact.id}'][phx-click='delete_contact']")
    |> render_click()

    refute render(lv) =~ contact.email_address
  end
end
