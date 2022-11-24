defmodule StatServer.Worker do
  @moduledoc false

  use GenServer

  require Logger

  @sink_interval 5_000
  @queue_name "data_pipe"

  def push(data) when is_list(data) do
    GenServer.cast(__MODULE__, {:push, data})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    :ets.new(:worker_ets, [:named_table])

    Process.send_after(self(), :tick, 0)
    {:ok, %{index: 0}}
  end

  @impl true
  def handle_cast({:push, data}, %{index: index} = state) do
    data
    |> Enum.each(fn
      {name, type, value} when type in ["incre", "gauge"] ->
        :ets.insert(:worker_ets, {"current", index, name, type, value})

      _ ->
        nil
    end)

    {:noreply, %{state | index: index + 1}}
  end

  @impl true
  def handle_info(:tick, state) do
    data =
      :ets.lookup(:worker_ets, "current")
      |> Enum.reduce(%{}, fn
        {_, _, name, "incre", value}, acc ->
          case Map.get(acc, name) do
            nil -> Map.put(acc, name, [name, "i", value])
            v -> Map.put(acc, name, [name, "i", v + value])
          end

        {_, _, name, "gauge", value}, acc ->
          Map.put(acc, name, [name, "g", value])
      end)
      |> Map.values()

    state =
      case data do
        [] ->
          # do nothing
          state

        data ->
          payload = :erlang.term_to_binary(data)
          Redix.command!(:redix, ["RPUSH", @queue_name, payload])

          # clean up
          :ets.delete(:worker_ets, "current")
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