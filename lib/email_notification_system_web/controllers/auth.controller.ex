defmodule EmailNotificationSystemWeb.AuthController do
  use EmailNotificationSystemWeb, :controller

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "You have been logged out successfully.")
    |> redirect(to: "/auth")
  end
end
