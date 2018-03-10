defmodule Soap.Message do

  @type t :: %__MODULE__{
    name: String.t(),
    part_name: String.t(),
    element: String.t(),  # NOTE: also referred to as "type" sometimes?
  }

  defstruct [:name, :part_name, :element]
end

