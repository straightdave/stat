defmodule StatServer.Repo.Migrations.CreateTableMetrics do
  use Ecto.Migration

  def change do
    create table("metrics") do
      # NOTE: it stores timestamp in Redis here, may not be UTC.
      add :timestamp, :integer, null: false
      add :data, :map
      add :created_at, :timestamptz, default: fragment("NOW()")
    end

    create index("metrics", :timestamp)
  end
end
