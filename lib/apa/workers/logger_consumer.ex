defmodule Apa.Workers.LoggerConsumer do
  @moduledoc """
  Logger consumer. Takes json in the form
  %{
    "level": <string>,
    "message": <message>
  }

  and prints accordingly.

  This is just for avoiding setting up file loggers as the RabbitMQ's example
  in tutorial 2
  """

  use GenServer
  use AMQP

  alias __MODULE__

  require Logger

  @default_queue ""
  @default_exchange "logs"
  @default_level "info"

  @levels ["debug", "info", "warning"]

  defstruct name: nil,
            # settings
            level: @default_level,
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
    Logger.notice("Initializing LoggerConsumer")
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

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, state) do
    # You might want to run payload consumption in separate Tasks in production
    consume(state, tag, redelivered, payload)
    {:noreply, state}
  end

  # Privates

  # Setup of amqp connection
  defp setup_amqp(%LoggerConsumer{exchange: exchange, user: user, password: password} = state) do
    {:ok, connection} =
      AMQP.Connection.open(
        username: user,
        password: password
      )

    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Exchange.declare(channel, exchange, :fanout)
    {:ok, %{queue: queue_name}} = AMQP.Queue.declare(channel, "", exclusive: true)
    Logger.info("Temporary exclusive queue [#{queue_name}]")

    # We've already created a fanout exchange and a queue.
    # Now we need to tell the exchange to send messages to our queue.
    # That relationship between exchange and a queue is called a binding.
    # From now on the logs exchange will append messages to our queue.

    # A binding is a relationship between an exchange and a queue.
    # This can be simply read as: the queue is interested in messages
    # from this exchange.
    AMQP.Queue.bind(channel, queue_name, exchange)

    # Register the GenServer process as a consumer
    {:ok, _consumer_tag} = Basic.consume(channel, queue_name)

    {:ok,
     %LoggerConsumer{
       state
       | connection: connection,
         channel: channel,
         queue: queue_name
     }}
  end

  # config -> state
  defp parse_config(%{} = config) do
    %LoggerConsumer{
      name: Map.get(config, "name", nil)
    }
    |> parse_settings(config)
  end

  defp parse_settings(%LoggerConsumer{} = partial_producer, %{"settings" => settings} = _config) do
    %LoggerConsumer{
      partial_producer
      | level: Map.get(settings, "level", @default_level)
    }
  end

  defp consume(
         %LoggerConsumer{name: name, channel: channel, level: configured_level} = _state,
         tag,
         redelivered,
         payload
       ) do
    %{"level" => level, "message" => message} = Jason.decode!(payload)

    if has_to_be_logged?(level, configured_level) do
      updated_message = "[#{name}] #{message}"
      log(level, updated_message)
    end

    Basic.ack(channel, tag)
  rescue
    exception ->
      :ok = Basic.reject(channel, tag, requeue: not redelivered)
      Logger.warning("Error [#{inspect(exception)}] json-decoding [#{payload}]")
  end

  defp has_to_be_logged?(log_level, configured_level) do
    # high performance here
    Enum.find_index(@levels, fn level -> level == log_level end) >=
      Enum.find_index(@levels, fn level -> level == configured_level end)
  end

  defp log("debug", message), do: Logger.debug(message)
  defp log("info", message), do: Logger.info(message)
  defp log("warning", message), do: Logger.warning(message)
  defp log(level, message), do: Logger.error("[#{level}] #{message}")
end
