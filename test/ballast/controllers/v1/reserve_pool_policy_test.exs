defmodule Ballast.Controller.V1.ReservePoolPolicyTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Ballast.Controller.V1.ReservePoolPolicy

  describe "add/1" do
    test "returns :ok" do
      event = %{}
      result = ReservePoolPolicy.add(event)
      assert result == :ok
    end
  end

  describe "modify/1" do
    test "returns :ok" do
      event = %{}
      result = ReservePoolPolicy.modify(event)
      assert result == :ok
    end
  end

  describe "delete/1" do
    test "returns :ok" do
      event = %{}
      result = ReservePoolPolicy.delete(event)
      assert result == :ok
    end
  end

  describe "reconcile/1" do
    test "returns :ok" do
      event = %{}
      result = ReservePoolPolicy.reconcile(event)
      assert result == :ok
    end
  end
end
