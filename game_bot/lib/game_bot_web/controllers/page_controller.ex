defmodule GameBotWeb.PageController do
  use GameBotWeb, :controller

  def home(conn, _params) do
    conn
    |> assign(:page_title, "GameBot")
    |> render(:home)
  end
end
