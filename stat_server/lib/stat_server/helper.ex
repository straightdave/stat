defmodule StatServer.Helper do
  @chars '0123456789abcdefghijklmnopqrstuvwxyz'

  def random_str(n) when is_integer(n) and n > 0 do
    for _ <- 1..n, into: "", do: <<Enum.random(@chars)>>
  end

  def get_ipv4() do
    with {:ok, ifs} <- :inet.getifaddrs(),
         {_if, attrs} <- List.keyfind(ifs, 'en0', 0),
         {_, {a, b, c, d}} <-
           Enum.find(attrs, fn
             {:addr, {_, _, _, _}} -> true
             _ -> false
           end) do
      # Tested on Mac
      "#{a}.#{b}.#{c}.#{d}"
    else
      _ -> nil
    end
  end
end
