defprotocol Soap.Client.Protocol do
  alias Soap.Client.Request
  alias Soap.Client.Response

  @moduledoc """
  Module containing protocol for sending out SOAP requests
  in an extensible way.
  """

  @type t :: struct()

  @doc """
  Sends out a synchronous SOAP request based on the struct passed in.
  """
  @spec soap_send(t(), Request.t()) :: Response.t()
  def soap_send(client, request)
end
