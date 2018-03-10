defmodule Soap.Type do

  @type t :: %__MODULE__{
    name: String.t(),
    data: %{},
  }

  defstruct [:name, :data]
end

