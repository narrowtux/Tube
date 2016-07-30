defmodule Tube.FrameHandler do
  alias Tube.Websocket
  alias Tube.Frame.{PingFrame, PongFrame, CloseFrame, TextFrame, DataFrame, ContinuationFrame}
  alias Tube.Frame


  @moduledoc false

  def handle_frame(%CloseFrame{}, %Websocket{initiated_close: close_frame_sent?} = state) do
    if not close_frame_sent? do
      reply = %CloseFrame{
        status_code: 1000
      }

      GenServer.cast self, {:send, reply}
    end
    state
  end

  def handle_frame(%PingFrame{application_data: data}, state) do
    reply = %PongFrame{
      application_data: data
    }

    GenServer.cast self, {:send, reply}
    state
  end

  def handle_frame(_other, state) do
    state
  end

end
