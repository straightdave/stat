defmodule StatServerTest do
  use ExUnit.Case
  doctest StatServer

  test "greets the world" do
    assert StatServer.hello() == :world
  end
end
