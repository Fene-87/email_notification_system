defmodule EmailNotificationSystemWeb.ComposeEmailLive do
  use EmailNotificationSystemWeb, :live_view
  on_mount {EmailNotificationSystemWeb.LiveAuth, :ensure_authenticated}
  alias EmailNotificationSystem.{Emails, Contacts, Groups, Accounts, Emails.Email, Contacts.Contact}
  alias EmailNotificationSystem.Repo

    def mount(_params, session, socket) do
    user =
      socket.assigns[:current_user] ||
        (session["user_id"] && Accounts.get_user!(session["user_id"])) ||
        nil

    if is_nil(user) do
      {:ok, Phoenix.LiveView.redirect(socket, to: ~p"/auth")}
    else
      contacts = Contacts.list_contacts(user.id)
      groups =
        if user.plan_type == "gold",
          do: Groups.list_groups(user.id) |> Repo.preload(:contacts),
          else: []

      form =
        Email.changeset(%Email{}, %{user_id: user.id, from_email: user.email_address})
        |> to_form()

      {:ok,
      assign(socket,
        current_user: user,
        form: form,
        contacts: contacts,
        groups: groups,
        selected_contacts: [],   # list, not MapSet
        selected_group: nil,
        email_type: "single",
        show_recipients: false
      )}
    end
  end

  def handle_event("toggle_recipients", _params, socket) do
    {:noreply, assign(socket, show_recipients: !socket.assigns.show_recipients)}
  end

  def handle_event("select_email_type", %{"type" => type}, socket) do
    {:noreply, assign(socket,
      email_type: type,
      selected_contacts: [],
      selected_group: nil
    )}
  end

  def handle_event("toggle_contact", %{"id" => contact_id}, socket) do
    selected = socket.assigns.selected_contacts

    new_selected =
      if contact_id in selected do
        List.delete(selected, contact_id)
      else
        [contact_id | selected]
      end

    {:noreply, assign(socket, selected_contacts: new_selected)}
  end

  def handle_event("select_group", %{"group_id" => group_id}, socket) do
    group_id = if group_id == "", do: nil, else: group_id
    {:noreply, assign(socket, selected_group: group_id)}
  end

  def handle_event("send_email", %{"email" => email_params}, socket) do
    user = socket.assigns.current_user
    email_params = Map.put(email_params, "user_id", user.id)

    case socket.assigns.email_type do
      "single" -> send_single_email(email_params, socket)
      "bulk" -> send_bulk_email(email_params, socket)
      "group" -> send_group_email(email_params, socket)
    end
  end

  defp send_single_email(email_params, socket) do
    if length(socket.assigns.selected_contacts) == 1 do
      # contact_id = hd(socket.assigns.selected_contacts)
      # contact = Enum.find(socket.assigns.contacts, &(&1.id == contact_id))

      contact_id = hd(socket.assigns.selected_contacts)
      contact = Enum.find(socket.assigns.contacts, &(&1.id == contact_id))

      email_params = Map.put(email_params, "email_type", "single")

      case Emails.create_email(email_params) do
        {:ok, email} ->
          case Emails.send_email(email, [contact]) do
            {:ok, _} ->
              {:noreply,
               socket
               |> put_flash(:info, "Email sent successfully!")
               |> push_navigate(to: ~p"/emails")}
            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to send email")}
          end
        {:error, changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    else
      {:noreply, put_flash(socket, :error, "Please select exactly one contact")}
    end
  end

  defp send_bulk_email(email_params, socket) do
    if length(socket.assigns.selected_contacts) > 1 do
      # contacts = Enum.filter(socket.assigns.contacts,
      #   &(&1.id in socket.assigns.selected_contacts))

      contacts = Enum.filter(socket.assigns.contacts, &(&1.id in socket.assigns.selected_contacts))

      email_params = Map.put(email_params, "email_type", "bulk")

      case Emails.create_email(email_params) do
        {:ok, email} ->
          case Emails.send_email(email, contacts) do
            {:ok, _} ->
              {:noreply,
               socket
               |> put_flash(:info, "Bulk email queued successfully!")
               |> push_navigate(to: ~p"/emails")}
            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to queue bulk email")}
          end
        {:error, changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    else
      {:noreply, put_flash(socket, :error, "Please select multiple contacts for bulk email")}
    end
  end

  defp send_group_email(email_params, socket) do
    if socket.assigns.selected_group do
      group = Groups.get_group!(socket.assigns.selected_group)

      email_params = Map.merge(email_params, %{
        "email_type" => "group",
        "group_id" => group.id
      })

      case Emails.create_email(email_params) do
        {:ok, email} ->
          case Emails.send_email(email, group.contacts) do
            {:ok, _} ->
              {:noreply,
               socket
               |> put_flash(:info, "Group email queued successfully!")
               |> push_navigate(to: ~p"/emails")}
            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to queue group email")}
          end
        {:error, changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    else
      {:noreply, put_flash(socket, :error, "Please select a group")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto space-y-6">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Compose Email</h1>
          <p class="text-gray-600">Create and send your email campaign</p>
        </div>
        <.link navigate={~p"/emails"} class="text-gray-600 hover:text-gray-900">
          <span class="w-5 h-5 inline mr-1">←</span>
          Back to Emails
        </.link>
      </div>

      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <!-- Email Type Selection -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-3">Email Type</label>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <button
              phx-click="select_email_type"
              phx-value-type="single"
              class={["p-4 border-2 rounded-lg text-left transition-all",
                if(@email_type == "single",
                  do: "border-blue-500 bg-blue-50",
                  else: "border-gray-200 hover:border-gray-300")]}
            >
              <div class="flex items-center mb-2">
                <span class="w-5 h-5 text-blue-600 mr-2">👤</span>
                <span class="font-medium">Single Email</span>
              </div>
              <p class="text-sm text-gray-600">Send to one contact</p>
            </button>

            <button
              phx-click="select_email_type"
              phx-value-type="bulk"
              class={["p-4 border-2 rounded-lg text-left transition-all",
                if(@email_type == "bulk",
                  do: "border-blue-500 bg-blue-50",
                  else: "border-gray-200 hover:border-gray-300")]}
            >
              <div class="flex items-center mb-2">
                <span class="w-5 h-5 text-gray-400 mr-2">👥</span>
                <span class="font-medium">Bulk Email</span>
              </div>
              <p class="text-sm text-gray-600">Send to multiple contacts</p>
            </button>

            <%= if @current_user.plan_type == "gold" do %>
              <button
                phx-click="select_email_type"
                phx-value-type="group"
                class={["p-4 border-2 rounded-lg text-left transition-all",
                  if(@email_type == "group",
                    do: "border-blue-500 bg-blue-50",
                    else: "border-gray-200 hover:border-gray-300")]}
              >
                <div class="flex items-center mb-2">
                  <span class="w-5 h-5 text-gray-400 mr-2">👥</span>
                  <span class="font-medium">Group Email</span>
                  <span class="ml-2 px-2 py-1 bg-yellow-100 text-yellow-800 text-xs rounded-full">Gold</span>
                </div>
                <p class="text-sm text-gray-600">Send to a group</p>
              </button>
            <% else %>
              <div class="p-4 border-2 border-gray-200 rounded-lg text-left opacity-50">
                <div class="flex items-center mb-2">
                  <span class="w-5 h-5 text-gray-400 mr-2">👥</span>
                  <span class="font-medium text-gray-500">Group Email</span>
                  <span class="ml-2 px-2 py-1 bg-gray-100 text-gray-500 text-xs rounded-full">Gold Plan</span>
                </div>
                <p class="text-sm text-gray-400">Upgrade to Gold plan</p>
              </div>
            <% end %>
          </div>
        </div>

        <.form for={@form} phx-submit="send_email" class="space-y-6">
          <!-- Email Content -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div class="space-y-4">
              <.input
                field={@form[:subject]}
                type="text"
                label="Subject"
                required
                class="w-full border border-blue-400 rounded-lg outline-none px-2 py-1 mt-2"
              />

              <.input
                field={@form[:from_email]}
                type="email"
                label="From Email"
                required
                class="w-full border border-blue-400 rounded-lg outline-none px-2 py-1 mt-2"
              />

              <.input
                field={@form[:reply_to]}
                type="email"
                label="Reply To (Optional)"
                class="w-full border border-blue-400 rounded-lg outline-none px-2 py-1 mt-2"
              />

              <div>
                <.input
                  field={@form[:priority]}
                  type="select"
                  label="Priority (1=High, 10=Low)"
                  options={[{"High Priority", 1}, {"Medium Priority", 5}, {"Low Priority", 10}]}
                  value={5}
                  class="w-full border border-blue-400 rounded-lg outline-none px-2 py-1 mt-2"
                />
              </div>
            </div>

            <div>
              <.input
                field={@form[:body]}
                type="textarea"
                label="Email Body"
                required
                class="w-full h-64 border border-blue-400 rounded-lg outline-none px-2 py-1 mt-2"
              />
            </div>
          </div>

          <!-- Recipients Selection -->
          <div class="border-t pt-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="font-medium text-gray-900">
                Recipients
                <%= if @email_type == "single" do %>
                  (Select 1 contact)
                <% else %>
                  <%= if @email_type == "bulk" do %>
                    (Select multiple contacts)
                  <% else %>
                    (Select a group)
                  <% end %>
                <% end %>
              </h3>
              <%= if @email_type != "group" do %>
                <button
                  type="button"
                  phx-click="toggle_recipients"
                  class="text-blue-600 hover:text-blue-700 text-sm"
                >
                  <%= if @show_recipients, do: "Hide", else: "Show" %> Recipients
                </button>
              <% end %>
            </div>

            <%= if @email_type == "group" do %>
              <div>
                <select
                  phx-change="select_group"
                  name="group_id"
                  class="w-full border-gray-300 rounded-lg"
                >
                  <option value="">Select a group...</option>
                  <%= for group <- @groups do %>
                    <option
                      value={group.id}
                      selected={@selected_group == group.id}
                    >
                      <%= group.name %> (<%= length(group.contacts) %> contacts)
                    </option>
                  <% end %>
                </select>
              </div>
            <% else %>
              <%= if @show_recipients do %>
                <div class="max-h-64 overflow-y-auto border border-gray-200 rounded-lg">
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-2 p-4">
                    <%= for contact <- @contacts do %>
                      <label class="flex items-center p-2 hover:bg-gray-50 rounded cursor-pointer">
                        <input
                          type="checkbox"
                          phx-click="toggle_contact"
                          phx-value-id={contact.id}
                          checked={contact.id in @selected_contacts}
                          class="mr-3"
                        />
                        <div class="flex-1">
                          <div class="font-medium text-sm"><%= Contact.full_name(contact) %></div>
                          <div class="text-xs text-gray-500"><%= contact.email_address %></div>
                        </div>
                      </label>
                    <% end %>
                  </div>
                </div>
              <% else %>
                <div class="text-sm text-gray-600">
                  <%= case @email_type do %>
                    <% "single" -> %>
                      <%= if length(@selected_contacts) == 1 do %>
                        <span class="font-medium text-green-600">1 contact selected</span>
                      <% else %>
                        <span class="font-medium text-red-600">Please select 1 contact</span>
                      <% end %>
                    <% "bulk" -> %>
                      <%= if length(@selected_contacts) > 1 do %>
                        <span class="font-medium text-green-600">
                          <%= length(@selected_contacts) %> contacts selected
                        </span>
                      <% else %>
                        <span class="font-medium text-red-600">Please select multiple contacts</span>
                      <% end %>
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </div>

          <!-- Submit Button -->
          <div class="flex justify-end space-x-4 pt-6 border-t">
            <.link
              navigate={~p"/emails"}
              class="px-6 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 font-medium"
            >
              Cancel
            </.link>
            <button
              type="submit"
              class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium flex items-center"
            >
              <span class="w-4 h-4 mr-2">🛩️</span>
              Send Email
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
