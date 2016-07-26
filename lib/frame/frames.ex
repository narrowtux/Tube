alias WsClient.Frame

defmodule WsClient.Frame.FrameType do
   @callback parse(payload :: bitstring) :: map
   @callback to_frame(frame_type :: map) :: %Frame{}
   @callback opcode() :: integer
end

defmodule WsClient.Frame.PingFrame do
  @behaviour WsClient.Frame.FrameType

  defstruct [application_data: ""]

  def opcode, do: 0x9

  def parse(payload) do
    %__MODULE__{application_data: payload}
  end

  def to_frame(%__MODULE__{} = ping_frame) do
    %Frame{
      fin: true,
      opcode: opcode,
      payload: ping_frame.application_data
    }
  end
end

defmodule WsClient.Frame.PongFrame do
  @behaviour WsClient.Frame.FrameType

  defstruct [application_data: ""]

  def opcode, do: 0xA

  def parse(payload) do
    %__MODULE__{application_data: payload}
  end

  def to_frame(%__MODULE__{} = pong_frame) do
    %Frame{
      fin: true,
      opcode: opcode,
      payload: pong_frame.application_data
    }
  end
end

defmodule WsClient.Frame.CloseFrame do
  @behaviour WsClient.Frame.FrameType

  defstruct [status_code: 1000, reason: ""]

  def opcode, do: 0x8

  def parse("") do
    %__MODULE__{}
  end

  def parse(<<status_code::integer-size(16), reason::binary>>) do
    %__MODULE__{
      status_code: status_code,
      reason: reason
    }
  end

  def to_frame(%__MODULE__{} = close_frame) do
    payload = <<close_frame.status_code::integer-size(16),
                close_frame.reason::binary>>
    %Frame{
      opcode: opcode,
      fin: true,
      payload: payload
    }
  end
end

defmodule WsClient.Frame.TextFrame do
  @behaviour WsClient.Frame.FrameType

  defstruct text: ""

  def opcode, do: 0x1

  def parse(text), do: %__MODULE__{text: text}

  def to_frame(%__MODULE__{text: text}) do
    %Frame{
      opcode: opcode,
      payload: text,
      fin: true
    }
  end
end

defmodule WsClient.Frame.DataFrame do
  @behaviour WsClient.Frame.FrameType

  defstruct data: ""

  def opcode, do: 0x2

  def parse(data), do: %__MODULE__{data: data}

  def to_frame(%__MODULE__{data: data}) do
    %Frame{
      opcode: opcode,
      payload: data,
      fin: true
    }
  end
end
