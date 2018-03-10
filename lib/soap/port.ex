defmodule Soap.Port do
  alias Soap.Operation

  @type t :: %__MODULE__{
    name: String.t(),
    operations: [%Operation{}]
  }

  defstruct [:name, :operations]
end

