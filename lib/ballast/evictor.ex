defmodule Ballast.Evictor do
  @moduledoc """
  Finds pods that are candidates for eviction.
  """

  @pod_batch_size 500
  @default_max_lifetime 600

  alias K8s.{Client, Operation, Selector}
  alias Ballast.Sys.Instrumentation, as: Inst

  @doc """
  Gets all pods with eviction enabled.
  """
  @spec candidates(map()) :: {:ok, list(map)} | {:error, HTTPoison.Response.t()}
  def candidates(%{} = policy) do
    op = Client.list("v1", :pods, namespace: :all)
    selector = Selector.parse(policy)
    op_w_selector = %Operation{op | label_selector: selector}
    params = %{limit: @pod_batch_size}

    {duration, response} = :timer.tc(Client, :run, [op_w_selector, :default, params: params])
    measurements = %{duration: duration}

    case response do
      {:ok, response} ->
        candidates = Map.get(response, "items")
        candidate_count = length(candidates)
        measurements = Map.put(measurements, :count, candidate_count)
        Inst.get_eviction_candidates_succeeded(measurements)
        {:ok, candidates}

      {:errror, %HTTPoison.Response{status_code: status}} = error ->
        Inst.get_eviction_candidates_failed(measurements, %{status: status})
        error
    end
  end

  @doc """
  Get a list of evictable pods on the given node pool.

  Filters `candidates/1` by `pod_started_before/1` and optionally `on_unpreferred_node/N`
  """
  @spec evictable(map) :: {:ok, list(map)} | {:error, HTTPoison.Response.t()}
  def evictable(%{} = policy) do
    with {:ok, nodes} <- get_nodes(),
         {:ok, candidates} <- candidates(policy) do
      max_lifetime = max_lifetime(policy)
      started_before = pods_started_before(candidates, max_lifetime)

      ready_for_eviction =
        case mode(policy) do
          :all -> started_before
          :unpreferred -> pods_on_unpreferred_node(started_before, nodes)
        end

      {:ok, ready_for_eviction}
    end
  end

  @spec pods_on_unpreferred_node(list(map), list(map)) :: list(map)
  defp pods_on_unpreferred_node(pods, nodes) do
    Enum.filter(pods, fn pod -> pod_on_unpreferred_node(pod, nodes) end)
  end

  @spec pod_on_unpreferred_node(map, list(map)) :: boolean
  def pod_on_unpreferred_node(
        %{
          "spec" => %{
            "nodeName" => node_name,
            "affinity" => %{"nodeAffinity" => %{"preferredDuringSchedulingIgnoredDuringExecution" => affinity}}
          }
        },
        nodes
      ) do
    prefs = Enum.map(affinity, fn a -> Map.get(a, "preference") end)

    preferred =
      nodes
      |> find_node_by_name(node_name)
      |> Ballast.Kube.Node.matches_preferences?(prefs)

    !preferred
  end

  def pod_on_unpreferred_node(_pod_with_no_affinity, _nodes), do: false

  @spec find_node_by_name(list(map), binary()) :: map() | nil
  defp find_node_by_name(nodes, node_name) do
    Enum.find(nodes, fn %{"metadata" => %{"name" => name}} -> name == node_name end)
  end

  @doc false
  @spec pods_started_before(list(map), pos_integer) :: list(map())
  def pods_started_before(pods, max_lifetime) do
    Enum.filter(pods, fn pod -> pod_started_before(pod, max_lifetime) end)
  end

  @doc """
  Check if a pod started before a given time

  ## Examples
      iex> start_time = DateTime.utc_now |> DateTime.add(-61, :second) |> DateTime.to_string
      ...> Ballast.Evictor.pod_started_before(%{"status" => %{"startTime" => start_time}}, 60)
      true

      iex> start_time = DateTime.utc_now |> DateTime.to_string
      ...> Ballast.Evictor.pod_started_before(%{"status" => %{"startTime" => start_time}}, 60)
      false
  """
  @spec pod_started_before(map, pos_integer) :: boolean
  def pod_started_before(%{"status" => %{"startTime" => start_time}}, seconds) do
    seconds_ago = -parse_seconds(seconds)
    cutoff_time = DateTime.utc_now() |> DateTime.add(seconds_ago, :second)

    with {:ok, start_time, _} <- DateTime.from_iso8601(start_time),
         :lt <- DateTime.compare(start_time, cutoff_time) do
      true
    else
      _ -> false
    end
  end

  def pod_started_before(_, _), do: false

  @spec max_lifetime(map()) :: pos_integer()
  defp max_lifetime(%{"spec" => %{"maxLifetime" => sec}}), do: parse_seconds(sec)
  defp max_lifetime(_), do: @default_max_lifetime

  @spec mode(map()) :: :all | :unpreferred
  defp mode(%{"spec" => %{"mode" => "unpreferred"}}), do: :unpreferred
  defp mode(_), do: :all

  @spec parse_seconds(binary() | pos_integer() | {pos_integer(), term()}) :: pos_integer()
  defp parse_seconds(sec) when is_binary(sec), do: sec |> Integer.parse() |> parse_seconds
  defp parse_seconds(sec) when is_integer(sec), do: sec
  defp parse_seconds({sec, _}), do: sec
  defp parse_seconds(_), do: 0

  defp get_nodes() do
    op = K8s.Client.list("v1", :nodes)

    with {:ok, stream} <- K8s.Client.stream(op, :default) do
      nodes = Enum.into(stream, [])
      {:ok, nodes}
    end
  end
end
