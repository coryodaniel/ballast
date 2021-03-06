defmodule Ballast.Kube.Node do
  @moduledoc """
  Encapsulates a Kubernetes [`Node` resource](https://kubernetes.io/docs/concepts/architecture/nodes/).
  """

  @kind "Node"

  @resources_constrainted_conditions [
    # "NetworkUnavailable",
    "OutOfDisk",
    "MemoryPressure",
    "PIDPressure",
    "DiskPressure"
  ]

  alias K8s.{Client, Resource}
  alias Ballast.Sys.Instrumentation, as: Inst

  @doc """
  List kubernetes nodes.
  """
  @spec list(map()) :: {:ok, list(map)} | :error
  def list(params \\ %{}) do
    op = Client.list("v1", :nodes)

    with {:ok, stream} <- Client.stream(op, :default, params: params) do
      {duration, nodes} = :timer.tc(Enum, :into, [stream, []])
      measurements = %{duration: duration, count: length(nodes)}
      Inst.nodes_list_succeeded(measurements, %{})

      {:ok, nodes}
    else
      _error ->
        Inst.nodes_list_failed(%{}, %{})
        :error
    end
  end

  @doc """
  Checks if `status.conditions` are present and node is `Ready`

  [Node Status](https://kubernetes.io/docs/concepts/architecture/nodes/#node-status)

  ## Examples
    When `status.conditions` is present, and node is `Ready`

      iex> node = %{
      ...>   "kind" => "#{@kind}",
      ...>   "status" => %{
      ...>     "conditions" => [
      ...>       %{"type" => "MemoryPressure", "status" => "False"},
      ...>       %{"type" => "Ready", "status" => "True"}
      ...>     ]
      ...>    }
      ...> }
      ...> Ballast.Kube.Node.ready?(node)
      true

    When `status.conditions` is present, and node is not `Ready`

      iex> node = %{
      ...>   "kind" => "#{@kind}",
      ...>   "status" => %{
      ...>     "conditions" => [%{"type" => "Ready", "status" => "False"}]
      ...>    }
      ...> }
      ...> Ballast.Kube.Node.ready?(node)
      false

    When `status.conditions` is missing:

      iex> node = %{"kind" => "#{@kind}"}
      ...> Ballast.Kube.Node.ready?(node)
      false
  """
  @spec ready?(map()) :: boolean()
  def ready?(%{"status" => %{"conditions" => conditions}} = _node) do
    conditions
    |> find_condition_by_type("Ready")
    |> condition_has_status?("True")
  end

  def ready?(_), do: false

  # Currently only supports mNatchExpressions (not matchFields)
  # Also ignores weight of preferences
  @doc false
  @spec matches_preferences?(map, list(map)) :: boolean
  def matches_preferences?(node, prefs) do
    Enum.any?(prefs, fn pref ->
      exprs = Map.get(pref, "matchExpressions", %{})
      match_expressions?(node, exprs)
    end)
  end

  @doc """
  Checks if a node matches all `matchExpressions` logical `AND`

  ## Examples
    Matching all expressions:

      iex> node = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "prod", "tier" => "frontend"}}}
      ...> expr1 = %{"operator" => "In", "key" => "env", "values" => ["prod", "qa"]}
      ...> expr2 = %{"operator" => "Exists", "key" => "tier"}
      ...> Ballast.Kube.Node.match_expressions?(node, [expr1, expr2])
      true

    Matching some expressions:

      iex> node = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "prod", "tier" => "frontend"}}}
      ...> expr1 = %{"operator" => "In", "key" => "env", "values" => ["prod", "qa"]}
      ...> expr2 = %{"operator" => "Exists", "key" => "foo"}
      ...> Ballast.Kube.Node.match_expressions?(node, [expr1, expr2])
      false
  """
  @spec match_expressions?(map, list(map)) :: boolean
  def match_expressions?(node, exprs) do
    Enum.all?(exprs, fn expr -> match_expression?(node, expr) end)
  end

  @doc """
  Checks whether a node matches a selector `matchExpression`

  ## Examples
    When an `In` expression matches
      iex> node = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "prod"}}}
      ...> expr = %{"operator" => "In", "key" => "env", "values" => ["prod", "qa"]}
      ...> Ballast.Kube.Node.match_expression?(node, expr)
      true

    When an `In` expression doesnt match
      iex> node = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "dev"}}}
      ...> expr = %{"operator" => "In", "key" => "env", "values" => ["prod", "qa"]}
      ...> Ballast.Kube.Node.match_expression?(node, expr)
      false

    When an `NotIn` expression matches
      iex> node = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "dev"}}}
      ...> expr = %{"operator" => "NotIn", "key" => "env", "values" => ["prod"]}
      ...> Ballast.Kube.Node.match_expression?(node, expr)
      true

    When an `NotIn` expression doesnt match
      iex> node = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "dev"}}}
      ...> expr = %{"operator" => "NotIn", "key" => "env", "values" => ["dev"]}
      ...> Ballast.Kube.Node.match_expression?(node, expr)
      false

    When an `Exists` expression matches
      iex> node = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "dev"}}}
      ...> expr = %{"operator" => "Exists", "key" => "env"}
      ...> Ballast.Kube.Node.match_expression?(node, expr)
      true

    When an `Exists` expression doesnt match
      iex> node = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "dev"}}}
      ...> expr = %{"operator" => "Exists", "key" => "tier"}
      ...> Ballast.Kube.Node.match_expression?(node, expr)
      false

    When an `DoesNotExist` expression matches
      iex> node = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "dev"}}}
      ...> expr = %{"operator" => "DoesNotExist", "key" => "tier"}
      ...> Ballast.Kube.Node.match_expression?(node, expr)
      true

    When an `DoesNotExist` expression doesnt match
      iex> node = %{"kind" => "Node", "metadata" => %{"labels" => %{"env" => "dev"}}}
      ...> expr = %{"operator" => "DoesNotExist", "key" => "env"}
      ...> Ballast.Kube.Node.match_expression?(node, expr)
      false
  """
  @spec match_expression?(map(), map()) :: boolean()
  def match_expression?(%{} = node, %{"operator" => "In", "key" => k, "values" => v}) do
    label = Resource.label(node, k)
    Enum.member?(v, label)
  end

  def match_expression?(%{} = node, %{"operator" => "NotIn", "key" => k, "values" => v}) do
    label = Resource.label(node, k)
    !Enum.member?(v, label)
  end

  def match_expression?(%{} = node, %{"operator" => "Exists", "key" => k}) do
    Resource.has_label?(node, k)
  end

  def match_expression?(%{} = node, %{"operator" => "DoesNotExist", "key" => k}) do
    !Resource.has_label?(node, k)
  end

  def match_expression?(_, _), do: false

  @doc """
  Percent CPU available

  ## Examples
    iex> node = %{"status" => %{"allocatable" => %{"cpu" => "940m"}, "capacity" => %{"cpu" => "1"}}}
    ...> Ballast.Kube.Node.percent_cpu_available(node)
    0.94
  """
  @spec percent_cpu_available(map) :: float
  def percent_cpu_available(node) do
    {allocatable, capacity} = get_field_status(node, "cpu")
    Resource.cpu(allocatable) / Resource.cpu(capacity)
  end

  @doc """
  Percent memory available

  ## Examples
    iex> node = %{"status" => %{"allocatable" => %{"memory" => "8Gi"}, "capacity" => %{"memory" => "16Gi"}}}
    ...> Ballast.Kube.Node.percent_memory_available(node)
    0.50
  """
  @spec percent_memory_available(map) :: float
  def percent_memory_available(node) do
    {allocatable, capacity} = get_field_status(node, "memory")
    Resource.memory(allocatable) / Resource.memory(capacity)
  end

  @doc """
  Percent pods available

  ## Examples
    iex> node = %{"status" => %{"allocatable" => %{"pods" => "20"}, "capacity" => %{"pods" => "100"}}}
    ...> Ballast.Kube.Node.percent_pods_available(node)
    0.20
  """
  @spec percent_pods_available(map) :: float
  def percent_pods_available(node) do
    {allocatable, capacity} = get_field_status(node, "pods")
    String.to_integer(allocatable) / String.to_integer(capacity)
  end

  defp get_field_status(node, field) do
    allocatable = get_in(node, ["status", "allocatable", field])
    capacity = get_in(node, ["status", "capacity", field])

    {allocatable, capacity}
  end

  @doc """
  Finds the node with the most CPU

  ## Examples
      iex> node1 = %{"metadata" => %{"name" => "foo"}, "status" => %{"allocatable" => %{"cpu" => "940m"}}}
      ...> node2 = %{"metadata" => %{"name" => "bar"}, "status" => %{"allocatable" => %{"cpu" => "1"}}}
      ...> Ballast.Kube.Node.with_most_cpu([node1, node2])
      %{"metadata" => %{"name" => "bar"},"status" => %{"allocatable" => %{"cpu" => "1"}}}
  """
  @spec with_most_cpu(list(map)) :: map
  def with_most_cpu(nodes) do
    initial = {0, nil}

    {_highest, node} =
      Enum.reduce(nodes, initial, fn node, {highest, _} = acc ->
        cpu =
          node
          |> get_in(["status", "allocatable", "cpu"])
          |> Resource.cpu()

        case cpu > highest do
          true ->
            {cpu, node}

          false ->
            acc
        end
      end)

    node
  end

  @doc """
  Finds the node with the most memory

  ## Examples
      iex> node1 = %{"metadata" => %{"name" => "foo"}, "status" => %{"allocatable" => %{"memory" => "10Gi"}}}
      ...> node2 = %{"metadata" => %{"name" => "bar"}, "status" => %{"allocatable" => %{"memory" => "3Gi"}}}
      ...> Ballast.Kube.Node.with_most_memory([node1, node2])
      %{"metadata" => %{"name" => "foo"}, "status" => %{"allocatable" => %{"memory" => "10Gi"}}}
  """
  @spec with_most_memory(list(map)) :: map
  def with_most_memory(nodes) do
    initial = {0, nil}

    {_highest, node} =
      Enum.reduce(nodes, initial, fn node, {highest, _} = acc ->
        memory =
          node
          |> get_in(["status", "allocatable", "memory"])
          |> Resource.memory()

        case memory > highest do
          true ->
            {memory, node}

          false ->
            acc
        end
      end)

    node
  end

  @doc """
  Check the node's conditions to see if they are contrained, under pressure, or insufficient.

  [Node Conditions](https://kubernetes.io/docs/concepts/architecture/nodes/#condition)

  The checked conditions are: `#{inspect(@resources_constrainted_conditions)}`

  ## Examples
    Is constrained if any of the conditions listed above are constrained

      iex> node = %{
      ...>   "kind" => "#{@kind}",
      ...>   "status" => %{
      ...>     "conditions" => [
      ...>       %{"type" => "PIDPressure", "status" => "False"},
      ...>       %{"type" => "MemoryPressure", "status" => "True"}
      ...>     ]
      ...>    }
      ...> }
      ...> Ballast.Kube.Node.resources_constrained?(node)
      true

    Is constrained if the status is "Unknown"

    Is not constrained when an unknown condition is constrained
  """
  @spec resources_constrained?(map) :: boolean
  def resources_constrained?(node), do: !!first_constrained_condition(node)

  @doc """
  Returns the first constrained condition

  The checked conditions are: `#{inspect(@resources_constrainted_conditions)}`

  ## Examples
      iex> node = %{
      ...>   "kind" => "#{@kind}",
      ...>   "status" => %{
      ...>     "conditions" => [
      ...>       %{"type" => "PIDPressure", "status" => "False"},
      ...>       %{"type" => "MemoryPressure", "status" => "True"}
      ...>     ]
      ...>    }
      ...> }
      ...> Ballast.Kube.Node.first_constrained_condition(node)
      %{"type" => "MemoryPressure", "status" => "True"}
  """
  @spec first_constrained_condition(map) :: map | nil
  def first_constrained_condition(%{"status" => %{"conditions" => conditions}} = _node) do
    Enum.find(conditions, fn %{"type" => type} = condition ->
      case condition_has_status?(condition, "True") do
        true ->
          Enum.member?(@resources_constrainted_conditions, type)

        _ ->
          false
      end
    end)
  end

  def first_constrained_condition(_), do: nil

  @spec find_condition_by_type(list(map()), binary()) :: map()
  defp find_condition_by_type([], _), do: nil

  defp find_condition_by_type(conditions, type) do
    Enum.find(conditions, fn condition ->
      condition["type"] == type
    end)
  end

  @spec condition_has_status?(map | nil, binary) :: boolean()
  defp condition_has_status?(%{"status" => status}, status), do: true
  defp condition_has_status?(_, _), do: false
end
