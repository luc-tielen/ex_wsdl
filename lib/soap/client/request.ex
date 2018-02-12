defmodule Soap.Client.Request do
  @moduledoc """
  Module containing struct describing a SOAP request.
  """

  @typedoc """
  Type describing the SOAP request.
  :wsdl contains a URI to WSDL location (local or remote).
  :data contains the actual data to be sent out.
  """
  @type t :: %__MODULE__{wsdl: String.t, data: struct()}

  @enforce_keys [:wsdl, :data]
  defstruct [:wsdl, :data]  # TODO properties
end
