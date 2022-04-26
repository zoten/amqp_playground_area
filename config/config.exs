# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :apa, default_configuration_path: "configuration.yaml"

config :logger, :console,
  level: :info,
  format: "$time $metadata[$level] $message\n",
  metadata: [:pid, :file, :line]

import_config "#{config_env()}.exs"
