defmodule EmailNotificationSystemWeb.ProfileLive do
  use EmailNotificationSystemWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Profile")}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto">
      <h1 class="text-2xl font-bold text-gray-900">Profile</h1>
      <p class="text-gray-600">Manage your account settings</p>
    </div>
    """
  end
end
