defmodule Soap.Operation do

  @type t :: %__MODULE__{
    name: String.t(),
    input_msg: String.t(),
    output_msg: String.t(),
  }

  defstruct [:name, :input_msg, :output_msg]
end

