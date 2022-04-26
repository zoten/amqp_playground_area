defmodule Apa.Workers.IntegerPrinterConsumer do
  @moduledoc """
  Basic consumer
  """

  use GenServer
  use AMQP

  alias __MODULE__

  require Logger

  @default_queue "default"

  defstruct name: nil,
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
    Logger.notice("Initializing Consumer")
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
  defp setup_amqp(%IntegerPrinterConsumer{queue: queue, user: user, password: password} = state) do
    {:ok, connection} =
      AMQP.Connection.open(
        username: user,
        password: password
      )

    {:ok, channel} = AMQP.Channel.open(connection)

    Logger.info("Declaring queue [#{queue}]")
    AMQP.Queue.declare(channel, queue)

    # Register the GenServer process as a consumer
    {:ok, _consumer_tag} = Basic.consume(channel, queue)

    {:ok,
     %IntegerPrinterConsumer{
       state
       | connection: connection,
         channel: channel
     }}
  end

  # config -> state
  defp parse_config(%{} = config) do
    %IntegerPrinterConsumer{
      name: Map.get(config, "name", nil)
    }
  end

  defp consume(
         %IntegerPrinterConsumer{name: name, channel: channel} = _state,
         tag,
         redelivered,
         payload
       ) do
    number = String.to_integer(payload)

    Logger.info("Consumer [#{name}] consumed number [#{number}]")
    Basic.ack(channel, tag)
  rescue
    # Requeue unless it's a redelivered message.
    # This means we will retry consuming a message once in case of exception
    # before we give up and have it moved to the error queue
    #
    # You might also want to catch :exit signal in production code.
    # Make sure you call ack, nack or reject otherwise consumer will stop
    # receiving messages.
    exception ->
      :ok = Basic.reject(channel, tag, requeue: not redelivered)
      Logger.warning("Error [#{inspect(exception)}] converting [#{payload}] to integer")
  end
end
