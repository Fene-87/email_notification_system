defmodule EmailNotificationSystemWeb.Admin.AdminUsersLive do
  use EmailNotificationSystemWeb, :live_view
  alias EmailNotificationSystem.Accounts
  alias EmailNotificationSystem.Accounts.User

  # Ensure current_user is assigned and is admin/superuser
  on_mount {EmailNotificationSystemWeb.LiveAuth, :ensure_admin}

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Manage Users") |> refresh_users()}
  end

  # --- Events ---

  def handle_event("upgrade", %{"id" => id}, socket) do
    act(socket, Accounts.update_user_plan(socket.assigns.current_user, id, "gold"))
  end

  def handle_event("downgrade", %{"id" => id}, socket) do
    act(socket, Accounts.update_user_plan(socket.assigns.current_user, id, "basic"))
  end

  def handle_event("grant_superuser", %{"id" => id}, socket) do
    act(socket, Accounts.grant_superuser(socket.assigns.current_user, id))
  end

  def handle_event("revoke_superuser", %{"id" => id}, socket) do
    act(socket, Accounts.revoke_superuser(socket.assigns.current_user, id))
  end

  def handle_event("delete_user", %{"id" => id}, socket) do
    acting  = socket.assigns.current_user
    target  = Accounts.get_user!(id)

    can_delete? =
      acting.access_level in ["admin", "superuser"] and
      acting.id != target.id and
      (acting.access_level == "superuser" or target.access_level != "superuser")

    if can_delete? do
      {:ok, _} = Accounts.delete_user_and_data(target)
      users = Accounts.list_users()
      {:noreply, socket |> put_flash(:info, "User deleted.") |> assign(:users, users)}
    else
      {:noreply, put_flash(socket, :error, "Not permitted.")}
    end
  end

  def handle_event("upgrade_plan", %{"id" => id}, socket) do
    with %{access_level: "superuser"} <- socket.assigns.current_user,
        user <- Accounts.get_user!(id),
        {:ok, _} <- Accounts.upgrade_to_gold(user) do
      {:noreply,
      socket
      |> put_flash(:info, "Upgraded #{user.first_name} to Gold.")
      |> assign(:users, Accounts.list_users())}
    else
      _ -> {:noreply, put_flash(socket, :error, "Not allowed")}
    end
  end

  def handle_event("downgrade_plan", %{"id" => id}, socket) do
    with %{access_level: "superuser"} <- socket.assigns.current_user,
        user <- Accounts.get_user!(id),
        {:ok, _} <- Accounts.downgrade_to_basic(user) do
      {:noreply,
      socket
      |> put_flash(:info, "Downgraded #{user.first_name} to Basic.")
      |> assign(:users, Accounts.list_users())}
    else
      _ -> {:noreply, put_flash(socket, :error, "Not allowed")}
    end
  end

  def handle_event("grant_admin", %{"id" => id}, socket) do
    with %{access_level: "superuser"} <- socket.assigns.current_user,
        user <- Accounts.get_user!(id),
        {:ok, _} <- Accounts.grant_admin_access(user) do
      {:noreply,
      socket
      |> put_flash(:info, "Granted admin to #{user.first_name}.")
      |> assign(:users, Accounts.list_users())}
    else
      _ -> {:noreply, put_flash(socket, :error, "Not allowed")}
    end
  end

  def handle_event("revoke_admin", %{"id" => id}, socket) do
    with %{access_level: "superuser"} <- socket.assigns.current_user,
        user <- Accounts.get_user!(id),
        {:ok, _} <- Accounts.revoke_admin_access(user) do
      {:noreply,
      socket
      |> put_flash(:info, "Revoked admin from #{user.first_name}.")
      |> assign(:users, Accounts.list_users())}
    else
      _ -> {:noreply, put_flash(socket, :error, "Not allowed")}
    end
  end

  # --- Helpers ---

  defp act(socket, {:ok, _user}) do
    {:noreply, socket |> put_flash(:info, "Updated.") |> refresh_users()}
  end

  defp act(socket, {:error, :forbidden}) do
    {:noreply, put_flash(socket, :error, "Not authorized.")}
  end

  defp act(socket, {:error, :cannot_modify_self}) do
    {:noreply, put_flash(socket, :error, "You cannot modify your own role.")}
  end

  defp act(socket, {:error, :last_admin}) do
    {:noreply, put_flash(socket, :error, "Cannot remove the last admin.")}
  end

  defp act(socket, {:error, :not_found}) do
    {:noreply, put_flash(socket, :error, "User not found.")}
  end

  defp act(socket, {:error, %Ecto.Changeset{} = cs}) do
    {:noreply, put_flash(socket, :error, "Validation failed: #{inspect(cs.errors)}")}
  end

  defp act(socket, {:error, other}) do
    {:noreply, put_flash(socket, :error, "Update failed: #{inspect(other)}")}
  end

  defp refresh_users(socket),
    do: assign(socket, :users, Accounts.list_users())

  # --- View ---

  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto">
      <h1 class="text-2xl font-bold text-gray-900">Manage Users</h1>
      <p class="text-gray-600">Admin user management</p>

      <div class="mt-6">
        <%= if length(@users) > 0 do %>
          <div class="grid gap-4">
            <%= for user <- @users do %>
              <div class="bg-white p-4 rounded-lg shadow border flex items-center justify-between">
                <div>
                  <h3 class="font-medium"><%= user.first_name %> <%= user.last_name %></h3>
                  <p class="text-gray-600"><%= user.email_address %></p>
                  <p class="text-sm text-gray-500">
                    Plan: <%= user.plan_type %> • Role: <%= user.access_level %>
                  </p>
                </div>

                <div class="flex items-center space-x-2">
                  <%= if @current_user.access_level == "superuser" and @current_user.id != user.id do %>
                    <%= if user.access_level == "admin" do %>
                      <button phx-click="grant_superuser" phx-value-id={user.id}
                              class="px-3 py-2 border rounded-lg text-sm bg-indigo-600 hover:bg-indigo-700 text-white">
                        Make superuser
                      </button>
                    <% end %>

                    <%= if user.access_level == "superuser" do %>
                      <button phx-click="revoke_superuser" phx-value-id={user.id}
                              class="px-3 py-2 border rounded-lg text-sm hover:bg-gray-50">
                        Revoke superuser
                      </button>
                    <% end %>

                    <%= if user.plan_type == "gold" do %>
                      <button phx-click="downgrade_plan" phx-value-id={user.id}
                              class="px-3 py-2 border rounded-lg text-sm hover:bg-gray-50">
                        Downgrade
                      </button>
                    <% else %>
                      <button phx-click="upgrade_plan" phx-value-id={user.id}
                              class="px-3 py-2 bg-yellow-500 text-white rounded-lg text-sm hover:bg-yellow-600">
                        Upgrade to Gold
                      </button>
                    <% end %>

                    <%= if user.access_level == "admin" do %>
                      <button phx-click="revoke_admin" phx-value-id={user.id}
                              class="px-3 py-2 border rounded-lg text-sm hover:bg-gray-50">
                        Revoke Admin
                      </button>
                    <% else %>
                      <button phx-click="grant_admin" phx-value-id={user.id}
                              class="px-3 py-2 bg-purple-600 text-white rounded-lg text-sm hover:bg-purple-700">
                        Grant Admin
                      </button>
                    <% end %>
                  <% end %>

                  <%!-- Delete: allowed for admin & superuser (not self; admin cannot delete a superuser) --%>
                  <%= if (@current_user.access_level in ["admin", "superuser"]) and
                        @current_user.id != user.id and
                        (@current_user.access_level == "superuser" or user.access_level != "superuser") do %>
                    <button
                      phx-click="delete_user"
                      phx-value-id={user.id}
                      data-confirm={"Delete #{user.first_name} #{user.last_name} and ALL their data?"}
                      class="px-3 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 text-sm"
                    >
                      <span class="w-4 h-4 inline-flex items-center justify-center mr-1" aria-hidden="true">×</span>
                      Delete
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <p class="text-gray-500">No users found.</p>
        <% end %>
      </div>
    </div>
    """
  end

  # Button component helpers (simple class builder)
  defp btn(opts) do
    base = "px-3 py-1.5 rounded-md text-sm font-medium border"
    if opts[:disabled], do: base <> " bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed",
                       else: base <> " bg-white hover:bg-gray-50 text-gray-700 border-gray-300"
  end

  # Conditionally render role action buttons
  attr :current_user, User, required: true
  attr :user, User, required: true
  defp role_buttons(assigns) do
    ~H"""
    <%= if @user.id == @current_user.id do %>
      <span class="text-xs text-gray-500">You</span>
    <% else %>
      <%= case {@current_user.access_level, @user.access_level} do %>
        <% {"superuser", "superuser"} -> %>
          <button phx-click="revoke_superuser" phx-value-id={@user.id} class={btn([])}>Revoke superuser</button>
        <% {"superuser", "admin"} -> %>
          <button phx-click="revoke_admin" phx-value-id={@user.id} class={btn([])}>Revoke admin</button>
          <button phx-click="grant_superuser" phx-value-id={@user.id} class={btn([])}>Make superuser</button>
        <% {"superuser", "frontend"} -> %>
          <button phx-click="grant_admin" phx-value-id={@user.id} class={btn([])}>Make admin</button>
        <% {"admin", "superuser"} -> %>
          <span class="text-xs text-gray-500">Superuser (no action)</span>
        <% {"admin", "admin"} -> %>
          <button phx-click="revoke_admin" phx-value-id={@user.id} class={btn([])}>Revoke admin</button>
        <% {"admin", "frontend"} -> %>
          <button phx-click="grant_admin" phx-value-id={@user.id} class={btn([])}>Make admin</button>
        <% _ -> %>
          <span class="text-xs text-gray-500">No actions</span>
      <% end %>
    <% end %>
    """
  end
end
