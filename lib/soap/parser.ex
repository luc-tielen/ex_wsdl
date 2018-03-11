defmodule Soap.Parser do
  alias Soap.{WSDL, Message, Port, Service}
  alias Soap.{Operation, OperationMsg, Binding, BindingOperation}
  alias XML.{Parser, Doc, Tag}
  import XML.{Doc, Tag}
  import Focus


  @spec parse_wsdl(file_name :: String.t) :: {:ok, %WSDL{}} | {:error, any}
  def parse_wsdl(file_name) do
    with {:file_exists, true} <- {:file_exists, File.exists?(file_name)},
         {:ok, wsdl_contents} <- File.read(file_name),
         {:ok, xml_data} <- Parser.parse(wsdl_contents),
         trimmed_xml_data <- trim_whitespace(xml_data),
         {:ok, wsdl_data} <- extract_wsdl_info(trimmed_xml_data)
    do
      {:ok, wsdl_data}
    else
      {:file_exists, false} -> {:error, "File not found: #{file_name}."}
      {:error, _} = error -> error
      unexpected -> {:error, "Received unexpected value: #{unexpected}."}
    end
  end

  def extract_wsdl_info(xml_doc) do
    tags = Focus.view(body_lens() ~> values_lens(), xml_doc)
    msgs = extract_messages(tags)
    ports = extract_ports(tags)
    services = extract_services(tags)
    bindings = extract_bindings(tags)
    # TODO types
    {:ok, %WSDL{messages: msgs, ports: ports, services: services,
                bindings: bindings}}
  end

  defp extract_messages(tags) do
    extract_tags_with_name(tags, "message", &extract_message/1)
  end

  defp extract_message(tag = %Tag{}) do
    name_lens = Lens.make_lens("name")
    element_lens = Lens.make_lens("element")
    part_lens = values_lens() ~> Lens.idx(0) ~> attributes_lens()
    [msg_name, part_name, type] = Focus.view_list([attr_name_lens(),
                                                   part_lens ~> name_lens,
                                                   part_lens ~> element_lens],
                                                   tag)
    %Message{name: msg_name, part_name: part_name, element: type}
  end

  defp extract_ports(tags) do
    extract_tags_with_name(tags, "portType", &extract_port/1)
  end

  defp extract_port(tag = %Tag{}) do
    port_name = Focus.view(attr_name_lens(), tag)
    operations = map_tag_values(tag, &extract_operation/1)
    %Port{name: port_name, operations: operations}
  end

  defp extract_operation(tag = %Tag{}) do
    op_name = Focus.view(attr_name_lens(), tag)
    msgs = map_tag_values(tag, fn msg ->
      Focus.alongside(attributes_lens() ~> Lens.make_lens("message"), name_lens())
      |> Focus.view(msg)
    end)

    input_msg = find_op_with_type!(msgs, "input")
    output_msg = find_op_with_type!(msgs, "output")
    %Operation{name: op_name, input_msg: input_msg, output_msg: output_msg}
  end

  defp find_op_with_type!(tags, type) do
    {op, _} =
      tags
      |> Stream.filter(fn {_, t} -> t == type end)
      |> Enum.fetch!(0)
    op
  end

  defp extract_services(tags) do
    extract_tags_with_name(tags, "service", &extract_service/1)
  end

  defp extract_service(tag) do
    svc_name = Focus.view(attr_name_lens(), tag)
    binding_tag = extract_value_with_name!(tag, "port", 0)
    svc_docs = extract_value_with_name!(tag, "documentation", 0)

    port_name = attr_name_lens() |> Focus.view(binding_tag)
    docs = values_lens() ~> Lens.idx(0) |> Focus.view(svc_docs)
    binding_name =
      attributes_lens()
      ~> Lens.make_lens("binding")
      |> Focus.view(binding_tag)
    location =
      values_lens()
      ~> Lens.idx(0)
      ~> attributes_lens()
      ~> Lens.make_lens("location")
      |> Focus.view(binding_tag)

    %Service{name: svc_name, documentation: docs, port_name: port_name,
             binding_name: binding_name, location: location}
  end

  defp extract_bindings(tags) do
    attr_type_lens = attributes_lens() ~> Lens.make_lens("type")
    style_lens = attributes_lens() ~> Lens.make_lens("style")

    bindings =
      tags
      |> Stream.filter(fn tag -> tag.name == "binding" end)
      |> Enum.fetch!(0)
    soap_binding_tag = extract_value_with_name!(bindings, "soap:binding", 0)
    [binding_name, type] = Focus.view_list([attr_name_lens(), attr_type_lens],
                                           bindings)
    style = Focus.view(style_lens, soap_binding_tag)

    operations =
      values_lens()
      |> Focus.view(bindings)
      |> extract_tags_with_name("operation", &extract_binding_operation/1)
    %Binding{name: binding_name, type: type, style: style, operations: operations}
  end

  defp extract_binding_operation(tag = %Tag{}) do
    action_lens = attributes_lens() ~> Lens.make_lens("soapAction")
    use_lens = values_lens() ~> Lens.idx(0) ~> attributes_lens() ~> Lens.make_lens("use")

    operation_tag = extract_value_with_name!(tag, "soap:operation", 0)
    input_tag = extract_value_with_name!(tag, "input", 0)
    output_tag = extract_value_with_name!(tag, "output", 0)

    name = Focus.view(attr_name_lens(), tag)
    action = Focus.view(action_lens, operation_tag)
    input_use = Focus.view(use_lens, input_tag)
    output_use = Focus.view(use_lens, output_tag)
    %BindingOperation{name: name, action: action,
                      input_use: input_use, output_use: output_use}
  end

  defp trim_whitespace(doc = %Doc{body: body = %Tag{}}) do
    %Doc{doc | body: trim_whitespace(body)}
  end
  defp trim_whitespace(xml = %Tag{values: vals}) when is_nil(vals), do: xml
  defp trim_whitespace(xml = %Tag{values: vals}) when is_list(vals) do
    updated_vals =
      vals
      |> Enum.reject(&contains_only_whitespace/1)
      |> Enum.map(&trim_whitespace/1)
    %Tag{xml | values: updated_vals}
  end
  defp trim_whitespace(x), do: x

  defp contains_only_whitespace(str) when is_binary(str), do: String.trim(str) == ""
  defp contains_only_whitespace(_), do: false

  defp attr_name_lens(), do: attributes_lens() ~> Lens.make_lens("name")

  defp extract_tags_with_name(tags, name, extract_fn) do
    tags
    |> Stream.filter(fn tag -> tag.name == name end)
    |> Enum.map(extract_fn)
  end

  defp extract_value_with_name!(tag, name, idx) do
    values_lens()
    |> Focus.view(tag)
    |> Stream.filter(fn t -> t.name == name end)
    |> Enum.fetch!(idx)
  end

  defp map_tag_values(tag, map_fn) do
    values_lens()
    |> Focus.view(tag)
    |> Enum.map(map_fn)
  end
end

