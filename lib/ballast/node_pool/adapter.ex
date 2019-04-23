defmodule Ballast.NodePool.Adapters do
  @moduledoc """
  `NodePool` adapter for getting node pool metadata.
  """

  @callback get(Tesla.Client.t(), Ballast.NodePool.t()) :: {:ok, map} | {:error, Tesla.Env.t()}
  @callback list(Tesla.Client.t(), Ballast.NodePool.t()) :: {:ok, list(map)} | {:error, Tesla.Env.t()}
  @callback size(Tesla.Client.t(), Ballast.NodePool.t()) :: {:ok, integer} | {:error, Tesla.Env.t()} | {:error, atom}
end
