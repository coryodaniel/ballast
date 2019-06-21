defmodule Ballast.Kube do
  @moduledoc """
  Abstractions around the kubernetes resources and the [`k8s`](https://hexdocs.pm/k8s/readme.html) library.
  """

  @default_list_operation_limit 100

  # @typedoc "K8s pagination request"
  # @type request_t :: %{
  #         kind: atom | binary,
  #         group_version: binary,
  #         continue: nil | binary | :halt,
  #         limit: nil | pos_integer,
  #         # :namespace for list/N
  #         list_opts: map,
  #         # :params for run/N
  #         run_opts: map
  #       }

  # @type state_t :: {list(map), request_t}

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

  def stream(group_version, kind, opts \\ []) do
    start = fn ->
      case list(group_version, kind, opts) do
        {:ok, items, continue} ->
          {items, continue}

        _error ->
          {[], nil}
      end
    end

    fetch_next_page = fn
      state = {_, :halt} ->
        {:halt, state}

      state = {[], continue} ->
        case list(group_version, kind, opts, @default_list_operation_limit, continue) do
          {:ok, items, continue} -> pop_item({items, continue})
          {:error, _msg} -> {:halt, state}
        end
    end

    next_item = fn
      state = {[], nil} ->
        {:halt, state}

      state = {[], _next} ->
        fetch_next_page.(state)

      state ->
        pop_item(state)
    end

    Stream.resource(start, next_item, &stop/1)
  end

  @spec do_continue(map) :: :halt | binary
  defp do_continue(%{"metadata" => %{"continue" => ""}}), do: :halt
  defp do_continue(%{"metadata" => %{"continue" => cont}}) when is_binary(cont), do: cont
  defp do_continue(_map), do: :halt

  @doc false
  @spec pop_item({list(), binary}) :: {[term], {list(), binary}}
  # Return the next item to the stream caller `[head]` and return the tail as the new state of the Stream
  def pop_item({[head | tail], next}) do
    new_state = {tail, next}
    {[head], new_state}
  end

  @doc false
  @spec stop(list()) :: nil
  # Stop processing the stream.
  def stop(_state), do: nil
end
