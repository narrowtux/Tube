defmodule WsClient.Http.Response do
  defstruct [status: 0, status_text: "None", headers: %{}, body: "", http_version: "1.1"]

  def parse(binary) do
    parse_status_line(binary, %__MODULE__{})
  end

  defp parse_status_line(rest, struct) do
    [
      _matched,
      version,
      status_code,
      status_text,
      rest
      ] = Regex.run(~r/^HTTP\/(1.1|1.0) ([0-9]+) ([^\r]*)\r\n(.*)/sf, rest)
    status_code = String.to_integer(status_code)
    struct = Map.merge(struct, %__MODULE__{
      http_version: version,
      status: status_code,
      status_text: status_text
      })
    parse_header_line(rest, struct)
  end

  defp parse_header_line(<<"\r\n"::utf8,
                          rest::binary>>, struct) do
     parse_body(rest, struct)
  end

  defp parse_header_line(rest, struct) do
    [
      _matched,
      key,
      value,
      rest
    ] = Regex.run(~r/^([a-zA-Z0-9\-]+): ([^\r]*)\r\n(.*)/sf, rest)
    key = String.downcase(key)
    struct = Map.update(struct, :headers, %{}, fn
      [] -> %{key => value} # match empty list because elixir converts %{} to []
      map -> Map.put(map, key, value)
    end)
    parse_header_line(rest, struct)
  end

  defp parse_body(body, struct) do
    if Map.has_key?(struct, "content-length") do
      {Map.put(struct, :body, body), ""}
    else
      # this is actually the first message (still in the same tcp frame)
      {struct, body}
    end
  end
end
