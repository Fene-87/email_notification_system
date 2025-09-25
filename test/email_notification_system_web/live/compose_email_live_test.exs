defmodule EmailNotificationSystemWeb.ComposeEmailLiveTest do
  use EmailNotificationSystemWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias EmailNotificationSystem.Fixtures
  alias EmailNotificationSystem.Contacts

  # Unique helper name to avoid clash with other files
  defp log_in_as(conn, user), do: init_test_session(conn, %{"user_id" => user.id})

  test "shows contacts, selects one, and sends single email", %{conn: conn} do
    user =
      Fixtures.user_fixture(%{
        email_address: "sender@example.com",
        access_level: "frontend",
        plan_type: "basic"
      })

    # Create a contact for this user
    {:ok, contact} =
      Contacts.create_contact(%{
        first_name: "Linus",
        last_name: "Torvalds",
        email_address: "linus@example.com",
        user_id: user.id
      })

    conn_user = log_in_as(conn, user)

    {:ok, lv, html} = live(conn_user, ~p"/emails/compose")
    assert html =~ "Compose Email"

    # Show recipients list
    lv
    |> element("button[phx-click=toggle_recipients]")
    |> render_click()

    # Select the contact (checkbox uses phx-click toggle_contact)
    lv
    |> element("input[phx-click=toggle_contact][phx-value-id=\"#{contact.id}\"]")
    |> render_click(%{"value" => "on"})

    # Submit the form using a selector that does not depend on an #id
    lv
    |> form("form[phx-submit=send_email]", %{
      "email" => %{
        "subject" => "Hello",
        "from_email" => user.email_address,
        "reply_to" => "",
        "priority" => "5",
        "body" => "Hi there"
      }
    })
    |> render_submit()

    # Expect navigate to /emails after queuing
    assert_redirect(lv, ~p"/emails")
  end
end
