defmodule Soap.Operation do

  @type t :: %__MODULE__{
    input_msg: String.t(),
    output_msg: String.t(),
  }

  defstruct [:input_msg, :output_msg]
end
