defmodule Apa.Workers.TopicAnimalProducer do
  @moduledoc """
  (modified) Logs producer for the topic tutorial step

  https://www.rabbitmq.com/tutorials/tutorial-five-elixir.html

  Produces animal sentences, in hardcoded (random) topics
  """

  use GenServer

  alias __MODULE__

  require Logger

  @celerities ["slow", "quick", "lazy"]
  @colors ["brown", "orange", "yellow"]
  @animals ["fox", "rabbit", "bear"]

  @default_interval_ms 1_000
  @default_exchange "topic_logs"

  # Collapsed state for different kinds of producers
  defstruct name: nil,
            interval: @default_interval_ms,
            # incremental_integer state
            current_value: 0,
            # amqp state
            user: "user",
            password: "password",
            connection: nil,
            channel: nil,
            exchange: @default_exchange

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%{"name" => name} = config) do
    GenServer.start_link(__MODULE__, config, name: String.to_atom(name))
  end

  @spec init(any) :: {:ok, any}
  def init(config) do
    Logger.notice("Initializing TopicAnimalProducer")
    Logger.debug("config [#{inspect(config)}]")

    state = parse_config(config)

    Process.send_after(self(), :start, 200)

    {:ok, state}
  end

  def handle_info(:start, state) do
    {:ok, setup_state} = setup_amqp(state)
    {:ok, send_state} = produce_and_send_value(setup_state)
    {:ok, final_state} = next_step(send_state)

    {:noreply, final_state}
  end

  def handle_info(:next, state) do
    {:ok, send_state} = produce_and_send_value(state)
    {:ok, final_state} = next_step(send_state)

    {:noreply, final_state}
  end

  def terminate(reason, %TopicAnimalProducer{connection: connection} = _state) do
    close_amqp_connection(connection)
    {:shutdown, reason}
  end

  # Privates

  defp produce_and_send_value(state) do
    {topic, message, new_state} = produce_value(state)

    {:ok, send_state} = send_value(topic, message, new_state)
    {:ok, send_state}
  end

  # Selects what to do after a value has been sent
  defp next_step(%TopicAnimalProducer{interval: interval} = state) do
    Process.send_after(self(), :next, interval)
    {:ok, state}
  end

  defp close_amqp_connection(nil), do: :ok
  defp close_amqp_connection(connection), do: AMQP.Connection.close(connection)

  # Setup of amqp connection
  defp setup_amqp(%TopicAnimalProducer{user: user, password: password, exchange: exchange} = state) do
    {:ok, connection} =
      AMQP.Connection.open(
        username: user,
        password: password
      )

    {:ok, channel} = AMQP.Channel.open(connection)

    # This time we declare a topic exchange
    AMQP.Exchange.declare(channel, exchange, :topic)

    {:ok,
     %TopicAnimalProducer{
       state
       | connection: connection,
         channel: channel
     }}
  end

  # Produce next value
  # returns {topic, message, state}
  defp produce_value(%TopicAnimalProducer{current_value: current_value} = state) do
    new_value = current_value + 1
    log_content = Apa.Generators.Words.get_random_words(Enum.random(1..10)) |> Enum.join(" ")

    celerity = Enum.random(@celerities)
    color = Enum.random(@colors)
    animal = Enum.random(@animals)

    topic = "#{celerity}.#{color}.#{animal}"

    log_line = "A fact about [#{topic}]: #{log_content}"

    {topic, log_line, %TopicAnimalProducer{state | current_value: new_value}}
  end

  defp send_value(topic, message, %TopicAnimalProducer{channel: channel, exchange: exchange} = state) do
    # This time we publish on the exchange, and not on a specific queue
    # A queue is important when you need to share it between producers and consumers
    # but here we want to hear about all log messages
    AMQP.Basic.publish(channel, exchange, topic, message)
    {:ok, state}
  end

  # config -> state
  defp parse_config(%{} = config) do
    %TopicAnimalProducer{
      name: Map.get(config, "name", nil)
    }
    |> parse_settings(config)
  end

  defp parse_settings(%TopicAnimalProducer{} = partial_producer, %{"settings" => settings} = _config) do
    %TopicAnimalProducer{
      partial_producer
      | interval: Map.get(settings, "interval", @default_interval_ms)
    }
  end
end
