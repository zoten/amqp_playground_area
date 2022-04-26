defmodule Apa.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: ApaRegistry},
      Apa.TablesOwner,
      Apa.Configuration.Srv,
      Apa.ApaSupervisor,
      Apa.Bootstrapper
      # Starts a worker by calling: Apa.Worker.start_link(arg)
      # {Apa.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Apa.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
