defmodule Soap.Service do

  @type t :: %__MODULE__{
    name: String.t(),
    documentation: String.t(),
    port_name: String.t(),
    binding_name: String.t(),
    location: String.t() | nil,
  }

  defstruct [
    :name,
    :documentation,
    :port_name,
    :binding_name,
    :location,
  ]
end
