defmodule Apa.Workers.RpcEchoServer do
  @moduledoc """
  RPC Server that waits a random time and echoes back given value
  """

  use GenServer
  use AMQP

  alias __MODULE__

  require Logger

  @default_interval_ms 1_000
  @default_min_ms 1
  @default_max_ms 5_000
  @default_queue "rpc_queue"

  defstruct name: nil,
            interval: @default_interval_ms,
            min: @default_min_ms,
            max: @default_max_ms,
            # AMQP state
            user: "user",
            password: "password",
            connection: nil,
            channel: nil,
            queue: @default_queue

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%{"name" => name} = config) do
    GenServer.start_link(__MODULE__, config, name: String.to_atom(name))
  end

  @spec init(any) :: {:ok, any}
  def init(config) do
    Logger.notice("Initializing RpcEchoServer")
    Logger.debug("config [#{inspect(config)}]")

    state = parse_config(config)
    {:ok, initial_state} = setup_amqp(state)

    {:ok, initial_state}
  end

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

  def handle_info(
        {:basic_deliver, payload,
         %{reply_to: reply_to, correlation_id: correlation_id, delivery_tag: tag, redelivered: redelivered}},
        state
      ) do
    # You might want to run payload consumption in separate Tasks in production
    consume(state, tag, redelivered, payload, reply_to, correlation_id)
    {:noreply, state}
  end

  # Privates

  # Setup of amqp connection
  defp setup_amqp(%RpcEchoServer{queue: queue, user: user, password: password} = state) do
    {:ok, connection} =
      AMQP.Connection.open(
        username: user,
        password: password
      )

    {:ok, channel} = AMQP.Channel.open(connection)

    Logger.info("Declaring queue [#{queue}]")
    AMQP.Queue.declare(channel, queue)

    # We might want to run more than one server process.
    # In order to spread the load equally over multiple servers we need
    # to set the prefetch_count setting.
    AMQP.Basic.qos(channel, prefetch_count: 1)

    # Register the GenServer process as a consumer
    {:ok, _consumer_tag} = Basic.consume(channel, queue)

    {:ok,
     %RpcEchoServer{
       state
       | connection: connection,
         channel: channel
     }}
  end

  # config -> state
  defp parse_config(%{} = config) do
    %RpcEchoServer{
      name: Map.get(config, "name", nil)
    }
    |> parse_settings(config)
  end

  defp parse_settings(%RpcEchoServer{} = partial_producer, %{"settings" => settings} = _config) do
    %RpcEchoServer{
      partial_producer
      | interval: Map.get(settings, "interval", @default_interval_ms),
        min: Map.get(settings, "min", @default_min_ms),
        max: Map.get(settings, "max", @default_max_ms)
    }
  end

  defp consume(
         %RpcEchoServer{name: name, channel: channel, min: min, max: max} = _state,
         tag,
         _redelivered,
         payload,
         reply_to,
         correlation_id
       ) do
    sleep = Enum.random(min..max)
    Logger.info("Consumer [#{name}] gonna sleep [#{sleep}]ms before answering")
    :timer.sleep(sleep)

    AMQP.Basic.publish(
      channel,
      "",
      reply_to,
      "#{payload}",
      correlation_id: correlation_id
    )

    Logger.info(
      "Consumer [#{name}] consumed message [#{payload}] -> [#{inspect(reply_to)}] correlation_id [#{correlation_id}]"
    )

    Basic.ack(channel, tag)
  end
end
