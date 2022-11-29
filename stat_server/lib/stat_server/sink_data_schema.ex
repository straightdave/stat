defmodule StatServer.SinkDataSchema do
  use Ecto.Schema

  import Ecto.Changeset

  schema "metrics" do
    field(:timestamp, :integer)
    field(:data, :map)
    field(:created_at, :utc_datetime)
  end

  def new do
    %__MODULE__{}
  end

  def changeset(sink_data, params \\ %{}) do
    sink_data
    |> cast(params, [:timestamp, :data])
  end
end
