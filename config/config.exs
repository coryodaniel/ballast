# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :logger, level: :info

config :bonny,
  reconcile_every: 30 * 1000,
  reconcile_batch_size: 10,
  watch_timeout: 60 * 1000,
  controllers: [Ballast.Controller.V1.PoolPolicy]

import_config "#{Mix.env()}.exs"
