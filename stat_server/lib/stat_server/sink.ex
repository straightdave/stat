defmodule StatServer.Sink do
  @moduledoc false

  use GenServer

  alias StatServer.Helper

  require Logger

  @ets_key "current"

  @sink_interval 5_000
  @sink_script File.read!("priv/lua/sink.lua")

  # Redis zset name
  @pile_name "data_pile"

  # =============================
  # Module's exposed functions
  # =============================
  # Note that there are multiple instances of the process Sink.

  def push(data) when is_list(data) do
    # make sure the workload is spread equally to all partitions
    partitions = PartitionSupervisor.partitions(:sinks)
    name = {:via, PartitionSupervisor, {:sinks, :rand.uniform(partitions)}}

    GenServer.cast(name, {:push, data})
  end

  # =============================
  # Process's internal functions
  # =============================

  def start_link(args) do
    name = "p_#{args[:partition]}" |> String.to_atom()
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @impl true
  def init(args) do
    ets_name = "ets_#{args[:partition]}" |> String.to_atom()
    :ets.new(ets_name, [:named_table])

    uniq = Helper.get_ipv4() || Helper.random_str(4)
    state = %{index: 0, ets: ets_name, p: args[:partition], uniq: uniq}
    Logger.info("Sink #{state.p} starts (instance: #{uniq})")

    Process.send_after(self(), :tick, 0)
    {:ok, state}
  end

  @impl true
  def handle_cast({:push, data}, %{index: i, ets: t} = state) do
    data
    |> Enum.each(fn
      [name, type, value] when type in ["i", "g"] ->
        :ets.insert(t, {@ets_key, i, name, type, value})

      _ ->
        nil
    end)

    {:noreply, %{state | index: i + 1}}
  end

  @impl true
  def handle_info(:tick, %{ets: t} = state) do
    data =
      :ets.lookup(t, @ets_key)
      |> Enum.reduce(%{}, fn
        {_, _, name, "i", value}, acc ->
          case Map.get(acc, name) do
            nil -> Map.put(acc, name, [name, "i", value])
            v -> Map.put(acc, name, [name, "i", v + value])
          end

        {_, _, name, "g", value}, acc ->
          Map.put(acc, name, [name, "g", value])
      end)
      |> Map.values()

    state =
      case data do
        [] ->
          state

        data ->
          # Simple serialization via :erlang.term_to_binary
          member =
            {
              data,
              # Redis ZSET requires unique members.
              # There are many sinks in an App instance,
              # and many instances in a distributed system.
              # This unique field can be discarded after data's retrieved.
              "#{state.uniq}_#{state.p}"
            }
            |> :erlang.term_to_binary()

          Redix.command!(:redix, ["EVAL", @sink_script, 1, @pile_name, member])

          :ets.delete(t, @ets_key)
          %{state | index: 0}
      end

    Process.send_after(self(), :tick, @sink_interval)
    {:noreply, state}
  rescue
    err ->
      Logger.error(Exception.format(:error, err))

      # hope it may succeed next time
      Process.send_after(self(), :tick, @sink_interval)
      {:noreply, state}
  end
end
