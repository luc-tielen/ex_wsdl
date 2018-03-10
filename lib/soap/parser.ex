defmodule Soap.Parser do
  alias Soap.{WSDL, Message, Port, Operation, OperationMsg, Service}
  alias XML.{Parser, Doc, Tag}
  import XML.{Doc, Tag}
  import Focus


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
    result = xml |> trim_whitespace() |> extract_wsdl_info()
    case result do
      {:error, _} = err -> err
      {:ok, wsdl} -> wsdl
    end
  end

  def extract_wsdl_info(xml_doc) do
    msgs = extract_messages(xml_doc)
    ports = extract_ports(xml_doc)
    services = extract_services(xml_doc)
    # TODO bindings, types
    {:ok, %WSDL{messages: msgs, ports: ports, services: services}}
  end

  defp extract_messages(xml_doc) do
    body_lens()
    ~> values_lens()  # definitions
    |> Focus.view(xml_doc)
    |> Stream.filter(fn tag -> tag.name == "message" end)
    |> Enum.map(&extract_message/1)
  end

  defp extract_message(tag = %Tag{}) do
    name_lens = Lens.make_lens("name")
    element_lens = Lens.make_lens("element")
    msg_name_lens = attributes_lens() ~> name_lens
    part_lens = values_lens() ~> Lens.idx(0) ~> attributes_lens()

    [msg_name, part_name, type] = Focus.view_list([msg_name_lens,
                                                   part_lens ~> name_lens,
                                                   part_lens ~> element_lens],
                                                   tag)
    %Message{name: msg_name, part_name: part_name, element: type}
  end

  defp extract_ports(xml_doc) do
    body_lens()
    ~> values_lens()  # definitions
    |> Focus.view(xml_doc)
    |> Stream.filter(fn tag -> tag.name == "portType" end)
    |> Enum.map(&extract_port/1)
  end

  defp extract_port(tag = %Tag{}) do
    port_name = attributes_lens() ~> Lens.make_lens("name") |> Focus.view(tag)
    operations = values_lens() |> Focus.view(tag) |> Enum.map(&extract_operation/1)
    %Port{name: port_name, operations: operations}
  end

  defp extract_operation(tag = %Tag{}) do
    name_lens = Lens.make_lens("name")
    op_name = attributes_lens() ~> name_lens |> Focus.view(tag)
    msgs =
      values_lens()
      |> Focus.view(tag)
      |> Enum.map(fn msg ->
        [attributes_lens() ~> Lens.make_lens("message"), Tag.name_lens()]
        |> Focus.view_list(msg)
        |> List.to_tuple()
      end)

    input_msg = Stream.filter(msgs, fn {_, type} -> type == "input" end) |> Enum.at(0)
    output_msg = Stream.filter(msgs, fn {_, type} -> type == "output" end) |> Enum.at(0)
    %Operation{name: op_name, input_msg: input_msg, output_msg: output_msg}
  end

  defp extract_services(xml_doc) do
    body_lens()
    ~> values_lens()  # definitions
    |> Focus.view(xml_doc)
    |> Stream.filter(fn tag -> tag.name == "service" end)
    |> Enum.map(&extract_service/1)
  end

  defp extract_service(tag) do
    attr_name_lens = attributes_lens() ~> Lens.make_lens("name")
    svc_name = attr_name_lens |> Focus.view(tag)
    svc_docs = values_lens()
              |> Focus.view(tag)
              |> Enum.filter(fn tag -> tag.name == "documentation" end)
              |> Enum.fetch(0)
    docs = case svc_docs do
      :error -> ""
      {:ok, docs_tag} -> values_lens() ~> Lens.idx(0) |> Focus.view(docs_tag)
    end
    svc_bindings = values_lens()
              |> Focus.view(tag)
              |> Enum.filter(fn tag -> tag.name == "port" end)
              |> Enum.fetch(0)
    binding_tag = case svc_bindings do
      :error -> nil
      {:ok, binding} -> binding
    end

    port_name = attr_name_lens |> Focus.view(binding_tag)
    binding_name = attributes_lens() ~> Lens.make_lens("binding") |> Focus.view(binding_tag)

    location = values_lens()
      ~> Lens.idx(0)
      ~> attributes_lens()
      ~> Lens.make_lens("location")
      |> Focus.view(binding_tag)

    %Service{name: svc_name, documentation: docs, port_name: port_name,
             binding_name: binding_name, location: location}
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
  defp trim_whitespace({:ok, x}), do: trim_whitespace(x)
  defp trim_whitespace(x), do: x

  defp contains_only_whitespace(str) when is_binary(str), do: String.trim(str) == ""
  defp contains_only_whitespace(_), do: false

end

