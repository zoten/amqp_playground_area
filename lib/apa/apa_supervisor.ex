defmodule Apa.ApaSupervisor do
  @doc """
  Dynamic supervisor for processes that may or may be not active
  """

  use DynamicSupervisor
  alias __MODULE__

  require Logger

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Starts a worker by module and configuration
  """
  @spec start_worker(module :: module, config :: any) :: :ok
  def start_worker(module, config) do
    Logger.debug("Gonna start [#{inspect(module)}] [#{inspect(config)}]")
    {:ok, child_info} = DynamicSupervisor.start_child(ApaSupervisor, {module, config})
    Logger.info("Started [#{inspect(module)}] child [#{inspect(child_info)}]")
    :ok
  end

  # DynamicSupervisor callbacks

  @impl true
  def init(_arg) do
    # :one_for_one strategy: if a child process crashes, only that process is restarted.
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
