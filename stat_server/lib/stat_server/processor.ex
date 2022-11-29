defmodule StatServer.Processor do
  @moduledoc """
  Processor calculates data from queue and store in DB.
  """

  use GenServer

  alias StatServer.{Repo, SinkDataSchema}

  require Logger

  @get_script File.read!("priv/lua/get.lua")

  # Redis zset name
  @pile_name "data_pile"

  # Processor instances should be less. No need to have many processors.
  # So keep the number of Pods.
  @process_interval 2_000

  # time span of data to get (5 by default in Lua script)
  @timespan 10

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Process.send_after(self(), :tick, 0)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:tick, state) do
    state = do_tick(state)

    Process.send_after(self(), :tick, @process_interval)
    {:noreply, state}
  end

  defp do_tick(state) do
    Redix.command!(:redix, ["EVAL", @get_script, 1, @pile_name, @timespan])
    |> do_calc()
    |> do_save()

    state
  rescue
    err ->
      Logger.warn(Exception.format(:error, err))
      state
  end

  defp do_calc(1), do: nil
  defp do_calc(2), do: nil

  defp do_calc([t, data]) when is_list(data) do
    data
    |> Enum.map(&:erlang.binary_to_term/1)
    |> IO.inspect(label: "#{t} =>")
    |> Enum.map(&elem(&1, 0))
    |> IO.inspect()

    # |> Enum.reduce(%{}, fn
    #   {_, _, name, "i", value}, acc ->
    #     case Map.get(acc, name) do
    #       nil -> Map.put(acc, name, [name, "i", value])
    #       v -> Map.put(acc, name, [name, "i", v + value])
    #     end

    #   {_, _, name, "g", value}, acc ->
    #     Map.put(acc, name, [name, "g", value])
    # end)
    # |> Map.values()

    {t, nil}
  end

  defp do_calc(o) do
    Logger.warn("Unknown result of get.lua: #{inspect(o)}")
    nil
  end

  defp do_save({_, nil}), do: :ok

  defp do_save({t, data}) do
    SinkDataSchema.new()
    |> SinkDataSchema.changeset(%{timestamp: t, data: data})
    |> Repo.insert!()

    :ok
  end

  defp do_save(_), do: :ok
end
