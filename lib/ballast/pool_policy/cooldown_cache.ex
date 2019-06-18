defmodule Ballast.PoolPolicy.CooldownCache do
  @moduledoc """
  Cooldown tracking for `Ballast.PoolPolicy`
  """

  use GenServer
  alias Ballast.PoolPolicy

  # Client

  @spec start_link(any()) :: {:error, any()} | {:ok, pid()}
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec ran(PoolPolicy.t()) :: :ok
  def ran(%PoolPolicy{name: name, cooldown_seconds: cooldown_seconds}) do
    GenServer.cast(__MODULE__, {:ran, name, cooldown_seconds})
  end

  @spec ready?(PoolPolicy.t()) :: :ok | {:error, :cooling_down}
  def ready?(%PoolPolicy{} = policy) do
    GenServer.call(__MODULE__, {:ready?, policy})
  end

  # Server

  @impl true
  @spec init(map) :: {:ok, map}
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:ready?, policy}, _from, state) do
    entry = Map.get(state, policy.name)
    is_ready = is_ready?(entry)

    {:reply, is_ready, state}
  end

  @impl true
  def handle_cast({:ran, name, cooldown_seconds}, state) do
    cooldown_ms = cooldown_seconds * 1000
    new_state = Map.put(state, name, now() + cooldown_ms)
    {:noreply, new_state}
  end

  @spec is_ready?(nil | pos_integer) :: :ok | {:error, :cooling_down}
  defp is_ready?(nil), do: :ok

  defp is_ready?(until) do
    case now() >= until do
      true ->
        :ok

      false ->
        {:error, :cooling_down}
    end
  end

  @spec now() :: pos_integer
  defp now do
    :os.system_time(:millisecond)
  end
end
