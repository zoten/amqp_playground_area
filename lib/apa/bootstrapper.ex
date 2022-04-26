defmodule Apa.Bootstrapper do
  @moduledoc """
  This is meant to be the last child of the main supervisor.
  Starts different kinds of workers, depending on configuration
  """
  use GenServer

  alias Apa.ApaSupervisor
  alias Apa.Configuration.Srv, as: ConfigSrv
  alias Apa.Configuration.Config

  require Logger

  # Client Functions
  def start_link(opts) do
    GenServer.start_link(Apa.Bootstrapper, Enum.into(opts, %{}), name: Apa.Bootstrapper)
  end

  # Server callbacks
  @impl true
  def init(init_arg) do
    Logger.info("Init Apa.Bootstrapper, args: [#{inspect(init_arg)}]")

    [{supervisor_pid, _}] = Registry.lookup(ApaRegistry, Apa.TablesOwner)

    try do
      :ets.new(__MODULE__, [:set, :public, :named_table])
      :ets.give_away(__MODULE__, supervisor_pid, [])
    rescue
      _ -> :ok
    end

    pid = self()

    case :ets.lookup(__MODULE__, :pid) do
      [] ->
        Logger.info("First boot, initializing")
        :ets.insert(__MODULE__, {:pid, pid})
        :ok = first_boot(init_arg)
        {:ok, %{}}

      [{:pid, ^pid}] ->
        Logger.info("Restarting with same pid, doing nothing")
        {:ok, %{}}

      [{:pid, other_pid}] ->
        Logger.info("Process has crashed from [#{inspect(other_pid)}] and is restarting, overwriting old pid")
        :ets.insert(__MODULE__, {:pid, pid})
        {:ok, %{}}
    end
  end

  # Bootstrapping function
  defp first_boot(_args) do
    # Get and apply config
    config = ConfigSrv.get_config()
    Logger.debug("Gonna apply config [#{inspect(config)}]")
    apply_config(config)
    :ok
  end

  def apply_config(%Config{} = config) do
    config
    |> Config.get_workers()
    |> Enum.reduce_while(
      :ok,
      fn worker_configuration, :ok ->
        case start_worker(worker_configuration) do
          :ok -> {:cont, :ok}
          err -> {:halt, err}
        end
      end
    )
  end

  defp start_worker(%{"role" => "producer"} = worker_configuration) do
    module = Apa.Workers.get_producer_module(worker_configuration)
    ApaSupervisor.start_worker(module, worker_configuration)
    :ok
  end

  defp start_worker(%{"role" => "consumer"} = worker_configuration) do
    module = Apa.Workers.get_consumer_module(worker_configuration)
    ApaSupervisor.start_worker(module, worker_configuration)
    :ok
  end

  defp start_worker(%{"role" => "rpc_server"} = worker_configuration) do
    module = Apa.Workers.get_rpc_server_module(worker_configuration)
    ApaSupervisor.start_worker(module, worker_configuration)
    :ok
  end

  defp start_worker(%{"role" => "rpc_client"} = worker_configuration) do
    module = Apa.Workers.get_rpc_client_module(worker_configuration)
    ApaSupervisor.start_worker(module, worker_configuration)
    :ok
  end

  defp start_worker(%{} = worker_configuration) do
    Logger.error("Failed to start unknown worker [#{inspect(worker_configuration)}]")
    {:error, :unknown_worker_type}
  end
end
