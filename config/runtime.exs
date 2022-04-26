import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.

config :apa,
  configuration_path:
    System.get_env(
      "CONFIGURATION_PATH",
      Application.get_env(:apa, :default_configuration_path)
    )
