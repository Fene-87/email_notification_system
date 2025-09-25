defmodule EmailNotificationSystemWeb.AuthLive do
  use EmailNotificationSystemWeb, :live_view
  alias EmailNotificationSystem.Accounts

  def mount(_params, session, socket) do
    socket = assign_current_user(socket, session)

    if socket.assigns[:current_user] do
      path = destination_for(socket.assigns.current_user)
      {:ok, push_navigate(socket, to: path)}
    else
      {:ok,
      assign(socket,
        form: to_form(%{}, as: :auth),
        mode: :login,
        error: nil
      )}
    end
  end

  def handle_event("toggle_mode", _params, socket) do
    new_mode = if socket.assigns.mode == :login, do: :register, else: :login
    {:noreply, assign(socket, mode: new_mode, error: nil)}
  end

  def handle_event("authenticate", %{"auth" => auth_params}, socket) do
    case socket.assigns.mode do
      :login -> handle_login(auth_params, socket)
      :register -> handle_register(auth_params, socket)
    end
  end

  defp destination_for(%EmailNotificationSystem.Accounts.User{} = user) do
    if EmailNotificationSystem.Accounts.User.can_access_admin?(user),
      do: ~p"/admin",
      else: ~p"/dashboard"
  end

  defp handle_login(params, socket) do
    email = params["email"] || params["email_address"]
    password = params["password"] || ""

    case EmailNotificationSystem.Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        token = Phoenix.Token.sign(EmailNotificationSystemWeb.Endpoint, "user session", user.id)

        {:noreply,
        socket
        |> put_flash(:info, "Signed in.")
        |> push_navigate(to: ~p"/sessions/complete?token=#{token}")}  # <-- token in URL

      {:error, _reason} ->
        {:noreply, assign(socket, error: "Invalid email or password")}
    end
  end

  defp handle_register(params, socket) do
    case Accounts.create_user(params) do
      {:ok} ->


        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully!")
         |> push_navigate(to: ~p"/auth")}
      {:error, changeset} ->
        {:noreply, assign(socket, error: extract_error(changeset))}
    end
  end

  defp assign_current_user(socket, session) do
    case session do
      %{"user_id" => user_id} ->
        assign(socket, :current_user, Accounts.get_user!(user_id))
      %{"user_token" => token} ->
        case Phoenix.Token.verify(EmailNotificationSystemWeb.Endpoint, "user session", token, max_age: 86400) do
          {:ok, user_id} ->
            assign(socket, :current_user, Accounts.get_user!(user_id))
          {:error, _} ->
            socket
        end
      _ ->
        socket
    end
  end

  defp extract_error(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.map(fn {key, [msg | _]} -> "#{key}: #{msg}" end)
    |> Enum.join(", ")
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-indigo-900 via-blue-900 to-purple-900">
      <div class="flex items-center justify-center min-h-screen p-4">
        <div class="w-full max-w-md">
          <!-- Logo and Title -->
          <div class="text-center mb-8">
            <div class="mx-auto w-16 h-16 bg-gradient-to-r from-blue-400 to-purple-500 rounded-2xl flex items-center justify-center mb-4">
              <.icon name="hero-envelope" class="w-8 h-8 text-white" />
            </div>
            <h1 class="text-3xl font-bold text-white mb-2">Email Notification System</h1>
            <p class="text-blue-200">Professional email management platform</p>
          </div>

          <!-- Auth Card -->
          <div class="bg-white/10 backdrop-blur-lg rounded-2xl shadow-2xl p-8 border border-white/20">
            <div class="mb-6">
              <h2 class="text-2xl font-semibold text-white mb-2">
                <%= if @mode == :login, do: "Welcome", else: "Create account" %>
              </h2>
              <p class="text-blue-200 text-sm">
                <%= if @mode == :login, do: "Sign in to your account", else: "Get started with your account" %>
              </p>
            </div>

            <.form for={@form} phx-submit="authenticate" class="space-y-4">
              <%= if @mode == :register do %>
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <.input
                      field={@form[:first_name]}
                      type="text"
                      placeholder="First name"
                      class="bg-white/10 border-white/20 text-white placeholder-blue-200 focus:border-blue-400 focus:ring-blue-400"
                    />
                  </div>
                  <div>
                    <.input
                      field={@form[:last_name]}
                      type="text"
                      placeholder="Last name"
                      class="bg-white/10 border-white/20 text-white placeholder-blue-200 focus:border-blue-400 focus:ring-blue-400"
                    />
                  </div>
                </div>
                <.input
                  field={@form[:msisdn]}
                  type="tel"
                  placeholder="Phone number"
                  class="bg-white/10 border-white/20 text-white placeholder-blue-200 focus:border-blue-400 focus:ring-blue-400"
                />
              <% end %>

              <.input
                field={@form[:email_address]}
                type="email"
                placeholder="Email address"
                class="bg-white/10 border-white/20 text-white placeholder-blue-200 focus:border-blue-400 focus:ring-blue-400"
              />

              <.input
                field={@form[:password]}
                type="password"
                placeholder="Password"
                class="bg-white/10 border-white/20 text-white placeholder-blue-200 focus:border-blue-400 focus:ring-blue-400"
              />

              <%= if @error do %>
                <div class="p-3 bg-red-500/20 border border-red-400/30 rounded-lg">
                  <p class="text-red-200 text-sm"><%= @error %></p>
                </div>
              <% end %>

              <.button
                type="submit"
                class="w-full bg-gradient-to-r from-blue-500 to-purple-600 hover:from-blue-600 hover:to-purple-700 text-white font-semibold py-3 rounded-xl transition-all duration-200 shadow-lg hover:shadow-xl"
              >
                <%= if @mode == :login, do: "Sign In", else: "Create Account" %>
              </.button>
            </.form>

            <div class="mt-6 text-center">
              <button
                phx-click="toggle_mode"
                class="text-blue-300 hover:text-white text-sm transition-colors duration-200"
              >
                <%= if @mode == :login do %>
                  Don't have an account? <span class="font-semibold">Sign up</span>
                <% else %>
                  Already have an account? <span class="font-semibold">Sign in</span>
                <% end %>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
