defmodule EmailNotificationSystemWeb.Admin.AdminDashboardLive do
  use EmailNotificationSystemWeb, :live_view
  alias EmailNotificationSystem.{Accounts}
  import Ecto.Query

  on_mount {EmailNotificationSystemWeb.LiveAuth, :ensure_admin}

  def mount(_params, _session, socket) do
    stats = get_system_stats()
    recent_users = get_recent_users()
    email_stats = get_email_stats()
    recent_emails = get_recent_emails()

    {:ok, assign(socket,
      stats: stats,
      recent_users: recent_users,
      email_stats: email_stats,
      recent_emails: recent_emails
    )}
  end

  defp get_system_stats do
    %{
      total_users: Accounts.list_users() |> length(),
      active_users: Accounts.list_users() |> Enum.filter(&(&1.is_active)) |> length(),
      gold_users: Accounts.list_users() |> Enum.filter(&(&1.plan_type == "gold")) |> length(),
      admin_users: Accounts.list_admin_users() |> length(),
      total_contacts: get_total_contacts(),
      total_groups: get_total_groups(),
      total_emails: get_total_emails()
    }
  end

  defp get_total_contacts do
    EmailNotificationSystem.Repo.aggregate(EmailNotificationSystem.Contacts.Contact, :count, :id)
  end

  defp get_total_groups do
    EmailNotificationSystem.Repo.aggregate(EmailNotificationSystem.Groups.Group, :count, :id)
  end

  defp get_total_emails do
    EmailNotificationSystem.Repo.aggregate(EmailNotificationSystem.Emails.Email, :count, :id)
  end

  defp get_recent_users do
    from(u in EmailNotificationSystem.Accounts.User,
      order_by: [desc: u.inserted_at],
      limit: 5
    )
    |> EmailNotificationSystem.Repo.all()
  end

  defp get_recent_emails do
    from(e in EmailNotificationSystem.Emails.Email,
      order_by: [desc: e.inserted_at],
      limit: 5,
      preload: [:user]
    )
    |> EmailNotificationSystem.Repo.all()
  end

  defp get_email_stats do
    from(e in EmailNotificationSystem.Emails.Email,
      group_by: e.status,
      select: {e.status, count(e.id)}
    )
    |> EmailNotificationSystem.Repo.all()
    |> Enum.into(%{})
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Admin Dashboard</h1>
          <p class="text-gray-600">System overview and management</p>
        </div>
        <div class="flex items-center space-x-3">
          <.link navigate={~p"/admin/users"} class="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg font-medium">
            Manage Users
          </.link>
        </div>
      </div>

      <!-- Stats Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <!-- Users Stats -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div class="flex items-center">
            <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
              <.icon name="hero-users" class="w-6 h-6 text-blue-600" />
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Total Users</p>
              <p class="text-2xl font-bold text-gray-900"><%= @stats.total_users %></p>
            </div>
          </div>
          <div class="mt-4 flex items-center justify-between text-sm">
            <span class="text-green-600"><%= @stats.active_users %> active</span>
            <span class="text-purple-600"><%= @stats.admin_users %> admins</span>
          </div>
        </div>

        <!-- Gold Users -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div class="flex items-center">
            <div class="w-12 h-12 bg-yellow-100 rounded-lg flex items-center justify-center">
              <.icon name="hero-star" class="w-6 h-6 text-yellow-600" />
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Gold Users</p>
              <p class="text-2xl font-bold text-gray-900"><%= @stats.gold_users %></p>
            </div>
          </div>
          <div class="mt-4">
            <div class="text-sm text-gray-500">
              <%= if @stats.total_users > 0 do %>
                <%= round(@stats.gold_users / @stats.total_users * 100) %>% of total users
              <% else %>
                0% of total users
              <% end %>
            </div>
          </div>
        </div>

        <!-- Contacts -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div class="flex items-center">
            <div class="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
              <.icon name="hero-identification" class="w-6 h-6 text-green-600" />
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Total Contacts</p>
              <p class="text-2xl font-bold text-gray-900"><%= @stats.total_contacts %></p>
            </div>
          </div>
          <div class="mt-4">
            <div class="text-sm text-gray-500">
              <%= @stats.total_groups %> groups created
            </div>
          </div>
        </div>

        <!-- Emails -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div class="flex items-center">
            <div class="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
              <.icon name="hero-envelope" class="w-6 h-6 text-purple-600" />
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Total Emails</p>
              <p class="text-2xl font-bold text-gray-900"><%= @stats.total_emails %></p>
            </div>
          </div>
          <div class="mt-4">
            <div class="text-sm text-gray-500">
              System-wide emails sent
            </div>
          </div>
        </div>
      </div>

      <!-- Content Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Recent Users -->
        <div class="bg-white rounded-lg shadow-sm border border-gray-200">
          <div class="p-6 border-b border-gray-200">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-gray-900">Recent Users</h2>
              <.link navigate={~p"/admin/users"} class="text-purple-600 hover:text-purple-700 text-sm font-medium">
                View all
              </.link>
            </div>
          </div>

          <div class="divide-y divide-gray-200">
            <%= if length(@recent_users) > 0 do %>
              <%= for user <- @recent_users do %>
                <div class="p-6 hover:bg-gray-50">
                  <div class="flex items-center justify-between">
                    <div class="flex items-center">
                      <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                        <span class="text-blue-600 font-semibold text-sm">
                          <%= String.first(user.first_name) %><%= String.first(user.last_name) %>
                        </span>
                      </div>
                      <div class="ml-3">
                        <p class="font-medium text-gray-900">
                          <%= user.first_name %> <%= user.last_name %>
                        </p>
                        <p class="text-sm text-gray-500"><%= user.email_address %></p>
                      </div>
                    </div>

                    <div class="flex items-center space-x-2">
                      <%= if user.plan_type == "gold" do %>
                        <span class="px-2 py-1 bg-yellow-100 text-yellow-800 text-xs rounded-full">
                          Gold
                        </span>
                      <% end %>

                      <%= if user.access_level in ["admin", "superuser"] do %>
                        <span class="px-2 py-1 bg-purple-100 text-purple-800 text-xs rounded-full">
                          <%= String.capitalize(user.access_level) %>
                        </span>
                      <% end %>

                      <div class="text-xs text-gray-500">
                        <%= Calendar.strftime(user.inserted_at, "%b %d") %>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            <% else %>
              <div class="p-6 text-center text-gray-500">
                No users yet
              </div>
            <% end %>
          </div>
        </div>

        <!-- Email Statistics -->
        <div class="bg-white rounded-lg shadow-sm border border-gray-200">
          <div class="p-6 border-b border-gray-200">
            <h2 class="text-lg font-semibold text-gray-900">Email Statistics</h2>
          </div>

          <div class="p-6">
            <%= if map_size(@email_stats) > 0 do %>
              <div class="space-y-4">
                <%= for {status, count} <- @email_stats do %>
                  <div class="flex items-center justify-between">
                    <div class="flex items-center">
                      <div class={["w-3 h-3 rounded-full mr-3", status_color(status)]}></div>
                      <span class="text-sm text-gray-600 capitalize"><%= status %></span>
                    </div>
                    <span class="font-semibold text-gray-900"><%= count %></span>
                  </div>
                <% end %>
              </div>

              <!-- Success Rate -->
              <div class="mt-6 pt-6 border-t border-gray-200">
                <div class="flex items-center justify-between">
                  <span class="text-sm text-gray-600">Success Rate</span>
                  <span class="font-semibold text-green-600">
                    <%= calculate_success_rate(@email_stats) %>%
                  </span>
                </div>
              </div>
            <% else %>
              <div class="text-center text-gray-500">
                <.icon name="hero-chart-bar" class="w-12 h-12 mx-auto mb-2 text-gray-300" />
                <p>No email data available</p>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Additional Content Row -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Recent Emails -->
        <div class="bg-white rounded-lg shadow-sm border border-gray-200">
          <div class="p-6 border-b border-gray-200">
            <h2 class="text-lg font-semibold text-gray-900">Recent Email Activity</h2>
          </div>

          <div class="divide-y divide-gray-200">
            <%= if length(@recent_emails) > 0 do %>
              <%= for email <- @recent_emails do %>
                <div class="p-6 hover:bg-gray-50">
                  <div class="flex items-center justify-between">
                    <div class="flex-1">
                      <h3 class="font-medium text-gray-900 truncate max-w-xs">
                        <%= email.subject %>
                      </h3>
                      <p class="text-sm text-gray-500 mt-1">
                        By <%= email.user.first_name %> <%= email.user.last_name %>
                      </p>
                    </div>

                    <div class="flex items-center space-x-2">
                      <span class={["px-2 py-1 rounded-full text-xs font-medium", status_badge_class(email.status)]}>
                        <%= String.capitalize(email.status) %>
                      </span>
                      <div class="text-xs text-gray-500">
                        <%= Calendar.strftime(email.inserted_at, "%b %d") %>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            <% else %>
              <div class="p-6 text-center text-gray-500">
                No emails sent yet
              </div>
            <% end %>
          </div>
        </div>

        <!-- System Health & Quick Actions -->
        <div class="space-y-6">
          <!-- System Health -->
          <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
            <h2 class="text-lg font-semibold text-gray-900 mb-4">System Health</h2>

            <div class="grid grid-cols-1 gap-4">
              <div class="flex items-center justify-between">
                <div class="flex items-center">
                  <div class="w-8 h-8 bg-green-100 rounded-full flex items-center justify-center">
                    <.icon name="hero-check-circle" class="w-5 h-5 text-green-600" />
                  </div>
                  <span class="ml-3 font-medium text-gray-900">Database</span>
                </div>
                <span class="text-sm text-green-600">Healthy</span>
              </div>

              <div class="flex items-center justify-between">
                <div class="flex items-center">
                  <div class="w-8 h-8 bg-green-100 rounded-full flex items-center justify-center">
                    <.icon name="hero-server" class="w-5 h-5 text-green-600" />
                  </div>
                  <span class="ml-3 font-medium text-gray-900">Email Queue</span>
                </div>
                <span class="text-sm text-green-600">Running</span>
              </div>

              <div class="flex items-center justify-between">
                <div class="flex items-center">
                  <div class="w-8 h-8 bg-green-100 rounded-full flex items-center justify-center">
                    <.icon name="hero-signal" class="w-5 h-5 text-green-600" />
                  </div>
                  <span class="ml-3 font-medium text-gray-900">System Status</span>
                </div>
                <span class="text-sm text-green-600">Online</span>
              </div>
            </div>
          </div>

          <!-- Quick Actions -->
          <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
            <h2 class="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h2>

            <div class="space-y-3">
              <.link
                navigate={~p"/admin/users"}
                class="flex items-center p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
              >
                <.icon name="hero-users" class="w-5 h-5 text-purple-600 mr-3" />
                <span class="font-medium text-gray-900">Manage Users</span>
              </.link>

              <%= if @current_user.access_level == "superuser" do %>
                <button class="w-full flex items-center p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
                  <.icon name="hero-cog-6-tooth" class="w-5 h-5 text-gray-600 mr-3" />
                  <span class="font-medium text-gray-900">System Settings</span>
                </button>
              <% end %>

              <.link
                navigate={~p"/dashboard"}
                class="flex items-center p-3 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
              >
                <.icon name="hero-arrow-left" class="w-5 h-5 text-gray-600 mr-3" />
                <span class="font-medium text-gray-900">Back to Main Dashboard</span>
              </.link>
            </div>
          </div>
        </div>
      </div>

      <!-- Growth Metrics -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-6">Platform Overview</h2>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <!-- User Growth -->
          <div class="text-center">
            <div class="text-2xl font-bold text-gray-900 mb-1"><%= @stats.total_users %></div>
            <div class="text-sm text-gray-600 mb-2">Total Users</div>
            <div class="text-xs text-green-600">
              <%= @stats.active_users %> active (<%= if @stats.total_users > 0, do: round(@stats.active_users / @stats.total_users * 100), else: 0 %>%)
            </div>
          </div>

          <!-- Premium Adoption -->
          <div class="text-center">
            <div class="text-2xl font-bold text-gray-900 mb-1"><%= @stats.gold_users %></div>
            <div class="text-sm text-gray-600 mb-2">Gold Plan Users</div>
            <div class="text-xs text-yellow-600">
              <%= if @stats.total_users > 0, do: round(@stats.gold_users / @stats.total_users * 100), else: 0 %>% conversion rate
            </div>
          </div>

          <!-- Email Volume -->
          <div class="text-center">
            <div class="text-2xl font-bold text-gray-900 mb-1"><%= @stats.total_emails %></div>
            <div class="text-sm text-gray-600 mb-2">Emails Processed</div>
            <div class="text-xs text-blue-600">
              <%= calculate_success_rate(@email_stats) %>% delivery rate
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp status_color("sent"), do: "bg-green-500"
  defp status_color("failed"), do: "bg-red-500"
  defp status_color("sending"), do: "bg-yellow-500"
  defp status_color("queued"), do: "bg-blue-500"
  defp status_color(_), do: "bg-gray-500"

  defp status_badge_class("sent"), do: "bg-green-100 text-green-800"
  defp status_badge_class("failed"), do: "bg-red-100 text-red-800"
  defp status_badge_class("sending"), do: "bg-yellow-100 text-yellow-800"
  defp status_badge_class("queued"), do: "bg-blue-100 text-blue-800"
  defp status_badge_class(_), do: "bg-gray-100 text-gray-800"

  defp calculate_success_rate(email_stats) do
    total = Map.values(email_stats) |> Enum.sum()
    sent = Map.get(email_stats, "sent", 0)

    if total > 0 do
      round(sent / total * 100)
    else
      0
    end
  end
end
