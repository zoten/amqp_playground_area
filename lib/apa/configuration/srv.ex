defmodule Apa.Configuration.Srv do
  @moduledoc """
  Serializer for configuration actions
  """

  use GenServer

  alias Apa.Configuration.Config
  alias Apa.Configuration.Reader

  require Logger

  @ets_name :oam
  @config_key :configuration

  # Public API
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Get whole configuration

  This call does not pass through genserver, since local ets maintains serialization
  """
  @spec get_config :: map
  def get_config do
    case :ets.lookup(@ets_name, @config_key) do
      [] -> %{}
      [{@config_key, config}] -> config
    end
  end

  ## GenServer

  # GenServer callbacks
  @impl GenServer
  def init(state) do
    Logger.notice("Initializing OAM configuration handler")

    [{supervisor_pid, _}] = Registry.lookup(ApaRegistry, Apa.TablesOwner)

    :ets.new(@ets_name, [:set, :public, :named_table])
    :ets.give_away(@ets_name, supervisor_pid, [])

    {:ok, config} = Reader.read()
    {:ok, parsed_config} = Config.parse(config)

    do_set_config(parsed_config)

    {:ok, state}
  end

  # Privates

  defp do_set_config(value) do
    :ets.insert(@ets_name, {@config_key, value})

    :ok = apply_config(value)

    :ok
  end

  defp apply_config(_config), do: :ok
end
