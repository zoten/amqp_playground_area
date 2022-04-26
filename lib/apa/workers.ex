defmodule Apa.Workers do
  @moduledoc """
  Commodity module to route between different workers types
  (collapsing consumers and producers for brevity)
  """

  @consumer_type_logger "logger"
  @consumer_type_integer_printer "integer_printer"
  @consumer_type_time_consumer "time_consumer"
  @consumer_type_routing_logger "routing_logger"
  @consumer_type_topics_logger "topics_logger"

  @producer_type_incremental_integer "incremental_integer"
  @producer_type_random_time_seq "random_time_seq"
  @producer_type_logger "logger"
  @producer_type_routing_logger "routing_logger"
  @producer_type_random_animal "random_animal"

  @spec get_consumer_module(map) ::
          Apa.Workers.IntegerPrinterConsumer
          | Apa.Workers.LoggerConsumer
          | Apa.Workers.RoutingLoggerConsumer
          | Apa.Workers.TimeConsumer
  def get_consumer_module(%{"type" => @consumer_type_logger}), do: Apa.Workers.LoggerConsumer
  def get_consumer_module(%{"type" => @consumer_type_routing_logger}), do: Apa.Workers.RoutingLoggerConsumer
  def get_consumer_module(%{"type" => @consumer_type_integer_printer}), do: Apa.Workers.IntegerPrinterConsumer
  def get_consumer_module(%{"type" => @consumer_type_time_consumer}), do: Apa.Workers.TimeConsumer
  def get_consumer_module(%{"type" => @consumer_type_topics_logger}), do: Apa.Workers.TopicsLoggerConsumer
  def get_consumer_module(config), do: raise("Unsupported consumer config [#{inspect(config)}]")

  @spec get_producer_module(map) ::
          Apa.Workers.IncrementalIntegerProducer
          | Apa.Workers.LogsProducer
          | Apa.Workers.RandomTimeSeqProducer
          | Apa.Workers.RoutingLogsProducer
  def get_producer_module(%{"type" => @producer_type_logger}), do: Apa.Workers.LogsProducer
  def get_producer_module(%{"type" => @producer_type_routing_logger}), do: Apa.Workers.RoutingLogsProducer
  def get_producer_module(%{"type" => @producer_type_random_time_seq}), do: Apa.Workers.RandomTimeSeqProducer
  def get_producer_module(%{"type" => @producer_type_incremental_integer}), do: Apa.Workers.IncrementalIntegerProducer
  def get_producer_module(%{"type" => @producer_type_random_animal}), do: Apa.Workers.TopicAnimalProducer
  def get_producer_module(config), do: raise("Unsupported producer config [#{inspect(config)}]")
end
