defmodule EmailNotificationSystemWeb.DashboardLive do
  use EmailNotificationSystemWeb, :live_view
  alias EmailNotificationSystem.{Contacts, Groups, Emails}

  # Add authentication
  on_mount {EmailNotificationSystemWeb.LiveAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Get dashboard stats
    contacts_count = length(Contacts.list_contacts(user.id))
    groups_count = length(Groups.list_groups(user.id))
    emails = Emails.list_emails(user.id)
    emails_count = length(emails)

    # Recent emails (last 5)
    recent_emails = Enum.take(emails, 5)

    {:ok, assign(socket,
      contacts_count: contacts_count,
      groups_count: groups_count,
      emails_count: emails_count,
      recent_emails: recent_emails,
      user: user
    )}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Welcome Header -->
      <div class="bg-gradient-to-r from-blue-600 to-purple-600 rounded-2xl p-6 text-white">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold mb-2">
              Karibu, <%= @user.first_name %>!
            </h1>
            <p class="text-blue-100">
              Here's what's happening with your email campaigns today.
            </p>
          </div>

          <form action={~p"/logout"} method="post" class="inline">
            <input type="hidden" name="_method" value="delete" />
            <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
            <button type="submit"
                    class="px-3 py-2 rounded-lg bg-red-600 text-white hover:bg-red-700 text-sm">
              Log out
            </button>
          </form>
        </div>
      </div>

      <!-- Stats Grid -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div class="flex items-center">
            <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
              <span class="w-6 h-6 text-blue-600">👥</span>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Contacts</p>
              <p class="text-2xl font-bold text-gray-900"><%= @contacts_count %></p>
            </div>
          </div>
          <div class="mt-4">
            <.link navigate={~p"/contacts"} class="text-blue-600 hover:text-blue-700 text-sm font-medium">
              Manage contacts →
            </.link>
          </div>
        </div>

        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div class="flex items-center">
            <div class="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
              <span class="w-6 h-6 text-green-600">👥</span>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Groups</p>
              <p class="text-2xl font-bold text-gray-900"><%= @groups_count %></p>
            </div>
          </div>
          <div class="mt-4">
            <.link navigate={~p"/groups"} class="text-green-600 hover:text-green-700 text-sm font-medium">
              Manage groups →
            </.link>
          </div>
        </div>

        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div class="flex items-center">
            <div class="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
              <span class="w-6 h-6 text-purple-600">✉️</span>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Emails Sent</p>
              <p class="text-2xl font-bold text-gray-900"><%= @emails_count %></p>
            </div>
          </div>
          <div class="mt-4">
            <.link navigate={~p"/emails"} class="text-purple-600 hover:text-purple-700 text-sm font-medium">
              View all emails →
            </.link>
          </div>
        </div>
      </div>

      <!-- Quick Actions -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <.link navigate={~p"/emails/compose"}
                 class="flex items-center p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-blue-400 hover:bg-blue-50 transition-colors group">
            <span class="w-6 h-6 text-gray-400 group-hover:text-blue-600 mr-3">✏️</span>
            <span class="text-gray-600 group-hover:text-blue-600 font-medium">Compose Email</span>
          </.link>

          <button
                 phx-click="show_add_contact_modal"
                 class="flex items-center p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-green-400 hover:bg-green-50 transition-colors group">
            <span class="w-6 h-6 text-gray-400 group-hover:text-green-600 mr-3">➕</span>
            <span class="text-gray-600 group-hover:text-green-600 font-medium">Add Contact</span>
          </button>

          <%= if @user.plan_type == "gold" do %>
            <button
                   phx-click="show_create_group_modal"
                   class="flex items-center p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-purple-400 hover:bg-purple-50 transition-colors group">
              <span class="w-6 h-6 text-gray-400 group-hover:text-purple-600 mr-3">⊕</span>
              <span class="text-gray-600 group-hover:text-purple-600 font-medium">Create Group</span>
            </button>
          <% end %>

          <.link navigate={~p"/emails"}
                 class="flex items-center p-4 border-2 border-dashed border-gray-300 rounded-lg hover:border-orange-400 hover:bg-orange-50 transition-colors group">
            <span class="w-6 h-6 text-gray-400 group-hover:text-orange-600 mr-3">📊</span>
            <span class="text-gray-600 group-hover:text-orange-600 font-medium">View Reports</span>
          </.link>
        </div>
      </div>

      <!-- Recent Emails -->
      <%= if length(@recent_emails) > 0 do %>
        <div class="bg-white rounded-xl shadow-sm border border-gray-200">
          <div class="p-6 border-b border-gray-200">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-gray-900">Recent Emails</h2>
              <.link navigate={~p"/emails"} class="text-blue-600 hover:text-blue-700 text-sm font-medium">
                View all
              </.link>
            </div>
          </div>
          <div class="divide-y divide-gray-200">
            <%= for email <- @recent_emails do %>
              <div class="p-6 hover:bg-gray-50">
                <div class="flex items-center justify-between">
                  <div class="flex-1">
                    <h3 class="font-medium text-gray-900 truncate"><%= email.subject %></h3>
                    <p class="text-sm text-gray-500 mt-1">
                      Type: <%= String.capitalize(email.email_type) %> •
                      Status: <span class={status_class(email.status)}><%= String.capitalize(email.status) %></span>
                    </p>
                  </div>
                  <div class="flex items-center text-sm text-gray-500">
                    <span class="w-4 h-4 mr-1">⏰</span>
                    <%= format_date(email.inserted_at) %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Event handlers for quick actions
  def handle_event("show_add_contact_modal", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/contacts")}
  end

  def handle_event("show_create_group_modal", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/groups")}
  end

  defp status_class("sent"), do: "text-green-600"
  defp status_class("failed"), do: "text-red-600"
  defp status_class("sending"), do: "text-yellow-600"
  defp status_class("queued"), do: "text-blue-600"
  defp status_class(_), do: "text-gray-600"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
