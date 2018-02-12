defmodule ElixirSoapClientTest do
  use ExUnit.Case
  doctest ElixirSoapClient

  test "greets the world" do
    assert ElixirSoapClient.hello() == :world
  end
end
