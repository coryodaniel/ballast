defmodule Ballast.Kube do
  @moduledoc """
  Abstractions around the kubernetes resources and the [`k8s`](https://hexdocs.pm/k8s/readme.html) library.
  """

  @default_list_operation_limit 25

  def test() do
    "v1"
    |> Ballast.Kube.stream(:nodes)
    |> Stream.filter(&Ballast.Kube.Node.ready?/1)
    |> Stream.map(fn %{"metadata" => %{"name" => name}} -> name end)
    |> Enum.into([])
  end

  def list(version, kind, opts, limit \\ @default_list_operation_limit, continue \\ nil)

  def list(version, kind, opts, limit, continue) do
    pagination_params = %{limit: limit, continue: continue}
    params = Map.merge(opts[:params] || %{}, pagination_params)

    version
    |> K8s.Client.list(kind, opts)
    |> K8s.Client.run(:default, params: params)
    |> case do
      {:ok, response} ->
        items = Map.get(response, "items")
        {:ok, items, do_continue(response)}

      {:error, msg} ->
        {:error, msg}
    end
  end

  # stream(version, kind,
  #   namespace: "foo",
  #   params: %{
  #     # labelSelector: "",
  #     labelSelector: ~s[cloud.google.com/gke-nodepool="#{name}"]
  #   }
  # )

  def stream(version, kind, opts \\ []) do
    start = fn ->
      case list(version, kind, opts) do
        {:ok, items, continue} ->
          {items, continue}

        _error ->
          {[], nil}
      end
    end

    # Use pattern matching to pop the top item off the list of items, passing the
    # tail as the new state.
    pop_item = fn {[head | tail], next} ->
      new_state = {tail, next}
      {[head], new_state}
    end

    # Get the next page, and use pop_item to both set the new state and return the
    # first item of the new page.
    fetch_next_page = fn
      state = {_, :halt} ->
        {:halt, state}

      state = {[], continue} ->
        case list(version, kind, opts, @default_list_operation_limit, continue) do
          {:ok, items, continue} -> pop_item.({items, continue})
          {:error, _msg} -> {:halt, state}
        end
    end

    next_item = fn
      state = {[], nil} ->
        {:halt, state}

      state = {[], _next} ->
        fetch_next_page.(state)

      state ->
        pop_item.(state)
    end

    stop = fn _state -> nil end

    Stream.resource(start, next_item, stop)
  end

  @spec do_continue(map) :: :halt | binary
  defp do_continue(%{"metadata" => %{"continue" => ""}}), do: :halt
  defp do_continue(%{"metadata" => %{"continue" => cont}}) when is_binary(cont), do: cont
  defp do_continue(_map), do: :halt
end
