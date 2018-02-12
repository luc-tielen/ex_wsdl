defmodule Soap.Client.Response do
  @moduledoc """
  Module containing struct describing a SOAP response.
  """

  @typedoc """
  Type describing a SOAP response.
  :data contains the actual response.
  """
  @type t :: %__MODULE__{data: struct()}

  @enforce_keys [:data]
  defstruct [:data]  # TODO properties
end
