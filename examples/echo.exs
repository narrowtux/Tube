alias Tube.Websocket
alias Tube.Frame.{PingFrame, PongFrame, CloseFrame, TextFrame, DataFrame}

{:ok, pid} = GenServer.start_link(Websocket, uri: "ws://localhost:4001/ws", opts: [parent: self])

GenServer.call(pid, :connect)

receive do
  {:websocket, :open} ->
    GenServer.cast(pid, {:send, %TextFrame{text: "Hello World"}})
  _ -> IO.puts("???")
end

receive do
  {:websocket, :frame, frame} ->
    IO.inspect frame
    Websocket.close pid
  _ ->
    IO.puts("???")
end

receive do {:websocket, :frame, %CloseFrame{}} -> end

receive do
  {:websocket, :closed} ->
    IO.puts("Closed")
  _ -> IO.puts "???"
end
