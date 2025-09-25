defmodule EmailNotificationSystemWeb.Router do
  use EmailNotificationSystemWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {EmailNotificationSystemWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public routes
  scope "/", EmailNotificationSystemWeb do
    pipe_through :browser

    live "/", AuthLive
    live "/auth", AuthLive
    get "/sessions/complete", SessionController, :complete
    delete "/logout", SessionController, :delete
  end

  # Protected routes
  scope "/", EmailNotificationSystemWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/dashboard", DashboardLive
    live "/contacts", ContactsLive
    live "/groups", GroupsLive
    live "/emails", EmailsLive
    live "/emails/compose", ComposeEmailLive
    live "/profile", ProfileLive
  end

  # Admin routes
  scope "/admin", EmailNotificationSystemWeb.Admin do
    pipe_through [:browser, :require_authenticated_user, :require_admin]

    live "/", AdminDashboardLive
    live "/users", AdminUsersLive
  end

  # API routes
  scope "/api", EmailNotificationSystemWeb do
    pipe_through :api
  end

  # Development routes
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dev/dashboard", metrics: EmailNotificationSystemWeb.Telemetry
    end
  end

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  # Authentication plugs
  defp require_authenticated_user(conn, _opts) do
    cond do
      user_id = get_session(conn, :user_id) ->
        user = EmailNotificationSystem.Accounts.get_user!(user_id)
        assign(conn, :current_user, user)

      # Check query params for token (from LiveView redirects)
      token = conn.params["token"] ->
        case Phoenix.Token.verify(EmailNotificationSystemWeb.Endpoint, "user session", token, max_age: 86400) do
          {:ok, user_id} ->
            user = EmailNotificationSystem.Accounts.get_user!(user_id)
            conn
            |> put_session(:user_id, user_id)
            |> assign(:current_user, user)
          {:error, _} ->
            redirect_to_auth(conn)
        end

      true ->
        redirect_to_auth(conn)
    end
  end

  defp redirect_to_auth(conn) do
    conn
    |> put_flash(:error, "You must be logged in to access this page.")
    |> redirect(to: "/auth")
    |> halt()
  end

  defp require_admin(conn, _opts) do
    if conn.assigns.current_user.access_level in ["admin", "superuser"] do
      conn
    else
      conn
      |> put_flash(:error, "You don't have permission to access this page.")
      |> redirect(to: "/dashboard")
      |> halt()
    end
  end
end
