defmodule Ballast.Evictor do
  @moduledoc """
  Finds pods that are candidates for eviction.
  """

  @label "ballast.bonny.run/evictableAfter"
  @pod_batch_size 500
  @cluster_name :default

  alias K8s.Client
  alias Ballast.Instrumentation, as: Inst

  @doc """
  Gets all pods with eviction enabled.
  TODO: if continue, gather all pods first and return
  """
  def candidates() do
    operation = Client.list("v1", "pod", namespace: :all)
    {duration, response} = :timer.tc(Client, :run, [operation, @cluster_name, params: pod_query()])
    measurements = %{duration: duration}

    case response do
      {:ok, response} ->
        Inst.get_eviction_candidates_succeeded(measurements)
        {:ok, Map.get(response, "items")}

      error ->
        Inst.get_eviction_candidates_failed(measurements)
        error
    end
  end

  def evictable() do
    with {:ok, candidates} <- candidates(),
         pods <- Enum.filter(candidates, &pod_started_before/1) do
      {:ok, pods}
    end
  end

  def evictable(match: pattern) do
    with {:ok, candidates} <- evictable(),
         pods <- Enum.filter(candidates, &pod_spec_node_name_matches(&1, pattern)) do
      {:ok, pods}
    end
  end

  @doc """
  Determines if a pod's assigned node matches a substring

  ## Examples
      iex> Ballast.Evictor.pod_spec_node_name_matches(%{"spec" => %{"nodeName" => "cloud-cool-pool-65678"}}, "cool-pool")
      true

      iex> Ballast.Evictor.pod_spec_node_name_matches(%{"spec" => %{"nodeName" => "cloud-cool-pool-65678"}}, "uncool-pool")
      false
  """
  def pod_spec_node_name_matches(%{"spec" => %{"nodeName" => name}}, substring), do: String.contains?(name, substring)
  def pod_spec_node_name_matches(_, _), do: false

  @doc """
  Check if a pod started before a given time

  ## Examples
      iex> start_time = DateTime.utc_now |> DateTime.add(-61, :second) |> DateTime.to_string
      ...> metadata = %{"labels" => %{"#{@label}" => "60"}}
      ...> Ballast.Evictor.pod_started_before(%{"metadata" => metadata, "status" => %{"startTime" => start_time}})
      true

      iex> start_time = DateTime.utc_now |> DateTime.to_string
      ...> metadata = %{"labels" => %{"#{@label}" => "60"}}
      ...> Ballast.Evictor.pod_started_before(%{"metadata" => metadata, "status" => %{"startTime" => start_time}})
      false
  """
  @spec pod_started_before(map) :: boolean
  def pod_started_before(%{"metadata" => %{"labels" => %{@label => seconds}}, "status" => %{"startTime" => start_time}}) do
    seconds_ago = -parse_seconds(seconds)
    cutoff_time = DateTime.utc_now() |> DateTime.add(seconds_ago, :second)

    with {:ok, start_time, _} <- DateTime.from_iso8601(start_time),
         :lt <- DateTime.compare(start_time, cutoff_time) do
      true
    else
      _ -> false
    end
  end

  def pod_started_before(_), do: false

  defp parse_seconds(sec) when is_binary(sec), do: sec |> Integer.parse() |> parse_seconds
  defp parse_seconds(sec) when is_integer(sec), do: sec
  defp parse_seconds({sec, _}), do: sec
  defp parse_seconds(_), do: 0

  @spec pod_query() :: keyword
  defp pod_query(), do: [{:labelSelector, @label}, {:limit, @pod_batch_size}]
end