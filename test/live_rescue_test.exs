defmodule LiveRescueTest do
  use ExUnit.Case

  describe "has_error?/1" do
    test "returns false when no error in assigns" do
      assigns = %{}
      refute LiveRescue.has_error?(assigns)
    end

    test "returns false when __live_rescue__ exists but no error" do
      assigns = %{__live_rescue__: %{}}
      refute LiveRescue.has_error?(assigns)
    end

    test "returns true when error is set" do
      assigns = %{__live_rescue__: %{error: true}}
      assert LiveRescue.has_error?(assigns)
    end
  end
end
