defmodule EmailNotificationSystemWeb.LiveAuth do
  import Phoenix.Component
  import Phoenix.LiveView
  alias EmailNotificationSystem.Accounts

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = assign_current_user(socket, session)

    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/auth")}
    end
  end

  def on_mount(:maybe_authenticated, _params, session, socket) do
    socket = assign_current_user(socket, session)
    {:cont, socket}
  end

  def on_mount(:ensure_admin, _params, session, socket) do
    socket = assign_current_user(socket, session)

    if socket.assigns[:current_user] &&
       socket.assigns.current_user.access_level in ["admin", "superuser"] do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/dashboard")}
    end
  end

  defp assign_current_user(socket, session) do
    cond do
      # Check session for user_id
      user_id = session["user_id"] ->
        assign(socket, :current_user, Accounts.get_user!(user_id))

      # Check for user token in session
      token = session["user_token"] ->
        case Phoenix.Token.verify(EmailNotificationSystemWeb.Endpoint, "user session", token, max_age: 86400) do
          {:ok, user_id} ->
            assign(socket, :current_user, Accounts.get_user!(user_id))
          {:error, _} ->
            assign(socket, :current_user, nil)
        end

      true ->
        assign(socket, :current_user, nil)
    end
  end
end
