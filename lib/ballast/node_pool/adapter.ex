defmodule Ballast.NodePool.Adapters do
  @moduledoc """
  `NodePool` adapter for getting node pool metadata.
  """

  @doc """
  Returns the cloud provider specific unique ID for the node pool
  """
  @callback id(Ballast.NodePool.t()) :: binary

  @doc """
  Populates a `NodePool` with the current instance count and the cloud providers HTTP response (`data` field).
  """
  @callback get(Ballast.NodePool.t(), Tesla.Client.t()) :: {:ok, Ballast.NodePool.t()} | {:error, Tesla.Env.t()}

  @doc """
  Scale the minimum count.
  """
  @callback scale(Ballast.PoolPolicy.Changeset.t(), Tesla.Client.t()) :: {:ok, map} | {:error, Tesla.Env.t()}

  @doc """
  Determine if autoscaling is enabled on the pool.
  """
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
