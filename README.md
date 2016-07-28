# Tube

Pure-Elixir WebSocket client

 * Runs on a supervisable GenServer
 * Tested with autobahn

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `tube` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:tube, "~> 0.1.0"}]
    end
    ```

  2. Ensure `tube` is started before your application:

    ```elixir
    def application do
      [applications: [:tube]]
    end
    ```
