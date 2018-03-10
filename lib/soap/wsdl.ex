defmodule Soap.WSDL do
  alias Soap.Type
  alias Soap.Message
  alias Soap.Port
  alias Soap.Binding
  alias Soap.Service

  @moduledoc """
  Module containing struct representing a WSDL file.
  """

  @type t :: %__MODULE__{
    types: [%Type{}],
    messages: [%Message{}],
    ports: [%Port{}],
    bindings: [%Binding{}],
    locations: [%Service{}],
  }

  defstruct [:types, :messages, :ports, :bindings, :locations]
end
