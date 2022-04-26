defmodule Apa.Workers.RandomTimeSeqProducer do
  @moduledoc """
  Basic producer, used for the first
  """

  use GenServer

  alias __MODULE__

  require Logger

  @default_min_ms 1
  @default_max_ms 5_000
  @default_interval_ms 1_000
  @default_queue "default"

  # Collapsed state for different kinds of producers
  defstruct name: nil,
            interval: @default_interval_ms,
            # random_time_seq state
            current_seq: 0,
            min: @default_min_ms,
            max: @default_max_ms,
            # amqp state
            user: "user",
            password: "password",
            connection: nil,
            channel: nil,
            queue: @default_queue

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @spec init(any) :: {:ok, any}
  def init(config) do
    Logger.notice("Initializing RandomTimeSeqProducer")
    Logger.debug("config [#{inspect(config)}]")

    state = parse_config(config)

    Process.send_after(self(), :start, 200)

    {:ok, state}
  end

  def handle_info(:start, state) do
    {:ok, setup_state} = setup_amqp(state)
    {:ok, new_state} = produce_and_send_value(setup_state)

    {:noreply, new_state}
  end

  def handle_info(:next, state) do
    {:ok, new_state} = produce_and_send_value(state)

    {:noreply, new_state}
  end

  def terminate(reason, %RandomTimeSeqProducer{connection: connection} = _state) do
    close_amqp_connection(connection)
    {:shutdown, reason}
  end

  # Privates

  defp produce_and_send_value(state) do
    {new_value, new_state} = produce_value(state)

    {:ok, send_state} = send_value(new_value, new_state)
    {:ok, final_state} = next_step(send_state)
    {:ok, final_state}
  end

  # Selects what to do after a value has been sent
  defp next_step(%RandomTimeSeqProducer{interval: interval} = state) do
    Process.send_after(self(), :next, interval)
    {:ok, state}
  end

  defp next_step(%RandomTimeSeqProducer{} = state) do
    Logger.warning("Unhandled [next_step] state [#{inspect(state)}], going idle")
    {:ok, state}
  end

  defp close_amqp_connection(nil), do: :ok
  defp close_amqp_connection(connection), do: AMQP.Connection.close(connection)

  # Setup of amqp connection
  defp setup_amqp(%RandomTimeSeqProducer{queue: queue, user: user, password: password} = state) do
    {:ok, connection} =
      AMQP.Connection.open(
        username: user,
        password: password
      )

    {:ok, channel} = AMQP.Channel.open(connection)

    Logger.info("Declaring queue [#{queue}]")
    AMQP.Queue.declare(channel, queue)

    {:ok,
     %RandomTimeSeqProducer{
       state
       | connection: connection,
         channel: channel
     }}
  end

  # Produce next value
  defp produce_value(%RandomTimeSeqProducer{current_seq: current_seq, min: min, max: max} = state) do
    new_seq = current_seq + 1
    new_wait = Enum.random(min..max)
    new_value = Jason.encode!(%{seq: new_seq, sleep: new_wait})
    {new_value, %RandomTimeSeqProducer{state | current_seq: new_seq}}
  end

  defp send_value(value, %RandomTimeSeqProducer{queue: queue, channel: channel} = state) do
    AMQP.Basic.publish(channel, "", queue, value)
    {:ok, state}
  end

  # config -> state
  defp parse_config(%{} = config) do
    %RandomTimeSeqProducer{
      name: Map.get(config, "name", nil)
    }
    |> parse_settings(config)
  end

  defp parse_settings(%RandomTimeSeqProducer{} = partial_producer, %{"settings" => settings} = _config) do
    %RandomTimeSeqProducer{
      partial_producer
      | interval: Map.get(settings, "interval", @default_interval_ms),
        min: Map.get(settings, "min", @default_min_ms),
        max: Map.get(settings, "max", @default_max_ms)
    }
  end
end
