defmodule TestApp.Worker do
  @moduledoc false

  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Process.send_after(self(), :tick1, 2_000)
    Process.send_after(self(), :tick2, 5_000)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:tick1, state) do
    StatClient.incre("test_app.counter")

    Process.send_after(self(), :tick1, :rand.uniform(10) * 1000)
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick2, state) do
    StatClient.gauge("test_app.gauge", :rand.uniform(10))

    Process.send_after(self(), :tick2, 1_000)
    {:noreply, state}
  end
end
