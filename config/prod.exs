use Mix.Config

config :k8s,
  clusters: %{
    # An empty config defaults to using pod.spec.serviceAccountName
    default: %{}
  }
