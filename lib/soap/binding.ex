defmodule Soap.Binding do
  alias Soap.BindingOperation

  @type t :: %__MODULE__{
    name: String.t(),
    type: String.t(),
    style: String.t(),
    operations: [%BindingOperation{}]
  }

  defstruct [:name, :type, :style, :operations]
end

