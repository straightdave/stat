defmodule StatServer.Repo do
  use Ecto.Repo,
    otp_app: :stat_server,
    adapter: Ecto.Adapters.Postgres
end
