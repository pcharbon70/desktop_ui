defmodule DesktopUI.Layout.HBoxTest do
  use ExUnit.Case
  alias DesktopUI.{Layout, Layout.Context, Widget}

  describe "HBox intrinsic size" do
    test "calculates width as sum of children" do
      # "Hi" = 2 chars * 8 = 16px width
      # Total width = 16 + 16 = 32px
      widget = Widget.container(:hbox, [
        Widget.label("Hi"),
        Widget.label("Hi")
      ])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Width = sum of children (32px)
      assert layout.width == 32
    end

    test "calculates height as max of children" do
      # Both labels are 16px height
      # Max height = 16px
      widget = Widget.container(:hbox, [
        Widget.label("Hello"),  # 40px width, 16px height
        Widget.label("Hi")      # 16px width, 16px height
      ])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Height = max child height (16px)
      assert layout.height == 16
    end

    test "adds spacing between children" do
      # "A" = 1 char * 8 = 8px width
      # "B" = 1 char * 8 = 8px width
      # Spacing: 10px
      # Total = 8 + 8 + 10 = 26px
      widget = Widget.container(:hbox, [
        Widget.label("A"),
        Widget.label("B")
      ], spacing: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 26
    end

    test "adds spacing only between children, not after last" do
      # Three labels: 8px + 8px + 8px = 24px width
      # Spacing between: 2 gaps * 10px = 20px
      # Total = 24 + 20 = 44px
      widget = Widget.container(:hbox, [
        Widget.label("A"),
        Widget.label("B"),
        Widget.label("C")
      ], spacing: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 44
    end

    test "adds padding to all sides" do
      # Label: 40px width (5 chars), 16px height
      # Padding: 10px on each side = 20px total
      # Total = 40 + 20 = 60px width, 16 + 20 = 36px height
      widget = Widget.container(:hbox, [
        Widget.label("Hello")
      ], padding: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 60
      assert layout.height == 36
    end

    test "returns minimum size for empty container" do
      widget = Widget.container(:hbox, [])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Empty containers get minimum size from constraints (default min_width/min_height = 1)
      assert layout.height == 1
      assert layout.width == 1
    end
  end

  describe "HBox child positioning" do
    test "arranges children horizontally" do
      widget = Widget.container(:hbox, [
        Widget.label("A"),  # 8px width
        Widget.label("B")   # 8px width
      ])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Container has children
      assert layout.widget.children != nil
      assert length(layout.widget.children) == 2

      # First child at x=0
      first_child = Enum.at(layout.widget.children, 0)
      assert first_child.x == 0

      # Second child at x=8 (after first child)
      second_child = Enum.at(layout.widget.children, 1)
      assert second_child.x == 8
    end

    test "positions first child at padding offset" do
      widget = Widget.container(:hbox, [
        Widget.label("A")
      ], padding: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      first_child = Enum.at(layout.widget.children, 0)
      assert first_child.x == 10
      assert first_child.y == 10
    end

    test "adds spacing between children" do
      widget = Widget.container(:hbox, [
        Widget.label("A"),  # 8px width
        Widget.label("B")   # 8px width
      ], spacing: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # First child at x=0
      first_child = Enum.at(layout.widget.children, 0)
      assert first_child.x == 0

      # Second child at x=18 (8 + 10 spacing)
      second_child = Enum.at(layout.widget.children, 1)
      assert second_child.x == 18
    end

    test "does not add spacing after last child" do
      widget = Widget.container(:hbox, [
        Widget.label("A"),  # 8px width
        Widget.label("B"),  # 8px width
        Widget.label("C")   # 8px width
      ], spacing: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Positions: 0, 18, 36
      first = Enum.at(layout.widget.children, 0)
      second = Enum.at(layout.widget.children, 1)
      third = Enum.at(layout.widget.children, 2)

      assert first.x == 0
      assert second.x == 18
      assert third.x == 36
    end

    test "spacing and padding work together" do
      widget = Widget.container(:hbox, [
        Widget.label("A"),  # 8px width
        Widget.label("B")   # 8px width
      ], spacing: 10, padding: 5)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # First child at x=5 (padding)
      first = Enum.at(layout.widget.children, 0)
      assert first.x == 5

      # Second child at x=23 (5 + 8 + 10)
      second = Enum.at(layout.widget.children, 1)
      assert second.x == 23
    end
  end

  describe "HBox alignment" do
    test ":top aligns children to top edge" do
      widget = Widget.container(:hbox, [
        Widget.label("Hi")  # 16px height
      ], padding: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      child = Enum.at(layout.widget.children, 0)
      # Top alignment = padding
      assert child.y == 10
    end

    test ":top aligns children when explicitly set" do
      widget = Widget.container(:hbox, [
        Widget.label("Hi")  # 16px height
      ], padding: 10, align: :top)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      child = Enum.at(layout.widget.children, 0)
      assert child.y == 10
    end

    test ":center centers children vertically" do
      # Child height: 16px
      # Available height: 600 - 20 (padding) = 580px
      # Center position = 10 + (580 - 16) / 2 = 10 + 282 = 292
      widget = Widget.container(:hbox, [
        Widget.label("Hi")
      ], padding: 10, align: :center)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      child = Enum.at(layout.widget.children, 0)
      # Centered in available space: 10 + div(580 - 16, 2) = 10 + 282 = 292
      assert child.y == 292
    end

    test ":bottom aligns children to bottom edge" do
      # Child height: 16px
      # Available height: 600 - 20 (padding) = 580px
      # Bottom position = 10 + (580 - 16) = 574
      widget = Widget.container(:hbox, [
        Widget.label("Hi")  # 16px height
      ], padding: 10, align: :bottom)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      child = Enum.at(layout.widget.children, 0)
      assert child.y == 574
    end

    test "alignment works with multiple children" do
      widget = Widget.container(:hbox, [
        Widget.label("A"),  # 8px width, 16px height
        Widget.label("BB")  # 16px width, 16px height
      ], padding: 10, align: :center)

      {:ok, layout} = Layout.calculate(widget, %{width: 200, height: 100})

      first = Enum.at(layout.widget.children, 0)
      second = Enum.at(layout.widget.children, 1)

      # Available height: 100 - 20 = 80px
      # Both should be centered at y = 10 + div(80 - 16, 2) = 10 + 32 = 42
      assert first.y == 42
      assert second.y == 42
    end
  end

  describe "HBox padding" do
    test "insets children from container edges" do
      widget = Widget.container(:hbox, [
        Widget.label("Hi")
      ], padding: 20)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      child = Enum.at(layout.widget.children, 0)
      assert child.x == 20
      assert child.y == 20
    end

    test "reduces available space for children" do
      # Container with 100px height, 20px padding
      # Child available height = 100 - 40 = 60px
      widget = Widget.container(:hbox, [
        Widget.label("A")
      ], padding: 20)

      {:ok, layout} = Layout.calculate(widget, %{width: 100, height: 100})

      # Child should be positioned correctly
      # The actual available space calculation happens during layout
      child = Enum.at(layout.widget.children, 0)
      assert child.x == 20
      assert child.y == 20
    end

    test "padding works with all alignment options" do
      for align <- [:top, :center, :bottom] do
        widget = Widget.container(:hbox, [
          Widget.label("Hi")
        ], padding: 15, align: align)

        {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

        child = Enum.at(layout.widget.children, 0)
        assert child.x == 15
      end
    end
  end

  describe "HBox overflow" do
    test "handles children exceeding available width" do
      # Create children that total more than available width
      # Each child is 40px (5 chars), so 10 children = 400px
      children = for _i <- 1..10, do: Widget.label("Hello")

      widget = Widget.container(:hbox, children)

      # Available width is only 300px
      {:ok, layout} = Layout.calculate(widget, %{width: 300, height: 600})

      # Container width is clamped to available bounds
      assert layout.width == 300
    end

    test "clamps container to available bounds when constrained" do
      # Create children that total more than available width
      children = for _i <- 1..10, do: Widget.label("Text")

      widget = Widget.container(:hbox, children)

      # Context with max_width constraint
      context = Context.new(800, 600, constraints: [max_width: 200])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600}, context)

      # Container should be clamped to max_width
      assert layout.width == 200
    end
  end

  describe "HBox with constraints" do
    test "respects min_width constraint" do
      widget = Widget.container(:hbox, [
        Widget.label("Hi")  # Small content
      ])

      context = Context.new(800, 600, constraints: [min_width: 200])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600}, context)

      assert layout.width >= 200
    end

    test "respects max_width constraint" do
      widget = Widget.container(:hbox, [
        Widget.label("A very long text here")  # Wide content
      ])

      context = Context.new(800, 600, constraints: [max_width: 50])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600}, context)

      assert layout.width <= 50
    end

    test "respects fixed_width constraint" do
      widget = Widget.container(:hbox, [
        Widget.label("Content")
      ])

      context = Context.new(800, 600, constraints: [fixed_width: 300])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600}, context)

      assert layout.width == 300
    end

    test "respects fixed_height constraint" do
      widget = Widget.container(:hbox, [
        Widget.label("A"),
        Widget.label("B")
      ])

      context = Context.new(800, 600, constraints: [fixed_height: 100])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600}, context)

      assert layout.height == 100
    end
  end

  describe "HBox nested containers" do
    test "handles hbox containing vbox" do
      inner_vbox = Widget.container(:vbox, [
        Widget.label("Inner 1"),
        Widget.label("Inner 2")
      ])

      widget = Widget.container(:hbox, [
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

    test "calculates correct size for nested hbox" do
      inner_hbox = Widget.container(:hbox, [
        Widget.label("A"),
        Widget.label("B")
      ])

      widget = Widget.container(:hbox, [
        Widget.label("Outer"),
        inner_hbox
      ])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Outer: 40px + (8 + 8) = 56px width
      assert layout.width == 56
    end

    test "handles vbox containing hbox" do
      inner_hbox = Widget.container(:hbox, [
        Widget.label("A"),
        Widget.label("B")
      ])

      widget = Widget.container(:vbox, [
        Widget.label("Outer"),
        inner_hbox
      ])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Outer: 16px (label) + 16px (inner hbox height) = 32px height
      assert layout.height == 32
    end
  end

  describe "HBox edge cases" do
    test "handles single child" do
      widget = Widget.container(:hbox, [
        Widget.label("Only")
      ])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      assert layout.width == 32  # "Only" = 4 chars * 8
      assert layout.height == 16
    end

    test "handles zero spacing" do
      widget = Widget.container(:hbox, [
        Widget.label("A"),
        Widget.label("B")
      ], spacing: 0)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Width: 8 + 8 = 16px (no spacing)
      assert layout.width == 16
    end

    test "handles zero padding" do
      widget = Widget.container(:hbox, [
        Widget.label("A")
      ], padding: 0)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      child = Enum.at(layout.widget.children, 0)
      assert child.x == 0
      assert child.y == 0
    end

    test "defaults to top alignment" do
      widget = Widget.container(:hbox, [
        Widget.label("Hi")
      ], padding: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      child = Enum.at(layout.widget.children, 0)
      # Should default to top alignment
      assert child.y == 10
    end
  end

  describe "HBox with buttons" do
    test "layouts buttons horizontally" do
      # Button: text + (20px width, 10px height) padding
      # "Hi" = 16px + 20px = 36px width, 26px height
      # "Bye" = 24px + 20px = 44px width, 26px height
      widget = Widget.container(:hbox, [
        Widget.button("Hi", :hi),
        Widget.button("Bye", :bye)
      ], spacing: 5)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Width: 36 + 5 + 44 = 85px
      assert layout.width == 85

      # Height: max(26, 26) = 26px
      assert layout.height == 26
    end

    test "positions buttons correctly with spacing" do
      widget = Widget.container(:hbox, [
        Widget.button("A", :a),
        Widget.button("B", :b)
      ], spacing: 10)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      first = Enum.at(layout.widget.children, 0)
      second = Enum.at(layout.widget.children, 1)

      # First at x=0, second at x=38 (button "A" width 28px + 10px spacing)
      assert first.x == 0
      assert second.x == 38
    end
  end

  describe "HBox with varying heights" do
    test "height is max of children heights" do
      # All labels are 16px height
      # But let's test with buttons which are taller
      widget = Widget.container(:hbox, [
        Widget.label("Text"),     # 16px height
        Widget.button("Btn", :b)  # 26px height
      ])

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      # Height = max(16, 26) = 26px
      assert layout.height == 26
    end

    test "shorter children are aligned correctly" do
      widget = Widget.container(:hbox, [
        Widget.label("A"),         # 16px height
        Widget.button("Tall", :t)  # 26px height
      ], align: :center)

      {:ok, layout} = Layout.calculate(widget, %{width: 800, height: 600})

      first = Enum.at(layout.widget.children, 0)
      second = Enum.at(layout.widget.children, 1)

      # Each child is centered independently within the available height
      # Available: 600px
      # Label (16px): y = div(600 - 16, 2) = 292
      # Button (26px): y = div(600 - 26, 2) = 287
      assert first.y == 292
      assert second.y == 287
    end
  end
end
