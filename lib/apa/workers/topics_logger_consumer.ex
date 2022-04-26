defmodule Apa.Workers.TopicsLoggerConsumer do
  @moduledoc """
  (modified) Logs consumer for the topics tutorial step

  https://www.rabbitmq.com/tutorials/tutorial-five-elixir.html

  Subscribes only to the topics configured in .settings.topics array
  Logs accordingly (at info level)
  """

  use GenServer
  use AMQP

  alias __MODULE__

  require Logger

  @default_queue ""
  @default_exchange "topic_logs"
  @default_topics ["#"]

  defstruct name: nil,
            # settings
            topics: @default_topics,
            # AMQP state
            user: "user",
            password: "password",
            connection: nil,
            exchange: @default_exchange,
            channel: nil,
            queue: @default_queue

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%{"name" => name} = config) do
    GenServer.start_link(__MODULE__, config, name: String.to_atom(name))
  end

  @spec init(any) :: {:ok, any}
  def init(config) do
    Logger.notice("Initializing TopicsLoggerConsumer")
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

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered} = meta}, state) do
    # You might want to run payload consumption in separate Tasks in production

    # Let's consume using routing key to decide how to log the message
    consume(state, tag, redelivered, payload, meta.routing_key)
    {:noreply, state}
  end

  # Privates

  # Setup of amqp connection
  defp setup_amqp(%TopicsLoggerConsumer{topics: topics, exchange: exchange, user: user, password: password} = state) do
    {:ok, connection} =
      AMQP.Connection.open(
        username: user,
        password: password
      )

    {:ok, channel} = AMQP.Channel.open(connection)

    # this time we use a `direct` exchange
    AMQP.Exchange.declare(channel, exchange, :topic)

    {:ok, %{queue: queue_name}} = AMQP.Queue.declare(channel, "", exclusive: true)
    Logger.info("Temporary exclusive queue [#{queue_name}]")

    # Let's bind to all severities we are interested in
    Logger.info("Subscribing to topics [#{inspect(topics)}]")

    for topic <- topics do
      # You see here the explicit routing key indicator
      Logger.debug("Subscribing to topic [#{topic}]")
      :ok = AMQP.Queue.bind(channel, queue_name, exchange, routing_key: topic)
    end

    # Register the GenServer process as a consumer
    {:ok, _consumer_tag} = Basic.consume(channel, queue_name, nil)

    {:ok,
     %TopicsLoggerConsumer{
       state
       | connection: connection,
         channel: channel,
         queue: queue_name
     }}
  end

  # config -> state
  defp parse_config(%{} = config) do
    %TopicsLoggerConsumer{
      name: Map.get(config, "name", nil)
    }
    |> parse_settings(config)
  end

  defp parse_settings(%TopicsLoggerConsumer{} = partial_producer, %{"settings" => settings} = _config) do
    %TopicsLoggerConsumer{
      partial_producer
      | topics: Map.get(settings, "topics", @default_topics)
    }
  end

  # routing_key has exactly the log level name in this example
  defp consume(
         %TopicsLoggerConsumer{name: name, channel: channel} = _state,
         tag,
         redelivered,
         payload,
         routing_key
       ) do
    updated_message = "[#{name}] #{payload}, because I'm really interested in [#{routing_key}]"
    Logger.info(updated_message)

    Basic.ack(channel, tag)
  rescue
    exception ->
      :ok = Basic.reject(channel, tag, requeue: not redelivered)
      Logger.warning("Error [#{inspect(exception)}] json-decoding [#{payload}]")
  end
end
