defmodule StatServer.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      StatServer.Repo,
      {Redix, name: :redix},
      {
        PartitionSupervisor,
        child_spec: StatServer.Sink,
        name: :sinks,
        with_arguments: fn [args], partition ->
          [Keyword.put(args, :partition, partition)]
        end
      },
      StatServer.Processor,
      {Plug.Cowboy, scheme: :http, plug: StatServer.API, options: [port: 4000]}
    ]

    Logger.info("Starting StatServer ...")

    opts = [strategy: :one_for_one, name: StatServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
