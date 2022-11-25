defmodule StatClient do
  @moduledoc """
  Documentation for `StatClient`.
  """

  use GenServer

  require Logger

  @interval Application.compile_env(:stat_client, :interval, 5_000)

  # ===================
  # Exposed functions
  # ===================

  @doc """
  Incremental function.
  """
  @spec incre(String.t(), integer()) :: :ok
  def incre(topic, value \\ 1)

  def incre(topic, value) when is_integer(value) and value > 0 do
    GenServer.cast(__MODULE__, {:record, topic, "i", value})
  end

  def incre(_, _), do: :ok

  @doc """
  Gauge function.
  """
  @spec gauge(String.t(), number()) :: :ok
  def gauge(topic, value) when is_number(value) do
    GenServer.cast(__MODULE__, {:record, topic, "g", value})
  end

  def gauge(_, _), do: :ok

  # ===================
  # Internal functions
  # ===================

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc false
  @impl true
  def init(_args) do
    :ets.new(:stat_client, [:named_table])

    Process.send_after(self(), :tick, 0)
    {:ok, %{index: 0}}
  end

  @doc false
  @impl true
  def handle_cast({:record, topic, type, value}, %{index: i} = state) do
    :ets.insert(:stat_client, {"data", i, topic, type, value})

    {:noreply, %{state | index: i + 1}}
  rescue
    err ->
      Logger.warn(Exception.format(:error, err))
      {:noreply, state}
  end

  @doc false
  @impl true
  def handle_info(:tick, state) do
    :ets.lookup(:stat_client, "data")
    |> Enum.reduce(%{}, fn
      {_, _, topic, "i", value}, acc ->
        case Map.get(acc, topic) do
          nil -> Map.put(acc, topic, [topic, "i", value])
          v -> Map.put(acc, topic, [topic, "i", v + value])
        end

      {_, _, topic, "g", value}, acc ->
        Map.put(acc, topic, [topic, "g", value])

      _, acc ->
        acc
    end)
    |> Map.values()
    |> report()

    # clean up
    :ets.delete(:stat_client, "data")
    state = %{state | index: 0}

    Process.send_after(self(), :tick, @interval)
    {:noreply, state}
  rescue
    err ->
      Logger.warn(Exception.format(:error, err))

      Process.send_after(self(), :tick, @interval)
      {:noreply, state}
  end

  defp report(data) do
    Logger.info("reporting ...")

    payload =
      data
      |> Enum.map(fn [topic, type, value] ->
        "#{topic},#{type},#{value}"
      end)
      |> Enum.join("\n")

    with {:error, err} <- HTTPoison.post("http://127.0.0.1:4000/data", payload) do
      Logger.warn(Exception.format(:error, err))
    end
  end
end
