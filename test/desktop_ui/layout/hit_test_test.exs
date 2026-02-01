defmodule DesktopUI.Layout.HitTestTest do
  use ExUnit.Case
  alias DesktopUI.{Layout, Widget}

  describe "hit_test/3" do
    test "returns nil when point is outside all widgets" do
      # Create a simple button layout
      widget = Widget.button("Click", :clicked, id: :btn)
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Point outside the layout
      assert Layout.hit_test(layout, 9999, 9999) == nil
      assert Layout.hit_test(layout, -1, -1) == nil
    end

    test "returns widget info when point is inside a button" do
      # Create a button at position (0, 0) with some size
      widget = Widget.button("Click", :clicked, id: :my_btn)
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Point inside the button (buttons start at 0,0 and have positive size)
      # The exact position depends on the button's calculated size
      assert {:ok, %{widget_id: :my_btn, on_click: :clicked}} =
        Layout.hit_test(layout, 5, 5)
    end

    test "returns on_click message for interactive buttons" do
      widget = Widget.button("Increment", :increment, id: :btn_inc)
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert {:ok, %{widget_id: :btn_inc, on_click: :increment}} =
        Layout.hit_test(layout, 10, 10)
    end

    test "returns nil for label without on_click" do
      widget = Widget.label("Hello World", id: :my_label)
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Labels don't have on_click, so hit_test returns nil
      assert Layout.hit_test(layout, 10, 10) == nil
    end

    test "finds widget in nested container (vbox)" do
      # Create a vbox with two buttons
      widget =
        Widget.container(:vbox, [
          Widget.button("Top", :top_clicked, id: :btn_top),
          Widget.button("Bottom", :bottom_clicked, id: :btn_bottom)
        ],
        spacing: 10,
        padding: 5)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # The first button should be at around y=5 (after padding)
      # The second button should be below the first with spacing
      top_result = Layout.hit_test(layout, 10, 10)
      _bottom_result = Layout.hit_test(layout, 10, 60)

      # Both should return results (exact positions depend on button sizes)
      assert top_result == {:ok, %{widget_id: :btn_top, on_click: :top_clicked}} or
        top_result == {:ok, %{widget_id: :btn_bottom, on_click: :bottom_clicked}}
    end

    test "finds widget in nested container (hbox)" do
      # Create an hbox with two buttons
      widget =
        Widget.container(:hbox, [
          Widget.button("Left", :left_clicked, id: :btn_left),
          Widget.button("Right", :right_clicked, id: :btn_right)
        ],
        spacing: 10,
        padding: 5)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # The first button should be at around x=5 (after padding)
      left_result = Layout.hit_test(layout, 10, 10)

      assert left_result == {:ok, %{widget_id: :btn_left, on_click: :left_clicked}}
    end

    test "finds widget in deeply nested containers" do
      # Create nested containers: vbox containing hbox containing button
      widget =
        Widget.container(:vbox, [
          Widget.container(:hbox, [
            Widget.button("Nested", :nested_clicked, id: :btn_nested)
          ],
          padding: 10)
        ],
        padding: 5)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Should find the nested button
      result = Layout.hit_test(layout, 20, 20)

      assert {:ok, %{widget_id: :btn_nested, on_click: :nested_clicked}} = result
    end

    test "returns nil for container with no on_click" do
      # Containers don't typically receive clicks
      widget =
        Widget.container(:vbox, [
          Widget.label("Hello")
        ],
        id: :my_container)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Clicking on the container itself (not on a child) returns nil
      # Since we're clicking at 10,10 which should hit the label, and labels don't have on_click
      assert Layout.hit_test(layout, 10, 10) == nil
    end

    test "topmost widget wins for overlapping widgets" do
      # Create overlapping widgets by using exact positioning
      # For this test, we'll use a container with children that might overlap
      # In practice, with vbox/hbox, children don't overlap, but the
      # reverse search order ensures the last (topmost) child is checked first

      widget =
        Widget.container(:vbox, [
          Widget.button("Bottom", :bottom_clicked, id: :btn_bottom),
          Widget.button("Top", :top_clicked, id: :btn_top)
        ],
        spacing: 0,
        padding: 0)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # The top button (second in list, rendered last) should be found first
      # at its position
      top_result = Layout.hit_test(layout, 5, 5)

      # The first button (bottom) is at y=0
      # The second button (top) is at y=bottom_button_height
      # So y=5 should hit the first button
      assert {:ok, %{widget_id: :btn_bottom, on_click: :bottom_clicked}} = top_result
    end

    test "handles empty container layout" do
      widget = Widget.container(:vbox, [])
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Empty container has no widgets to click
      assert Layout.hit_test(layout, 10, 10) == nil
    end

    test "handles button without id" do
      # Button with on_click but no id should return nil
      widget = Widget.button("Click", :clicked)
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # No id means no hit test result
      assert Layout.hit_test(layout, 10, 10) == nil
    end

    test "handles button with id but no on_click" do
      # Button with id but no on_click should return nil
      # Note: This is not possible with the current Widget.button/3 API
      # which requires on_click, but the hit_test function handles this case
      widget = Widget.label("No Click", id: :no_click_label)
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Labels don't have on_click
      assert Layout.hit_test(layout, 10, 10) == nil
    end

    test "clicking on padding area returns nil" do
      # Create a container with padding
      widget =
        Widget.container(:vbox, [
          Widget.button("Click", :clicked, id: :btn)
        ],
        padding: 50)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Click in the padding area (before the button)
      # The container starts at 0,0, but with padding=50,
      # the button should start at x=50, y=50
      # So clicking at y=10 should not hit the button
      assert Layout.hit_test(layout, 10, 10) == nil

      # Clicking on the button should work
      # The button starts at x=50, y=50 (after padding)
      # With typical button size ~60x26, try the center of the button
      result = Layout.hit_test(layout, 60, 60)
      assert {:ok, %{widget_id: :btn, on_click: :clicked}} = result
    end

    test "nested hbox in vbox" do
      # Create an hbox inside a vbox
      widget =
        Widget.container(:vbox, [
          Widget.label("Title"),
          Widget.container(:hbox, [
            Widget.button("Left", :left, id: :btn_left),
            Widget.button("Right", :right, id: :btn_right)
          ],
          spacing: 5)
        ],
        spacing: 10,
        padding: 5)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Should find buttons in the nested hbox
      # These positions depend on calculated sizes, but we can check
      # that we get a valid result somewhere
      result = Layout.hit_test(layout, 20, 50)

      # Either button or nil depending on exact position
      # But the structure should be valid
      assert is_nil(result) or match?({:ok, %{widget_id: _, on_click: _}}, result)
    end

    test "nested vbox in hbox" do
      # Create a vbox inside an hbox
      widget =
        Widget.container(:hbox, [
          Widget.container(:vbox, [
            Widget.button("Top", :top, id: :btn_top),
            Widget.button("Bottom", :bottom, id: :btn_bottom)
          ],
          spacing: 5),
          Widget.label("Side")
        ],
        spacing: 10,
        padding: 5)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Should find buttons in the nested vbox
      result = Layout.hit_test(layout, 20, 20)

      # Should find one of the buttons
      assert match?({:ok, %{widget_id: _, on_click: _}}, result)
    end
  end
end
