defmodule Soap.BindingOperation do

  @type t :: %__MODULE__{
    name: String.t(),
    action: String.t(),
    input_use: String.t(),
    output_use: String.t(),
  }

  defstruct [:name, :action, :input_use, :output_use]
end

