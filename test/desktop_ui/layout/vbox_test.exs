defmodule DesktopUI.Layout.VBoxTest do
  use ExUnit.Case
  alias DesktopUI.{Layout, Layout.Context, Widget}

  describe "VBox intrinsic size" do
    test "calculates height as sum of children" do
      # "Hi" = 2 chars * 8 = 16px width, 16px height
      # Total height = 16 + 16 = 32px
      widget = Widget.container(:vbox, [
        Widget.label("Hi"),
        Widget.label("Hi")
      ])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Height = sum of children (32px)
      assert layout.height == 32
    end

    test "calculates width as max of children" do
      # "Hello" = 5 chars * 8 = 40px width
      # "Hi" = 2 chars * 8 = 16px width
      # Max width = 40px
      widget = Widget.container(:vbox, [
        Widget.label("Hello"),
        Widget.label("Hi")
      ])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Width = max child width (40px)
      assert layout.width == 40
    end

    test "adds spacing between children" do
      # Two labels: 16px + 16px = 32px height
      # Spacing: 10px
      # Total = 32 + 10 = 42px
      widget = Widget.container(:vbox, [
        Widget.label("A"),
        Widget.label("B")
      ], spacing: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.height == 42
    end

    test "adds spacing only between children, not after last" do
      # Three labels: 16px * 3 = 48px height
      # Spacing between: 2 gaps * 10px = 20px
      # Total = 48 + 20 = 68px
      widget = Widget.container(:vbox, [
        Widget.label("A"),
        Widget.label("B"),
        Widget.label("C")
      ], spacing: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.height == 68
    end

    test "adds padding to all sides" do
      # Label: 16px height, 40px width (5 chars)
      # Padding: 10px on each side = 20px total
      # Total = 16 + 20 = 36px height, 40 + 20 = 60px width
      widget = Widget.container(:vbox, [
        Widget.label("Hello")
      ], padding: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.height == 36
      assert layout.width == 60
    end

    test "returns minimum size for empty container" do
      widget = Widget.container(:vbox, [])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Empty containers get minimum size from constraints (default min_width/min_height = 1)
      assert layout.height == 1
      assert layout.width == 1
    end
  end

  describe "VBox child positioning" do
    test "stacks children vertically" do
      widget = Widget.container(:vbox, [
        Widget.label("A"),  # 16px height
        Widget.label("B")   # 16px height
      ])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Container has children
      assert layout.widget.children != nil
      assert length(layout.widget.children) == 2

      # First child at y=0
      first_child = Enum.at(layout.widget.children, 0)
      assert first_child.y == 0

      # Second child at y=16 (below first child)
      second_child = Enum.at(layout.widget.children, 1)
      assert second_child.y == 16
    end

    test "positions first child at padding offset" do
      widget = Widget.container(:vbox, [
        Widget.label("A")
      ], padding: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      first_child = Enum.at(layout.widget.children, 0)
      assert first_child.y == 10
      assert first_child.x == 10
    end

    test "adds spacing between children" do
      widget = Widget.container(:vbox, [
        Widget.label("A"),  # 16px height
        Widget.label("B")   # 16px height
      ], spacing: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # First child at y=0
      first_child = Enum.at(layout.widget.children, 0)
      assert first_child.y == 0

      # Second child at y=26 (16 + 10 spacing)
      second_child = Enum.at(layout.widget.children, 1)
      assert second_child.y == 26
    end

    test "does not add spacing after last child" do
      widget = Widget.container(:vbox, [
        Widget.label("A"),  # 16px height
        Widget.label("B"),  # 16px height
        Widget.label("C")   # 16px height
      ], spacing: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Positions: 0, 26, 52
      # Not: 0, 26, 52 (with extra 10 at end)
      first = Enum.at(layout.widget.children, 0)
      second = Enum.at(layout.widget.children, 1)
      third = Enum.at(layout.widget.children, 2)

      assert first.y == 0
      assert second.y == 26
      assert third.y == 52
    end

    test "spacing and padding work together" do
      widget = Widget.container(:vbox, [
        Widget.label("A"),  # 16px height
        Widget.label("B")   # 16px height
      ], spacing: 10, padding: 5)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # First child at y=5 (padding)
      first = Enum.at(layout.widget.children, 0)
      assert first.y == 5

      # Second child at y=31 (5 + 16 + 10)
      second = Enum.at(layout.widget.children, 1)
      assert second.y == 31
    end
  end

  describe "VBox alignment" do
    test ":left aligns children to left edge" do
      widget = Widget.container(:vbox, [
        Widget.label("Hi")  # 16px width
      ], padding: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      child = Enum.at(layout.widget.children, 0)
      # Left alignment = padding
      assert child.x == 10
    end

    test ":left aligns children when explicitly set" do
      widget = Widget.container(:vbox, [
        Widget.label("Hi")  # 16px width
      ], padding: 10, align: :left)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      child = Enum.at(layout.widget.children, 0)
      assert child.x == 10
    end

    test ":center centers children horizontally" do
      # Child width: 16px
      # Available width: 800 - 20 (padding) = 780px
      # Center position = 10 + (780 - 16) / 2 = 10 + 382 = 392
      widget = Widget.container(:vbox, [
        Widget.label("Hi")
      ], padding: 10, align: :center)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      child = Enum.at(layout.widget.children, 0)
      # Centered in available space: 10 + div(780 - 16, 2) = 10 + 382 = 392
      assert child.x == 392
    end

    test ":right aligns children to right edge" do
      # Child width: 16px
      # Available width: 800 - 20 (padding) = 780px
      # Right position = 10 + (780 - 16) = 774
      widget = Widget.container(:vbox, [
        Widget.label("Hi")  # 16px width
      ], padding: 10, align: :right)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      child = Enum.at(layout.widget.children, 0)
      assert child.x == 774
    end

    test "alignment works with multiple children" do
      widget = Widget.container(:vbox, [
        Widget.label("A"),  # 8px width
        Widget.label("BB")  # 16px width
      ], padding: 10, align: :center)

      {:ok, layout} = Layout.calculate(widget, %{width: 200, height: 600})

      first = Enum.at(layout.widget.children, 0)
      second = Enum.at(layout.widget.children, 1)

      # Available width: 200 - 20 = 180px
      # First: 10 + div(180 - 8, 2) = 10 + 86 = 96
      # Second: 10 + div(180 - 16, 2) = 10 + 82 = 92
      assert first.x == 96
      assert second.x == 92
    end
  end

  describe "VBox padding" do
    test "insets children from container edges" do
      widget = Widget.container(:vbox, [
        Widget.label("Hi")
      ], padding: 20)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      child = Enum.at(layout.widget.children, 0)
      assert child.x == 20
      assert child.y == 20
    end

    test "reduces available space for children" do
      # Container with 100px width, 20px padding
      # Child available width = 100 - 40 = 60px
      widget = Widget.container(:vbox, [
        Widget.label("A very long text that should be constrained")
      ], padding: 20)

      {:ok, layout} = Layout.calculate(widget, %{width: 100, height: 100})

      child = Enum.at(layout.widget.children, 0)
      # Child width should be constrained by available space (60px)
      assert child.width <= 60
    end

    test "padding works with all alignment options" do
      for align <- [:left, :center, :right] do
        widget = Widget.container(:vbox, [
          Widget.label("Hi")
        ], padding: 15, align: align)

        {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

        child = Enum.at(layout.widget.children, 0)
        assert child.y == 15
      end
    end
  end

  describe "VBox overflow" do
    test "handles children exceeding available height" do
      # Create children that total more than available height
      # Each child is 16px, so 10 children = 160px
      children = for _i <- 1..10, do: Widget.label("Text")

      widget = Widget.container(:vbox, children)

      # Available height is only 100px
      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 100})

      # Container height is clamped to available bounds
      # The layout system clamps to available space to prevent overflow
      assert layout.height == 100
    end

    test "clamps container to available bounds when constrained" do
      # Create children that total more than available height
      children = for _i <- 1..10, do: Widget.label("Text")

      widget = Widget.container(:vbox, children)

      # Context with max_height constraint
      context = Context.new(800, 600, constraints: [max_height: 100])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600}, context)

      # Container should be clamped to max_height
      assert layout.height == 100
    end
  end

  describe "VBox with constraints" do
    test "respects min_width constraint" do
      widget = Widget.container(:vbox, [
        Widget.label("Hi")  # Small content
      ])

      context = Context.new(800, 600, constraints: [min_width: 200])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600}, context)

      assert layout.width >= 200
    end

    test "respects max_width constraint" do
      widget = Widget.container(:vbox, [
        Widget.label("A very long text here")  # Wide content
      ])

      context = Context.new(800, 600, constraints: [max_width: 50])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600}, context)

      assert layout.width <= 50
    end

    test "respects fixed_width constraint" do
      widget = Widget.container(:vbox, [
        Widget.label("Content")
      ])

      context = Context.new(800, 600, constraints: [fixed_width: 300])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600}, context)

      assert layout.width == 300
    end

    test "respects fixed_height constraint" do
      widget = Widget.container(:vbox, [
        Widget.label("A"),
        Widget.label("B")
      ])

      context = Context.new(800, 600, constraints: [fixed_height: 100])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600}, context)

      assert layout.height == 100
    end
  end

  describe "VBox with buttons" do
    test "layouts buttons vertically" do
      # Button: text + (20px width, 10px height) padding
      # "OK" = 2 chars * 8 = 16px + 20px = 36px width, 16px + 10px = 26px height
      # "Cancel" = 6 chars * 8 = 48px + 20px = 68px width, 26px height
      widget = Widget.container(:vbox, [
        Widget.button("OK", :ok),
        Widget.button("Cancel", :cancel)
      ], spacing: 5)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Height: 26 + 5 + 26 = 57px
      assert layout.height == 57

      # Width: max(36, 68) = 68px (container expands to fit widest child)
      assert layout.width == 68
    end

    test "positions buttons correctly with spacing" do
      widget = Widget.container(:vbox, [
        Widget.button("A", :a),
        Widget.button("B", :b)
      ], spacing: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      first = Enum.at(layout.widget.children, 0)
      second = Enum.at(layout.widget.children, 1)

      # First at y=0, second at y=36 (button height) + 10 (spacing)
      assert first.y == 0
      assert second.y == 36
    end
  end

  describe "VBox nested containers" do
    test "handles vbox containing labels" do
      inner_vbox = Widget.container(:vbox, [
        Widget.label("Inner 1"),
        Widget.label("Inner 2")
      ])

      widget = Widget.container(:vbox, [
        Widget.label("Outer"),
        inner_vbox
      ])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Outer container should have children
      assert length(layout.widget.children) == 2

      # Second child is the inner vbox
      inner = Enum.at(layout.widget.children, 1)
      assert inner.widget != nil
    end

    test "calculates correct size for nested vbox" do
      inner_vbox = Widget.container(:vbox, [
        Widget.label("A"),
        Widget.label("B")
      ])

      widget = Widget.container(:vbox, [
        Widget.label("Outer"),
        inner_vbox
      ])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Outer: 16 + (16 + 16) = 48px height
      assert layout.height == 48
    end
  end

  describe "VBox edge cases" do
    test "handles single child" do
      widget = Widget.container(:vbox, [
        Widget.label("Only")
      ])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.height == 16
      assert layout.width == 32  # "Only" = 4 chars * 8
    end

    test "handles zero spacing" do
      widget = Widget.container(:vbox, [
        Widget.label("A"),
        Widget.label("B")
      ], spacing: 0)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Height: 16 + 16 = 32px (no spacing)
      assert layout.height == 32
    end

    test "handles zero padding" do
      widget = Widget.container(:vbox, [
        Widget.label("A")
      ], padding: 0)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      child = Enum.at(layout.widget.children, 0)
      assert child.x == 0
      assert child.y == 0
    end

    test "defaults to left alignment" do
      widget = Widget.container(:vbox, [
        Widget.label("Hi")
      ], padding: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      child = Enum.at(layout.widget.children, 0)
      # Should default to left alignment
      assert child.x == 10
    end
  end
end
