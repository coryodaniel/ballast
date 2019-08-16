defmodule Ballast.Controller.V1.EvictionPolicyTest do
  @moduledoc false
  use ExUnit.Case, async: false
  alias Ballast.Controller.V1.EvictionPolicy

  describe "add/1" do
    test "returns :ok" do
      event = %{}
      result = EvictionPolicy.add(event)
      assert result == :ok
    end
  end

  describe "modify/1" do
    test "returns :ok" do
      event = %{}
      result = EvictionPolicy.modify(event)
      assert result == :ok
    end
  end

  describe "delete/1" do
    test "returns :ok" do
      event = %{}
      result = EvictionPolicy.delete(event)
      assert result == :ok
    end
  end

  describe "reconcile/1" do
    test "returns :ok" do
      event = %{}
      result = EvictionPolicy.reconcile(event)
      assert result == :ok
    end
  end
end
