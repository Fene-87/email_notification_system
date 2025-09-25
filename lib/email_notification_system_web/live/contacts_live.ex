defmodule EmailNotificationSystemWeb.ContactsLive do
  use EmailNotificationSystemWeb, :live_view
  on_mount {EmailNotificationSystemWeb.LiveAuth, :ensure_authenticated}
  alias EmailNotificationSystem.{Contacts, Accounts, Contacts.Contact}

  def mount(_params, session, socket) do
    user =
      socket.assigns[:current_user] ||
        case session["user_id"] do
          nil -> nil
          id  -> Accounts.get_user!(id)
        end

    if is_nil(user) do
      {:ok, Phoenix.LiveView.redirect(socket, to: ~p"/auth")}
    else
      contacts = Contacts.list_contacts(user.id)

      {:ok,
       assign(socket,
         current_user: user,
         contacts: contacts,
         search_query: "",
         show_form: false,
         form: to_form(Contact.changeset(%Contact{}, %{}), as: :contact),
         editing_contact: nil
       )}
    end
  end

  def handle_event("search", %{"search" => query}, socket) do
    user_id = socket.assigns.current_user.id
    contacts = if query == "" do
      Contacts.list_contacts(user_id)
    else
      Contacts.search_contacts(user_id, query)
    end

    {:noreply, assign(socket, contacts: contacts, search_query: query)}
  end

  def handle_event("show_form", _params, socket) do
    form = to_form(Contact.changeset(%Contact{}, %{user_id: socket.assigns.current_user.id}))
    {:noreply, assign(socket, show_form: true, form: form, editing_contact: nil)}
  end

  def handle_event("hide_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, editing_contact: nil)}
  end

  def handle_event("edit_contact", %{"id" => id}, socket) do
    contact = Contacts.get_contact!(id)
    form = to_form(Contact.changeset(contact, %{}))
    {:noreply, assign(socket, show_form: true, form: form, editing_contact: contact)}
  end

  def handle_event("save_contact", %{"contact" => params}, socket) do
    params = Map.put(params, "user_id", socket.assigns.current_user.id)

    result = case socket.assigns.editing_contact do
      nil -> Contacts.create_contact(params)
      contact -> Contacts.update_contact(contact, params)
    end

    case result do
      {:ok, _contact} ->
        contacts = Contacts.list_contacts(socket.assigns.current_user.id)
        {:noreply, assign(socket,
          contacts: contacts,
          show_form: false,
          editing_contact: nil
        )}
      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete_contact", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case Contacts.soft_delete_contact(user_id, id) do
      {:ok, _} ->
        pruned = Enum.reject(socket.assigns.contacts, &(&1.id == id))
        {:noreply,
        socket
        |> assign(:contacts, pruned)
        |> put_flash(:info, "Contact deleted.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Contact not found.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Contacts</h1>
          <p class="text-gray-600">Manage your email contacts</p>
        </div>
        <button
          phx-click="show_form"
          class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-medium transition-colors flex items-center"
        >
          <span class="w-5 h-5 mr-2">＋</span>
          Add Contact
        </button>
      </div>

      <!-- Search -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
        <.form for={%{}} phx-submit="search" phx-change="search" class="flex">
          <div class="flex-1 mr-4">
            <.input
              name="search"
              type="text"
              placeholder="Search contacts..."
              value={@search_query}
              class="w-full outline-none"
            />
          </div>
        </.form>
      </div>

      <!-- Contact Form Modal -->
      <%= if @show_form do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-lg max-w-md w-full p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-lg font-semibold">
                <%= if @editing_contact, do: "Edit Contact", else: "Add Contact" %>
              </h2>
              <button phx-click="hide_form" class="text-gray-400 hover:text-gray-600">
                <span class="w-6 h-6 inline-flex items-center justify-center" aria-hidden="true">×</span>
              </button>
            </div>

            <.form for={@form} phx-submit="save_contact" class="space-y-4">
              <div class="grid grid-cols-2 gap-4">
                <.input
                  field={@form[:first_name]}
                  type="text"
                  label="First Name"
                  required
                  class="border border-blue-400 rounded-lg outline-none px-2 py-1 mt-2"
                />
                <.input
                  field={@form[:last_name]}
                  type="text"
                  label="Last Name"
                  required
                  class="border border-blue-400 rounded-lg outline-none px-2 py-1 mt-2"
                />
              </div>

              <div>
                <.input
                  field={@form[:email_address]}
                  type="email"
                  label="Email Address"
                  required
                  class="border border-blue-400 rounded-lg outline-none px-2 py-1 mt-2 flex"
                />

                <.input
                  field={@form[:phone_number]}
                  type="tel"
                  label="Phone Number"
                  class="border border-blue-400 rounded-lg outline-none px-2 py-1 mt-2 flex"
                />
              </div>

              <div class="flex justify-end space-x-3 mt-6">
                <button
                  type="button"
                  phx-click="hide_form"
                  class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                >
                  <%= if @editing_contact, do: "Update", else: "Create" %>
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <!-- Contacts List -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200">
        <%= if length(@contacts) > 0 do %>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead class="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th class="text-left py-3 px-6 font-medium text-gray-900">Name</th>
                  <th class="text-left py-3 px-6 font-medium text-gray-900">Email</th>
                  <th class="text-left py-3 px-6 font-medium text-gray-900">Phone</th>
                  <th class="text-left py-3 px-6 font-medium text-gray-900">Added</th>
                  <th class="text-right py-3 px-6 font-medium text-gray-900">Actions</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200">
                <%= for contact <- @contacts do %>
                  <tr class="hover:bg-gray-50">
                    <td class="py-4 px-6">
                      <div class="flex items-center">
                        <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                          <span class="text-blue-600 font-semibold text-sm">
                            <%= String.first(contact.first_name) %><%= String.first(contact.last_name) %>
                          </span>
                        </div>
                        <div class="ml-3">
                          <p class="font-medium text-gray-900"><%= Contact.full_name(contact) %></p>
                        </div>
                      </div>
                    </td>
                    <td class="py-4 px-6 text-gray-900"><%= contact.email_address %></td>
                    <td class="py-4 px-6 text-gray-900"><%= contact.phone_number || "-" %></td>
                    <td class="py-4 px-6 text-gray-500"><%= format_date(contact.inserted_at) %></td>
                    <td class="py-4 px-6">
                      <div class="flex items-center justify-end space-x-2">
                        <button
                          phx-click="edit_contact"
                          phx-value-id={contact.id}
                          class="text-blue-600 hover:text-blue-700 p-1"
                        >
                          <span class="w-4 h-4 inline-flex items-center justify-center" aria-hidden="true">✎</span>
                        </button>
                        <button
                          phx-click="delete_contact"
                          phx-value-id={contact.id}
                          onclick={"return confirm('Delete #{Contact.full_name(contact)}?')"}
                          class="text-red-600 hover:text-red-700 p-1"
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
            <span class="w-12 h-12 text-gray-400 mx-auto mb-4">👥</span>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No contacts yet</h3>
            <p class="text-gray-500 mb-4">Get started by adding your first contact.</p>
            <button
              phx-click="show_form"
              class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg font-medium"
            >
              Add Contact
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
