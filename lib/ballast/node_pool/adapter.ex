defmodule Ballast.NodePool.Adapters do
  @moduledoc """
  `NodePool` adapter for getting node pool metadata.
  """

  @callback id(Ballast.NodePool.t()) :: binary
  @callback scale(Ballast.PoolPolicy.Changeset.t(), Tesla.Client.t()) :: {:ok, map} | {:error, Tesla.Env.t()}
  @callback get(Ballast.NodePool.t(), Tesla.Client.t()) :: {:ok, Ballast.NodePool.t()} | {:error, Tesla.Env.t()}
  @callback size(Ballast.NodePool.t(), Tesla.Client.t()) :: {:ok, integer} | {:error, Tesla.Env.t()} | {:error, atom}
  @callback autoscaling_enabled?(Ballast.NodePool.t()) :: boolean()

  @doc """
  The label selector to find all nodes of a specific cloud provider pool via the Kubernetes API
  """
  @callback label_selector() :: binary

  @doc """
  The label selector to nodes of a specific cloud provider pool via the Kubernetes API
  """
  @callback label_selector(Ballast.NodePool.t()) :: binary
end
