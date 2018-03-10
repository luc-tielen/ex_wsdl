defmodule Soap.WSDL.Test do
  use ExUnit.Case, async: true
  alias Soap.WSDL
  doctest WSDL


  test "fails to parse non-existing WSDL files" do
    file = "missing.wsdl"
    assert {:error, "File not found: #{file}."} == WSDL.parse_wsdl(file)
  end

  test "parsing WSDL files" do
    expected = {:ok, %WSDL{}}
    assert expected == WSDL.parse_wsdl("test/fixtures/hello.wsdl")
  end
end
