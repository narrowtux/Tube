defmodule WsClient.Http.Request do
  defstruct [uri: nil, headers: [], body: "", method: "GET"]

  def to_string(%__MODULE__{} = request) do
    header_fields = request.headers
    |> Enum.map(fn
    {key, value} when is_binary(key) ->
      "#{key |> String.capitalize}: #{value}"
    {key, value} when is_atom(key) ->
      "#{key |> Atom.to_string |> String.capitalize}: #{value}"
    end)
    |> Enum.reduce(&(&2 <> "\r\n" <> &1))

    method = "#{request.method |> String.upcase} #{request.uri |> URI.to_string} HTTP/1.1"

    ~s[#{method}\r
#{header_fields}\r
\r
]
  end
end
