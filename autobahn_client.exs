alias WsClient.Websocket
alias WsClient.Frame.{PingFrame, PongFrame, CloseFrame, TextFrame, DataFrame}

defmodule AutobahnTest do
  use GenServer

  def init(args) do
    {:ok, pid} = GenServer.start_link(Websocket, uri: get_url_for_test(1), opts: [parent: self])
    GenServer.call(pid, :connect)
    {:ok, %{websocket: pid, i: 1}}
  end

  def get_url_for_test(test) do
    "ws://localhost:9001/runCase?case=#{test}&agent=Elixir"
  end

  def handle_info({:websocket, :open}, %{i: i} = state) do
    IO.puts "+ WS connection open (#{i})"

    {:noreply, %{state | i: i + 1}}
  end

  def handle_info({:websocket, :frame, %{__struct__: type} = frame}, %{websocket: pid} = state) when type in [TextFrame, DataFrame] do
    IO.puts "  #{inspect frame.__struct__}"
    GenServer.cast(pid, {:send, frame})

    {:noreply, state}
  end


  def handle_info({:websocket, :frame, frame}, state) do
    IO.puts "  #{inspect frame}"
    {:noreply, state}
  end

  def handle_info({:websocket, :closed}, %{i: i, websocket: pid} = state) do
    IO.puts "- Closed"

    if i <= 519 do
      GenServer.call(pid, {:set_uri, get_url_for_test(i)})
      GenServer.call(pid, :connect)
    end

    {:noreply, state}
  end

  def handle_info(_, state) do
    IO.puts "???"

    {:noreply, state}
  end


end

{:ok, pid} = GenServer.start_link(AutobahnTest, nil)
