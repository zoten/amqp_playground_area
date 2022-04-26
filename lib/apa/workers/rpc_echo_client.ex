defmodule Apa.Workers.RpcEchoClient do
  @moduledoc """
  (modified) RPC Client for the rpc tutorial step

  https://www.rabbitmq.com/tutorials/tutorial-six-elixir.html

  Produces sentences, sends them as RPC
  """

  use GenServer

  alias __MODULE__

  require Logger

  @default_interval_ms 1_000
  @default_send_queue "rpc_queue"

  # Collapsed state for different kinds of producers
  defstruct name: nil,
            interval: @default_interval_ms,
            # state
            # keep the last correlation id
            correlation_id: nil,
            # amqp state
            user: "user",
            password: "password",
            connection: nil,
            channel: nil,
            queue: "",
            send_queue: @default_send_queue

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%{"name" => name} = config) do
    GenServer.start_link(__MODULE__, config, name: String.to_atom(name))
  end

  @spec init(any) :: {:ok, any}
  def init(config) do
    Logger.notice("Initializing RpcEchoClient")
    Logger.debug("config [#{inspect(config)}]")

    state = parse_config(config)

    Process.send_after(self(), :start, 200)

    {:ok, state}
  end

  def handle_info(:start, state) do
    {:ok, setup_state} = setup_amqp(state)
    {:ok, send_state} = produce_and_send_value(setup_state)
    # This time we delegate next_step to the answer's handling

    # {:ok, final_state} = next_step(send_state)
    # {:noreply, final_state}

    {:noreply, send_state}
  end

  def handle_info(:next, state) do
    {:ok, send_state} = produce_and_send_value(state)

    # This time we delegate next_step to the answer's handling
    # It's nice to see how correlation ID may disalign uncommenting this

    # {:ok, final_state} = next_step(send_state)
    # {:noreply, final_state}
    {:noreply, send_state}
  end

  # AMQP callbacks

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
    {:stop, :normal, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  # This time client also hears for messages on its own queue
  def handle_info(
        {:basic_deliver, payload, %{correlation_id: correlation_id}},
        %RpcEchoClient{} = state
      ) do
    # You might want to run payload consumption in separate Tasks in production
    consume_answer(payload, correlation_id, state)
    {:noreply, state}
  end

  def terminate(reason, %RpcEchoClient{connection: connection} = _state) do
    close_amqp_connection(connection)
    {:shutdown, reason}
  end

  # Privates

  defp consume_answer(payload, correlation_id, %RpcEchoClient{correlation_id: current_correlation_id} = state)
       when correlation_id == current_correlation_id do
    Logger.info("Got expected answer for correlation_id [#{correlation_id}] -> [#{payload}]")
    next_step(state)
  end

  defp consume_answer(payload, correlation_id, %RpcEchoClient{correlation_id: current_correlation_id} = state) do
    Logger.warning(
      "Got unexpected answer for correlation_id [#{correlation_id}] but was waiting for current_correlation_id [#{current_correlation_id}] -> [#{payload}]"
    )

    next_step(state)
  end

  defp produce_and_send_value(state) do
    {correlation_id, message, new_state} = produce_value(state)

    {:ok, send_state} = send_value(correlation_id, message, new_state)
    {:ok, send_state}
  end

  # Selects what to do after a value has been sent
  defp next_step(%RpcEchoClient{interval: interval} = state) do
    Process.send_after(self(), :next, interval)
    {:ok, state}
  end

  defp close_amqp_connection(nil), do: :ok
  defp close_amqp_connection(connection), do: AMQP.Connection.close(connection)

  # Setup of amqp connection
  defp setup_amqp(%RpcEchoClient{user: user, password: password} = state) do
    {:ok, connection} =
      AMQP.Connection.open(
        username: user,
        password: password
      )

    {:ok, channel} = AMQP.Channel.open(connection)

    {:ok, %{queue: queue_name}} =
      AMQP.Queue.declare(
        channel,
        "",
        exclusive: true
      )

    {:ok, _} = AMQP.Basic.consume(channel, queue_name, nil)

    {:ok,
     %RpcEchoClient{
       state
       | connection: connection,
         channel: channel,
         queue: queue_name
     }}
  end

  # Produce next value
  # returns {correlation_id, message, state}
  defp produce_value(%RpcEchoClient{} = state) do
    content = Apa.Generators.Words.get_random_words(Enum.random(1..10)) |> Enum.join(" ")

    correlation_id = generate_correlation_id()
    Logger.debug("New correlation id [#{correlation_id}]")

    {correlation_id, content, %RpcEchoClient{state | correlation_id: correlation_id}}
  end

  defp generate_correlation_id do
    :erlang.unique_integer()
    |> :erlang.integer_to_binary()
    |> Base.encode64()
  end

  defp send_value(
         correlation_id,
         message,
         %RpcEchoClient{queue: recv_queue, send_queue: send_queue, channel: channel} = state
       ) do
    # This time we publish on the exchange, and not on a specific queue
    # A queue is important when you need to share it between producers and consumers
    # but here we want to hear about all log messages
    AMQP.Basic.publish(channel, "", send_queue, message, reply_to: recv_queue, correlation_id: correlation_id)
    {:ok, state}
  end

  # config -> state
  defp parse_config(%{} = config) do
    %RpcEchoClient{
      name: Map.get(config, "name", nil)
    }
    |> parse_settings(config)
  end

  defp parse_settings(%RpcEchoClient{} = partial_producer, %{"settings" => settings} = _config) do
    %RpcEchoClient{
      partial_producer
      | interval: Map.get(settings, "interval", @default_interval_ms)
    }
  end
end
