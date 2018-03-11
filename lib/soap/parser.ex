defmodule Soap.Parser do
  alias Soap.{WSDL, Message, Port, Service}
  alias Soap.{Operation, OperationMsg, Binding, BindingOperation}
  alias XML.{Parser, Doc, Tag}
  import XML.{Doc, Tag}
  import Focus


  # TODO refactor
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
    tags
    |> Stream.filter(fn tag -> tag.name == "message" end)
    |> Enum.map(&extract_message/1)
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
    tags
    |> Stream.filter(fn tag -> tag.name == "portType" end)
    |> Enum.map(&extract_port/1)
  end

  defp extract_port(tag = %Tag{}) do
    port_name = Focus.view(attr_name_lens(), tag)
    operations = values_lens() |> Focus.view(tag) |> Enum.map(&extract_operation/1)
    %Port{name: port_name, operations: operations}
  end

  defp extract_operation(tag = %Tag{}) do
    op_name = Focus.view(attr_name_lens(), tag)
    msgs =
      values_lens()
      |> Focus.view(tag)
      |> Enum.map(fn msg ->
        Focus.alongside(attributes_lens() ~> Lens.make_lens("message"), name_lens())
        |> Focus.view(msg)
      end)

    input_msg = Stream.filter(msgs, fn {_, type} -> type == "input" end) |> Enum.at(0)
    output_msg = Stream.filter(msgs, fn {_, type} -> type == "output" end) |> Enum.at(0)
    %Operation{name: op_name, input_msg: input_msg, output_msg: output_msg}
  end

  defp extract_services(tags) do
    tags
    |> Stream.filter(fn tag -> tag.name == "service" end)
    |> Enum.map(&extract_service/1)
  end

  defp extract_service(tag) do
    svc_name = attr_name_lens() |> Focus.view(tag)
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

    port_name = attr_name_lens() |> Focus.view(binding_tag)
    binding_name = attributes_lens() ~> Lens.make_lens("binding") |> Focus.view(binding_tag)

    location = values_lens()
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

    bindings_tag = tags
      |> Enum.filter(fn tag -> tag.name == "binding" end)
      |> Enum.fetch(0)
    bindings = case bindings_tag do
      {:ok, bindings} -> bindings
      :error -> []
    end

    soap_binding_tag = values_lens()
                 |> Focus.view(bindings)
                 |> Enum.filter(fn tag -> tag.name == "soap:binding" end)
                 |> Enum.fetch!(0)
    [binding_name, type] = Focus.view_list([attr_name_lens(), attr_type_lens], bindings)
    style = Focus.view(style_lens, soap_binding_tag)

    operations = values_lens()
                 |> Focus.view(bindings)
                 |> Enum.filter(fn tag -> tag.name == "operation" end)
                 |> Enum.map(&extract_binding_operation/1)
    %Binding{name: binding_name, type: type, style: style, operations: operations}
  end

  defp extract_binding_operation(tag = %Tag{}) do
    action_lens = attributes_lens() ~> Lens.make_lens("soapAction")
    use_lens = values_lens() ~> Lens.idx(0) ~> attributes_lens() ~> Lens.make_lens("use")

    operation_tag = values_lens()
                  |> Focus.view(tag)
                  |> Enum.filter(fn tag -> tag.name == "soap:operation" end)
                  |> Enum.fetch!(0)
    input_tag = values_lens()
                |> Focus.view(tag)
                |> Enum.filter(fn tag -> tag.name == "input" end)
                |> Enum.fetch!(0)
    output_tag = values_lens()
                 |> Focus.view(tag)
                 |> Enum.filter(fn tag -> tag.name == "output" end)
                 |> Enum.fetch!(0)

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
end

