defmodule EmailNotificationSystemWeb.GroupsLive do
  use EmailNotificationSystemWeb, :live_view
  alias EmailNotificationSystem.{Groups, Groups.Group, Contacts}

  on_mount {EmailNotificationSystemWeb.LiveAuth, :ensure_authenticated}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Check if user has gold plan
    if user.plan_type != "gold" do
      {:ok,
       socket
       |> put_flash(:error, "Groups feature requires Gold plan")
       |> push_navigate(to: ~p"/dashboard")}
    else
      groups = Groups.list_groups(user.id)
      contacts = Contacts.list_contacts(user.id)

      {:ok, assign(socket,
        groups: groups,
        contacts: contacts,
        show_form: false,
        form: to_form(Group.changeset(%Group{}, %{})),
        editing_group: nil,
        selected_group_for_contacts: nil,
        show_manage_contacts: false
      )}
    end
  end

  def handle_event("show_form", _params, socket) do
    form = to_form(Group.changeset(%Group{}, %{user_id: socket.assigns.current_user.id}))
    {:noreply, assign(socket, show_form: true, form: form, editing_group: nil)}
  end

  def handle_event("hide_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, editing_group: nil)}
  end

  def handle_event("edit_group", %{"id" => id}, socket) do
    group = Groups.get_group!(id)
    form = to_form(Group.changeset(group, %{}))
    {:noreply, assign(socket, show_form: true, form: form, editing_group: group)}
  end

  def handle_event("save_group", %{"group" => params}, socket) do
    params = Map.put(params, "user_id", socket.assigns.current_user.id)

    result = case socket.assigns.editing_group do
      nil -> Groups.create_group(params)
      group -> Groups.update_group(group, params)
    end

    case result do
      {:ok, _group} ->
        groups = Groups.list_groups(socket.assigns.current_user.id)
        {:noreply, assign(socket,
          groups: groups,
          show_form: false,
          editing_group: nil
        )}
      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete_group", %{"id" => id}, socket) do
    group = Groups.get_group!(id)
    {:ok, _} = Groups.delete_group(group)

    groups = Groups.list_groups(socket.assigns.current_user.id)
    {:noreply, assign(socket, groups: groups)}
  end

  def handle_event("manage_contacts", %{"id" => id}, socket) do
    {:noreply, assign(socket,
      selected_group_for_contacts: id,
      show_manage_contacts: true
    )}
  end

  def handle_event("hide_manage_contacts", _params, socket) do
    {:noreply, assign(socket,
      selected_group_for_contacts: nil,
      show_manage_contacts: false
    )}
  end

  def handle_event("add_contact_to_group", %{"contact_id" => contact_id}, socket) do
    Groups.add_contact_to_group(socket.assigns.selected_group_for_contacts, contact_id)
    groups = Groups.list_groups(socket.assigns.current_user.id)
    {:noreply, assign(socket, groups: groups)}
  end

  def handle_event("remove_contact_from_group", %{"contact_id" => contact_id}, socket) do
    Groups.remove_contact_from_group(socket.assigns.selected_group_for_contacts, contact_id)
    groups = Groups.list_groups(socket.assigns.current_user.id)
    {:noreply, assign(socket, groups: groups)}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Groups</h1>
          <p class="text-gray-600">Organize your contacts into groups</p>
        </div>
        <button
          phx-click="show_form"
          class="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg font-medium transition-colors flex items-center"
        >
          <span class="w-5 h-5 mr-2">＋</span>
          Create Group
        </button>
      </div>

      <!-- Group Form Modal -->
      <%= if @show_form do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-lg max-w-md w-full p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-lg font-semibold">
                <%= if @editing_group, do: "Edit Group", else: "Create Group" %>
              </h2>
              <button phx-click="hide_form" class="text-gray-400 hover:text-gray-600">
                <span class="w-6 h-6">✖</span>
              </button>
            </div>

            <.form for={@form} phx-submit="save_group" class="space-y-4">
              <.input
                field={@form[:name]}
                type="text"
                label="Group Name"
                required
                class="w-full border border-blue-400 rounded-lg outline-none px-2 py-1 mt-2"
              />

              <.input
                field={@form[:description]}
                type="textarea"
                label="Description"
                rows="3"
                class="w-full border border-blue-400 rounded-lg outline-none px-2 py-1 mt-2"
              />

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
                  class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
                >
                  <%= if @editing_group, do: "Update", else: "Create" %>
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <!-- Manage Contacts Modal -->
      <%= if @show_manage_contacts do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-lg max-w-2xl w-full p-6 max-h-[80vh] overflow-y-auto">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-lg font-semibold">Manage Group Contacts</h2>
              <button phx-click="hide_manage_contacts" class="text-gray-400 hover:text-gray-600">
                <span class="w-6 h-6">✖</span>
              </button>
            </div>

            <div class="space-y-4">
              <%= for contact <- @contacts do %>
                <% group = Enum.find(@groups, &(&1.id == @selected_group_for_contacts)) %>
                <% in_group = group && contact.id in Enum.map(group.contacts, & &1.id) %>

                <div class="flex items-center justify-between p-3 border rounded-lg">
                  <div class="flex items-center">
                    <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                      <span class="text-blue-600 font-semibold text-sm">
                        <%= String.first(contact.first_name) %><%= String.first(contact.last_name) %>
                      </span>
                    </div>
                    <div class="ml-3">
                      <p class="font-medium text-gray-900"><%= "#{contact.first_name} #{contact.last_name}" %></p>
                      <p class="text-sm text-gray-500"><%= contact.email_address %></p>
                    </div>
                  </div>

                  <%= if in_group do %>
                    <button
                      phx-click="remove_contact_from_group"
                      phx-value-contact_id={contact.id}
                      class="bg-red-100 text-red-700 px-3 py-1 rounded-full text-sm hover:bg-red-200"
                    >
                      Remove
                    </button>
                  <% else %>
                    <button
                      phx-click="add_contact_to_group"
                      phx-value-contact_id={contact.id}
                      class="bg-green-100 text-green-700 px-3 py-1 rounded-full text-sm hover:bg-green-200"
                    >
                      Add
                    </button>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Groups List -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200">
        <%= if length(@groups) > 0 do %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 p-6">
            <%= for group <- @groups do %>
              <div class="border border-gray-200 rounded-lg p-6 hover:shadow-md transition-shadow">
                <div class="flex items-start justify-between mb-4">
                  <div class="flex-1">
                    <h3 class="font-semibold text-gray-900 mb-2"><%= group.name %></h3>
                    <%= if group.description do %>
                      <p class="text-sm text-gray-600 mb-3"><%= group.description %></p>
                    <% end %>
                    <p class="text-sm text-gray-500">
                      <%= length(group.contacts) %> contacts
                    </p>
                  </div>

                  <div class="flex items-center space-x-1">
                    <button
                      phx-click="manage_contacts"
                      phx-value-id={group.id}
                      class="p-1 text-blue-600 hover:text-blue-700"
                      title="Manage contacts"
                    >
                      <span class="w-4 h-4">👥</span>
                    </button>
                    <button
                      phx-click="edit_group"
                      phx-value-id={group.id}
                      class="p-1 text-gray-600 hover:text-gray-700"
                      title="Edit group"
                    >
                      <span class="w-4 h-4 inline-flex items-center justify-center" aria-hidden="true">✎</span>
                    </button>
                    <button
                      phx-click="delete_group"
                      phx-value-id={group.id}
                      data-confirm="Are you sure you want to delete this group?"
                      class="p-1 text-red-600 hover:text-red-700"
                      title="Delete group"
                    >
                      <span class="w-4 h-4 inline-flex items-center justify-center" aria-hidden="true">🗑️</span>
                    </button>
                  </div>
                </div>

                <!-- Group contacts preview -->
                <%= if length(group.contacts) > 0 do %>
                  <div class="border-t pt-4">
                    <div class="flex -space-x-2">
                      <%= for {contact, index} <- Enum.with_index(Enum.take(group.contacts, 4)) do %>
                        <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center border-2 border-white">
                          <span class="text-blue-600 font-semibold text-xs">
                            <%= String.first(contact.first_name) %>
                          </span>
                        </div>
                      <% end %>
                      <%= if length(group.contacts) > 4 do %>
                        <div class="w-8 h-8 bg-gray-100 rounded-full flex items-center justify-center border-2 border-white">
                          <span class="text-gray-600 font-semibold text-xs">
                            +<%= length(group.contacts) - 4 %>
                          </span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-12">
            <span class="w-12 h-12 text-gray-400 mx-auto mb-4">👥</span>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No groups yet</h3>
            <p class="text-gray-500 mb-4">Create your first group to organize your contacts.</p>
            <button
              phx-click="show_form"
              class="bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-lg font-medium"
            >
              Create Group
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
