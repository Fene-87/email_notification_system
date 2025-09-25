defmodule EmailNotificationSystemWeb.PageControllerTest do
  use EmailNotificationSystemWeb.ConnCase, async: true

  test "GET / shows auth page", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "Email Notification System"
    assert body =~ "Sign in to your account"
  end
end
