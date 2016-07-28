defmodule Tube.Frame do
  use Bitwise

  @moduledoc """
  Represents a full frame of the WebSocket protocol

  ## Struct

  ### `fin`
  Indicates that this is the final fragment in a message.  The first
  fragment MAY also be the final fragment.

  ### `opcode`
  Defines the interpretation of the "Payload data".  If an unknown
  opcode is received, the receiving endpoint MUST _Fail the
  WebSocket Connection_.  The following values are defined.
  *  0x0 denotes a continuation frame
  *  0x1 denotes a text frame
  *  0x2 denotes a binary frame
  *  0x3-7 are reserved for further non-control frames
  *  0x8 denotes a connection close
  *  0x9 denotes a ping
  *  0xA denotes a pong
  *  0xB-F are reserved for further control frames

  ### `mask` and `mask_key`
  If mask is true, the `mask_key` will be a 4 byte long key. This will be used
  to unmask the payload data from client to server.

  ### `len`
  Length of the payload

  ### `payload`
  Binary of the frame's application data

  ### `control_frame?`
  If true, this frame's opcode means that this is a control frame.

  Control frames can be interleaved into fragmented messages.
  """

  defstruct [fin: true, opcode: 0, mask: false, len: 0, mask_key: "", payload: <<>>, control_frame?: false]


  @doc """
  Parses the given `binary` into a `%Tube.Frame{}` struct.

  ## Example

  ```
  iex(1)> Tube.Frame.parse(<<129, 139, 71, 28, 66, 60, 15, 121, 46, 80, 40, 60, 21, 83, 53, 112, 38>>)
  {:ok,
   %Tube.Frame{control_frame?: false, fin: true, len: 11, mask: 1,
    mask_key: <<71, 28, 66, 60>>, opcode: 1, payload: "Hello World"}, ""}
  ```

  ## Returns
  When parsed with no issues, it will return

  `{:ok, %Tube.Frame{}, rest}`

  `rest` will contain superflous bytes that are not part of the frame and should
  be kept until more TCP chops arrive.

  If there was an error,

  `{:error, reson}`

  will be returned
  """
  @spec parse(binary) :: {:ok, struct(), binary} | {:error, term}
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

  @doc """
  Applies the mask to the given payload.

  This can be done to either mask or unmask the payload.
  """
  @spec mask_payload(binary, binary) :: binary
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

  @doc """
  Converts the #{__MODULE__} struct to a binary.

  If the given frame has a `mask_key`, it will apply this key.
  """
  @spec to_binary(struct()) :: binary
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

  @doc """
  Generates a random mask using `:crypto.strong_rand_bytes/1` and adds it to the
  given frame
  """
  @spec put_mask(struct()) :: struct()
  def put_mask(%__MODULE__{} = struct) do
    mask = :crypto.strong_rand_bytes(4)
    %{struct |
      mask_key: mask,
      mask: 1
    }
  end
end
