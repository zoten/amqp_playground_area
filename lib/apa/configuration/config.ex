defmodule Apa.Configuration.Config do
  @moduledoc """
  Wrapper for parsing/getting values from configuration

  Poor naming and no deeper introspection, at the moment, this is just an example
  for modules separation

  This module will contain also stuff that should go into submodules
  """

  alias __MODULE__

  # Version of the configuration dialect
  @version "0.1.0"

  # This should be some
  defstruct version: @version,
            workers: []

  @spec parse(nil | map) :: {:ok, %Apa.Configuration.Config{version: any, workers: any}}
  def parse(nil), do: {:ok, %Config{}}

  def parse(%{} = value) do
    # Validate etc
    {:ok,
     %Config{
       version: string_or_atom_key(value, :version, @version),
       workers: string_or_atom_key(value, :workers, [])
     }}
  end

  def get_workers(%Config{workers: workers} = _config), do: workers

  # Privates

  defp string_or_atom_key(%{} = value, key, default) do
    parsed_key = to_string(key)
    # unsafe etc
    atom_key = String.to_atom(parsed_key)

    case Map.get(value, parsed_key, :undefined) do
      :undefined ->
        case Map.get(value, atom_key, :undefined) do
          :undefined -> default
          value -> value
        end

      value ->
        value
    end
  end
end
