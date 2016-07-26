defmodule WsClient.Frame do
  use Bitwise
  defstruct [fin: true, opcode: 0, mask: false, len: 0, mask_key: "", payload: <<>>, control_frame?: false]

  def parse(binary) when is_binary(binary) when byte_size(binary) >= 2 do
     case binary do
       <<fin::size(1),
           0::integer-size(3), #RFU
           opcode::integer-size(4),
           mask::size(1),
           len::integer-size(7), rest::binary>> ->
         control_frame? = (opcode &&& 0b1000) > 0

         {len, rest} = case len do
           126 ->
             << _::size(16),
                len::integer-size(16),
                rest::binary>> = binary
              {len, rest}
            127 ->
              << _::size(16),
                 len::integer-size(64),
                 rest::binary>> = binary
               {len, rest}
             len -> {len, rest}
         end

         case (case mask do
           0 ->
             if byte_size(rest) >= len do
               <<payload::binary-size(len),
                    rest::binary>> = rest
               {:ok, "", payload, rest}
             else
               :error
             end
           1 ->
             if byte_size(rest) >= len + 4 do
               <<mask_key::binary-size(4),
                    payload::binary-size(len),
                    rest::binary>> = rest
               {:ok, mask_key, payload, rest}
             else
               :error
             end
         end) do
           {:ok, mask_key, payload, rest} ->
             payload = if mask == 1 do
               mask_payload(payload, mask_key)
             else
               payload
             end

             fin = fin == 1

             case {fin, control_frame?, len} do
               {false, true, _} -> {:error, :invalid_header}
               {_, true, len} when len >= 126 -> {:error, :invalid_header}
               {_, _, _} ->
                 {:ok, %__MODULE__{
                   fin: fin,
                   opcode: opcode,
                   control_frame?: control_frame?,
                   mask: mask,
                   len: len,
                   mask_key: mask_key,
                   payload: payload
                 }, rest}
             end
           :error ->
             {:error, :not_enough_payload} # this means that the next tcp frame will have more payload
         end
     _ ->
      IO.inspect(binary)
      {:error, :invalid_header} #this means that the payload is actually part of an older message
     end
  end

  def parse(_), do: {:error, :incomplete_header}

  def mask_payload(payload, mask_key) do
    <<a::integer-size(8), b::integer-size(8), c::integer-size(8), d::integer-size(8)>> = mask_key
     __mask_payload(payload, [a, b, c, d], 0, "")
  end

  defp __mask_payload("", _, _, masked), do: masked

  defp __mask_payload(<<first::integer-size(8), rest::binary>>, mask_key, i, masked) do
    mask = Enum.at(mask_key, rem(i, 4))
    first = bxor(first, mask)
    __mask_payload(rest, mask_key, i + 1, masked <> <<first::integer-size(8)>>)
  end

  def to_binary(%__MODULE__{} = struct) do
    struct = %{struct | mask: struct.mask_key != ""}

    len = case byte_size(struct.payload) do
      len when len >= 1 <<< 16 ->
        << 127::integer-size(7), len::integer-size(64) >>
      len when len >= 126 ->
        << 126::integer-size(7), len::integer-size(16) >>
      len ->
        << len::integer-size(7) >>
    end

    fin = if struct.fin, do: 1, else: 0
    mask = if struct.mask, do: 1, else: 0
    opcode = struct.opcode
    mask_key = struct.mask_key
    payload = struct.payload |> mask_payload(mask_key)

    len_size = bit_size(len)
    payload_size = byte_size(payload)
    mask_size = byte_size(mask_key)

    << fin::size(1),
       0::integer-size(3), #RFU
       opcode::integer-size(4),
       mask::size(1),
       len::binary-size(len_size)-unit(1),
       mask_key::binary-size(mask_size),
       payload::binary-size(payload_size) >>
  end

  def put_mask(%__MODULE__{} = struct) do
    mask = :crypto.strong_rand_bytes(4)
    %{struct |
      mask_key: mask,
      mask: 1
    }
  end
end
