defmodule Apa.Configuration.Reader do
  @moduledoc """
  Configuration parser
  """

  require Logger

  @doc """
  Read configuration and return parsed map
  """
  @spec read :: {:ok, any} | {:error, any}
  def read do
    path = Application.get_env(:apa, :configuration_path)

    case read(path) do
      {:ok, content} ->
        Logger.debug("Configuration [#{inspect(content)}]")
        {:ok, content}

      err ->
        raise "Error reading configuration [#{inspect(err)}]"
    end
  end

  # Read, parse, whatever :)
  # (Edge cases not covered, this is an example)
  defp read(path) do
    Logger.debug("Reading configuration from [#{path}]")

    case YamlElixir.read_all_from_file(path) do
      {:ok, result} when is_list(result) ->
        {:ok, result |> List.first() |> parse()}

      {:ok, something_else} ->
        {:error, {:unexpected_parsed_configuration, something_else}}

      other ->
        other
    end
  end

  defp parse(nil), do: %{}
  defp parse(value) when is_map(value), do: value
end
