import Config

config :stat_server, StatServer.Repo,
  database: "stat_server",
  username: "dave",
  password: "123123",
  hostname: "localhost"

config :stat_server, ecto_repos: [StatServer.Repo]
