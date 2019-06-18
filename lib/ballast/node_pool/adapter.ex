defmodule Ballast.NodePool.Adapters do
  @moduledoc """
  `NodePool` adapter for getting node pool metadata.
  """

  @callback id(Ballast.NodePool.t()) :: binary
  @callback scale(Ballast.PoolPolicy.Changeset.t(), Tesla.Client.t()) :: {:ok, map} | {:error, Tesla.Env.t()}
  @callback get(Ballast.NodePool.t(), Tesla.Client.t()) :: {:ok, Ballast.NodePool.t()} | {:error, Tesla.Env.t()}
  @callback size(Ballast.NodePool.t(), Tesla.Client.t()) :: {:ok, integer} | {:error, Tesla.Env.t()} | {:error, atom}
  @callback autoscaling_enabled?(Ballast.NodePool.t()) :: boolean()
end
