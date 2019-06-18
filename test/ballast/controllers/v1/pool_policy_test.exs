defmodule Ballast.Controller.V1.PoolPolicyTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Ballast.Controller.V1.PoolPolicy

  @spec make_resource() :: map()
  defp make_resource() do
    YamlElixir.read_from_file!("test/support/resource.yaml")
  end

  describe "add/1" do
    test "returns :ok" do
      event = make_resource()
      result = PoolPolicy.add(event)
      assert result == :ok
    end
  end

  describe "modify/1" do
    test "returns :ok" do
      event = make_resource()
      result = PoolPolicy.modify(event)
      assert result == :ok
    end
  end

  describe "delete/1" do
    test "returns :ok" do
      event = make_resource()
      result = PoolPolicy.delete(event)
      assert result == :ok
    end
  end

  describe "reconcile/1" do
    test "returns :ok" do
      event = make_resource()
      result = PoolPolicy.reconcile(event)
      assert result == :ok
    end
  end
end
