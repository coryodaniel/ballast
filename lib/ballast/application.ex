defmodule Ballast.Application do
  @moduledoc false

  use Application

  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    children = [
      {Ballast.PoolPolicy.CooldownCache, []}
    ]

    Ballast.Logger.attach()

    opts = [strategy: :one_for_one, name: Ballast.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
