defmodule EmailNotificationSystemWeb.EmailsLive do
  use EmailNotificationSystemWeb, :live_view
  alias EmailNotificationSystem.{Emails}

  on_mount {EmailNotificationSystemWeb.LiveAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    if connected?(socket) do
      Phoenix.PubSub.subscribe(EmailNotificationSystem.PubSub, "emails:#{user.id}")
    end

    emails = Emails.list_emails(user.id)
    {:ok, assign(socket, emails: emails, filter: "all", show_details: false, selected_email: nil)}
  end

  @impl true
  def handle_info({:email_event, _event, _email_id}, socket) do
    user_id = socket.assigns.current_user.id
    {:noreply, assign(socket, emails: Emails.list_emails(user_id))}
  end

  @impl true
  def handle_info({:email_updated, _email_id}, socket) do
    user_id = socket.assigns.current_user.id
    {:noreply, assign(socket, emails: EmailNotificationSystem.Emails.list_emails(user_id))}
  end

  @impl true
  def handle_info(_unknown, socket) do
    {:noreply, socket}
  end


  def handle_event("filter_emails", %{"filter" => filter}, socket) do
    user = socket.assigns.current_user
    emails = case filter do
      "all" -> Emails.list_emails(user.id)
      status -> Emails.list_emails(user.id) |> Enum.filter(&(&1.status == status))
    end

    {:noreply, assign(socket, emails: emails, filter: filter)}
  end

  def handle_event("show_details", %{"id" => id}, socket) do
    email = Emails.get_email!(id)
    stats = Emails.get_email_stats(id)
    {:noreply, assign(socket, selected_email: email, email_stats: stats, show_details: true)}
  end

  def handle_event("hide_details", _params, socket) do
    {:noreply, assign(socket, show_details: false, selected_email: nil)}
  end

  def handle_event("retry_email", %{"id" => id}, socket) do
    user  = socket.assigns.current_user
    email = Emails.get_email!(id)

    case Emails.retry_failed_email(email, user) do
      {:ok, _email} ->
        {:noreply,
        socket
        |> assign(emails: Emails.list_emails(user.id))
        |> put_flash(:info, "Retry queued. Status set to queued; delivery will resume shortly.")}

      {:error, :not_gold} ->
        {:noreply, put_flash(socket, :error, "Retry requires Gold plan.")}

      {:error, :no_failed_recipients} ->
        {:noreply, put_flash(socket, :info, "Nothing to retry for this email.")}

      {:error, other} ->
        {:noreply, put_flash(socket, :error, "Failed to queue retry: #{inspect(other)}")}
    end
  end


  def handle_event("delete_email", %{"id" => id}, socket) do
    email = Emails.get_email!(id)
    {:ok, _} = Emails.delete_email(email)

    emails = Emails.list_emails(socket.assigns.current_user.id)
    {:noreply, assign(socket, emails: emails)}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Email History</h1>
          <p class="text-gray-600">View and manage your sent emails</p>
        </div>
        <.link
          navigate={~p"/emails/compose"}
          class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-medium transition-colors flex items-center"
        >
          <span class="w-5 h-5 mr-2">＋</span>
          Compose Email
        </.link>
      </div>

      <!-- Filter Tabs -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-1">
        <div class="flex space-x-1">
          <%= for {label, filter_value} <- [{"All", "all"}, {"Sent", "sent"}, {"Failed", "failed"}, {"Queued", "queued"}, {"Sending", "sending"}] do %>
            <button
              phx-click="filter_emails"
              phx-value-filter={filter_value}
              class={[
                "px-4 py-2 rounded-md text-sm font-medium transition-colors",
                if(@filter == filter_value,
                  do: "bg-blue-100 text-blue-700",
                  else: "text-gray-600 hover:text-gray-900 hover:bg-gray-50")
              ]}
            >
              <%= label %>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Email Details Modal -->
      <%= if @show_details && @selected_email do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-lg max-w-4xl w-full max-h-[90vh] overflow-y-auto">
            <div class="p-6 border-b border-gray-200">
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold">Email Details</h2>
                <button phx-click="hide_details" class="text-gray-400 hover:text-gray-600">
                  <span class="w-6 h-6 inline-flex items-center justify-center" aria-hidden="true">✕</span>
                </button>
              </div>
            </div>

            <div class="p-6 space-y-6">
              <!-- Email Info -->
              <div class="grid grid-cols-2 gap-6">
                <div>
                  <h3 class="font-medium text-gray-900 mb-3">Email Information</h3>
                  <dl class="space-y-2 text-sm">
                    <div>
                      <dt class="text-gray-500">Subject:</dt>
                      <dd class="font-medium"><%= @selected_email.subject %></dd>
                    </div>
                    <div>
                      <dt class="text-gray-500">Type:</dt>
                      <dd class="capitalize"><%= @selected_email.email_type %></dd>
                    </div>
                    <div>
                      <dt class="text-gray-500">Status:</dt>
                      <dd class={["capitalize font-medium", status_class(@selected_email.status)]}>
                        <%= @selected_email.status %>
                      </dd>
                    </div>
                    <div>
                      <dt class="text-gray-500">Priority:</dt>
                      <dd><%= @selected_email.priority %></dd>
                    </div>
                  </dl>
                </div>

                <div>
                  <h3 class="font-medium text-gray-900 mb-3">Delivery Stats</h3>
                  <div class="grid grid-cols-2 gap-4">
                    <%= for {status, count} <- @email_stats do %>
                      <div class="bg-gray-50 rounded-lg p-3 text-center">
                        <div class="text-lg font-bold text-gray-900"><%= count %></div>
                        <div class="text-sm text-gray-600 capitalize"><%= status %></div>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>

              <!-- Email Body -->
              <div>
                <h3 class="font-medium text-gray-900 mb-3">Email Content</h3>
                <div class="bg-gray-50 rounded-lg p-4">
                  <div class="prose max-w-none">
                    <%= raw(@selected_email.body) %>
                  </div>
                </div>
              </div>

              <!-- Recipients -->
              <%= if @selected_email.email_recipients do %>
                <div>
                  <h3 class="font-medium text-gray-900 mb-3">Recipients</h3>
                  <div class="bg-gray-50 rounded-lg max-h-48 overflow-y-auto">
                    <div class="divide-y divide-gray-200">
                      <%= for recipient <- @selected_email.email_recipients do %>
                        <div class="p-3 flex items-center justify-between">
                          <div>
                            <div class="font-medium text-sm"><%= recipient.recipient_email %></div>
                            <%= if recipient.recipient_name do %>
                              <div class="text-xs text-gray-500"><%= recipient.recipient_name %></div>
                            <% end %>
                          </div>
                          <span class={["px-2 py-1 rounded-full text-xs font-medium", recipient_status_class(recipient.status)]}>
                            <%= String.capitalize(recipient.status) %>
                          </span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Actions -->
              <div class="flex justify-end space-x-3 pt-4 border-t">
                <%= if @current_user.plan_type == "gold" && @selected_email.status in ["failed"] do %>
                  <button
                    phx-click="retry_email"
                    phx-value-id={@selected_email.id}
                    class="bg-yellow-600 hover:bg-yellow-700 text-white px-4 py-2 rounded-lg text-sm font-medium"
                  >
                    Retry Failed
                  </button>
                <% end %>

                <button
                  phx-click="delete_email"
                  phx-value-id={@selected_email.id}
                  data-confirm="Are you sure you want to delete this email?"
                  class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg text-sm font-medium"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Emails List -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200">
        <%= if length(@emails) > 0 do %>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead class="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th class="text-left py-3 px-6 font-medium text-gray-900">Subject</th>
                  <th class="text-left py-3 px-6 font-medium text-gray-900">Type</th>
                  <th class="text-left py-3 px-6 font-medium text-gray-900">Status</th>
                  <th class="text-left py-3 px-6 font-medium text-gray-900">Recipients</th>
                  <th class="text-left py-3 px-6 font-medium text-gray-900">Sent</th>
                  <th class="text-right py-3 px-6 font-medium text-gray-900">Actions</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200">
                <%= for email <- @emails do %>
                  <tr class="hover:bg-gray-50">
                    <td class="py-4 px-6">
                      <div class="font-medium text-gray-900 truncate max-w-xs">
                        <%= email.subject %>
                      </div>
                      <%= if email.group do %>
                        <div class="text-sm text-gray-500">
                          Group: <%= email.group.name %>
                        </div>
                      <% end %>
                    </td>
                    <td class="py-4 px-6">
                      <span class={["px-2 py-1 rounded-full text-xs font-medium", type_class(email.email_type)]}>
                        <%= String.capitalize(email.email_type) %>
                      </span>
                    </td>
                    <td class="py-4 px-6">
                      <span class={["px-2 py-1 rounded-full text-xs font-medium", status_badge_class(email.status)]}>
                        <%= String.capitalize(email.status) %>
                      </span>
                    </td>
                    <td class="py-4 px-6 text-gray-900">
                      <%= length(email.email_recipients || []) %>
                    </td>
                    <td class="py-4 px-6 text-gray-500">
                      <%= if email.sent_at do %>
                        <%= format_datetime(email.sent_at) %>
                      <% else %>
                        -
                      <% end %>
                    </td>
                    <td class="py-4 px-6">
                      <div class="flex items-center justify-end space-x-2">
                        <button
                          phx-click="show_details"
                          phx-value-id={email.id}
                          class="text-blue-600 hover:text-blue-700 p-1"
                          title="View details"
                        >
                          <span class="w-4 h-4 inline-flex items-center justify-center" aria-hidden="true">👁</span>
                        </button>

                        <%= if @current_user.plan_type == "gold" && email.status in ["failed"] do %>
                          <button
                            phx-click="retry_email"
                            phx-value-id={email.id}
                            class="text-yellow-600 hover:text-yellow-700 p-1"
                            title="Retry failed email"
                          >
                            <span class="w-4 h-4 inline-flex items-center justify-center" aria-hidden="true">↻</span>
                          </button>
                        <% end %>

                        <button
                          phx-click="delete_email"
                          phx-value-id={email.id}
                          data-confirm="Are you sure you want to delete this email?"
                          class="text-red-600 hover:text-red-700 p-1"
                          title="Delete email"
                        >
                          <span class="w-4 h-4 inline-flex items-center justify-center" aria-hidden="true">🗑️</span>
                        </button>
                      </div>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% else %>
          <div class="text-center py-12">
            <span class="w-12 h-12 text-gray-400 mx-auto mb-4">✉️</span>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No emails yet</h3>
            <p class="text-gray-500 mb-4">Start by composing your first email campaign.</p>
            <.link
              navigate={~p"/emails/compose"}
              class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-medium"
            >
              Compose Email
            </.link>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp status_class("sent"), do: "text-green-600"
  defp status_class("failed"), do: "text-red-600"
  defp status_class("sending"), do: "text-yellow-600"
  defp status_class("queued"), do: "text-blue-600"
  defp status_class(_), do: "text-gray-600"

  defp status_badge_class("sent"), do: "bg-green-100 text-green-800"
  defp status_badge_class("failed"), do: "bg-red-100 text-red-800"
  defp status_badge_class("sending"), do: "bg-yellow-100 text-yellow-800"
  defp status_badge_class("queued"), do: "bg-blue-100 text-blue-800"
  defp status_badge_class(_), do: "bg-gray-100 text-gray-800"

  defp type_class("single"), do: "bg-blue-100 text-blue-800"
  defp type_class("bulk"), do: "bg-purple-100 text-purple-800"
  defp type_class("group"), do: "bg-green-100 text-green-800"

  defp recipient_status_class("sent"), do: "bg-green-100 text-green-800"
  defp recipient_status_class("delivered"), do: "bg-blue-100 text-blue-800"
  defp recipient_status_class("opened"), do: "bg-purple-100 text-purple-800"
  defp recipient_status_class("clicked"), do: "bg-indigo-100 text-indigo-800"
  defp recipient_status_class("bounced"), do: "bg-red-100 text-red-800"
  defp recipient_status_class("failed"), do: "bg-red-100 text-red-800"
  defp recipient_status_class(_), do: "bg-gray-100 text-gray-800"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end
end
