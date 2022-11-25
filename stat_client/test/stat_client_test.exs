defmodule StatClientTest do
  use ExUnit.Case
  doctest StatClient

  test "greets the world" do
    assert StatClient.hello() == :world
  end
end
