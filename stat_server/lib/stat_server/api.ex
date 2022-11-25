defmodule StatServer.API do
  @moduledoc false

  use Plug.Router

  require Logger

  plug(:match)
  plug(:dispatch)

  get "/hello" do
    send_resp(conn, 200, "world")
  end

  post "/data" do
    {:ok, data, conn} = read_body(conn)

    data
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      with [name, type, value] when type in ["i", "g"] <-
             String.split(line, ",", trim: true),
           {v, ""} <- Integer.parse(value) do
        [name, type, v]
      else
        _ -> nil
      end
    end)
    |> Enum.reject(&(&1 == nil))
    |> IO.inspect(label: "received")
    |> StatServer.Worker.push()

    send_resp(conn, 200, "ok")
  end

  match _ do
    send_resp(conn, 404, "Oops")
  end
end
