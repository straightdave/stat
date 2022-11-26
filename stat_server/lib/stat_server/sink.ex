defmodule StatServer.Sink do
  @moduledoc false

  use GenServer

  require Logger

  @sink_interval 5_000
  @queue_name "data_pipe"

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

    Process.send_after(self(), :tick, 0)
    {:ok, %{index: 0, ets: ets_name, p: args[:partition]}}
  end

  @impl true
  def handle_cast({:push, data}, %{index: i, ets: t} = state) do
    data
    |> Enum.each(fn
      [name, type, value] when type in ["i", "g"] ->
        :ets.insert(t, {"current", i, name, type, value}) |> IO.inspect()

      _ ->
        nil
    end)

    {:noreply, %{state | index: i + 1}}
  end

  @impl true
  def handle_info(:tick, %{ets: t, p: p} = state) do
    data =
      :ets.lookup(t, "current")
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
      |> IO.inspect(label: "ready_to_enqueue from #{p}")

    state =
      case data do
        [] ->
          # do nothing
          state

        data ->
          payload = :erlang.term_to_binary(data)
          Redix.command!(:redix, ["RPUSH", @queue_name, payload])
          Logger.info("Enqueued from #{p}")

          # clean up
          :ets.delete(t, "current")
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
