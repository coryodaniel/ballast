use Mix.Config

config :ballast, node_pool_adapter: Ballast.NodePool.Adapters.Mock

config :k8s,
  clusters: %{
    default: %{
      conf: "test/support/docker-for-desktop.yaml",
      conf_opts: [context: "docker-for-desktop"]
    }
  }
