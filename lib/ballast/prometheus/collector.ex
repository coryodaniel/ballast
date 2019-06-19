defmodule Ballast.Prometheus.Collector do
  @moduledoc """
  Prometheus observations of telemetry metrics
  """
  use Prometheus.Metric

  # @historgram [
  #   name: :ballast_pod_eviction_succeeded,
  #   labels: [:method],
  #   buckets: [100, 300, 500, 750, 1000],
  #   help: "Http Request execution time"
  # ]
  # Histogram.observe([name: :http_request_duration_milliseconds, labels: [method]], time)

  @counter [
    name: :ballast_pod_eviction_count,
    help: "Pod eviction count",
    labels: [:node, :pod]
  ]

  @counter [
    name: :ballast_pod_eviction_failure_count,
    help: "Pod eviction failure count",
    labels: [:node, :pod]
  ]

  @spec attach() :: :ok
  @doc "Attach `Ballast.Instrumentation` to prometheus"
  def attach() do
    # events = Ballast.Instrumentation.events()
    events = [
      [:ballast, :pod, :eviction, :succeeded],
      [:ballast, :pod, :eviction, :failed]
    ]

    :telemetry.attach_many("ballast-prometheus-exporter", events, &event_handler/4, :info)
    :ok
  end

  @doc false
  @spec event_handler(keyword, map | integer, map, term) :: :ok
  def event_handler([:ballast, :pod, :eviction, status], _measurements, %{node: node, pod: pod}, _config) do
    labels = [
      normalize_node_label(node),
      normalize_pod_label(pod)
    ]

    Counter.inc(name: :ballast_pod_eviction_count, labels: labels)

    if status == :failed do
      Counter.inc(name: :ballast_pod_eviction_failure_count, labels: labels)
    end

    :ok
  end

  # Removes node suffixes: gke-ballast-ballast-od-n1-1-5197e85c-6jss => gke-ballast-ballast-od-n1-1
  # Probably should exist in adapter? I guess we'll see.
  @spec normalize_node_label(binary) :: binary
  def normalize_node_label(node) do
    parts = String.split(node, "-")
    prefix_length = length(parts) - 2

    parts
    |> Enum.take(prefix_length)
    |> Enum.join("-")
  end

  # Removes pod suffixes: nginx-deployment-7c7cf6cc9c-6t6g4 => nginx-deployment
  # Probably should be bassed in formatted from evictor.ex as this could get hairy :shrug:
  @spec normalize_pod_label(binary) :: binary
  def normalize_pod_label(pod) do
    parts = String.split(pod, "-")
    prefix_length = length(parts) - 2

    parts
    |> Enum.take(prefix_length)
    |> Enum.join("-")
  end
end
