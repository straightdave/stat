defmodule StatServer.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      {Redix, host: "127.0.0.1", name: :redix},
      StatServer.Worker,
      {Plug.Cowboy, scheme: :http, plug: StatServer.API, options: [port: 4000]}
    ]

    Logger.info("Starting StatServer ...")

    opts = [strategy: :one_for_one, name: StatServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
