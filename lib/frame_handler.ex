defmodule WsClient.FrameHandler do
  alias WsClient.Websocket
  alias WsClient.Frame.{PingFrame, PongFrame, CloseFrame, TextFrame, DataFrame}
  alias WsClient.Frame

  def handle_frame(%CloseFrame{}, %Websocket{initiated_close: close_frame_sent?, socket: socket} = state) do
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
    |> PongFrame.to_frame

    GenServer.cast self, {:send, reply}
    state
  end

  def handle_frame(_other, state) do
    state
  end

end
