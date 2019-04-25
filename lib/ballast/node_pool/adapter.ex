defmodule Ballast.NodePool.Adapters do
  @moduledoc """
  `NodePool` adapter for getting node pool metadata.
  """

  @callback get(Ballast.NodePool.t(), Tesla.Client.t()) :: {:ok, map} | {:error, Tesla.Env.t()}
  @callback size(Ballast.NodePool.t(), Tesla.Client.t()) :: {:ok, integer} | {:error, Tesla.Env.t()} | {:error, atom}
end
