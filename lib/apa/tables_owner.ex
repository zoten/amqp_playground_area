defmodule Apa.TablesOwner do
  @moduledoc """
  Simple owner of ets tables, meant not to die and to maintain state
  """
  use GenServer

  require Logger

  @impl true
  @spec init(any()) :: {:ok, any()}
  def init(init_arg) do
    Registry.register(ApaRegistry, Apa.TablesOwner, %{})
    {:ok, init_arg}
  end

  @spec start_link(maybe_improper_list()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(args) when is_list(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def handle_info({:"ETS-TRANSFER", name, _pid, _data}, state) do
    Logger.debug("TablesOwner received ETS-TRANSFER message for [#{inspect(name)}]")
    {:noreply, state}
  end
end
