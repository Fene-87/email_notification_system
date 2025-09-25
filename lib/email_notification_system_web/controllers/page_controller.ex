defmodule EmailNotificationSystemWeb.PageController do
  use EmailNotificationSystemWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
