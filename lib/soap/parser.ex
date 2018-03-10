defmodule Soap.Parser do
  alias Soap.WSDL
  alias XML.Parser
  alias XML.Doc
  alias XML.Tag

  # TODO rewrite using with statement
  @spec parse_wsdl(file_name :: String.t) :: {:ok, %WSDL{}} | {:error, any}
  def parse_wsdl(file_name) do
    if File.exists?(file_name) do
      file_name
      |> File.read!()
      |> Parser.parse()
      |> handle_xml()
    else
      {:error, "File not found: #{file_name}."}
    end
  end

  defp handle_xml({:error, reason}), do: {:error, reason}
  defp handle_xml(xml) do
    simple_xml = trim_whitespace(xml)
    IO.inspect simple_xml
    # TODO extract info out of wsdl
    {:ok, %WSDL{}}
  end

  defp trim_whitespace(doc = %Doc{body: body = %Tag{}}) do
    %Doc{doc | body: trim_whitespace(body)}
  end
  defp trim_whitespace(xml = %Tag{values: vals}) when is_nil(vals), do: xml
  defp trim_whitespace(xml = %Tag{values: vals}) when is_list(vals) do
    updated_vals = vals
                   |> Enum.reject(&contains_only_whitespace/1)
                   |> Enum.map(&trim_whitespace/1)
    %Tag{xml | values: updated_vals}
  end
  defp trim_whitespace(x), do: x

  defp contains_only_whitespace(str) when is_binary(str), do: String.trim(str) == ""
  defp contains_only_whitespace(_), do: false

end

