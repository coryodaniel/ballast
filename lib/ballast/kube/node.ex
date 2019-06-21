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

  @spec all() :: nil
  def all() do
    nil
    # recursively get all, see
  end

  @spec ready?(map()) :: boolean()
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
  def ready?(%{"status" => %{"conditions" => conditions}} = _node) do
    conditions
    |> find_condition_by_type("Ready")
    |> condition_has_status?("True")
  end

  def ready?(_), do: false

  @spec resources_constrained?(map) :: boolean
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
  def resources_constrained?(node), do: !!first_constrained_condition(node)

  @spec first_constrained_condition(map) :: map | nil
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
