alias Tube.Frame

defmodule Tube.Frame.ControlFrame do
  @moduledoc false
  @callback parse(payload :: bitstring) :: map
  @callback to_frame(frame_type :: map) :: %Frame{}
  @callback opcode() :: integer
end

defmodule Tube.Frame.ApplicationFrame do
  @moduledoc false
  @callback parse(payload :: bitstring) :: map
  @callback to_frame(frame_type :: map) :: %Frame{}
  @callback opcode() :: integer
  @callback merge(frame :: map, continued :: map) :: map
  @callback validate(frame :: map) :: :ok | {:error, reason :: string}
end

defmodule Tube.Frame.ContinuationFrame do
  @behaviour Tube.Frame.ControlFrame

  @moduledoc """
  Represents a continuation frame.

  Continuation frames contain a `payload`.
  """

  defstruct data: ""

  def opcode, do: 0x0

  def parse(data), do: {:ok, %__MODULE__{data: data}}

  def to_frame(%__MODULE__{data: data}) do
    %Frame{
      opcode: opcode,
      payload: data,
      fin: true
    }
  end
end

defmodule Tube.Frame.PingFrame do
  @behaviour Tube.Frame.ControlFrame

  @moduledoc """
  Represents a ping frame

  Ping frames can contain a `payload` whose interpretation is up to the
  application
  """

  defstruct [application_data: ""]

  def opcode, do: 0x9

  def parse(payload) do
    {:ok, %__MODULE__{application_data: payload}}
  end

  def to_frame(%__MODULE__{} = ping_frame) do
    %Frame{
      fin: true,
      opcode: opcode,
      payload: ping_frame.application_data
    }
  end
end

defmodule Tube.Frame.PongFrame do
  @behaviour Tube.Frame.ControlFrame

  @moduledoc """
  Represents a pong frame

  Pong frames can contain a `payload` whose interpretation is up to the
  application
  """

  defstruct [application_data: ""]

  def opcode, do: 0xA

  def parse(payload) do
    {:ok, %__MODULE__{application_data: payload}}
  end

  def to_frame(%__MODULE__{} = pong_frame) do
    %Frame{
      fin: true,
      opcode: opcode,
      payload: pong_frame.application_data
    }
  end
end

defmodule Tube.Frame.CloseFrame do
  @behaviour Tube.Frame.ControlFrame

  @moduledoc """
  Represents a close frame

  Close frames can contain a `status_code` (integer) and a `reason` (string).
  """

  defstruct [status_code: 1000, reason: ""]

  def opcode, do: 0x8

  def parse("") do
    {:ok, %__MODULE__{}}
  end

  def parse(<<status_code::integer-size(16), reason::binary>>) do
    case String.printable?(reason) do
      true ->
        {:ok, %__MODULE__{
          status_code: status_code,
          reason: reason
        }}
      false ->
        {:error, "Invalid UTF8"}
    end

  end

  def parse(_), do: {:error, "Invalid payload"}

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

defmodule Tube.Frame.TextFrame do
  @behaviour Tube.Frame.ApplicationFrame

  @moduledoc """
  Represents a text frame

  Ping frames contain a `text` which is a string
  """

  defstruct text: ""

  def opcode, do: 0x1

  def parse(text), do: {:ok, %__MODULE__{text: text}}

  def to_frame(%__MODULE__{text: text}) do
    %Frame{
      opcode: opcode,
      payload: text,
      fin: true
    }
  end

  def merge(%__MODULE__{text: text}, %Tube.Frame.ContinuationFrame{data: append}) do
    %__MODULE__{
      text: text <> append
    }
  end

  def validate(%__MODULE__{text: text}) do
    case String.printable?(text) do
      true -> :ok
      false -> {:error, "invalid UTF8"}
    end
  end

end

defmodule Tube.Frame.DataFrame do
  @behaviour Tube.Frame.ApplicationFrame

  @moduledoc """
  Represents a data frame

  Ping frames contain `data` which is a binary
  """

  defstruct data: ""

  def opcode, do: 0x2

  def parse(data), do: {:ok, %__MODULE__{data: data}}

  def to_frame(%__MODULE__{data: data}) do
    %Frame{
      opcode: opcode,
      payload: data,
      fin: true
    }
  end

  def merge(%__MODULE__{data: data}, %Tube.Frame.ContinuationFrame{data: append}) do
    %__MODULE__{
      data: data <> append
    }
  end

  def validate(_), do: :ok
end
