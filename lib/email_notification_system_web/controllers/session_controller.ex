defmodule EmailNotificationSystemWeb.SessionController do
  use EmailNotificationSystemWeb, :controller
  alias EmailNotificationSystem.Accounts
  alias EmailNotificationSystem.Accounts.User

  def complete(conn, %{"token" => token}) do
    with {:ok, user_id} <-
           Phoenix.Token.verify(EmailNotificationSystemWeb.Endpoint, "user session", token, max_age: 86_400),
         user <- Accounts.get_user!(user_id) do
      dest = if User.can_access_admin?(user), do: ~p"/admin", else: ~p"/dashboard"

      conn
      |> put_session(:user_id, user.id)
      |> configure_session(renew: true)
      |> redirect(to: dest)
    else
      _ ->
        conn
        |> put_flash(:error, "Session expired. Please sign in.")
        |> redirect(to: ~p"/auth")
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Signed out.")
    |> redirect(to: ~p"/auth")
  end
end
