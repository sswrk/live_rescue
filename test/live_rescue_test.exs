defmodule LiveRescueTest do
  use ExUnit.Case

  describe "has_error?/1" do
    test "returns false when no error state in socket" do
      assigns = %{socket: %{private: %{}}}
      refute LiveRescue.has_error?(assigns)
    end

    test "returns false when socket has no private key" do
      assigns = %{}
      refute LiveRescue.has_error?(assigns)
    end

    test "returns true when error is set in socket private" do
      assigns = %{socket: %{private: %{__live_rescue__: %{error: true}}}}
      assert LiveRescue.has_error?(assigns)
    end
  end
end
